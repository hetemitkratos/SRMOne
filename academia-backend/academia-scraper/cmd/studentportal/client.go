package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/valyala/fasthttp"
)

// ---------------------------------------------------------------------------
// CookieJar — simplified cookie jar for the student portal
// ---------------------------------------------------------------------------

type SPCookieJar struct {
	mu      sync.Mutex
	cookies map[string]string
}

func NewSPCookieJar() *SPCookieJar {
	return &SPCookieJar{cookies: make(map[string]string)}
}

func (j *SPCookieJar) SetCookies(setCookieHeaders []string) {
	j.mu.Lock()
	defer j.mu.Unlock()
	for _, raw := range setCookieHeaders {
		parts := strings.SplitN(raw, ";", 2)
		if len(parts) < 1 {
			continue
		}
		nv := strings.TrimSpace(parts[0])
		idx := strings.Index(nv, "=")
		if idx < 0 {
			continue
		}
		name := strings.TrimSpace(nv[:idx])
		val := strings.TrimSpace(nv[idx+1:])
		if val == "" || val == "delete" || val == "null" {
			delete(j.cookies, name)
			continue
		}
		j.cookies[name] = val
	}
}

func (j *SPCookieJar) SeedCookies(cookies map[string]string) {
	j.mu.Lock()
	defer j.mu.Unlock()
	for name, val := range cookies {
		if val != "" {
			j.cookies[name] = val
		}
	}
}

func (j *SPCookieJar) CookieHeader() string {
	j.mu.Lock()
	defer j.mu.Unlock()
	if len(j.cookies) == 0 {
		return ""
	}
	parts := make([]string, 0, len(j.cookies))
	for name, val := range j.cookies {
		parts = append(parts, name+"="+val)
	}
	return strings.Join(parts, "; ")
}

func (j *SPCookieJar) Serialized() []SPSerializedCookie {
	j.mu.Lock()
	defer j.mu.Unlock()
	out := make([]SPSerializedCookie, 0, len(j.cookies))
	for name, val := range j.cookies {
		out = append(out, SPSerializedCookie{Name: name, Value: val})
	}
	return out
}

func (j *SPCookieJar) HasCookie(name string) bool {
	j.mu.Lock()
	defer j.mu.Unlock()
	_, ok := j.cookies[name]
	return ok
}

func (j *SPCookieJar) GetCookie(name string) string {
	j.mu.Lock()
	defer j.mu.Unlock()
	return j.cookies[name]
}

// ---------------------------------------------------------------------------
// SPClient — fasthttp client for the student portal
// ---------------------------------------------------------------------------

type SPClient struct {
	jar       *SPCookieJar
	userAgent string
	relay     *spRelay // non-nil when SP_RELAY_URL is set
}

const spHost = "sp.srmist.edu.in"
const spBaseURL = "https://sp.srmist.edu.in"
const spUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"

func NewSPClient() *SPClient {
	relay := newSPRelayFromEnv()
	if relay != nil {
		fmt.Fprintf(os.Stderr, "[spClient] routing portal traffic via relay %s\n", relay.url)
	}
	return &SPClient{
		jar:       NewSPCookieJar(),
		userAgent: spUserAgent,
		relay:     relay,
	}
}

type SPRequestSnapshot struct {
	StatusCode int
	URL        string
	Location   string
	Body       []byte
	Headers    map[string]string
}

func (c *SPClient) DoRequest(method, rawURL string, body []byte, contentType string, extraHeaders map[string]string, followRedirects bool) (SPRequestSnapshot, error) {
	currentURL := rawURL
	currentMethod := method
	currentBody := append([]byte(nil), body...)

	for redirects := 0; redirects < 10; redirects++ {
		headers := map[string]string{
			"User-Agent":      c.userAgent,
			"Accept":          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
			"Accept-Language": "en-US,en;q=0.9",
		}
		if contentType != "" {
			headers["Content-Type"] = contentType
		}
		if cookieStr := c.jar.CookieHeader(); cookieStr != "" {
			headers["Cookie"] = cookieStr
		}
		for key, val := range extraHeaders {
			headers[key] = val
		}

		var raw rawResponse
		var err error
		if c.relay != nil {
			raw, err = c.relay.send(currentMethod, currentURL, headers, currentBody)
		} else {
			raw, err = sendDirect(currentMethod, currentURL, headers, currentBody)
		}
		if err != nil {
			return SPRequestSnapshot{}, fmt.Errorf("request to %s failed: %w", currentURL, err)
		}

		if len(raw.setCookies) > 0 {
			c.jar.SetCookies(raw.setCookies)
		}

		statusCode := raw.status
		location := ""
		for k, v := range raw.headers {
			if strings.EqualFold(k, "Location") {
				location = v
				break
			}
		}

		snap := SPRequestSnapshot{
			StatusCode: statusCode,
			URL:        currentURL,
			Location:   location,
			Body:       raw.body,
			Headers:    raw.headers,
		}

		if followRedirects && isSPRedirect(statusCode) && location != "" {
			nextURL, err := resolveSPURL(currentURL, location)
			if err != nil {
				return snap, err
			}
			if shouldSPSwitchToGet(statusCode, currentMethod) {
				currentMethod = "GET"
				currentBody = nil
				contentType = ""
			}
			currentURL = nextURL
			continue
		}

		return snap, nil
	}

	return SPRequestSnapshot{}, fmt.Errorf("too many redirects for %s", rawURL)
}

// rawResponse is what a transport returns for one HTTP hop (no redirect
// following, no cookie handling — DoRequest does both).
type rawResponse struct {
	status     int
	headers    map[string]string
	setCookies []string
	body       []byte
}

// sendDirect performs the request from this process with fasthttp.
func sendDirect(method, rawURL string, headers map[string]string, body []byte) (rawResponse, error) {
	req := fasthttp.AcquireRequest()
	resp := fasthttp.AcquireResponse()
	defer fasthttp.ReleaseRequest(req)
	defer fasthttp.ReleaseResponse(resp)

	req.SetRequestURI(rawURL)
	req.Header.SetMethod(method)
	req.Header.Set("Connection", "close") // Disable keep-alive to prevent server dropped connection errors
	for key, val := range headers {
		req.Header.Set(key, val)
	}
	if len(body) > 0 {
		req.SetBody(body)
	}

	var err error
	for attempt := 0; attempt < 3; attempt++ {
		err = fasthttp.Do(req, resp)
		if err == nil {
			break
		}
		if strings.Contains(err.Error(), "the server closed connection") {
			time.Sleep(200 * time.Millisecond)
			continue
		}
		break
	}
	if err != nil {
		return rawResponse{}, err
	}

	out := rawResponse{
		status:  resp.StatusCode(),
		headers: make(map[string]string),
		body:    append([]byte(nil), resp.Body()...),
	}
	resp.Header.VisitAll(func(key, value []byte) {
		if strings.EqualFold(string(key), "Set-Cookie") {
			out.setCookies = append(out.setCookies, string(value))
			return
		}
		out.headers[string(key)] = string(value)
	})
	return out, nil
}

// spRelay forwards each hop through the Cloudflare Worker in
// relay/cf-worker. sp.srmist.edu.in answers login POSTs from Render's (and
// AWS's) egress IPs with a generic "Invalid credentials" page regardless of
// the captcha/password; Cloudflare's network is accepted.
type spRelay struct {
	url    string
	secret string
	client *http.Client
}

func newSPRelayFromEnv() *spRelay {
	relayURL := strings.TrimSpace(os.Getenv("SP_RELAY_URL"))
	if relayURL == "" {
		return nil
	}
	return &spRelay{
		url:    relayURL,
		secret: strings.TrimSpace(os.Getenv("SP_RELAY_SECRET")),
		client: &http.Client{Timeout: 60 * time.Second},
	}
}

type relayRequest struct {
	Method  string            `json:"method"`
	URL     string            `json:"url"`
	Headers map[string]string `json:"headers"`
	Body    string            `json:"body,omitempty"`
}

type relayResponse struct {
	Status    int               `json:"status"`
	Headers   map[string]string `json:"headers"`
	SetCookie []string          `json:"setCookie"`
	Body      string            `json:"body"`
	Error     string            `json:"error,omitempty"`
}

func (r *spRelay) send(method, rawURL string, headers map[string]string, body []byte) (rawResponse, error) {
	payload, err := json.Marshal(relayRequest{
		Method:  method,
		URL:     rawURL,
		Headers: headers,
		Body:    base64.StdEncoding.EncodeToString(body),
	})
	if err != nil {
		return rawResponse{}, fmt.Errorf("relay encode: %w", err)
	}

	req, err := http.NewRequest("POST", r.url, bytes.NewReader(payload))
	if err != nil {
		return rawResponse{}, fmt.Errorf("relay request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Relay-Secret", r.secret)

	resp, err := r.client.Do(req)
	if err != nil {
		return rawResponse{}, fmt.Errorf("relay transport: %w", err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return rawResponse{}, fmt.Errorf("relay read: %w", err)
	}

	var rr relayResponse
	if err := json.Unmarshal(respBytes, &rr); err != nil {
		preview := string(respBytes)
		if len(preview) > 200 {
			preview = preview[:200]
		}
		return rawResponse{}, fmt.Errorf("relay returned non-JSON (HTTP %d): %s", resp.StatusCode, preview)
	}
	if resp.StatusCode != http.StatusOK {
		return rawResponse{}, fmt.Errorf("relay error (HTTP %d): %s", resp.StatusCode, rr.Error)
	}

	decoded, err := base64.StdEncoding.DecodeString(rr.Body)
	if err != nil {
		return rawResponse{}, fmt.Errorf("relay body decode: %w", err)
	}
	if rr.Headers == nil {
		rr.Headers = map[string]string{}
	}
	return rawResponse{
		status:     rr.Status,
		headers:    rr.Headers,
		setCookies: rr.SetCookie,
		body:       decoded,
	}, nil
}

// logEgressIP prints the public IP this process is currently egressing from.
// Enabled with SP_DIAG_IP=1. Each call opens a fresh connection, so it shows
// whether the host's NAT rotates source IPs between requests.
func logEgressIP(label string) {
	if os.Getenv("SP_DIAG_IP") == "" {
		return
	}
	if os.Getenv("SP_RELAY_URL") != "" {
		fmt.Fprintf(os.Stderr, "[spDiag] %s: portal traffic goes via relay, local egress IP not relevant\n", label)
		return
	}
	req := fasthttp.AcquireRequest()
	resp := fasthttp.AcquireResponse()
	defer fasthttp.ReleaseRequest(req)
	defer fasthttp.ReleaseResponse(resp)
	req.SetRequestURI("https://api.ipify.org?format=text")
	req.Header.Set("Connection", "close")
	if err := fasthttp.DoTimeout(req, resp, 10*time.Second); err != nil {
		fmt.Fprintf(os.Stderr, "[spDiag] %s egress IP lookup failed: %v\n", label, err)
		return
	}
	fmt.Fprintf(os.Stderr, "[spDiag] %s egress IP=%s\n", label, strings.TrimSpace(string(resp.Body())))
}

func isSPRedirect(status int) bool {
	return status >= 301 && status <= 308
}

func shouldSPSwitchToGet(status int, method string) bool {
	if method == "GET" || method == "HEAD" {
		return false
	}
	return status == 301 || status == 302 || status == 303
}

func resolveSPURL(base, ref string) (string, error) {
	baseURL, err := url.Parse(base)
	if err != nil {
		return "", err
	}
	refURL, err := url.Parse(ref)
	if err != nil {
		return "", err
	}
	return baseURL.ResolveReference(refURL).String(), nil
}
