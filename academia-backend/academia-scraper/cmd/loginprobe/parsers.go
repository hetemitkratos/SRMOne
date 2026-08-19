package main

import (
	"bytes"
	encoding_base64 "encoding/base64"
	"encoding/json"
	"fmt"
	stdhtml "html"
	"net/url"
	"os"
	"regexp"
	"sort"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"golang.org/x/net/html"
)

// ---------------------------------------------------------------------------
// Signin page / lookup / password parsers
// ---------------------------------------------------------------------------

func parseSigninPage(rawHTML []byte, finalURL, fallbackServiceURL string) (SigninPageInfo, error) {
	info := SigninPageInfo{
		FinalURL:        finalURL,
		ServiceURL:      fallbackServiceURL,
		CSRFParam:       extractJSQuotedValue(string(rawHTML), "csrfParam"),
		CSRFCookieName:  extractJSQuotedValue(string(rawHTML), "csrfCookieName"),
		URIPathPrefix:   extractJSQuotedValue(string(rawHTML), "uriPrefix"),
		EmailOnlySignin: extractJSBooleanValue(string(rawHTML), "emailOnlySignin"),
	}

	if info.ServiceURL == "" {
		info.ServiceURL = extractServiceURL(string(rawHTML), finalURL)
	}

	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(rawHTML))
	if err != nil {
		return info, err
	}

	doc.Find(`input[type="hidden"]`).Each(func(_ int, sel *goquery.Selection) {
		name, ok := sel.Attr("name")
		if !ok || strings.TrimSpace(name) == "" {
			return
		}
		value, _ := sel.Attr("value")
		info.HiddenFields = append(info.HiddenFields, HiddenField{
			Name:  strings.TrimSpace(name),
			Value: value,
		})
	})

	return info, nil
}

func parseLookupResponse(body []byte) lookupResult {
	result := lookupResult{}
	payload := parseJSONMap(body)
	if payload == nil {
		return result
	}

	result.summary.Code = getString(payload, "code")
	result.summary.ResourceName = getString(payload, "resource_name")
	result.summary.LocalizedMessage = getString(payload, "localized_message")
	result.summary.ErrorCode = firstErrorCode(payload)

	resource := nestedMap(payload, result.summary.ResourceName)
	if resource == nil {
		resource = nestedMap(payload, "lookup")
	}
	if resource == nil {
		return result
	}

	result.identifier = getString(resource, "identifier")
	result.digest = getString(resource, "digest")
	result.summary.Identifier = result.identifier
	if modes := nestedMap(resource, "modes"); modes != nil {
		result.summary.AllowedModes = getStringSlice(modes["allowed_modes"])
	}
	return result
}

func parsePasswordResponse(body []byte, location string) passwordResult {
	result := passwordResult{}
	payload := parseJSONMap(body)
	if payload == nil {
		return result
	}

	result.summary.Code = getString(payload, "code")
	result.summary.ResourceName = getString(payload, "resource_name")
	result.summary.LocalizedMessage = getString(payload, "localized_message")
	result.summary.ErrorCode = firstErrorCode(payload)

	resource := nestedMap(payload, result.summary.ResourceName)
	if resource != nil {
		result.summary.RedirectURI = getString(resource, "redirect_uri")
		result.summary.Status = getString(resource, "status")
		result.redirectURI = result.summary.RedirectURI
	}

	if result.redirectURI == "" {
		result.redirectURI = location
	}
	return result
}

// ---------------------------------------------------------------------------
// Page classification
// ---------------------------------------------------------------------------

func classifyPage(pageURL, body string) (string, string) {
	lowerURL := strings.ToLower(pageURL)
	lowerBody := strings.ToLower(body)

	switch {
	case strings.Contains(lowerURL, "sessions-reminder"),
		strings.Contains(lowerURL, "block-sessions"),
		strings.Contains(lowerURL, "preannouncement/block-sessions"),
		strings.Contains(lowerURL, "preannouncement/continue"),
		strings.Contains(lowerURL, "announcement/sessions-reminder"),
		strings.Contains(lowerURL, "announcement/continue"):
		return classSessions, "session reminder / active sessions page detected"
	case strings.Contains(lowerBody, "daily sign-in limit"),
		(strings.Contains(lowerBody, "signed in") && strings.Contains(lowerBody, "times today")),
		strings.Contains(lowerBody, "you are nearing your daily sign-in limit"),
		(strings.Contains(lowerURL, "signin-block") && strings.Contains(lowerBody, "i understand")):
		return classDailyLimit, "daily sign-in warning detected"
	default:
		return classUnknown, ""
	}
}

func classifyFromMessage(message, errorCode string) string {
	lowerMessage := strings.ToLower(message)
	switch {
	case strings.Contains(lowerMessage, "incorrect password"),
		strings.Contains(lowerMessage, "invalid password"),
		strings.Contains(lowerMessage, "verify your email address"),
		errorCode == "U401":
		return classInvalidCreds
	case strings.Contains(lowerMessage, "captcha"),
		errorCode == "IN107",
		errorCode == "IN108":
		return classCaptcha
	case strings.Contains(lowerMessage, "throttle"),
		strings.Contains(lowerMessage, "too many"),
		strings.Contains(lowerMessage, "temporarily blocked"):
		return classJSDependent
	default:
		return classUnknown
	}
}

func looksLikeUnauthenticatedPage(pageURL, body string) bool {
	lowerURL := strings.ToLower(pageURL)
	lowerBody := strings.ToLower(body)
	if strings.Contains(lowerURL, "/accounts/") || strings.Contains(lowerURL, "signin") {
		return true
	}
	return strings.Contains(lowerBody, "sign in to continue") ||
		strings.Contains(lowerBody, "zoho accounts") ||
		strings.Contains(lowerBody, "academic web services login")
}

// ---------------------------------------------------------------------------
// Attendance parser
// ---------------------------------------------------------------------------

func parseAttendance(decodedHTML string) ([]map[string]string, []string, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(decodedHTML))
	if err != nil {
		return nil, nil, fmt.Errorf("could not parse decoded HTML: %w", err)
	}

	var table *goquery.Selection
	var headers []string
	tableCount := 0
	doc.Find("table").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		tableCount++
		rowHeaders := extractHeaders(sel)
		fmt.Fprintf(os.Stderr, "[parseAttendance] table #%d headers=%v\n", tableCount, rowHeaders)
		if len(rowHeaders) < 2 {
			return true
		}
		if containsString(rowHeaders, "Attn %") {
			table = sel
			headers = rowHeaders
			fmt.Fprintf(os.Stderr, "[parseAttendance] matched table #%d (has Attn %%)\n", tableCount)
			return false
		}
		return true
	})

	if table == nil {
		preview := decodedHTML
		if len(preview) > 500 {
			preview = preview[:500]
		}
		fmt.Fprintf(os.Stderr, "[parseAttendance] no table matched (tables=%d) HTML preview: %s\n", tableCount, preview)
		return nil, nil, fmt.Errorf("attendance table not found in decoded HTML")
	}

	var records []map[string]string
	table.Find("tr").Each(func(index int, row *goquery.Selection) {
		if index == 0 {
			return
		}
		cells := extractCells(row)
		if len(cells) == 0 || strings.TrimSpace(cells[0]) == "" {
			return
		}
		record := make(map[string]string, len(headers))
		for i, header := range headers {
			if i < len(cells) {
				record[header] = cells[i]
			} else {
				record[header] = ""
			}
		}
		records = append(records, record)
	})

	if len(records) == 0 {
		return nil, headers, fmt.Errorf("attendance table parsed but contained no data rows")
	}

	return records, headers, nil
}

func mapAttendanceRows(rows []map[string]string) []AttendanceRecord {
	result := make([]AttendanceRecord, 0, len(rows))
	for _, row := range rows {
		courseCode := strings.TrimSpace(row["Course Code"])
		if newline := strings.Index(courseCode, "\n"); newline >= 0 {
			courseCode = strings.TrimSpace(courseCode[:newline])
		}
		result = append(result, AttendanceRecord{
			CourseCode:     courseCode,
			CourseTitle:    strings.TrimSpace(row["Course Title"]),
			Category:       strings.TrimSpace(row["Category"]),
			FacultyName:    strings.TrimSpace(row["Faculty Name"]),
			Slot:           strings.TrimSpace(row["Slot"]),
			RoomNo:         strings.TrimSpace(row["Room No"]),
			HoursConducted: strings.TrimSpace(row["Hours Conducted"]),
			HoursAbsent:    strings.TrimSpace(row["Hours Absent"]),
			AttendancePct:  strings.TrimSpace(row["Attn %"]),
		})
	}
	return result
}

// ---------------------------------------------------------------------------
// Student info parser
// ---------------------------------------------------------------------------

func parseStudentInfoHTML(decodedHTML string) (map[string]string, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(decodedHTML))
	if err != nil {
		return nil, fmt.Errorf("could not parse student info HTML: %w", err)
	}

	var table *goquery.Selection
	doc.Find("table").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		headers := extractHeaders(sel)
		if containsString(headers, "Registration Number:") {
			table = sel
			return false
		}
		return true
	})

	if table == nil {
		return nil, fmt.Errorf("student info table not found")
	}

	info := map[string]string{}
	table.Find("tr").Each(func(_ int, row *goquery.Selection) {
		cells := extractCells(row)
		for i := 0; i < len(cells); i++ {
			key := strings.TrimSpace(cells[i])
			if key == "" || key == ":" {
				continue
			}

			key = strings.TrimSpace(strings.TrimSuffix(key, ":"))
			if key == "" {
				continue
			}

			valueIndex := i + 1
			for valueIndex < len(cells) && strings.TrimSpace(cells[valueIndex]) == "" {
				valueIndex++
			}
			if valueIndex < len(cells) && strings.TrimSpace(cells[valueIndex]) == ":" {
				valueIndex++
			}
			for valueIndex < len(cells) && strings.TrimSpace(cells[valueIndex]) == "" {
				valueIndex++
			}
			if valueIndex >= len(cells) {
				continue
			}

			value := strings.TrimSpace(cells[valueIndex])
			if value != "" && value != ":" {
				info[key] = value
			}
		}
	})

	if len(info) == 0 {
		return nil, fmt.Errorf("student info table parsed but contained no data")
	}
	return info, nil
}

// ---------------------------------------------------------------------------
// Student photo helpers
// ---------------------------------------------------------------------------

func isZohoPreviewURL(url string) bool {
	lowerURL := strings.ToLower(url)
	if strings.Contains(lowerURL, "previewengine") || (strings.Contains(lowerURL, "zoho.com") && strings.Contains(lowerURL, "/image/")) {
		return true
	}
	if strings.Contains(lowerURL, "academia.srmist.edu.in") && strings.Contains(lowerURL, "download-file?filepath=") {
		return true
	}
	return false
}

func extractStudentPhotoSource(decodedHTML string) (string, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(decodedHTML))
	if err != nil {
		return "", fmt.Errorf("could not parse student photo HTML: %w", err)
	}

	var src string

	doc.Find(`img[src*="Photo_Upload_Student_Report"], img[src*="Your_Photo/image/"]`).EachWithBreak(func(_ int, img *goquery.Selection) bool {
		value, ok := img.Attr("src")
		if ok && strings.TrimSpace(value) != "" {
			src = strings.TrimSpace(value)
			return false
		}
		return true
	})
	if src != "" {
		return src, nil
	}

	doc.Find("td").EachWithBreak(func(_ int, cell *goquery.Selection) bool {
		if !strings.Contains(strings.ToLower(extractCellText(cell)), "photo-id") {
			return true
		}
		row := cell.Parent()
		row.Find("img[src]").EachWithBreak(func(_ int, img *goquery.Selection) bool {
			value, ok := img.Attr("src")
			if ok && strings.TrimSpace(value) != "" {
				src = strings.TrimSpace(value)
				return false
			}
			return true
		})
		return src == ""
	})
	if src != "" {
		return src, nil
	}

	doc.Find("img[src]").EachWithBreak(func(_ int, img *goquery.Selection) bool {
		value, ok := img.Attr("src")
		if ok && isZohoPreviewURL(value) {
			src = strings.TrimSpace(value)
			return false
		}
		return true
	})

	if src == "" {
		return "", fmt.Errorf("student photo source not found")
	}
	return src, nil
}

func extractStudentPhotoDownloadURL(decodedHTML string) (string, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(decodedHTML))
	if err != nil {
		return "", fmt.Errorf("could not parse student photo download HTML: %w", err)
	}

	var candidate string
	doc.Find(`img[src*="Photo_Upload_Student_Report"], img[src*="Your_Photo/image/"]`).EachWithBreak(func(_ int, img *goquery.Selection) bool {
		for _, attr := range []string{"src", "downqual", "medqual", "lowqual"} {
			value, ok := img.Attr(attr)
			if !ok {
				continue
			}
			value = strings.TrimSpace(value)
			if value == "" || !strings.Contains(value, "/image/") {
				continue
			}
			candidate = value
			return false
		}
		return candidate == ""
	})

	if candidate == "" {
		doc.Find("img[src]").EachWithBreak(func(_ int, img *goquery.Selection) bool {
			for _, attr := range []string{"src", "downqual", "medqual", "lowqual"} {
				value, ok := img.Attr(attr)
				if ok && isZohoPreviewURL(value) {
					candidate = strings.TrimSpace(value)
					return false
				}
			}
			return candidate == ""
		})
	}

	if candidate == "" {
		return "", fmt.Errorf("student photo download candidate not found")
	}

	if isZohoPreviewURL(candidate) {
		return candidate, nil
	}

	filepath := candidate[strings.LastIndex(candidate, "/image/")+len("/image/"):]
	filepath = strings.TrimSpace(filepath)
	if filepath == "" {
		return "", fmt.Errorf("student photo filepath could not be derived")
	}

	return defaultBaseURL +
		"/srm_university/academia-academic-services/report/Student_Profile_Report/" +
		defaultStudentPhotoReportID +
		"/Your_Photo/download-file?filepath=/" + url.QueryEscape(filepath) +
		"&digestValue=e30=", nil
}

func guessImageContentType(rawURL string) string {
	lower := strings.ToLower(rawURL)
	switch {
	case strings.Contains(lower, ".png"):
		return "image/png"
	case strings.Contains(lower, ".webp"):
		return "image/webp"
	case strings.Contains(lower, ".gif"):
		return "image/gif"
	default:
		return "image/jpeg"
	}
}

// ---------------------------------------------------------------------------
// Marks parser
// ---------------------------------------------------------------------------

func parseMarksHTML(decodedHTML string) ([]MarkRecord, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(decodedHTML))
	if err != nil {
		return nil, fmt.Errorf("could not parse marks HTML: %w", err)
	}

	var table *goquery.Selection
	doc.Find("table").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		headers := extractHeaders(sel)
		if containsString(headers, "Test Performance") {
			table = sel
			return false
		}
		return true
	})

	if table == nil {
		return nil, fmt.Errorf("marks table not found")
	}

	var result []MarkRecord
	rows := extractDirectRows(table)
	for index, row := range rows {
		if index == 0 {
			continue
		}

		cells := extractDirectCells(row)
		if len(cells) < 2 || strings.TrimSpace(extractCellText(cells[0])) == "" {
			continue
		}

		record := MarkRecord{
			CourseCode: strings.TrimSpace(extractCellText(cells[0])),
			CourseType: strings.TrimSpace(extractCellText(cells[1])),
			Tests:      []MarkTest{},
		}

		if len(cells) >= 3 {
			cells[2].Find("td").Each(func(_ int, inner *goquery.Selection) {
				test := parseMarkTestCell(inner)
				if test.TestName != "" || test.Score != "" || test.MaxScore != "" {
					record.Tests = append(record.Tests, test)
				}
			})
		}

		result = append(result, record)
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("marks table parsed but contained no data rows")
	}
	return result, nil
}

func parseMarkTestCell(cell *goquery.Selection) MarkTest {
	lines := splitNonEmpty(extractCellText(cell), regexpMustCompile(`[\n\t]+`))
	if len(lines) == 0 {
		return MarkTest{}
	}

	spec := strings.TrimSpace(lines[0])
	score := ""
	if len(lines) > 1 {
		score = strings.TrimSpace(strings.Join(lines[1:], " "))
	}

	test := MarkTest{
		TestName: spec,
		Score:    score,
	}
	if slash := strings.LastIndex(spec, "/"); slash >= 0 {
		test.TestName = strings.TrimSpace(spec[:slash])
		test.MaxScore = strings.TrimSpace(spec[slash+1:])
	}
	return test
}

// ---------------------------------------------------------------------------
// Personal timetable parser
// ---------------------------------------------------------------------------

func parsePersonalTimetableHTML(decodedHTML string) (string, []map[string]string, []Advisor, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(decodedHTML))
	if err != nil {
		return "", nil, nil, fmt.Errorf("could not parse timetable HTML: %w", err)
	}

	batch := "1"
	info, err := parseStudentInfoHTML(decodedHTML)
	if err == nil {
		if parsedBatch := strings.TrimSpace(info["Batch"]); parsedBatch != "" {
			batch = parsedBatch
		}
	}

	var advisorTable *goquery.Selection
	var courseTable *goquery.Selection
	doc.Find("table").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		headers := extractHeaders(sel)
		if advisorTable == nil && containsString(headers, "Counselor") {
			advisorTable = sel
		}
		if courseTable == nil && containsString(headers, "Course Code") && containsString(headers, "Slot") {
			courseTable = sel
		}
		return advisorTable == nil || courseTable == nil
	})

	var advisors []Advisor
	if advisorTable != nil {
		firstRow := advisorTable.Find("tr").First()
		cells := extractCells(firstRow)
		for i := 2; i < len(cells); i++ {
			lines := splitNonEmpty(cells[i], regexpMustCompile(`\n+`))
			if len(lines) == 0 {
				continue
			}
			advisors = append(advisors, Advisor{
				Name:  valueAt(lines, 0),
				Role:  valueAt(lines, 1),
				Email: valueAt(lines, 2),
				Phone: valueAt(lines, 3),
			})
		}
	}

	if courseTable == nil {
		return batch, nil, advisors, fmt.Errorf("personal timetable course table not found")
	}

	headers := extractHeaders(courseTable)
	var courses []map[string]string
	courseTable.Find("tr").Each(func(index int, row *goquery.Selection) {
		if index == 0 {
			return
		}
		cells := extractCells(row)
		if len(cells) < 2 || strings.TrimSpace(cells[1]) == "" {
			return
		}
		record := map[string]string{}
		for i, header := range headers {
			if i < len(cells) {
				record[header] = strings.TrimSpace(cells[i])
			} else {
				record[header] = ""
			}
		}
		courses = append(courses, record)
	})

	if len(courses) == 0 {
		return batch, nil, advisors, fmt.Errorf("personal timetable parsed but contained no courses")
	}
	return batch, courses, advisors, nil
}

// ---------------------------------------------------------------------------
// Unified timetable (batch slot map) parser
// ---------------------------------------------------------------------------

func parseBatchSlotMapHTML(decodedHTML string) (map[string][]ScheduleEntry, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(decodedHTML))
	if err != nil {
		return nil, fmt.Errorf("could not parse unified timetable HTML: %w", err)
	}

	var table *goquery.Selection
	doc.Find("table").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		rows := extractTableMatrix(sel)
		if len(rows) > 0 && len(rows[0]) > 0 && strings.TrimSpace(rows[0][0]) == "FROM" {
			table = sel
			return false
		}
		return true
	})

	if table == nil {
		return nil, fmt.Errorf("unified timetable grid not found")
	}

	rows := extractTableMatrix(table)
	if len(rows) == 0 || len(rows[0]) < 2 {
		return nil, fmt.Errorf("unified timetable grid was empty")
	}

	timings := rows[0][1:]
	slotMap := map[string][]ScheduleEntry{}
	for _, row := range rows[1:] {
		if len(row) == 0 {
			continue
		}

		day := strings.TrimSpace(row[0])
		if !strings.HasPrefix(day, "Day") {
			continue
		}

		for col := 1; col < len(row) && col-1 < len(timings); col++ {
			cellText := strings.TrimSpace(row[col])
			if cellText == "" {
				continue
			}
			timing := strings.TrimSpace(timings[col-1])
			tokens := splitSlotTokens(cellText)
			for _, token := range tokens {
				slotMap[token] = append(slotMap[token], ScheduleEntry{
					Day:       day,
					HourIndex: col,
					Timing:    timing,
					SlotToken: token,
				})
			}
		}
	}

	if len(slotMap) == 0 {
		return nil, fmt.Errorf("unified timetable grid parsed but contained no slot mappings")
	}
	return slotMap, nil
}

func mergeTimetableCourses(rawCourses []map[string]string, slotMap map[string][]ScheduleEntry) []TimetableCourse {
	courses := make([]TimetableCourse, 0, len(rawCourses))
	for _, course := range rawCourses {
		rawSlot := strings.TrimSpace(course["Slot"])
		var schedule []ScheduleEntry
		for _, token := range splitCourseSlotTokens(rawSlot) {
			for _, entry := range slotMap[token] {
				schedule = append(schedule, ScheduleEntry{
					Day:       entry.Day,
					HourIndex: entry.HourIndex,
					Timing:    entry.Timing,
					SlotToken: token,
				})
			}
		}
		sort.Slice(schedule, func(i, j int) bool {
			leftDay, rightDay := parseDayNumber(schedule[i].Day), parseDayNumber(schedule[j].Day)
			if leftDay != rightDay {
				return leftDay < rightDay
			}
			return schedule[i].HourIndex < schedule[j].HourIndex
		})

		courses = append(courses, TimetableCourse{
			CourseCode:  strings.TrimSpace(course["Course Code"]),
			CourseTitle: strings.TrimSpace(course["Course Title"]),
			Credit:      strings.TrimSpace(course["Credit"]),
			Category:    strings.TrimSpace(course["Category"]),
			CourseType:  strings.TrimSpace(course["Course Type"]),
			FacultyName: strings.TrimSpace(course["Faculty Name"]),
			Slot:        rawSlot,
			RoomNo:      strings.TrimSpace(course["Room No."]),
			Schedule:    schedule,
		})
	}
	return courses
}

// ---------------------------------------------------------------------------
// Academic calendar parser
// ---------------------------------------------------------------------------

func parseAcademicCalendarHTML(decodedHTML, sem string) (CalendarResult, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(decodedHTML))
	if err != nil {
		return CalendarResult{}, fmt.Errorf("could not parse calendar HTML: %w", err)
	}

	monthRe := regexpMustCompile(`^(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)\b`)
	bestScore := 0
	bestHeaderRow := 0
	var bestTable [][]string

	doc.Find("table").Each(func(_ int, sel *goquery.Selection) {
		rows := extractTableMatrix(sel)
		for rowIndex := 0; rowIndex < len(rows) && rowIndex < 5; rowIndex++ {
			hits := 0
			for _, cell := range rows[rowIndex] {
				if monthRe.MatchString(strings.TrimSpace(cell)) {
					hits++
				}
			}
			if hits > bestScore {
				bestScore = hits
				bestHeaderRow = rowIndex
				bestTable = rows
			}
		}
		if bestScore == 0 && len(rows) > len(bestTable) {
			bestTable = rows
			bestHeaderRow = 0
		}
	})

	if len(bestTable) == 0 {
		return CalendarResult{}, fmt.Errorf("calendar table not found")
	}

	headerCells := bestTable[bestHeaderRow]
	type monthGroup struct {
		name     string
		dtCol    int
		dayCol   int
		eventCol int
		doCol    int
	}

	var monthGroups []monthGroup
	for i, cell := range headerCells {
		if monthRe.MatchString(strings.TrimSpace(cell)) && i >= 2 {
			monthGroups = append(monthGroups, monthGroup{
				name:     strings.TrimSpace(cell),
				dtCol:    i - 2,
				dayCol:   i - 1,
				eventCol: i,
				doCol:    i + 1,
			})
		}
	}

	if len(monthGroups) == 0 && len(headerCells) >= 4 {
		for i := 0; i+3 < len(headerCells); i += 5 {
			name := fmt.Sprintf("Month%d", len(monthGroups)+1)
			for _, cell := range headerCells[i:minInt(i+5, len(headerCells))] {
				if monthRe.MatchString(strings.TrimSpace(cell)) {
					name = strings.TrimSpace(cell)
					break
				}
			}
			monthGroups = append(monthGroups, monthGroup{
				name:     name,
				dtCol:    i,
				dayCol:   i + 1,
				eventCol: i + 2,
				doCol:    i + 3,
			})
		}
	}

	var months []CalendarMonth
	for _, group := range monthGroups {
		var days []CalendarDay
		for rowIndex := bestHeaderRow + 1; rowIndex < len(bestTable); rowIndex++ {
			row := bestTable[rowIndex]
			date := valueAt(row, group.dtCol)
			if strings.TrimSpace(date) == "" {
				continue
			}
			days = append(days, CalendarDay{
				Date:     strings.TrimSpace(date),
				Day:      strings.TrimSpace(valueAt(row, group.dayCol)),
				Event:    strings.TrimSpace(valueAt(row, group.eventCol)),
				DayOrder: strings.TrimSpace(valueAt(row, group.doCol)),
			})
		}
		months = append(months, CalendarMonth{
			Name: strings.TrimSpace(group.name),
			Days: days,
		})
	}

	title := ""
	for _, selector := range []string{"h1", "h2", "h3", ".page-title", `[class*="title"]`} {
		doc.Find(selector).EachWithBreak(func(_ int, sel *goquery.Selection) bool {
			text := strings.TrimSpace(extractCellText(sel))
			if text != "" && len(text) > 3 && len(text) < 200 {
				title = text
				return false
			}
			return true
		})
		if title != "" {
			break
		}
	}

	if len(months) == 0 {
		return CalendarResult{}, fmt.Errorf("calendar parsed but contained no month groups")
	}
	return CalendarResult{
		Sem:    sem,
		Title:  title,
		Months: months,
	}, nil
}

// ---------------------------------------------------------------------------
// HTML table helpers
// ---------------------------------------------------------------------------

func extractTableMatrix(table *goquery.Selection) [][]string {
	var rows [][]string
	table.Find("tr").Each(func(_ int, row *goquery.Selection) {
		rows = append(rows, extractCells(row))
	})
	return rows
}

func extractDirectRows(table *goquery.Selection) []*goquery.Selection {
	var rows []*goquery.Selection
	containers := table.ChildrenFiltered("tbody")
	if containers.Length() == 0 {
		containers = table
	}
	containers.Each(func(_ int, container *goquery.Selection) {
		container.ChildrenFiltered("tr").Each(func(_ int, row *goquery.Selection) {
			rows = append(rows, row)
		})
	})
	return rows
}

func extractDirectCells(row *goquery.Selection) []*goquery.Selection {
	var cells []*goquery.Selection
	row.ChildrenFiltered("th,td").Each(func(_ int, cell *goquery.Selection) {
		cells = append(cells, cell)
	})
	return cells
}

func extractHeaders(table *goquery.Selection) []string {
	return extractCells(table.Find("tr").First())
}

func extractCells(row *goquery.Selection) []string {
	var cells []string
	row.Find("th,td").Each(func(_ int, cell *goquery.Selection) {
		cells = append(cells, extractCellText(cell))
	})
	return cells
}

func extractCellText(cell *goquery.Selection) string {
	var b strings.Builder
	for _, node := range cell.Nodes {
		walkNodeText(&b, node)
	}

	lines := strings.Split(b.String(), "\n")
	for i, line := range lines {
		lines[i] = strings.Join(strings.Fields(line), " ")
	}

	text := strings.TrimSpace(strings.Join(lines, "\n"))
	for strings.Contains(text, "\n\n") {
		text = strings.ReplaceAll(text, "\n\n", "\n")
	}
	return text
}

func walkNodeText(b *strings.Builder, node *html.Node) {
	if node == nil {
		return
	}

	switch node.Type {
	case html.TextNode:
		b.WriteString(node.Data)
		return
	case html.ElementNode:
		if isLineBreakNode(node.Data) && !strings.HasSuffix(b.String(), "\n") {
			b.WriteByte('\n')
		}
	}

	for child := node.FirstChild; child != nil; child = child.NextSibling {
		walkNodeText(b, child)
	}

	if node.Type == html.ElementNode && isBlockNode(node.Data) && !strings.HasSuffix(b.String(), "\n") {
		b.WriteByte('\n')
	}
}

func isLineBreakNode(tag string) bool {
	return tag == "br" || tag == "hr"
}

func isBlockNode(tag string) bool {
	switch tag {
	case "div", "p", "section", "article", "header", "footer", "li", "tr", "table":
		return true
	default:
		return false
	}
}

// ---------------------------------------------------------------------------
// Token / regex helpers
// ---------------------------------------------------------------------------

func splitNonEmpty(raw string, separator *regexp.Regexp) []string {
	parts := separator.Split(raw, -1)
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			out = append(out, part)
		}
	}
	return out
}

func splitSlotTokens(raw string) []string {
	parts := regexpMustCompile(`\s*/\s*|\n+`).Split(raw, -1)
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			out = append(out, part)
		}
	}
	return out
}

func splitCourseSlotTokens(raw string) []string {
	parts := strings.Split(raw, "-")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			out = append(out, part)
		}
	}
	return out
}

func parseDayNumber(day string) int {
	matches := regexpMustCompile(`(\d+)`).FindStringSubmatch(day)
	if len(matches) < 2 {
		return 999
	}
	var value int
	for i := 0; i < len(matches[1]); i++ {
		value = (value * 10) + int(matches[1][i]-'0')
	}
	return value
}

func firstRegexGroup(raw, pattern string) string {
	re := regexpMustCompile(pattern)
	match := re.FindStringSubmatch(raw)
	if len(match) >= 2 {
		return match[1]
	}
	return ""
}

func containsString(values []string, want string) bool {
	for _, value := range values {
		if strings.TrimSpace(value) == want {
			return true
		}
	}
	return false
}

func valueAt[T ~[]E, E any](items T, index int) E {
	var zero E
	if index < 0 || index >= len(items) {
		return zero
	}
	return items[index]
}

func minInt(left, right int) int {
	if left < right {
		return left
	}
	return right
}

// ---------------------------------------------------------------------------
// JS string / sanitize payload decoders
// ---------------------------------------------------------------------------

func decodeSanitizedHTML(raw string) (decoded string, payload string, err error) {
	payload, err = extractSanitizePayload(raw)
	if err != nil {
		return "", "", err
	}

	decoded, err = decodeJSString(payload)
	if err != nil {
		return "", payload, fmt.Errorf("could not decode sanitize payload: %w", err)
	}
	return decoded, payload, nil
}

func decodeZMLValueHTML(raw string) (decoded string, payload string, err error) {
	doc, parseErr := goquery.NewDocumentFromReader(strings.NewReader(raw))
	if parseErr != nil {
		return "", "", fmt.Errorf("could not parse zmlvalue HTML: %w", parseErr)
	}

	var found string
	doc.Find("[zmlvalue]").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		value, ok := sel.Attr("zmlvalue")
		if ok && strings.TrimSpace(value) != "" {
			found = value
			return false
		}
		return true
	})

	if found == "" {
		return "", "", fmt.Errorf("zmlvalue payload marker not found")
	}

	decoded = stdhtml.UnescapeString(found)
	if !strings.Contains(strings.ToLower(decoded), "<table") {
		return "", found, fmt.Errorf("zmlvalue payload did not decode into table HTML")
	}
	return decoded, found, nil
}

func extractSanitizePayload(raw string) (string, error) {
	const marker = "pageSanitizer.sanitize('"

	start := strings.Index(raw, marker)
	if start < 0 {
		return "", fmt.Errorf("pageSanitizer payload marker not found")
	}

	i := start + len(marker)
	var b strings.Builder
	for i < len(raw) {
		ch := raw[i]
		if ch == '\\' {
			if i+1 >= len(raw) {
				return "", fmt.Errorf("unterminated escape sequence in sanitize payload")
			}
			b.WriteByte(raw[i])
			b.WriteByte(raw[i+1])
			i += 2
			continue
		}
		if ch == '\'' {
			return b.String(), nil
		}
		b.WriteByte(ch)
		i++
	}

	return "", fmt.Errorf("unterminated sanitize payload")
}

func decodeJSString(s string) (string, error) {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] != '\\' {
			b.WriteByte(s[i])
			continue
		}

		i++
		if i >= len(s) {
			return "", fmt.Errorf("unterminated escape")
		}

		switch s[i] {
		case 'x':
			if i+2 >= len(s) {
				return "", fmt.Errorf("short hex escape")
			}
			b.WriteByte(parseHexByte(s[i+1 : i+3]))
			i += 2
		case 'u':
			if i+4 >= len(s) {
				return "", fmt.Errorf("short unicode escape")
			}
			b.WriteRune(parseHexRune(s[i+1 : i+5]))
			i += 4
		case 'n':
			b.WriteByte('\n')
		case 'r':
			b.WriteByte('\r')
		case 't':
			b.WriteByte('\t')
		case 'b':
			b.WriteByte('\b')
		case 'f':
			b.WriteByte('\f')
		case '\\', '\'', '"', '/':
			b.WriteByte(s[i])
		default:
			b.WriteByte(s[i])
		}
	}
	return b.String(), nil
}

func parseHexByte(raw string) byte {
	var value byte
	for i := 0; i < len(raw); i++ {
		value *= 16
		value += hexNibble(raw[i])
	}
	return value
}

func parseHexRune(raw string) rune {
	var value rune
	for i := 0; i < len(raw); i++ {
		value *= 16
		value += rune(hexNibble(raw[i]))
	}
	return value
}

func hexNibble(ch byte) byte {
	switch {
	case ch >= '0' && ch <= '9':
		return ch - '0'
	case ch >= 'a' && ch <= 'f':
		return ch - 'a' + 10
	case ch >= 'A' && ch <= 'F':
		return ch - 'A' + 10
	default:
		return 0
	}
}

func unescapeJSLiteral(value string) string {
	value = strings.ReplaceAll(value, `\/`, `/`)
	value = strings.ReplaceAll(value, `\'`, `'`)
	value = strings.ReplaceAll(value, `\"`, `"`)
	return value
}

func extractJSQuotedValue(raw, name string) string {
	patterns := []string{
		`var ` + name + `\s*=\s*"([^"]*)"`,
		`var ` + name + `\s*=\s*'([^']*)'`,
	}
	for _, pattern := range patterns {
		if value := firstRegexGroup(raw, pattern); value != "" {
			return unescapeJSLiteral(value)
		}
	}
	return ""
}

func extractJSBooleanValue(raw, name string) bool {
	value := firstRegexGroup(raw, `var `+name+`\s*=\s*Boolean\("([^"]*)"\)`)
	return strings.EqualFold(value, "true")
}

func extractServiceURL(raw, fallbackURL string) string {
	if value := firstRegexGroup(raw, `serviceUrl\s*=\s*'([^']+)'`); value != "" {
		return unescapeJSLiteral(value)
	}
	parsed, err := url.Parse(fallbackURL)
	if err != nil {
		return ""
	}
	return parsed.Query().Get("serviceurl")
}

// ---------------------------------------------------------------------------
// JSON helpers
// ---------------------------------------------------------------------------

func parseJSONMap(body []byte) map[string]any {
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil
	}
	return payload
}

func nestedMap(payload map[string]any, key string) map[string]any {
	if key == "" {
		return nil
	}
	value, ok := payload[key]
	if !ok {
		return nil
	}
	typed, _ := value.(map[string]any)
	return typed
}

func getString(payload map[string]any, key string) string {
	value, ok := payload[key]
	if !ok || value == nil {
		return ""
	}
	switch typed := value.(type) {
	case string:
		return typed
	case fmt.Stringer:
		return typed.String()
	default:
		return fmt.Sprintf("%v", typed)
	}
}

func getStringSlice(value any) []string {
	items, ok := value.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(items))
	for _, item := range items {
		text := strings.TrimSpace(fmt.Sprintf("%v", item))
		if text != "" {
			out = append(out, text)
		}
	}
	return out
}

func firstErrorCode(payload map[string]any) string {
	errors, ok := payload["errors"].([]any)
	if !ok || len(errors) == 0 {
		return ""
	}
	first, ok := errors[0].(map[string]any)
	if !ok {
		return ""
	}
	return getString(first, "code")
}

func strconvQuote(value string) string {
	encoded, _ := json.Marshal(value)
	return string(encoded)
}

// ---------------------------------------------------------------------------
// Misc helpers
// ---------------------------------------------------------------------------

func extractHTMLTitle(htmlBody string) string {
	lower := strings.ToLower(htmlBody)
	start := strings.Index(lower, "<title")
	if start < 0 {
		return ""
	}
	start = strings.Index(htmlBody[start:], ">")
	if start < 0 {
		return ""
	}
	start = strings.Index(lower, "<title") + start + 1
	end := strings.Index(lower[start:], "</title>")
	if end < 0 {
		return strings.TrimSpace(htmlBody[start:minInt(start+120, len(htmlBody))])
	}
	return strings.TrimSpace(htmlBody[start : start+end])
}

func resolveURL(baseURL, location string) (string, error) {
	base, err := url.Parse(baseURL)
	if err != nil {
		return "", err
	}
	ref, err := url.Parse(location)
	if err != nil {
		return "", err
	}
	return base.ResolveReference(ref).String(), nil
}

func deriveSessionContinueURL(currentURL string) string {
	parsed, err := url.Parse(currentURL)
	if err != nil {
		return ""
	}

	if strings.Contains(parsed.Path, "/preannouncement/block-sessions") {
		derived := *parsed
		derived.Path = strings.TrimRight(parsed.Path, "/") + "/next"
		derived.RawQuery = ""
		return derived.String()
	}

	nextPath := strings.TrimRight(parsed.Path, "/") + "/next"
	query := parsed.Query()
	query.Set("status", "2")

	derived := *parsed
	derived.Path = nextPath
	derived.RawQuery = query.Encode()
	return derived.String()
}

func derivePreannouncementDeleteURL(currentURL string) string {
	parsed, err := url.Parse(currentURL)
	if err != nil {
		return ""
	}

	index := strings.Index(parsed.Path, "/preannouncement/")
	if index < 0 {
		return ""
	}

	derived := *parsed
	derived.Path = strings.TrimRight(parsed.Path[:index], "/") + "/webclient/v1/announcement/pre/blocksessions"
	derived.RawQuery = ""
	return derived.String()
}

func extractSessionContinueURL(rawHTML, currentURL string) string {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(rawHTML))
	if err == nil {
		selectors := []string{
			`#continue_button[href]`,
			`.continue_button[href]`,
			`a[href*="/next?status=2"]`,
			`a[href*="status=2"]`,
			`button[href*="status=2"]`,
		}
		for _, selector := range selectors {
			href, ok := doc.Find(selector).First().Attr("href")
			if ok && strings.TrimSpace(href) != "" {
				if resolved, err := resolveURL(currentURL, href); err == nil {
					return resolved
				}
			}
		}
	}

	if href := firstRegexGroup(rawHTML, `href="([^"]*\/next\?status=2[^"]*)"`); href != "" {
		if resolved, err := resolveURL(currentURL, href); err == nil {
			return resolved
		}
	}

	return ""
}

func extractContinuationActions(rawHTML, currentURL string) []sessionAction {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(rawHTML))
	if err != nil {
		return nil
	}

	var actions []sessionAction
	seen := map[string]bool{}
	addAction := func(action sessionAction) {
		if strings.TrimSpace(action.url) == "" {
			return
		}
		if strings.TrimSpace(action.method) == "" {
			action.method = methodGet
		}
		key := action.method + " " + action.url + " " + string(action.body)
		if seen[key] {
			return
		}
		seen[key] = true
		actions = append(actions, action)
	}

	doc.Find("a[href], button[href], [data-href]").Each(func(_ int, sel *goquery.Selection) {
		for _, attr := range []string{"href", "data-href"} {
			target, ok := sel.Attr(attr)
			if !ok {
				continue
			}
			if resolved, ok := resolveSessionActionURL(currentURL, target); ok {
				addAction(sessionAction{
					name:   "session_action_link",
					method: methodGet,
					url:    resolved,
				})
			}
		}
	})

	doc.Find("form").Each(func(_ int, form *goquery.Selection) {
		actionURL, _ := form.Attr("action")
		if strings.TrimSpace(actionURL) == "" {
			actionURL = currentURL
		}
		resolved, ok := resolveSessionActionURL(currentURL, actionURL)
		if !ok {
			return
		}

		method := strings.ToUpper(strings.TrimSpace(attrOrDefault(form, "method", methodGet)))
		values := url.Values{}
		form.Find("input,select,textarea").Each(func(_ int, field *goquery.Selection) {
			name, ok := field.Attr("name")
			if !ok || strings.TrimSpace(name) == "" {
				return
			}
			fieldType := strings.ToLower(strings.TrimSpace(attrOrDefault(field, "type", "")))
			if fieldType == "submit" || fieldType == "button" {
				return
			}
			value, _ := field.Attr("value")
			values.Add(name, value)
		})

		action := sessionAction{
			name:   "session_action_form",
			method: method,
			url:    resolved,
		}
		if method != methodGet && len(values) > 0 {
			action.body = []byte(values.Encode())
			action.contentType = "application/x-www-form-urlencoded;charset=UTF-8"
		}
		addAction(action)
	})

	doc.Find("[onclick]").Each(func(_ int, sel *goquery.Selection) {
		onclick, _ := sel.Attr("onclick")
		for _, candidate := range extractJSURLCandidates(onclick) {
			if resolved, ok := resolveSessionActionURL(currentURL, candidate); ok {
				addAction(sessionAction{
					name:   "session_action_onclick",
					method: methodGet,
					url:    resolved,
				})
			}
		}
	})

	return actions
}

func resolveSessionActionURL(currentURL, rawTarget string) (string, bool) {
	target := strings.TrimSpace(rawTarget)
	if target == "" {
		return "", false
	}
	target = strings.Trim(target, `"'`)
	lower := strings.ToLower(target)
	relevant := strings.Contains(lower, "block-sessions") ||
		strings.Contains(lower, "sessions-reminder") ||
		strings.Contains(lower, "signin-block") ||
		strings.Contains(lower, "terminate") ||
		strings.Contains(lower, "status=2") ||
		strings.Contains(lower, "continue") ||
		strings.Contains(lower, "understand")
	if !relevant {
		return "", false
	}
	resolved, err := resolveURL(currentURL, target)
	if err != nil {
		return "", false
	}
	return resolved, true
}

func extractJSURLCandidates(raw string) []string {
	patterns := []string{
		`location\.href\s*=\s*['"]([^'"]+)['"]`,
		`window\.location\s*=\s*['"]([^'"]+)['"]`,
		`window\.open\(\s*['"]([^'"]+)['"]`,
		`['"]([^'"]*(?:block-sessions|sessions-reminder|status=2|terminate|continue)[^'"]*)['"]`,
	}
	seen := map[string]bool{}
	var matches []string
	for _, pattern := range patterns {
		re := regexpMustCompile(pattern)
		for _, item := range re.FindAllStringSubmatch(raw, -1) {
			if len(item) < 2 {
				continue
			}
			candidate := strings.TrimSpace(item[1])
			if candidate == "" || seen[candidate] {
				continue
			}
			seen[candidate] = true
			matches = append(matches, candidate)
		}
	}
	return matches
}

func attrOrDefault(sel *goquery.Selection, name, fallback string) string {
	value, ok := sel.Attr(name)
	if !ok {
		return fallback
	}
	return value
}

// base64StdEncoding is an alias to avoid clashing with any future import.
var base64StdEncoding = encoding_base64.StdEncoding

// queryEscape wraps url.QueryEscape for use from main.go without importing net/url.
func queryEscape(s string) string {
	return url.QueryEscape(s)
}
