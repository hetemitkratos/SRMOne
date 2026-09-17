package main

// ---------------------------------------------------------------------------
// Request / Response types for the SRM Student Portal scraper
// ---------------------------------------------------------------------------

const (
	spModeLogin         = "login"
	spModeFetch         = "fetch"
	spModeLoginAndFetch = "login_and_fetch"
	spModePrepare       = "prepare_only"
)

const (
	spClassAuthenticated = "authenticated_session_established"
	spClassInvalidCreds  = "invalid_credentials"
	spClassCaptchaFailed = "captcha_failed"
	spClassCaptchaNeeded = "captcha_needed"
	spClassUnknown       = "unknown_error"
)

type SPRequest struct {
	Mode          string               `json:"mode"`
	Email         string               `json:"email"`
	Password      string               `json:"password"`
	CaptchaAPIKey string               `json:"captchaApiKey,omitempty"`
	CaptchaAPIURL string               `json:"captchaApiUrl,omitempty"`
	CaptchaAnswer string               `json:"captchaAnswer,omitempty"`
	LoginState    *SPPendingLogin      `json:"loginState,omitempty"`
	Cookies       []SPSerializedCookie `json:"cookies,omitempty"`
	Sections      []string             `json:"sections,omitempty"`
}

// SPPendingLogin is the serialized state needed to resume a login after the
// user solves the captcha manually. It round-trips through the backend.
type SPPendingLogin struct {
	CaptchaFieldName string   `json:"captchaFieldName"`
	DomainFieldName  string   `json:"domainFieldName"`
	RandomDelimiter  string   `json:"randomDelimiter"`
	PageLoadMs       int64    `json:"pageLoadMs"`
	HoneypotNames    []string `json:"honeypotNames"`
}

type SPSerializedCookie struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

type SPAttendanceRecord struct {
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

type SPStudentInfo struct {
	Name      string `json:"name,omitempty"`
	RegNumber string `json:"regNumber,omitempty"`
	NetID     string `json:"netId,omitempty"`
	Branch    string `json:"branch,omitempty"`
	Program   string `json:"program,omitempty"`
	School    string `json:"school,omitempty"`
	Semester  string `json:"semester,omitempty"`
	Section   string `json:"section,omitempty"`
	Batch     string `json:"batch,omitempty"`
	Email     string `json:"email,omitempty"`
	Mobile    string `json:"mobile,omitempty"`
	PhotoURL  string `json:"photoUrl,omitempty"`
}

type SPResponse struct {
	Success        bool                 `json:"success"`
	Classification string               `json:"classification"`
	Cookies        []SPSerializedCookie `json:"cookies,omitempty"`
	CaptchaImage   string               `json:"captchaImage,omitempty"`
	LoginState     *SPPendingLogin      `json:"loginState,omitempty"`
	StudentInfo    SPStudentInfo        `json:"studentInfo,omitempty"`
	Attendance     []SPAttendanceRecord `json:"attendance,omitempty"`
	Error          string               `json:"error,omitempty"`
}
