package scraper

import (
	"bytes"
	"fmt"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/PuerkitoBio/goquery"
	"github.com/valyala/fasthttp"
	"github.com/vivek2584/faculty-scraper/models"
)

var reFeaturedImage = regexp.MustCompile(`"featuredImage"\s*:\s*"(https:[^"]+\.(?:jpg|jpeg|png|webp))"`)

const (
	userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
	baseURL   = "https://www.srmist.edu.in"
)

var httpClient = &fasthttp.Client{
	MaxConnsPerHost:     32,
	MaxIdleConnDuration: 60 * time.Second,
	ReadTimeout:         15 * time.Second,
	WriteTimeout:        15 * time.Second,
	MaxConnWaitTimeout:  10 * time.Second,
}

// fetchPage downloads a URL and returns the HTML body.
func fetchPage(rawURL string) (string, error) {
	req := fasthttp.AcquireRequest()
	resp := fasthttp.AcquireResponse()
	defer fasthttp.ReleaseRequest(req)
	defer fasthttp.ReleaseResponse(resp)

	req.SetRequestURI(rawURL)
	req.Header.SetMethod("GET")
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

	if err := httpClient.DoTimeout(req, resp, 15*time.Second); err != nil {
		return "", fmt.Errorf("failed to fetch %s: %w", rawURL, err)
	}

	if resp.StatusCode() != 200 {
		return "", fmt.Errorf("fetch %s returned status %d", rawURL, resp.StatusCode())
	}

	return string(resp.Body()), nil
}

// ScrapeProfile fetches a single faculty profile by slug.
// slug example: "dr-ganapathy-sankar-u"
func ScrapeProfile(slug string) (*models.Faculty, error) {
	profileURL := baseURL + "/faculty/" + slug + "/"
	html, err := fetchPage(profileURL)
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(bytes.NewReader([]byte(html)))
	if err != nil {
		return nil, fmt.Errorf("could not parse profile HTML: %w", err)
	}

	faculty := parseProfile(doc, profileURL)
	if faculty.Name == "" {
		return nil, fmt.Errorf("no faculty data found at %s", profileURL)
	}
	return &faculty, nil
}

// parseProfile extracts Faculty data from a parsed goquery document.
func parseProfile(doc *goquery.Document, profileURL string) models.Faculty {
	f := models.Faculty{
		ProfileURL: profileURL,
	}

	// Name (from og:title meta tag — cleanest source)
	if name, ok := doc.Find("meta[property='og:title']").Attr("content"); ok {
		f.Name = strings.TrimSuffix(strings.TrimSpace(name), " - SRMIST")
	}

	// Profile photo — extracted from WordPress JSON data embedded in a <script> block.
	doc.Find("script").Each(func(_ int, el *goquery.Selection) {
		if f.PhotoURL != "" {
			return
		}
		text := el.Text()
		if m := reFeaturedImage.FindStringSubmatch(text); len(m) > 1 {
			f.PhotoURL = strings.ReplaceAll(m[1], `\/`, `/`)
		}
	})

	// Info list items (designation, department, phone, email)
	var listItems []string
	doc.Find("div.hide_empty_list_item .elementor-icon-list-items .elementor-icon-list-item .elementor-icon-list-text").Each(func(_ int, el *goquery.Selection) {
		text := strings.TrimSpace(el.Text())
		if text != "" {
			listItems = append(listItems, text)
		}
	})

	if len(listItems) >= 1 {
		f.Designation = listItems[0]
	}
	// Email is detected by @ rather than position — some pages omit department/phone
	for _, item := range listItems {
		if strings.Contains(item, "@") {
			f.Email = item
			break
		}
	}
	// Department is index 1 only if it is not an email address
	if len(listItems) >= 2 && !strings.Contains(listItems[1], "@") {
		f.Department = listItems[1]
	}

	// Campus / College info
	campusText := strings.TrimSpace(doc.Find(".faculty-cdc").Text())
	campusText = strings.TrimPrefix(campusText, "CAMPUS:")
	campusText = strings.TrimSpace(campusText)
	campusText = strings.Join(strings.Fields(campusText), " ")
	f.Campus = campusText

	// Experience, Research Interest, Courses — all in text-editor widgets
	doc.Find("div[data-widget_type='text-editor.default'] .elementor-widget-container").Each(func(_ int, el *goquery.Selection) {
		text := strings.TrimSpace(el.Text())
		switch {
		case strings.HasPrefix(text, "EXPERIENCE"):
			exp := strings.TrimPrefix(text, "EXPERIENCE :")
			exp = strings.TrimPrefix(exp, "EXPERIENCE:")
			f.Experience = strings.TrimSpace(exp)
		case strings.HasPrefix(text, "RESEARCH INTEREST"):
			ri := strings.TrimPrefix(text, "RESEARCH INTEREST :")
			ri = strings.TrimPrefix(ri, "RESEARCH INTEREST:")
			f.ResearchInterest = strings.TrimSpace(ri)
		case strings.HasPrefix(text, "COURSES"):
			c := strings.TrimPrefix(text, "COURSES :")
			c = strings.TrimPrefix(c, "COURSES:")
			f.Courses = strings.TrimSpace(c)
		}
	})

	// ── Tab content ───────────────────────────────────────────────
	tabTitles := make(map[int]string)
	doc.Find(".elementor-tab-title").Each(func(_ int, el *goquery.Selection) {
		if tab, ok := el.Attr("data-tab"); ok && tab != "" {
			n, _ := strconv.Atoi(tab)
			title := strings.ToLower(strings.TrimSpace(el.Text()))
			tabTitles[n] = title
		}
	})

	doc.Find(".elementor-tab-content").Each(func(_ int, el *goquery.Selection) {
		tab, ok := el.Attr("data-tab")
		if !ok || tab == "" {
			return
		}
		n, _ := strconv.Atoi(tab)
		title := tabTitles[n]
		content := cleanText(el.Text())
		if content == "" {
			return
		}

		switch {
		case strings.Contains(title, "education"):
			f.Education = content
		case strings.Contains(title, "publication"):
			f.Publications = content
		case strings.Contains(title, "award"):
			f.Awards = content
		case strings.Contains(title, "workshop") || strings.Contains(title, "seminar") || strings.Contains(title, "conference"):
			f.Workshops = content
		case strings.Contains(title, "work experience"):
			f.WorkExperience = content
		case strings.Contains(title, "membership"):
			f.Memberships = content
		case strings.Contains(title, "responsibilities") || strings.Contains(title, "responsibility"):
			f.Responsibilities = content
		}
	})

	return f
}

// SearchFaculty searches for faculty by name using SRM's WordPress search page.
// Returns a list of profile slugs (e.g., ["dr-ganapathy-sankar-u", "mr-ganapathy-s"]).
func SearchFaculty(name string) ([]string, error) {
	searchURL := fmt.Sprintf("%s/?s=%s&post_type=faculty", baseURL, url.QueryEscape(name))
	html, err := fetchPage(searchURL)
	if err != nil {
		return nil, fmt.Errorf("search request failed: %w", err)
	}

	doc, err := goquery.NewDocumentFromReader(bytes.NewReader([]byte(html)))
	if err != nil {
		return nil, fmt.Errorf("could not parse search results HTML: %w", err)
	}

	var slugs []string
	seen := map[string]bool{}

	doc.Find("article a[href]").Each(func(_ int, el *goquery.Selection) {
		href, ok := el.Attr("href")
		if !ok || !strings.Contains(href, "/faculty/") {
			return
		}
		parts := strings.Split(strings.TrimRight(href, "/"), "/")
		if len(parts) == 0 {
			return
		}
		slug := parts[len(parts)-1]
		if slug == "" || seen[slug] {
			return
		}
		seen[slug] = true
		slugs = append(slugs, slug)
	})

	return slugs, nil
}

// SearchAndScrape searches for faculty by name and scrapes ALL matching profiles in parallel.
func SearchAndScrape(name string) ([]*models.Faculty, error) {
	slugs, err := SearchFaculty(name)
	if err != nil {
		return nil, err
	}

	var (
		mu       sync.Mutex
		wg       sync.WaitGroup
		profiles []*models.Faculty
	)
	for _, slug := range slugs {
		wg.Add(1)
		go func(s string) {
			defer wg.Done()
			f, err := ScrapeProfile(s)
			if err != nil {
				fmt.Printf("Warning: failed to scrape %s: %v\n", s, err)
				return
			}
			mu.Lock()
			profiles = append(profiles, f)
			mu.Unlock()
		}(slug)
	}
	wg.Wait()
	return profiles, nil
}

// cleanText collapses runs of whitespace into single spaces and trims.
func cleanText(s string) string {
	return strings.Join(strings.Fields(strings.TrimSpace(s)), " ")
}
