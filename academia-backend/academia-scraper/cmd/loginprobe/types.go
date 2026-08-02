package main

import (
	"net/http"
	"regexp"
	"sync"
)

// ---------------------------------------------------------------------------
// Modes
// ---------------------------------------------------------------------------

const (
	modeLogin         = "login"
	modeFetch         = "fetch"
	modeLoginAndFetch = "login_and_fetch"
)

// ---------------------------------------------------------------------------
// Classifications
// ---------------------------------------------------------------------------

const (
	classAuthenticated = "authenticated_session_established"
	classInvalidCreds  = "invalid_credentials"
	classSessions      = "session_reminder_or_active_sessions"
	classDailyLimit    = "daily_signin_warning"
	classCaptcha       = "captcha_or_antibot_challenge"
	classJSDependent   = "js_dependent_flow_or_waf_block"
	classUnknown       = "unknown_intermediate_page"
)

// ---------------------------------------------------------------------------
// Request / Response types (must match the original ProbeResponse schema)
// ---------------------------------------------------------------------------

type ProbeRequest struct {
	Mode          string             `json:"mode"`
	Email         string             `json:"email"`
	Password      string             `json:"password"`
	BaseURL       string             `json:"baseUrl"`
	SigninURL     string             `json:"signinUrl"`
	AttendanceURL string             `json:"attendanceUrl"`
	UserAgent     string             `json:"userAgent"`
	Cookies       []SerializedCookie `json:"cookies,omitempty"`
	Sections      []string           `json:"sections,omitempty"`
	CalendarSems  []string           `json:"calendarSems,omitempty"`
	LoginOnly     bool               `json:"loginOnly"`
}

type SerializedCookie struct {
	Name        string `json:"name"`
	Value       string `json:"value"`
	Path        string `json:"path,omitempty"`
	Domain      string `json:"domain,omitempty"`
	ExpiresUnix int64  `json:"expiresUnix,omitempty"`
	Secure      bool   `json:"secure,omitempty"`
	HttpOnly    bool   `json:"httpOnly,omitempty"`
}

type HiddenField struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

type SigninPageInfo struct {
	FinalURL        string        `json:"finalUrl"`
	URIPathPrefix   string        `json:"uriPathPrefix"`
	ServiceURL      string        `json:"serviceUrl"`
	CSRFParam       string        `json:"csrfParam"`
	CSRFCookieName  string        `json:"csrfCookieName"`
	EmailOnlySignin bool          `json:"emailOnlySignin"`
	HiddenFields    []HiddenField `json:"hiddenFields,omitempty"`
}

type RequestTrace struct {
	Name        string `json:"name"`
	Method      string `json:"method"`
	URL         string `json:"url"`
	StatusCode  int    `json:"statusCode"`
	Location    string `json:"location,omitempty"`
	ContentType string `json:"contentType,omitempty"`
	BodyLength  int    `json:"bodyLength,omitempty"`
}

type LookupSummary struct {
	Attempted        bool     `json:"attempted"`
	StatusCode       int      `json:"statusCode"`
	Code             string   `json:"code,omitempty"`
	ResourceName     string   `json:"resourceName,omitempty"`
	AllowedModes     []string `json:"allowedModes,omitempty"`
	Identifier       string   `json:"identifier,omitempty"`
	LocalizedMessage string   `json:"localizedMessage,omitempty"`
	ErrorCode        string   `json:"errorCode,omitempty"`
}

type PasswordSummary struct {
	Attempted        bool   `json:"attempted"`
	StatusCode       int    `json:"statusCode"`
	Code             string `json:"code,omitempty"`
	ResourceName     string `json:"resourceName,omitempty"`
	LocalizedMessage string `json:"localizedMessage,omitempty"`
	ErrorCode        string `json:"errorCode,omitempty"`
	RedirectURI      string `json:"redirectUri,omitempty"`
	Status           string `json:"status,omitempty"`
	Location         string `json:"location,omitempty"`
}

type AttendanceDebug struct {
	PayloadFound        bool     `json:"payloadFound"`
	PayloadLength       int      `json:"payloadLength"`
	DecodedLength       int      `json:"decodedLength"`
	DecodedHasCourse    bool     `json:"decodedHasCourseCode"`
	DecodedHasAttn      bool     `json:"decodedHasAttnPct"`
	DecodedHasHours     bool     `json:"decodedHasHoursConducted"`
	MatchedHeaders      []string `json:"matchedHeaders"`
	MatchedRowCount     int      `json:"matchedRowCount"`
	ResponseContentType string   `json:"responseContentType"`
}

type AttendanceRecord struct {
	CourseCode     string `json:"courseCode"`
	CourseTitle    string `json:"courseTitle"`
	Category       string `json:"category"`
	FacultyName    string `json:"facultyName"`
	Slot           string `json:"slot"`
	RoomNo         string `json:"roomNo"`
	HoursConducted string `json:"hoursConducted"`
	HoursAbsent    string `json:"hoursAbsent"`
	AttendancePct  string `json:"attendancePct"`
}

type MarkTest struct {
	TestName string `json:"testName"`
	MaxScore string `json:"maxScore"`
	Score    string `json:"score"`
}

type MarkRecord struct {
	CourseCode string     `json:"courseCode"`
	CourseType string     `json:"courseType"`
	Tests      []MarkTest `json:"tests"`
}

type Advisor struct {
	Name  string `json:"name"`
	Role  string `json:"role"`
	Email string `json:"email"`
	Phone string `json:"phone"`
}

type ScheduleEntry struct {
	Day       string `json:"day"`
	HourIndex int    `json:"hourIndex"`
	Timing    string `json:"timing"`
	SlotToken string `json:"slotToken"`
}

type TimetableCourse struct {
	CourseCode  string          `json:"courseCode"`
	CourseTitle string          `json:"courseTitle"`
	Credit      string          `json:"credit"`
	Category    string          `json:"category"`
	CourseType  string          `json:"courseType"`
	FacultyName string          `json:"facultyName"`
	Slot        string          `json:"slot"`
	RoomNo      string          `json:"roomNo"`
	Schedule    []ScheduleEntry `json:"schedule"`
}

type TimetableResult struct {
	Batch    string            `json:"batch"`
	Courses  []TimetableCourse `json:"courses"`
	Advisors []Advisor         `json:"advisors"`
}

type CalendarDay struct {
	Date     string `json:"date"`
	Day      string `json:"day"`
	Event    string `json:"event"`
	DayOrder string `json:"dayOrder"`
}

type CalendarMonth struct {
	Name string        `json:"name"`
	Days []CalendarDay `json:"days"`
}

type CalendarResult struct {
	Sem    string          `json:"sem"`
	Title  string          `json:"title"`
	Months []CalendarMonth `json:"months"`
}

type AttendanceSummary struct {
	Attempted  bool            `json:"attempted"`
	Success    bool            `json:"success"`
	StatusCode int             `json:"statusCode"`
	Rows       int             `json:"rows"`
	Debug      AttendanceDebug `json:"debug"`
	Error      string          `json:"error,omitempty"`
}

type FetchData struct {
	StudentInfo map[string]string         `json:"studentInfo,omitempty"`
	Attendance  []AttendanceRecord        `json:"attendance,omitempty"`
	Marks       []MarkRecord              `json:"marks,omitempty"`
	Timetable   *TimetableResult          `json:"timetable,omitempty"`
	Calendars   map[string]CalendarResult `json:"calendars,omitempty"`
	Errors      map[string]string         `json:"errors,omitempty"`
}

type ProbeResponse struct {
	Success         bool               `json:"success"`
	Classification  string             `json:"classification"`
	FinalURL        string             `json:"finalUrl,omitempty"`
	CookieNames     []string           `json:"cookieNames,omitempty"`
	Cookies         []SerializedCookie `json:"cookies,omitempty"`
	HasJSessionID   bool               `json:"hasJsessionId"`
	SigninPage      SigninPageInfo     `json:"signinPage"`
	Lookup          LookupSummary      `json:"lookup"`
	Password        PasswordSummary    `json:"password"`
	RedirectSummary []RequestTrace     `json:"redirectSummary,omitempty"`
	Attendance      AttendanceSummary  `json:"attendance"`
	Data            FetchData          `json:"data"`
	Error           string             `json:"error,omitempty"`
}

// ---------------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------------

type sessionAction struct {
	name        string
	method      string
	url         string
	body        []byte
	contentType string
}

type decodedFragmentDebug struct {
	statusCode    int
	contentType   string
	payloadFound  bool
	payloadLength int
}

// ---------------------------------------------------------------------------
// Regexp cache (shared, thread-safe)
// ---------------------------------------------------------------------------

var (
	regexpCache   = map[string]*regexp.Regexp{}
	regexpCacheMu sync.Mutex
)

func regexpMustCompile(pattern string) *regexp.Regexp {
	regexpCacheMu.Lock()
	defer regexpCacheMu.Unlock()
	if compiled, ok := regexpCache[pattern]; ok {
		return compiled
	}
	compiled := regexp.MustCompile(pattern)
	regexpCache[pattern] = compiled
	return compiled
}

// HTTP method constants we rely on (avoid importing net/http everywhere).
const (
	methodGet    = http.MethodGet
	methodPost   = http.MethodPost
	methodDelete = http.MethodDelete
)
