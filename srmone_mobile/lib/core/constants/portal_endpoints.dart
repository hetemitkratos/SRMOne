// lib/core/constants/portal_endpoints.dart
// SRM portal endpoints, base URLs, and portal IDs — ported verbatim from
// academia-scraper/cmd/loginprobe/login.go constants section.

class PortalEndpoints {
  PortalEndpoints._();

  // ─── Academia Portal ─────────────────────────────────────────────────────────
  static const String academiaBaseUrl = 'https://academia.srmist.edu.in';
  static const String defaultPortalId = '40-10002227248';
  static const String defaultStudentPhotoReportId = '2727643000298055031';
  static const String signinPath = '/accounts/p/$defaultPortalId/signin';
  static const String attendanceUrl =
      '$academiaBaseUrl/srm_university/academia-academic-services/page/My_Time_Table_2023_24';
  static const String personalTimetableUrl =
      '$academiaBaseUrl/srm_university/academia-academic-services/page/My_Time_Table_2023_24';
  static const String unifiedTimetableBatch1 =
      '$academiaBaseUrl/srm_university/academia-academic-services/page/Unified_Time_Table_2025_Batch_1';
  static const String unifiedTimetableBatch2 =
      '$academiaBaseUrl/srm_university/academia-academic-services/page/Unified_Time_Table_2025_batch_2';
  static const String academicReportsUrl =
      '$academiaBaseUrl/srm_university/academia-academic-services/page/Academic_Reports';

  // ─── Student Portal ───────────────────────────────────────────────────────────
  static const String studentPortalBaseUrl = 'https://sp.srmist.edu.in';
  static const String spLoginUrl =
      '$studentPortalBaseUrl/srmiststudentportal/students/LoginServlet';
  static const String spAttendanceUrl =
      '$studentPortalBaseUrl/srmiststudentportal/students/report/studentattendancedetails.jsp';
  static const String spDashboardUrl =
      '$studentPortalBaseUrl/srmiststudentportal/students/report/studentpersonaldetails.jsp';

  // ─── Faculty Scraper ──────────────────────────────────────────────────────────
  static const String facultySearchUrl =
      'https://www.srmist.edu.in/?s={query}&post_type=faculty';
  static const String facultyProfileBaseUrl =
      'https://www.srmist.edu.in/faculty/';

  // ─── User-Agent ───────────────────────────────────────────────────────────────
  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0.0.0 Safari/537.36';
}
