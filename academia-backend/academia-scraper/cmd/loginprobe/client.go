package main

import (
	"fmt"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/valyala/fasthttp"
)

// CookieJar is a manual cookie jar for fasthttp, which doesn't ship one.
// It stores cookies per-domain (host-only) and replays them as a Cookie header.
type CookieJar struct {
	mu      sync.Mutex
	cookies map[string]map[string]string // host -> name -> value
}

func NewCookieJar() *CookieJar {
	return &CookieJar{cookies: make(map[string]map[string]string)}
}

// SetCookies stores cookies from a Set-Cookie response header for the given host.
func (j *CookieJar) SetCookies(host string, setCookieHeaders []string) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if j.cookies[host] == nil {
		j.cookies[host] = make(map[string]string)
	}
	for _, raw := range setCookieHeaders {
		// Parse "name=value; Path=/; ..." — take only name=value
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
			delete(j.cookies[host], name)
			continue
		}
		j.cookies[host][name] = val
	}
}

// SeedCookies injects pre-known cookies (from a serialized session) for a host.
func (j *CookieJar) SeedCookies(host string, cookies map[string]string) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if j.cookies[host] == nil {
		j.cookies[host] = make(map[string]string)
	}
	for name, val := range cookies {
		if val != "" {
			j.cookies[host][name] = val
		}
	}
}

// CookieHeader returns a "name1=val1; name2=val2" string for the host.
func (j *CookieJar) CookieHeader(host string) string {
	j.mu.Lock()
	defer j.mu.Unlock()
	hostCookies := j.cookies[host]
	if len(hostCookies) == 0 {
		return ""
	}
	parts := make([]string, 0, len(hostCookies))
	for name, val := range hostCookies {
		parts = append(parts, name+"="+val)
	}
	return strings.Join(parts, "; ")
}

// Cookies returns all cookies for a host as a map (for serialization / inspection).
func (j *CookieJar) Cookies(host string) map[string]string {
	j.mu.Lock()
	defer j.mu.Unlock()
	out := make(map[string]string, len(j.cookies[host]))
	for k, v := range j.cookies[host] {
		out[k] = v
	}
	return out
}

// CookieNames returns sorted cookie names for a host.
func (j *CookieJar) CookieNames(host string) []string {
	c := j.Cookies(host)
	names := make([]string, 0, len(c))
	for name := range c {
		names = append(names, name)
	}
	// sort
	for i := 0; i < len(names); i++ {
		for k := i + 1; k < len(names); k++ {
			if names[k] < names[i] {
				names[i], names[k] = names[k], names[i]
			}
		}
	}
	return names
}

// HasCookie checks if a named cookie exists for the host.
func (j *CookieJar) HasCookie(host, name string) bool {
	j.mu.Lock()
	defer j.mu.Unlock()
	_, ok := j.cookies[host][name]
	return ok
}

// GetCookie returns a single cookie value, or "".
func (j *CookieJar) GetCookie(host, name string) string {
	j.mu.Lock()
	defer j.mu.Unlock()
	return j.cookies[host][name]
}

// ---------------------------------------------------------------------------
// FHClient — a fasthttp-based HTTP client with cookie jar + manual redirects.
// ---------------------------------------------------------------------------

type FHClient struct {
	jar            *CookieJar
	userAgent      string
	host           string // target host, e.g. "academia.srmist.edu.in"
	client         *fasthttp.Client
	csrfParam      string
	csrfCookie     string
	defaultReferer string
}

func NewFHClient(host, userAgent string) *FHClient {
	return &FHClient{
		jar:       NewCookieJar(),
		userAgent: userAgent,
		host:      host,
		client: &fasthttp.Client{
			MaxConnsPerHost:        20,
			ReadTimeout:            60 * time.Second,
			WriteTimeout:           60 * time.Second,
			DisablePathNormalizing: true,
			ReadBufferSize:         16384,
		},
	}
}

// CSRFHeaderValue returns "param=value" from the CSRF cookie, or "".
func (c *FHClient) CSRFHeaderValue() string {
	val := c.jar.GetCookie(c.host, c.csrfCookie)
	if val == "" {
		return ""
	}
	return c.csrfParam + "=" + val
}

// RequestSnapshot mirrors the original code's requestSnapshot for compatibility.
type RequestSnapshot struct {
	Name       string
	Method     string
	URL        string
	StatusCode int
	Location   string
	Body       []byte
	Headers    map[string]string
}

// DoRequest performs an HTTP request with manual redirect following.
// followRedirects=true follows 3xx up to 10 hops (matching original behavior).
func (c *FHClient) DoRequest(name, method, rawURL string, body []byte, contentType string, extraHeaders map[string]string, followRedirects bool) (RequestSnapshot, error) {
	currentURL := rawURL
	currentMethod := method
	currentBody := append([]byte(nil), body...)

	for redirects := 0; redirects < 10; redirects++ {
		req := fasthttp.AcquireRequest()
		defer fasthttp.ReleaseRequest(req)
		resp := fasthttp.AcquireResponse()
		defer fasthttp.ReleaseResponse(resp)

		req.SetRequestURI(currentURL)
		req.Header.SetMethod(currentMethod)

		// Standard headers
		req.Header.Set("User-Agent", c.userAgent)
		req.Header.Set("Accept", "*/*")
		req.Header.Set("Accept-Language", "en-US,en;q=0.9")
		req.Header.Set("Connection", "keep-alive")

		// Default Referer (can be overridden by extraHeaders)
		if c.defaultReferer != "" {
			req.Header.Set("Referer", c.defaultReferer)
		}

		if contentType != "" {
			req.Header.Set("Content-Type", contentType)
		}

		// Cookie jar → Cookie header
		parsedURL, err := url.Parse(currentURL)
		if err != nil {
			return RequestSnapshot{}, fmt.Errorf("invalid URL %s: %w", currentURL, err)
		}
		if cookieStr := c.jar.CookieHeader(parsedURL.Hostname()); cookieStr != "" {
			req.Header.Set("Cookie", cookieStr)
		}

		// CSRF token from cookie → X-ZCSRF-TOKEN header
		if c.csrfParam != "" {
			if token := c.CSRFHeaderValue(); token != "" {
				req.Header.Set("X-ZCSRF-TOKEN", token)
			}
		}

		// Extra headers (caller-specific, may override defaults)
		for key, val := range extraHeaders {
			req.Header.Set(key, val)
		}

		if len(currentBody) > 0 {
			req.SetBody(currentBody)
		}

		if err := fasthttp.Do(req, resp); err != nil {
			return RequestSnapshot{}, fmt.Errorf("%s request failed: %w", name, err)
		}

		// Collect Set-Cookie headers into the jar
		var setCookies []string
		resp.Header.VisitAll(func(key, value []byte) {
			if strings.EqualFold(string(key), "Set-Cookie") {
				setCookies = append(setCookies, string(value))
			}
		})
		if len(setCookies) > 0 {
			c.jar.SetCookies(parsedURL.Hostname(), setCookies)
		}

		statusCode := resp.StatusCode()
		location := string(resp.Header.Peek("Location"))
		respBody := append([]byte(nil), resp.Body()...)

		// Build headers map for snapshot
		headers := make(map[string]string)
		resp.Header.VisitAll(func(key, value []byte) {
			headers[string(key)] = string(value)
		})

		snap := RequestSnapshot{
			Name:       name,
			Method:     currentMethod,
			URL:        currentURL,
			StatusCode: statusCode,
			Location:   location,
			Body:       respBody,
			Headers:    headers,
		}

		// Redirect handling
		if followRedirects && isRedirect(statusCode) && location != "" {
			nextURL, err := resolveURL(currentURL, location)
			if err != nil {
				return snap, err
			}
			// 303/301/302 + non-GET/HEAD → switch to GET (per RFC + original behavior)
			if shouldSwitchToGet(statusCode, currentMethod) {
				currentMethod = "GET"
				currentBody = nil
				contentType = ""
			}
			currentURL = nextURL
			continue
		}

		return snap, nil
	}

	return RequestSnapshot{}, fmt.Errorf("too many redirects for %s", rawURL)
}

func isRedirect(status int) bool {
	return status >= 301 && status <= 308
}

func shouldSwitchToGet(status int, method string) bool {
	if method == "GET" || method == "HEAD" {
		return false
	}
	return status == 301 || status == 302 || status == 303
}
