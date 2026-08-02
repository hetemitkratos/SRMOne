/**
 * Calendar-Timetable integration helper.
 *
 * The SRM academic calendar assigns a "day order" (1-5) to each working day.
 * This is NOT a fixed weekday-to-day-order mapping (e.g. Mon != always Day 1).
 * Holidays shift the day order sequence, so we must consult the calendar
 * to know which timetable day-order applies on any given date.
 *
 * Calendar day object shape (from /calendar API):
 *   { date: "3", day: "Mon", event: "Enrolment Day...", dayOrder: "5" }
 *   dayOrder is "1"-"5" for working days, "-" for holidays/weekends.
 */

const MONTH_ABBREVS = [
  "jan", "feb", "mar", "apr", "may", "jun",
  "jul", "aug", "sep", "oct", "nov", "dec",
];

/**
 * Parse a calendar month name like "Aug '26" or "August 2026" into { month, year }.
 * Returns { month: 0-11, year: 4-digit } or null.
 */
function parseMonthName(name) {
  if (!name) return null;
  const lower = name.toLowerCase().replace(/[''']/g, "").trim();
  // Match "aug 26" or "august 2026" or "aug'26"
  const m = lower.match(/([a-z]{3,9})\s*'?(\d{2,4})/);
  if (!m) return null;
  const monthStr = m[1].slice(0, 3);
  const monthIdx = MONTH_ABBREVS.indexOf(monthStr);
  if (monthIdx < 0) return null;
  let year = parseInt(m[2]);
  if (year < 100) year += 2000;
  return { month: monthIdx, year };
}

/**
 * Build a lookup map from the calendar data.
 * Returns a Map keyed by "YYYY-MM-DD" → { date, day, event, dayOrder, isHoliday, dayOrderNum }
 *
 * @param {object} calendar - The calendar object from /calendar API (has .months[])
 * @returns {Map<string, object>}
 */
export function buildCalendarMap(calendar) {
  const map = new Map();
  if (!calendar?.months) return map;

  for (const monthData of calendar.months) {
    const parsed = parseMonthName(monthData.name);
    if (!parsed) continue;
    const { month, year } = parsed;

    for (const day of monthData.days || []) {
      const dateNum = parseInt(day.date);
      if (isNaN(dateNum)) continue;

      const dateObj = new Date(year, month, dateNum);
      const key = dateKey(dateObj);
      const dayOrderRaw = String(day.dayOrder || "").trim();
      const dayOrderNum = dayOrderRaw !== "-" && dayOrderRaw !== "" ? parseInt(dayOrderRaw) : null;
      const eventText = (day.event || "").trim();
      const isHoliday = /holiday/i.test(eventText);

      map.set(key, {
        date: dateObj,
        day: day.day,
        event: eventText,
        dayOrder: dayOrderRaw,
        dayOrderNum,
        isHoliday,
        isWeekend: day.day === "Sun" || day.day === "Sat",
        isWorkingDay: !!dayOrderNum && !isHoliday,
      });
    }
  }
  return map;
}

/**
 * Format a Date as "YYYY-MM-DD" (local time, not UTC).
 */
export function dateKey(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * Get calendar info for a specific date.
 * @param {Map} calendarMap - from buildCalendarMap
 * @param {Date} date
 * @returns {object|null} - the calendar entry for this date, or null if not in calendar
 */
export function getCalendarInfo(calendarMap, date) {
  if (!calendarMap) return null;
  return calendarMap.get(dateKey(date)) || null;
}

/**
 * Get the effective day order for a date.
 * Returns the day order number (1-5) if it's a working day, or null if holiday/weekend/not in calendar.
 *
 * @param {Map} calendarMap
 * @param {Date} date
 * @returns {number|null}
 */
export function getEffectiveDayOrder(calendarMap, date) {
  const info = getCalendarInfo(calendarMap, date);
  if (!info) return null;
  if (info.isHoliday) return null;
  return info.dayOrderNum;
}

/**
 * Get the dates for the current week (Mon-Fri).
 * Returns an array of 5 Date objects, Monday through Friday.
 */
export function getCurrentWeekDates() {
  const today = new Date();
  const dayOfWeek = today.getDay(); // 0=Sun, 1=Mon, ... 6=Sat
  const monday = new Date(today);
  // If today is Sunday (0), go back 6 days; otherwise go back (dayOfWeek - 1) days
  const offset = dayOfWeek === 0 ? -6 : -(dayOfWeek - 1);
  monday.setDate(today.getDate() + offset);

  return Array.from({ length: 5 }, (_, i) => {
    const d = new Date(monday);
    d.setDate(monday.getDate() + i);
    return d;
  });
}

/**
 * Get the default day order for a weekday (fallback when calendar data is unavailable).
 * Mon=1, Tue=2, Wed=3, Thu=4, Fri=5
 */
export function getDefaultDayOrder(date) {
  const day = date.getDay(); // 1=Mon ... 5=Fri
  return day >= 1 && day <= 5 ? day : null;
}

/**
 * Get a human-readable description of the calendar state for a date.
 * Returns { status: "holiday"|"working"|"weekend"|"unknown", dayOrder, event, label }
 */
export function getDayStatus(calendarMap, date) {
  const info = getCalendarInfo(calendarMap, date);

  if (!info) {
    const defaultOrder = getDefaultDayOrder(date);
    const isWeekend = date.getDay() === 0 || date.getDay() === 6;
    return {
      status: isWeekend ? "weekend" : "unknown",
      dayOrder: defaultOrder,
      event: "",
      label: isWeekend ? "Weekend" : "No calendar data",
    };
  }

  if (info.isHoliday) {
    return {
      status: "holiday",
      dayOrder: null,
      event: info.event,
      label: info.event || "Holiday",
    };
  }

  if (info.isWeekend || !info.dayOrderNum) {
    return {
      status: "weekend",
      dayOrder: null,
      event: info.event,
      label: info.event || "Weekend",
    };
  }

  return {
    status: "working",
    dayOrder: info.dayOrderNum,
    event: info.event,
    label: info.event || `Day ${info.dayOrderNum}`,
  };
}
