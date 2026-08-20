/**
 * Schedule utilities — port of schedule_utils.js.
 * Pure functions for building daily schedule from timetable + calendar data.
 */

interface ClassEntry {
  courseCode: string;
  courseTitle: string;
  credit: string;
  category: string;
  courseType: string;
  facultyName: string;
  facultyPhotoUrl: string;
  slot: string;
  roomNo: string;
  timing: string;
  hourIndex: number;
  slotToken: string;
}

interface Course {
  courseCode: string;
  courseTitle: string;
  credit: string;
  category: string;
  courseType: string;
  facultyName: string;
  facultyPhotoUrl?: string;
  slot: string;
  roomNo: string;
  schedule?: Slot[];
}

interface Slot {
  day: string;
  timing: string;
  hourIndex: number;
  slotToken: string;
}

interface CalendarMonth {
  name: string;
  days: CalendarDay[];
}

interface CalendarDay {
  date: string;
  day: string;
  event?: string;
  dayOrder?: string;
}

interface StudentInfo {
  Semester?: string;
}

interface ScheduleResult {
  date: string;
  monthName: string;
  dayOfWeek: string;
  dayOrder: string | null;
  todayDayOrder: string | null;
  event: string;
  isHoliday: boolean;
  isWeekend: boolean;
  isOverride: boolean;
  semester: string | null;
  semType: string | null;
  classes: ClassEntry[];
}

function formatMonthName(now: Date): string {
  const monthShort = now.toLocaleDateString("en-GB", { month: "short" });
  const yearShort = String(now.getFullYear()).slice(2);
  return `${monthShort} '${yearShort}`;
}

function normalizeMonthName(value: string): string {
  return String(value || "")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

function buildClassEntry(course: Course, slot: Slot): ClassEntry {
  return {
    courseCode: course.courseCode,
    courseTitle: course.courseTitle,
    credit: course.credit,
    category: course.category,
    courseType: course.courseType,
    facultyName: course.facultyName,
    facultyPhotoUrl: course.facultyPhotoUrl || "",
    slot: course.slot,
    roomNo: course.roomNo,
    timing: slot.timing,
    hourIndex: slot.hourIndex,
    slotToken: slot.slotToken,
  };
}

export function buildScheduleFromData({
  timetable,
  calendar = null,
  studentInfo = null,
  overrideDayOrder = null,
  now = new Date(),
}: {
  timetable: { courses: Course[] };
  calendar?: { months: CalendarMonth[] } | null;
  studentInfo?: StudentInfo | null;
  overrideDayOrder?: string | null;
  now?: Date;
}): ScheduleResult {
  const todayDate = String(now.getDate());
  const todayDay = now.toLocaleDateString("en-GB", { weekday: "short" });
  const monthName = formatMonthName(now);

  if (!timetable || !Array.isArray(timetable.courses)) {
    throw new Error("timetable data is required to build schedule");
  }

  if (overrideDayOrder) {
    const dayLabel = `Day ${overrideDayOrder}`;
    const classes: ClassEntry[] = [];

    for (const course of timetable.courses) {
      for (const slot of (course.schedule || [])) {
        if (slot.day === dayLabel) {
          classes.push(buildClassEntry(course, slot));
        }
      }
    }

    classes.sort((a, b) => a.hourIndex - b.hourIndex);
    return {
      date: todayDate,
      monthName,
      dayOfWeek: todayDay,
      dayOrder: overrideDayOrder,
      todayDayOrder: null,
      event: "",
      isHoliday: false,
      isWeekend: false,
      isOverride: true,
      semester: null,
      semType: null,
      classes,
    };
  }

  if (!studentInfo) {
    throw new Error("student info is required to build today's schedule");
  }
  if (!calendar || !Array.isArray(calendar.months)) {
    throw new Error("calendar data is required to build today's schedule");
  }

  const semNum = parseInt(studentInfo.Semester || "1", 10);
  const semType = semNum % 2 === 0 ? "even" : "odd";

  let dayOrder: string | null = null;
  let todayEvent = "";
  let isWeekend = now.getDay() === 0 || now.getDay() === 6;

  const targetMonth = calendar.months.find(
    (month) => normalizeMonthName(month.name) === normalizeMonthName(monthName),
  );

  if (targetMonth) {
    const dayEntry = (targetMonth.days || []).find(
      (entry) => String(entry.date).trim() === todayDate,
    );
    if (dayEntry) {
      isWeekend = dayEntry.day === "Sat" || dayEntry.day === "Sun";
      todayEvent = dayEntry.event || "";
      dayOrder = dayEntry.dayOrder && dayEntry.dayOrder !== "-"
        ? dayEntry.dayOrder
        : null;
    }
  }

  const isHoliday = !isWeekend && !dayOrder && !!todayEvent;
  const activeDayLabel = dayOrder ? `Day ${dayOrder}` : null;
  const classes: ClassEntry[] = [];

  if (activeDayLabel) {
    for (const course of timetable.courses) {
      for (const slot of (course.schedule || [])) {
        if (slot.day === activeDayLabel) {
          classes.push(buildClassEntry(course, slot));
        }
      }
    }
    classes.sort((a, b) => a.hourIndex - b.hourIndex);
  }

  return {
    date: todayDate,
    monthName,
    dayOfWeek: todayDay,
    dayOrder,
    todayDayOrder: dayOrder,
    event: todayEvent,
    isHoliday,
    isWeekend,
    isOverride: false,
    semester: String(semNum),
    semType,
    classes,
  };
}

export function getSemType(studentInfo: { Semester?: string } = {}): string {
  const semNum = parseInt(studentInfo.Semester || "1", 10);
  return semNum % 2 === 0 ? "even" : "odd";
}

function numericValue(value: unknown): number {
  const parsed = typeof value === "number" ? value : parseFloat(String(value ?? "0"));
  return Number.isFinite(parsed) ? parsed : 0;
}

export function buildAttendanceSnapshot(
  attendance: Array<Record<string, unknown>> = [],
): {
  attendanceAverage: number | null;
  lowAttendanceCount: number;
  attendanceCount: number;
} {
  if (!Array.isArray(attendance) || attendance.length === 0) {
    return {
      attendanceAverage: null,
      lowAttendanceCount: 0,
      attendanceCount: 0,
    };
  }

  const percentages = attendance.map((record) => numericValue(record?.attendancePct));
  const average = Math.round(
    percentages.reduce((sum, value) => sum + value, 0) / percentages.length,
  );
  return {
    attendanceAverage: average,
    lowAttendanceCount: percentages.filter((value) => value < 75).length,
    attendanceCount: attendance.length,
  };
}
