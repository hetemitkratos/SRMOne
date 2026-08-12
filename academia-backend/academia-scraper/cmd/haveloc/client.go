package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"time"

	"github.com/valyala/fasthttp"
)

// FHClient wraps a fasthttp.Client with auth state for the haveloc API.
// Unlike academia, haveloc uses stateless auth (Cookie + API-KEY headers),
// so there's no cookie jar — auth is injected per-request.
type FHClient struct {
	client         fasthttp.Client
	userAgent      string
	encryptedToken string
	phaveloc       int64
	sub            string
}

func newFHClient() *FHClient {
	return &FHClient{
		client: fasthttp.Client{
			MaxConnsPerHost:     64,
			MaxIdleConnDuration: 90 * time.Second,
			ReadTimeout:         30 * time.Second,
			WriteTimeout:        30 * time.Second,
			MaxConnWaitTimeout:  10 * time.Second,
		},
		userAgent: userAgent,
	}
}

func (c *FHClient) setAuth(token string, phaveloc int64) error {
	sub, err := extractSubFromJWT(token)
	if err != nil {
		return err
	}
	c.sub = sub
	c.encryptedToken = encryptToken(token)
	c.phaveloc = phaveloc
	return nil
}

// doRequest performs an HTTP request and returns the raw JSON body, status code, and error.
// It retries on 429 with exponential backoff (up to 3 retries).
func (c *FHClient) doRequest(method, url string, body interface{}) (*json.RawMessage, int, error) {
	var bodyBytes []byte
	if body != nil {
		var err error
		bodyBytes, err = json.Marshal(body)
		if err != nil {
			return nil, 0, fmt.Errorf("marshal body: %w", err)
		}
	}

	maxRetries := 3
	for attempt := 0; attempt <= maxRetries; attempt++ {
		req := fasthttp.AcquireRequest()
		resp := fasthttp.AcquireResponse()

		req.SetRequestURI(url)
		req.Header.SetMethod(method)
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json, text/plain, */*")
		req.Header.Set("User-Agent", c.userAgent)
		req.Header.Set("Origin", "https://placements.haveloc.com")
		req.Header.Set("Referer", "https://placements.haveloc.com/")

		if c.encryptedToken != "" {
			req.Header.Set("Cookie", fmt.Sprintf("ihaveloc=%s; phaveloc=%d", c.encryptedToken, c.phaveloc))
		}
		if c.sub != "" {
			req.Header.Set("API-KEY", generateAPIKey(c.sub, c.phaveloc))
		}
		if bodyBytes != nil {
			req.SetBody(bodyBytes)
		}

		err := c.client.DoTimeout(req, resp, 30*time.Second)
		statusCode := resp.StatusCode()
		respBody := append([]byte(nil), resp.Body()...)

		fasthttp.ReleaseRequest(req)
		fasthttp.ReleaseResponse(resp)

		if err != nil {
			if attempt < maxRetries {
				time.Sleep(time.Duration(500*(attempt+1)) * time.Millisecond)
				continue
			}
			return nil, 0, fmt.Errorf("do request: %w", err)
		}

		// 429 (rate limited) and 502/503/504 (upstream gateway hiccups) are
		// usually transient — retry with backoff before giving up.
		if (statusCode == 429 || statusCode == 502 || statusCode == 503 || statusCode == 504) && attempt < maxRetries {
			time.Sleep(time.Duration(500*(attempt+1)) * time.Millisecond)
			continue
		}

		if statusCode == 401 {
			return nil, 401, fmt.Errorf("authentication expired")
		}

		if statusCode >= 400 {
			raw := json.RawMessage(respBody)
			msg := string(respBody)
			if isHTMLBody(respBody) {
				// Gateway/proxy error pages (nginx 502, etc.) aren't useful to
				// show a user — surface a short, clean message instead.
				msg = fmt.Sprintf("Haveloc portal is temporarily unavailable (HTTP %d)", statusCode)
			}
			return &raw, statusCode, fmt.Errorf("API error %d: %s", statusCode, msg)
		}

		if len(respBody) == 0 {
			empty := json.RawMessage("null")
			return &empty, statusCode, nil
		}

		raw := json.RawMessage(respBody)
		return &raw, statusCode, nil
	}

	return nil, 0, fmt.Errorf("max retries exceeded")
}

// isHTMLBody reports whether body looks like an HTML error page rather than
// the JSON the Haveloc API normally returns (e.g. an nginx 502 page).
func isHTMLBody(body []byte) bool {
	trimmed := bytes.TrimSpace(body)
	if len(trimmed) == 0 {
		return false
	}
	lower := bytes.ToLower(trimmed)
	return bytes.HasPrefix(lower, []byte("<!doctype")) || bytes.HasPrefix(lower, []byte("<html"))
}

// fetchDirect downloads a binary file (for JD/PDF downloads).
func (c *FHClient) fetchDirect(fileURL string) ([]byte, string, error) {
	req := fasthttp.AcquireRequest()
	resp := fasthttp.AcquireResponse()
	defer fasthttp.ReleaseRequest(req)
	defer fasthttp.ReleaseResponse(resp)

	req.SetRequestURI(fileURL)
	req.Header.SetMethod("GET")
	req.Header.Set("Accept", "*/*")
	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Origin", "https://placements.haveloc.com")
	req.Header.Set("Referer", "https://placements.haveloc.com/")

	if c.encryptedToken != "" {
		req.Header.Set("Cookie", fmt.Sprintf("ihaveloc=%s; phaveloc=%d", c.encryptedToken, c.phaveloc))
	}

	if err := c.client.DoTimeout(req, resp, 60*time.Second); err != nil {
		return nil, "", fmt.Errorf("do request: %w", err)
	}

	if resp.StatusCode() != 200 {
		body := append([]byte(nil), resp.Body()...)
		preview := string(body)
		if len(preview) > 500 {
			preview = preview[:500]
		}
		return nil, "", fmt.Errorf("JD download failed: status %d, body: %s", resp.StatusCode(), preview)
	}

	body := append([]byte(nil), resp.Body()...)
	contentType := string(resp.Header.Peek("Content-Type"))
	return body, contentType, nil
}
