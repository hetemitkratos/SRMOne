package main

import (
	"fmt"
	"net/url"
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
	client    *fasthttp.Client
}

const spHost = "sp.srmist.edu.in"
const spBaseURL = "https://sp.srmist.edu.in"
const spUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"

func NewSPClient() *SPClient {
	return &SPClient{
		jar:       NewSPCookieJar(),
		userAgent: spUserAgent,
		client: &fasthttp.Client{
			MaxConnsPerHost:        64,
			MaxIdleConnDuration:    90 * time.Second,
			ReadTimeout:            30 * time.Second,
			WriteTimeout:           30 * time.Second,
			MaxConnWaitTimeout:     10 * time.Second,
			DisablePathNormalizing: true,
		},
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
		req := fasthttp.AcquireRequest()
		resp := fasthttp.AcquireResponse()

		req.SetRequestURI(currentURL)
		req.Header.SetMethod(currentMethod)
		req.Header.Set("User-Agent", c.userAgent)
		req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
		req.Header.Set("Accept-Language", "en-US,en;q=0.9")
		req.Header.Set("Connection", "close") // Disable keep-alive to prevent server dropped connection errors

		if contentType != "" {
			req.Header.Set("Content-Type", contentType)
		}

		if cookieStr := c.jar.CookieHeader(); cookieStr != "" {
			req.Header.Set("Cookie", cookieStr)
		}

		for key, val := range extraHeaders {
			req.Header.Set(key, val)
		}

		if len(currentBody) > 0 {
			req.SetBody(currentBody)
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
			fasthttp.ReleaseRequest(req)
			fasthttp.ReleaseResponse(resp)
			return SPRequestSnapshot{}, fmt.Errorf("request to %s failed: %w", currentURL, err)
		}

		var setCookies []string
		resp.Header.VisitAll(func(key, value []byte) {
			if strings.EqualFold(string(key), "Set-Cookie") {
				setCookies = append(setCookies, string(value))
			}
		})
		if len(setCookies) > 0 {
			c.jar.SetCookies(setCookies)
		}

		statusCode := resp.StatusCode()
		location := string(resp.Header.Peek("Location"))
		respBody := append([]byte(nil), resp.Body()...)

		headers := make(map[string]string)
		resp.Header.VisitAll(func(key, value []byte) {
			headers[string(key)] = string(value)
		})

		snap := SPRequestSnapshot{
			StatusCode: statusCode,
			URL:        currentURL,
			Location:   location,
			Body:       respBody,
			Headers:    headers,
		}

		fasthttp.ReleaseRequest(req)
		fasthttp.ReleaseResponse(resp)

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
