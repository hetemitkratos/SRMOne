import { useNavigate } from "react-router-dom";
import { RefreshCw, ChevronRight, Calendar } from "lucide-react";
import { usePlacementData } from "../hooks/usePlacementData.js";
import Loading from "../components/Loading.jsx";
import ErrorBox from "../components/ErrorBox.jsx";

// The upstream /notification API may store the body under different keys.
function getNoticeContent(n) {
  return (
    n.body ||
    n.message ||
    n.content ||
    n.description ||
    n.notificationBody ||
    n.messageBody ||
    n.noticeBody ||
    n.text ||
    ""
  );
}

function stripHtmlPreview(html) {
  return (html || "")
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/[·•]\s*/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Short teaser: first 1–2 sentences, stop before list-y sections. */
function noticeTeaser(html, maxLen = 180) {
  let text = stripHtmlPreview(html);
  const cutMarkers = [
    /why participate/i,
    /register here/i,
    /dear (all|students|sir|madam)/i,
  ];
  for (const re of cutMarkers) {
    const idx = text.search(re);
    if (idx > 40) text = text.slice(0, idx).trim();
  }
  // Prefer ending on a sentence boundary
  if (text.length > maxLen) {
    const slice = text.slice(0, maxLen);
    const lastStop = Math.max(slice.lastIndexOf(". "), slice.lastIndexOf("! "), slice.lastIndexOf("? "));
    text = lastStop > 60 ? slice.slice(0, lastStop + 1) : `${slice.trim()}…`;
  }
  return text.trim();
}

function formatRelative(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  if (isNaN(d)) return "";
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
  if (diff < 2592000) return `${Math.floor(diff / 604800)}w ago`;
  return "";
}

function NoticeCard({ notice, onOpen }) {
  const preview = noticeTeaser(getNoticeContent(notice), 140);
  const relative = formatRelative(notice.createdDate);
  const hasPreview = preview && preview.length > 0;

  return (
    <button
      onClick={() => onOpen(notice)}
      className="group h-full w-full text-left bg-white rounded-[20px] p-4 sm:p-5 lg:p-6 border border-slate-200/60 shadow-sm hover:shadow-md hover:border-slate-300 hover:-translate-y-0.5 transition-all cursor-pointer duration-200 flex flex-col"
    >
      <div className="flex items-start gap-3.5 lg:gap-4 flex-1">
        <div className="w-11 h-11 lg:w-12 lg:h-12 rounded-xl bg-gradient-to-br from-lavender to-lavender/50 flex items-center justify-center flex-shrink-0 overflow-hidden group-hover:scale-105 transition-transform p-1.5">
          <img
            src="/assets/push-notifications_5z1s.svg"
            alt=""
            className="w-full h-full object-contain"
          />
        </div>
        <div className="flex-1 min-w-0 flex flex-col">
          <h3 className="font-bold text-[14px] lg:text-[15px] text-slate-800 group-hover:text-[#1A1A1A] transition-colors leading-snug line-clamp-2">
            {notice.title || notice.subject || "Untitled Notice"}
          </h3>
          {hasPreview && (
            <p className="text-[13px] text-slate-500 mt-1.5 line-clamp-2 leading-relaxed flex-1">
              {preview}
            </p>
          )}
          <div className="flex items-center gap-2 mt-3 pt-1">
            {notice.createdDate && (
              <>
                <Calendar size={11} className="text-slate-400" />
                <span className="text-[11px] text-slate-400 font-mono">
                  {new Date(notice.createdDate).toLocaleDateString("en-IN", {
                    day: "numeric",
                    month: "short",
                    year: "numeric",
                  })}
                </span>
                {relative && (
                  <span className="text-[11px] text-slate-300 font-mono">· {relative}</span>
                )}
              </>
            )}
          </div>
        </div>
        <ChevronRight
          size={18}
          className="text-slate-300 group-hover:text-slate-500 group-hover:translate-x-1 transition-all flex-shrink-0 mt-1 hidden sm:block"
        />
      </div>
    </button>
  );
}

export default function Notices() {
  const { data, loading, error, refetch } = usePlacementData("notices");
  const navigate = useNavigate();

  if (loading) return <Loading label="Fetching notices…" />;
  if (error) return <ErrorBox message={error} onRetry={refetch} />;

  const notices = data?._embedded?.entityModels || [];
  const [latest, ...rest] = notices;
  const latestTeaser = latest ? noticeTeaser(getNoticeContent(latest), 220) : "";

  const openNotice = (n) => {
    navigate(`/placement/notices/${n.id}`, { state: { notice: n } });
  };

  return (
    <div className="space-y-5 pt-4">
      {/* Hero banner with notification SVG */}
      <div className="bg-[#1A1A1A] rounded-[32px] p-8 md:p-10 flex flex-col md:flex-row items-start md:items-center justify-between overflow-hidden relative min-h-[200px] sm:min-h-[220px] lg:min-h-[240px]">
        <div className="absolute inset-y-0 right-0 h-full w-[42%] sm:w-52 md:w-80 lg:w-96 opacity-90 mix-blend-screen pointer-events-none py-3 pr-4 md:pr-6">
          <img
            src="/assets/push-notifications_5z1s.svg"
            alt="Notifications"
            className="w-full h-full object-contain object-right"
          />
        </div>

        <div className="relative z-10 text-white w-[58%] sm:w-[60%] md:w-auto md:max-w-md lg:max-w-lg mb-4 md:mb-0">
          <h1 className="font-display text-3xl sm:text-4xl lg:text-5xl font-bold mb-2 tracking-tight">Notices</h1>
          <p className="text-white/70 text-sm lg:text-base font-medium leading-relaxed">
            Placement announcements, shortlists, and updates from the career cell.
          </p>
        </div>

        <button
          onClick={refetch}
          className="relative z-10 w-11 h-11 rounded-full bg-white/10 hover:bg-white/20 border border-white/10 flex items-center justify-center text-white cursor-pointer transition-colors backdrop-blur-sm self-start md:self-auto"
          aria-label="Refresh notices"
        >
          <RefreshCw size={18} />
        </button>
      </div>

      <div className="flex items-center justify-between px-1">
        <p className="text-sm text-slate-500 font-medium">
          {notices.length} {notices.length === 1 ? "notice" : "notices"}
        </p>
      </div>

      {notices.length > 0 && (
        <>
          {/* Latest notice — featured on large screens */}
          {latest && (
            <button
              onClick={() => openNotice(latest)}
              className="group hidden lg:flex items-stretch w-full text-left bg-white rounded-[28px] border border-slate-200/60 shadow-sm hover:shadow-md hover:border-slate-300 transition-all cursor-pointer overflow-hidden"
            >
              <div className="flex-1 min-w-0 p-8 xl:p-10 flex flex-col">
                <span className="inline-flex self-start px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider bg-lavender/70 text-slate-700 mb-4">
                  Latest
                </span>
                <h2 className="font-display font-bold text-2xl xl:text-[28px] text-[#1A1A1A] leading-snug tracking-tight">
                  {latest.title || latest.subject || "Untitled Notice"}
                </h2>
                {latestTeaser && (
                  <p className="text-[15px] text-slate-500 mt-3 leading-relaxed max-w-2xl">
                    {latestTeaser}
                  </p>
                )}
                <div className="flex items-center gap-4 mt-auto pt-8">
                  {latest.createdDate && (
                    <span className="inline-flex items-center gap-1.5 text-[12px] text-slate-400 font-mono">
                      <Calendar size={13} />
                      {new Date(latest.createdDate).toLocaleDateString("en-IN", {
                        day: "numeric",
                        month: "short",
                        year: "numeric",
                      })}
                      {formatRelative(latest.createdDate) && (
                        <span className="text-slate-300">· {formatRelative(latest.createdDate)}</span>
                      )}
                    </span>
                  )}
                  <span className="inline-flex items-center gap-1 ml-auto text-[13px] font-semibold text-slate-700 group-hover:text-[#1A1A1A] transition-colors">
                    Read notice
                    <ChevronRight size={16} className="group-hover:translate-x-0.5 transition-transform" />
                  </span>
                </div>
              </div>
              <div className="w-[240px] xl:w-[280px] flex-shrink-0 bg-[#F4F0EB] flex items-center justify-center p-6 border-l border-slate-100">
                <img
                  src="/assets/push-notifications_5z1s.svg"
                  alt=""
                  className="w-full h-44 xl:h-52 object-contain"
                />
              </div>
            </button>
          )}

          {/* Mobile/tablet: include latest in the grid; desktop: rest only (latest featured above) */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3 md:gap-4">
            {/* Show latest in the list below lg */}
            {latest && (
              <div className="lg:hidden">
                <NoticeCard notice={latest} onOpen={openNotice} />
              </div>
            )}
            {rest.map((n, i) => (
              <NoticeCard key={n.id || i} notice={n} onOpen={openNotice} />
            ))}
            {/* On lg, if only one notice, featured already covers it — rest is empty. Fine. */}
            {/* On lg with multiple: rest fills grid. If we want latest ALSO in grid, skip — featured is enough. */}
          </div>
        </>
      )}

      {notices.length === 0 && (
        <div className="bg-white rounded-[24px] p-10 lg:p-16 border border-slate-200/60 text-center">
          <img
            src="/assets/unread-messages_hdpw.svg"
            alt="No notices"
            className="w-40 h-40 lg:w-52 lg:h-52 mx-auto mb-4 opacity-90"
          />
          <p className="text-slate-600 text-sm lg:text-base font-semibold">No notices yet</p>
          <p className="text-slate-400 text-xs lg:text-sm mt-1.5">New placement announcements will show up here.</p>
        </div>
      )}
    </div>
  );
}
