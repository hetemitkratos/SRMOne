// ─── Session / Auth ──────────────────────────────────────────────

export interface SessionPayload {
  userId: string;
  email: string;
  issuedAt: number;
  expiresAt: number;
}

// ─── Academia scraper types ──────────────────────────────────────

export interface AttendanceRecord {
  course_code: string;
  course_title: string;
  category: string;
  attended: number;
  total: number;
  percentage: number;
  faculty: string;
}

export interface MarkRecord {
  course_code: string;
  course_title: string;
  category: string;
  max_marks: number;
  scored_marks: number;
  weightage: number;
  conducted_on: string;
}

export interface TimetableCourse {
  course_code: string;
  course_title: string;
  slot: string;
  day: string;
  start_time: string;
  end_time: string;
  faculty: string;
  venue: string;
}

export interface CalendarEvent {
  title: string;
  start_date: string;
  end_date: string;
  type: string;
  course_code?: string;
}

export interface StudentInfo {
  name: string;
  reg_number: string;
  email: string;
  phone: string;
  department: string;
  program: string;
  batch: string;
  semester: string;
  section: string;
  photo_url: string;
  advisor: string;
}

// ─── Student Portal types ────────────────────────────────────────

export interface SPAttendanceRecord {
  course_code: string;
  course_title: string;
  attended: number;
  total: number;
  percentage: number;
}

export interface SPStudentInfo {
  name: string;
  reg_number: string;
  email: string;
  photo_url: string;
}

// ─── Haveloc types ───────────────────────────────────────────────

export interface HavelocJob {
  job_id: string;
  title: string;
  company: string;
  description: string;
  posted_on: string;
  deadline: string;
  job_type: string;
  location: string;
  eligibility: string;
  link: string;
}

// ─── Scraper status ──────────────────────────────────────────────

export interface ScraperStatus {
  email: string;
  source: string;
  status: string;
  message: string;
  last_run: string;
  data_hash?: string;
}

// ─── Credentials ─────────────────────────────────────────────────

export interface AcademiaCredentials {
  id: string;
  academia_email: string;
  encrypted_password: string;
  encrypted_sp_password: string | null;
  auto_login_enabled: boolean;
  last_auto_login_at: string | null;
}

export interface PlacementCredentials {
  id: string;
  academia_email: string;
  encrypted_password: string;
  auto_login_enabled: boolean;
}
