package main

import (
	"bytes"
	"fmt"
	"os"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"golang.org/x/net/html"
)

// parseSPHTML creates a goquery document from raw HTML bytes.
func parseSPHTML(htmlBytes []byte) *goquery.Document {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(htmlBytes))
	if err != nil {
		return nil
	}
	return doc
}

// parseSPAttendance extracts attendance records from the student portal HTML.
// The SRM student portal typically shows attendance in a table with columns like:
// Course Code, Course Title, Category, Faculty, Slot, Room, Hours Conducted, Hours Absent, Attn %
func parseSPAttendance(htmlBytes []byte) []SPAttendanceRecord {
	doc := parseSPHTML(htmlBytes)
	if doc == nil {
		fmt.Fprintf(os.Stderr, "[parseSPAttendance] failed to parse HTML\n")
		return nil
	}

	var records []SPAttendanceRecord

	// Find the attendance table — look for a table containing "Attn" or "Attendance" header
	var table *goquery.Selection
	var headers []string

	tableCount := 0
	doc.Find("table").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		tableCount++
		rowHeaders := spExtractHeaders(sel)
		fmt.Fprintf(os.Stderr, "[parseSPAttendance] table #%d headers=%v\n", tableCount, rowHeaders)
		if len(rowHeaders) < 2 {
			return true
		}
		// Match on common attendance table header patterns
		if spContainsHeader(rowHeaders, "Attn") || spContainsHeader(rowHeaders, "Attendance") ||
			(spContainsHeader(rowHeaders, "%") && spContainsHeader(rowHeaders, "Course")) ||
			(spContainsHeader(rowHeaders, "Percentage") && spContainsHeader(rowHeaders, "Code")) {
			table = sel
			headers = rowHeaders
			fmt.Fprintf(os.Stderr, "[parseSPAttendance] matched table #%d\n", tableCount)
			return false
		}
		return true
	})

	fmt.Fprintf(os.Stderr, "[parseSPAttendance] total tables=%d matched=%v\n", tableCount, table != nil)

	if table == nil {
		// Fallback: try any table with enough rows that looks like data
		doc.Find("table").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
			rowHeaders := spExtractHeaders(sel)
			if len(rowHeaders) >= 5 {
				table = sel
				headers = rowHeaders
				return false
			}
			return true
		})
	}

	if table == nil {
		fmt.Fprintf(os.Stderr, "[parseSPAttendance] no table matched (tables=%d)\n", tableCount)
		return nil
	}

	fmt.Fprintf(os.Stderr, "[parseSPAttendance] using headers=%v\n", headers)

	table.Find("tr").Each(func(index int, row *goquery.Selection) {
		if index == 0 {
			return
		}

		cells := spExtractCells(row)
		if len(cells) == 0 || strings.TrimSpace(cells[0]) == "" {
			return
		}

		recordMap := make(map[string]string, len(headers))
		for i, header := range headers {
			if i < len(cells) {
				recordMap[header] = cells[i]
			} else {
				recordMap[header] = ""
			}
		}

		record := SPAttendanceRecord{
			CourseCode:     spGetField(recordMap, []string{"Course Code", "courseCode", "Subject Code", "Code"}),
			CourseTitle:    spGetField(recordMap, []string{"Course Title", "courseTitle", "Subject", "Course", "Subject Name", "Description"}),
			Category:       spGetField(recordMap, []string{"Category", "category", "Type"}),
			FacultyName:    spGetField(recordMap, []string{"Faculty Name", "facultyName", "Faculty", "Teacher"}),
			Slot:           spGetField(recordMap, []string{"Slot", "slot"}),
			RoomNo:         spGetField(recordMap, []string{"Room No", "roomNo", "Room", "Room Number"}),
			HoursConducted: spGetField(recordMap, []string{"Hours Conducted", "hoursConducted", "Conducted", "Total Hours", "Max. hours"}),
			HoursAbsent:    spGetField(recordMap, []string{"Hours Absent", "hoursAbsent", "Absent", "Absent hours"}),
			AttendancePct:  spGetField(recordMap, []string{"Attn %", "Attendance %", "attendancePct", "Percentage", "%", "Attn", "Total Percentage"}),
		}

		// If HoursConducted came from "Max. hours", also check for "Att. hours" as attended
		// but we keep HoursConducted as Max. hours (total conducted) per the field semantics

		// Only add if we have at least a course code or course title
		if record.CourseCode != "" || record.CourseTitle != "" {
			records = append(records, record)
		}
	})

	fmt.Fprintf(os.Stderr, "[parseSPAttendance] parsed %d records\n", len(records))
	return records
}

// parseSPStudentInfo extracts student profile information from the portal HTML.
func parseSPStudentInfo(htmlBytes []byte) SPStudentInfo {
	doc := parseSPHTML(htmlBytes)
	if doc == nil {
		return SPStudentInfo{}
	}

	info := SPStudentInfo{}

	// Strategy 1: Look for table rows with label-value cell pairs
	// SRM profile page uses <tr><td>Label</td><td>Value</td></tr> structure
	doc.Find("tr").Each(func(_ int, row *goquery.Selection) {
		cells := spExtractCells(row)
		if len(cells) < 2 {
			return
		}
		label := strings.ToLower(strings.TrimSpace(cells[0]))
		value := strings.TrimSpace(cells[1])

		// Clean up label and value
		label = strings.TrimRight(label, ":")
		value = strings.TrimSpace(value)

		if value == "" || value == ":" {
			return
		}

		if (strings.Contains(label, "name") || strings.Contains(label, "student name")) && info.Name == "" {
			info.Name = value
		}
		if (strings.Contains(label, "reg") && (strings.Contains(label, "no") || strings.Contains(label, "number"))) && info.RegNumber == "" {
			info.RegNumber = value
		}
		if strings.Contains(label, "net") && strings.Contains(label, "id") && info.NetID == "" {
			info.NetID = value
		}
		if strings.Contains(label, "branch") && info.Branch == "" {
			info.Branch = value
		}
		if strings.Contains(label, "program") && info.Program == "" {
			info.Program = value
		}
		if strings.Contains(label, "school") && info.School == "" {
			info.School = value
		}
		if strings.Contains(label, "semester") && info.Semester == "" {
			info.Semester = value
		}
		if strings.Contains(label, "section") && info.Section == "" {
			info.Section = value
		}
		if strings.Contains(label, "batch") && info.Batch == "" {
			info.Batch = value
		}
		if strings.Contains(label, "email") && info.Email == "" {
			info.Email = value
		}
		if strings.Contains(label, "mobile") && info.Mobile == "" {
			info.Mobile = value
		}
	})

	// Strategy 2: Look for specific elements with IDs or classes
	doc.Find("#studentName, .student-name, #name").Each(func(_ int, sel *goquery.Selection) {
		if info.Name == "" {
			info.Name = strings.TrimSpace(sel.Text())
		}
	})

	doc.Find("#regNo, .reg-no, #registrationNumber").Each(func(_ int, sel *goquery.Selection) {
		if info.RegNumber == "" {
			info.RegNumber = strings.TrimSpace(sel.Text())
		}
	})

	// Strategy 3: Look for photo
	doc.Find("img").Each(func(_ int, sel *goquery.Selection) {
		if info.PhotoURL != "" {
			return
		}
		src, _ := sel.Attr("src")
		alt, _ := sel.Attr("alt")
		if strings.Contains(strings.ToLower(alt), "photo") || strings.Contains(strings.ToLower(src), "photo") {
			if strings.HasPrefix(src, "/") {
				info.PhotoURL = spBaseURL + src
			} else if strings.HasPrefix(src, "http") {
				info.PhotoURL = src
			}
		}
	})

	return info
}

// ---------------------------------------------------------------------------
// HTML parsing helpers
// ---------------------------------------------------------------------------

func spExtractHeaders(table *goquery.Selection) []string {
	firstRow := table.Find("tr").First()
	return spExtractCells(firstRow)
}

func spExtractCells(row *goquery.Selection) []string {
	var cells []string
	row.Find("th,td").Each(func(_ int, cell *goquery.Selection) {
		cells = append(cells, spExtractCellText(cell))
	})
	return cells
}

func spExtractCellText(cell *goquery.Selection) string {
	var b strings.Builder
	for _, node := range cell.Nodes {
		spWalkNodeText(&b, node)
	}

	text := b.String()
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		lines[i] = strings.Join(strings.Fields(line), " ")
	}

	normalized := strings.Join(lines, "\n")
	normalized = strings.TrimSpace(normalized)

	for strings.Contains(normalized, "\n\n") {
		normalized = strings.ReplaceAll(normalized, "\n\n", "\n")
	}

	return normalized
}

func spWalkNodeText(b *strings.Builder, node *html.Node) {
	if node == nil {
		return
	}

	switch node.Type {
	case html.TextNode:
		b.WriteString(node.Data)
		return
	case html.ElementNode:
		if spIsLineBreakNode(node.Data) && !strings.HasSuffix(b.String(), "\n") {
			b.WriteByte('\n')
		}
	}

	for child := node.FirstChild; child != nil; child = child.NextSibling {
		spWalkNodeText(b, child)
	}

	if node.Type == html.ElementNode && spIsBlockNode(node.Data) && !strings.HasSuffix(b.String(), "\n") {
		b.WriteByte('\n')
	}
}

func spIsLineBreakNode(tag string) bool {
	return tag == "br" || tag == "hr"
}

func spIsBlockNode(tag string) bool {
	switch tag {
	case "div", "p", "section", "article", "header", "footer", "li", "tr", "table":
		return true
	}
	return false
}

func spContainsHeader(headers []string, want string) bool {
	for _, h := range headers {
		if strings.Contains(strings.TrimSpace(h), want) {
			return true
		}
	}
	return false
}

func spGetField(m map[string]string, keys []string) string {
	for _, key := range keys {
		if val, ok := m[key]; ok && val != "" {
			return strings.TrimSpace(val)
		}
	}
	return ""
}

func spExtractValueAfterLabel(text, label string) string {
	// Try to extract "Label: Value" or "Label Value" patterns
	lowerText := strings.ToLower(text)
	idx := strings.Index(lowerText, label)
	if idx < 0 {
		return ""
	}
	rest := text[idx+len(label):]
	// Skip common separators
	rest = strings.TrimLeft(rest, " :\t\n")
	// Take the first line or up to next label
	for i, ch := range rest {
		if ch == '\n' || ch == '\r' {
			rest = rest[:i]
			break
		}
	}
	return strings.TrimSpace(rest)
}
