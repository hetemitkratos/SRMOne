import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { motion, AnimatePresence } from "framer-motion";
import {
  X, Mail, Building2, MapPin, Briefcase, GraduationCap, BookOpen,
  Award, FlaskConical, Users, Calendar, ExternalLink, Loader2,
  ChevronDown, FileText, ScrollText,
} from "lucide-react";
import { api } from "../api/client.js";

function cleanFacultyName(name = "") {
  return String(name)
    .replace(/\(.*?\)/g, "")
    .replace(/^(prof|mrs|ms|mr|dr)\.?\s*/i, "")
    .trim();
}

/**
 * Try to parse education text into a table structure.
 * Looks for patterns like "Degree Institute Specialisation Year".
 */
function parseEducationTable(text) {
  if (!text) return null;
  // Check if it looks like tabular education data (has Degree, Institute, Year keywords)
  if (!/degree|institute|organisation|specialisation|year/i.test(text.substring(0, 100))) {
    return null;
  }

  const lines = text.split(/\n+/).map((l) => l.trim()).filter(Boolean);
  // Find the header line
  const headerIdx = lines.findIndex((l) =>
    /degree.*institute.*specialisation.*year/i.test(l.replace(/\s+/g, " "))
  );

  if (headerIdx === -1) return null;

  // Everything after the header is data — entries are multi-word and start with a degree keyword
  const dataLines = lines.slice(headerIdx + 1);
  const degreeKeywords = /^(B\.?E\.?|B\.?Tech|M\.?E\.?|M\.?Tech|Ph\.?D\.?|MBA|M\.?Sc\.?|B\.?Sc\.?|Post\s+Doctorate|M\.?Phil|B\.?A\.?|M\.?A\.?)/i;

  const entries = [];
  let current = null;

  for (const line of dataLines) {
    if (degreeKeywords.test(line)) {
      if (current) entries.push(current);
      // Try to split the line into parts by multiple spaces or tab-like gaps
      const parts = line.split(/\s{2,}|\t/).map((p) => p.trim()).filter(Boolean);
      if (parts.length >= 3) {
        current = {
          degree: parts[0],
          institute: parts[1],
          specialisation: parts[2] || "",
          year: parts[3] || "",
        };
      } else {
        // Fallback: just store as raw text
        current = { degree: line, institute: "", specialisation: "", year: "" };
      }
    } else if (current) {
      // Continuation of previous entry
      current.institute += " " + line;
      current.institute = current.institute.trim();
    }
  }
  if (current) entries.push(current);

  return entries.length > 0 ? entries : null;
}

/**
 * Split long text into bullet-like entries.
 * Tries to detect numbered items, "List of X" headers, and sentence boundaries.
 */
function splitIntoEntries(text) {
  if (!text) return [];
  const lines = text
    .split(/\n+/)
    .map((l) => l.trim())
    .filter(Boolean);

  // If there are newlines, treat each line as a potential entry
  if (lines.length > 1) {
    // Group lines under "List of X" headers
    const groups = [];
    let currentGroup = { title: "", items: [] };

    for (const line of lines) {
      const isHeader = /^List of |^Attended |^Certificate Program|^SWAYAM|^DLD|^UHV|^Patents:/i.test(line);
      if (isHeader && currentGroup.items.length > 0) {
        groups.push(currentGroup);
        currentGroup = { title: line, items: [] };
      } else if (isHeader) {
        currentGroup = { title: line, items: [] };
      } else {
        currentGroup.items.push(line);
      }
    }
    if (currentGroup.items.length > 0 || currentGroup.title) {
      groups.push(currentGroup);
    }
    return groups.length > 0 ? groups : [{ title: "", items: lines }];
  }

  // Single long line — split by sentence-like boundaries
  const sentences = text
    .split(/(?<=[.])\s+(?=[A-Z])/)
    .map((s) => s.trim())
    .filter(Boolean);
  return [{ title: "", items: sentences }];
}

/**
 * Collapsible accordion section for long content.
 */
function AccordionSection({ icon, label, value, defaultOpen = false }) {
  const [open, setOpen] = useState(defaultOpen);
  const entries = splitIntoEntries(value);
  const eduTable = label === "Education" ? parseEducationTable(value) : null;
  const isLong = value.length > 300;

  return (
    <div className="rounded-xl border border-slate-200 overflow-hidden">
      <button
        onClick={() => setOpen((v) => !v)}
        className="w-full flex items-center justify-between px-4 py-3 bg-slate-50 hover:bg-slate-100 transition-colors cursor-pointer"
      >
        <div className="flex items-center gap-2.5">
          <span className="text-slate-400 flex-shrink-0">{icon}</span>
          <span className="text-[13px] font-bold text-slate-800">{label}</span>
          {!isLong && (
            <span className="text-[11px] text-slate-400 font-medium">
              {value.length > 50 ? `${value.substring(0, 50)}…` : value}
            </span>
          )}
          {isLong && (
            <span className="text-[10px] px-2 py-0.5 rounded-full bg-slate-200 text-slate-500 font-bold">
              {entries.reduce((acc, g) => acc + g.items.length, 0)} items
            </span>
          )}
        </div>
        <ChevronDown
          size={16}
          className={`text-slate-400 transition-transform flex-shrink-0 ${open ? "rotate-180" : ""}`}
        />
      </button>

      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2, ease: "easeOut" }}
            className="overflow-hidden"
          >
            <div className="px-4 py-4">
              {/* Education table */}
              {eduTable ? (
                <div className="overflow-x-auto">
                  <table className="w-full text-[12px] border-collapse">
                    <thead>
                      <tr className="border-b-2 border-slate-200">
                        <th className="text-left py-2 px-2 font-bold text-slate-500 uppercase tracking-wide text-[10px]">Degree</th>
                        <th className="text-left py-2 px-2 font-bold text-slate-500 uppercase tracking-wide text-[10px]">Institute</th>
                        <th className="text-left py-2 px-2 font-bold text-slate-500 uppercase tracking-wide text-[10px]">Specialisation</th>
                        <th className="text-left py-2 px-2 font-bold text-slate-500 uppercase tracking-wide text-[10px]">Year</th>
                      </tr>
                    </thead>
                    <tbody>
                      {eduTable.map((row, i) => (
                        <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                          <td className="py-2 px-2 font-semibold text-slate-700 whitespace-nowrap">{row.degree}</td>
                          <td className="py-2 px-2 text-slate-600">{row.institute}</td>
                          <td className="py-2 px-2 text-slate-600">{row.specialisation}</td>
                          <td className="py-2 px-2 text-slate-500 font-mono whitespace-nowrap">{row.year}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : entries.length > 1 || (entries.length === 1 && entries[0].items.length > 1) ? (
                /* Grouped bullet entries */
                <div className="space-y-4">
                  {entries.map((group, gi) => (
                    <div key={gi}>
                      {group.title && (
                        <p className="text-[11px] font-bold uppercase tracking-wide text-slate-400 mb-2 mt-1">
                          {group.title}
                        </p>
                      )}
                      <ul className="space-y-1.5">
                        {group.items.map((item, ii) => (
                          <li key={ii} className="flex items-start gap-2 text-[13px] text-slate-600 leading-relaxed">
                            <span className="w-1.5 h-1.5 rounded-full bg-slate-300 flex-shrink-0 mt-1.5" />
                            <span>{item}</span>
                          </li>
                        ))}
                      </ul>
                    </div>
                  ))}
                </div>
              ) : (
                /* Simple text */
                <p className="text-[13px] text-slate-600 leading-relaxed whitespace-pre-wrap">
                  {value}
                </p>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

/**
 * Fullscreen modal showing an enlarged faculty photo + scraped profile info.
 * Fetches data from /faculty?name= on open.
 */
export default function FacultyProfileModal({ open, name, photoUrl, onClose }) {
  const [faculty, setFaculty] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const label = cleanFacultyName(name) || name || "Faculty";
  const proxied = photoUrl ? api.facultyPhoto(photoUrl) : "";

  useEffect(() => {
    if (!open || !name) return;
    let cancelled = false;
    setLoading(true);
    setError("");
    setFaculty(null);

    // 1. Check localStorage first (24h TTL)
    const lsKey = `faculty_cache:${cleanFacultyName(name).toLowerCase().replace(/[^a-z0-9]+/g, "-")}`;
    const LOCAL_TTL = 24 * 60 * 60 * 1000; // 24 hours
    try {
      const raw = localStorage.getItem(lsKey);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed && parsed.fetchedAt && Date.now() - parsed.fetchedAt < LOCAL_TTL) {
          setFaculty(parsed.data);
          setLoading(false);
          return; // Cache hit — no API call needed
        }
      }
    } catch { /* ignore parse errors */ }

    // 2. Cache miss — fetch from backend (which checks DB + in-memory cache)
    api
      .faculty(name)
      .then((res) => {
        if (cancelled) return;
        if (res.faculty) {
          setFaculty(res.faculty);
          // Save to localStorage
          try {
            localStorage.setItem(lsKey, JSON.stringify({
              data: res.faculty,
              fetchedAt: Date.now(),
            }));
          } catch { /* localStorage full or disabled */ }
        } else if (res.error) {
          setError(res.error);
        }
      })
      .catch((err) => {
        if (!cancelled) setError(err.message || "Failed to load faculty info");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, name]);

  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => {
      if (e.key === "Escape") onClose?.();
    };
    document.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [open, onClose]);

  if (typeof document === "undefined") return null;

  const infoRows = [
    { icon: <Briefcase size={14} />, label: "Designation", value: faculty?.designation },
    { icon: <Building2 size={14} />, label: "Department", value: faculty?.department },
    { icon: <Mail size={14} />, label: "Email", value: faculty?.email, link: faculty?.email ? `mailto:${faculty.email}` : null },
    { icon: <MapPin size={14} />, label: "Campus", value: faculty?.campus },
    { icon: <Briefcase size={14} />, label: "Experience", value: faculty?.experience },
    { icon: <FlaskConical size={14} />, label: "Research Interest", value: faculty?.research_interest },
    { icon: <BookOpen size={14} />, label: "Courses", value: faculty?.courses },
  ];

  const tabSections = [
    { icon: <GraduationCap size={15} />, label: "Education", value: faculty?.education, defaultOpen: true },
    { icon: <ScrollText size={15} />, label: "Publications", value: faculty?.publications },
    { icon: <Award size={15} />, label: "Awards", value: faculty?.awards, defaultOpen: true },
    { icon: <Users size={15} />, label: "Workshops & Conferences", value: faculty?.workshops },
    { icon: <Briefcase size={15} />, label: "Work Experience", value: faculty?.work_experience, defaultOpen: true },
    { icon: <Users size={15} />, label: "Memberships", value: faculty?.memberships, defaultOpen: true },
    { icon: <Calendar size={15} />, label: "Responsibilities", value: faculty?.responsibilities, defaultOpen: true },
  ].filter((s) => s.value);

  return createPortal(
    <AnimatePresence>
      {open && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-8">
          <motion.button
            type="button"
            aria-label="Close preview"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 bg-slate-950/70 backdrop-blur-sm cursor-pointer border-0"
            onClick={onClose}
          />

          <motion.div
            role="dialog"
            aria-modal="true"
            aria-label={`Faculty profile: ${label}`}
            initial={{ opacity: 0, scale: 0.92, y: 16 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.96, y: 8 }}
            transition={{ duration: 0.2, ease: "easeOut" }}
            className="relative z-10 w-full max-w-2xl max-h-[88vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="relative rounded-[28px] overflow-hidden bg-white shadow-2xl border border-white/20">
              {/* Close button */}
              <button
                type="button"
                onClick={onClose}
                className="absolute top-3 right-3 z-20 w-9 h-9 rounded-full bg-black/55 hover:bg-black/75 text-white flex items-center justify-center backdrop-blur-sm cursor-pointer transition-colors"
                aria-label="Close"
              >
                <X size={16} strokeWidth={2.5} />
              </button>

              {/* Hero header with photo */}
              <div className="bg-[#1A1A1A] px-6 sm:px-8 pt-8 pb-6 relative overflow-hidden">
                <div className="absolute right-0 top-0 w-[35%] h-full opacity-5 pointer-events-none flex items-center justify-center">
                  <GraduationCap size={300} className="object-contain" />
                </div>
                <div className="relative z-10 flex items-start gap-5">
                  <div className="w-24 h-24 sm:w-28 sm:h-28 rounded-2xl bg-white/10 flex items-center justify-center flex-shrink-0 overflow-hidden border border-white/10">
                    {proxied ? (
                      <img
                        src={proxied}
                        alt={label}
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          e.target.style.display = "none";
                        }}
                      />
                    ) : (
                      <GraduationCap size={40} className="text-white/60" />
                    )}
                  </div>
                  <div className="flex-1 min-w-0 pt-1">
                    <h2 className="text-xl sm:text-2xl font-display font-bold text-white leading-tight break-words">
                      {faculty?.name || label}
                    </h2>
                    {faculty?.designation && (
                      <p className="text-white/60 text-sm mt-1">{faculty.designation}</p>
                    )}
                    {faculty?.department && (
                      <p className="text-white/40 text-[13px] mt-0.5">{faculty.department}</p>
                    )}
                    {faculty?.profile_url && (
                      <a
                        href={faculty.profile_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 text-[12px] font-semibold text-white/50 hover:text-white transition-colors mt-3"
                      >
                        <ExternalLink size={12} /> View full SRM profile
                      </a>
                    )}
                  </div>
                </div>
              </div>

              {/* Body */}
              <div className="p-6 sm:p-8">
                {loading && (
                  <div className="flex flex-col items-center justify-center py-12">
                    <Loader2 size={28} className="text-slate-300 animate-spin mb-3" />
                    <p className="text-sm text-slate-400 font-medium">Loading faculty info…</p>
                  </div>
                )}

                {error && !loading && (
                  <div className="text-center py-10">
                    <p className="text-sm text-slate-400 font-medium">
                      Couldn't load detailed info for this faculty member.
                    </p>
                    <p className="text-[12px] text-slate-300 mt-1">{error}</p>
                  </div>
                )}

                {faculty && !loading && (
                  <>
                    {/* Quick info grid */}
                    {infoRows.some((r) => r.value) && (
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-6">
                        {infoRows
                          .filter((r) => r.value)
                          .map((row, i) => (
                            <div
                              key={i}
                              className="flex items-start gap-2.5 px-4 py-3 rounded-xl bg-slate-50 border border-slate-100"
                            >
                              <div className="w-7 h-7 rounded-lg bg-white flex items-center justify-center text-slate-400 flex-shrink-0 border border-slate-100">
                                {row.icon}
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="text-[10px] font-bold uppercase tracking-wide text-slate-400">
                                  {row.label}
                                </p>
                                {row.link ? (
                                  <a
                                    href={row.link}
                                    className="text-[13px] font-semibold text-blue-600 hover:text-blue-800 break-all transition-colors"
                                  >
                                    {row.value}
                                  </a>
                                ) : (
                                  <p className="text-[13px] font-semibold text-slate-700 break-words">
                                    {row.value}
                                  </p>
                                )}
                              </div>
                            </div>
                          ))}
                      </div>
                    )}

                    {/* Detailed sections — accordion */}
                    {tabSections.length > 0 && (
                      <div className="space-y-2.5">
                        <p className="text-[11px] font-bold uppercase tracking-wide text-slate-400 pb-1 border-b border-slate-100 mb-3">
                          Detailed Information
                        </p>
                        {tabSections.map((section, i) => (
                          <AccordionSection
                            key={i}
                            icon={section.icon}
                            label={section.label}
                            value={section.value}
                            defaultOpen={section.defaultOpen}
                          />
                        ))}
                      </div>
                    )}

                    {infoRows.every((r) => !r.value) && tabSections.length === 0 && (
                      <div className="text-center py-8">
                        <GraduationCap size={36} className="text-slate-200 mx-auto mb-3" />
                        <p className="text-sm text-slate-400 font-medium">
                          No additional info available for this faculty member.
                        </p>
                      </div>
                    )}
                  </>
                )}

                {!faculty && !loading && !error && proxied && (
                  <div className="text-center py-8">
                    <img
                      src={proxied}
                      alt={label}
                      className="w-full max-h-[50vh] object-contain rounded-xl mx-auto"
                    />
                  </div>
                )}

                <p className="text-[11px] text-slate-400 font-medium mt-6 text-center">
                  Click outside or press Esc to close
                </p>
              </div>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>,
    document.body
  );
}
