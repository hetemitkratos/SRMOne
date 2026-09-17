package main

import (
	"fmt"
	"os"
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

const spInternalMarksURL = spBaseURL + "/srmiststudentportal/students/report/studentInternalMarkDetails.jsp"

var reMarkSplit = regexp.MustCompile(`^\s*([0-9.]+)\s*/\s*([0-9.]+)\s*$`)

// spFetchInternalMarks fetches the Student Portal internal-marks page
// (menu "Internal Mark Details", formId/iden 13) and parses the summary
// table: Code, Description, Mark / Max. Mark. Mirrors the attendance fetch —
// a dashboard GET establishes context, then one POST with the ClassPro body.
func spFetchInternalMarks(client *SPClient) ([]SPMarkRecord, error) {
	// Establish authenticated context (harmless if attendance already did it).
	_, _ = client.DoRequest("GET", spDashboardURL, nil, "", map[string]string{
		"Referer": spLoginURL,
	}, true)

	body := []byte("iden=13&filter=&hdnFormDetails=1&csrfPreventionSalt=")
	resp, err := client.DoRequest("POST", spInternalMarksURL, body,
		"application/x-www-form-urlencoded", map[string]string{
			"Referer":          spDashboardURL,
			"X-Requested-With": "XMLHttpRequest",
		}, true)
	if err != nil {
		return nil, fmt.Errorf("internal marks request failed: %w", err)
	}
	fmt.Fprintf(os.Stderr, "[spFetchMarks] status=%d body_len=%d\n", resp.StatusCode, len(resp.Body))

	records := parseSPInternalMarks(resp.Body)
	fmt.Fprintf(os.Stderr, "[spFetchMarks] parsed %d records\n", len(records))
	return records, nil
}

func parseSPInternalMarks(htmlBytes []byte) []SPMarkRecord {
	doc := parseSPHTML(htmlBytes)
	if doc == nil {
		return nil
	}

	var out []SPMarkRecord
	doc.Find("table").EachWithBreak(func(_ int, table *goquery.Selection) bool {
		headers := spExtractHeaders(table)
		if !(spContainsHeader(headers, "Code") && spContainsHeader(headers, "Mark")) {
			return true
		}
		// Column order on this page: Code | Description | Mark / Max. Mark | (link)
		table.Find("tr").Each(func(_ int, row *goquery.Selection) {
			cells := row.Find("td")
			if cells.Length() < 3 {
				return
			}
			code := strings.TrimSpace(cells.Eq(0).Text())
			title := strings.TrimSpace(cells.Eq(1).Text())
			markCell := strings.TrimSpace(cells.Eq(2).Text())
			if code == "" || strings.EqualFold(code, "Code") {
				return
			}
			obtained, maxMark := markCell, ""
			if m := reMarkSplit.FindStringSubmatch(markCell); m != nil {
				obtained, maxMark = m[1], m[2]
			}
			out = append(out, SPMarkRecord{
				CourseCode:  code,
				CourseTitle: title,
				Obtained:    obtained,
				MaxMark:     maxMark,
			})
		})
		return false // matched the marks table, stop
	})
	return out
}
