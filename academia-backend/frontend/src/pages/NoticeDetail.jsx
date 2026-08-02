import { useEffect, useState } from "react";
import { useParams, useLocation, useNavigate } from "react-router-dom";
import { ArrowLeft, Calendar, ExternalLink, Clock, User, Link2 } from "lucide-react";
import { useAuth } from "../hooks/useAuth.jsx";
import { placementApi } from "../api/placementClient.js";
import Loading from "../components/Loading.jsx";
import ErrorBox from "../components/ErrorBox.jsx";

// The upstream /notification API may store the body under different keys.
function getNoticeContent(n) {
  return (
    n?.body ||
    n?.message ||
    n?.content ||
    n?.description ||
    n?.notificationBody ||
    n?.messageBody ||
    n?.noticeBody ||
    n?.text ||
    ""
  );
}

function isHtml(s) {
  return /<[a-z][\s\S]*>/i.test(s || "");
}

// Soft-sanitize: fix S.No breaks + force content to fit the card (no horizontal scroll).
function sanitizeNoticeHtml(html) {
  if (!html) return html;
  return html
    .replace(
      /S\.\s*(?:<br\s*\/?>|\n|\r)+\s*N\s*(?:<br\s*\/?>|\n|\r)*\s*o/gi,
      "S.No"
    )
    .replace(/>\s*S\.\s*N\s*o\s*</gi, ">S.No<")
    .replace(/\s(?:width|height)\s*=\s*["'][^"']*["']/gi, "")
    .replace(/\s(?:width|height)\s*=\s*\d+%?/gi, "")
    .replace(/(?:min-|max-)?width\s*:\s*[^;)"']+/gi, "max-width:100%")
    .replace(/white-space\s*:\s*nowrap/gi, "white-space:normal")
    .replace(/overflow(-[xy])?\s*:\s*(auto|scroll|hidden)/gi, "overflow:visible");
}

// Extract any URLs from the content so we can surface them as clickable links
function extractLinks(html) {
  if (!html) return [];
  const links = [];
  const regex = /href=["']([^"']+)["']/gi;
  let m;
  while ((m = regex.exec(html)) !== null) {
    links.push(m[1]);
  }
  if (links.length === 0) {
    const bare = /(https?:\/\/[^\s<]+)/gi;
    while ((m = bare.exec(html)) !== null) {
      links.push(m[1]);
    }
  }
  return [...new Set(links)];
}

function formatRelative(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  if (isNaN(d)) return "";
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
  if (diff < 2592000) return `${Math.floor(diff / 604800)}w ago`;
  return "";
}

const NOTICE_PROSE = [
  "prose prose-sm md:prose-base max-w-none break-words overflow-x-hidden",
  "text-[14px] md:text-[15px] text-slate-700 leading-relaxed",
  "[&_*]:max-w-full",
  "[&_img]:max-w-full [&_img]:h-auto [&_img]:rounded-xl [&_img]:my-4",
  "[&_a]:text-blue-600 [&_a]:underline [&_a]:decoration-blue-300 [&_a]:underline-offset-2",
  "[&_a]:font-medium [&_a]:break-all hover:[&_a]:text-blue-800 hover:[&_a]:decoration-blue-600",
  "[&_p]:mb-4 [&_p]:leading-[1.7]",
  "[&_h1]:text-2xl [&_h1]:font-display [&_h1]:font-bold [&_h1]:text-slate-900 [&_h1]:mt-6 [&_h1]:mb-3",
  "[&_h2]:text-xl [&_h2]:font-display [&_h2]:font-bold [&_h2]:text-slate-900 [&_h2]:mt-6 [&_h2]:mb-3",
  "[&_h3]:text-lg [&_h3]:font-display [&_h3]:font-bold [&_h3]:text-slate-800 [&_h3]:mt-5 [&_h3]:mb-2",
  "[&_h4]:text-base [&_h4]:font-bold [&_h4]:text-slate-800 [&_h4]:mt-4 [&_h4]:mb-2",
  "[&_ul]:list-disc [&_ul]:pl-5 [&_ul]:mb-4 [&_ul]:space-y-2",
  "[&_ol]:list-decimal [&_ol]:pl-5 [&_ol]:mb-4 [&_ol]:space-y-2",
  "[&_li]:text-slate-700 [&_li]:leading-[1.7] [&_li]:pl-1",
  "[&_strong]:text-slate-900 [&_strong]:font-semibold",
  "[&_em]:italic [&_em]:text-slate-600",
  "[&_blockquote]:border-l-[3px] [&_blockquote]:border-slate-300 [&_blockquote]:bg-slate-50",
  "[&_blockquote]:px-5 [&_blockquote]:py-3 [&_blockquote]:rounded-r-xl [&_blockquote]:italic [&_blockquote]:text-slate-600 [&_blockquote]:my-5",
  "[&_code]:bg-slate-100 [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:rounded-md [&_code]:text-[13px] [&_code]:font-mono [&_code]:text-pink-600 [&_code]:break-all",
  "[&_pre]:bg-[#1A1A1A] [&_pre]:text-slate-100 [&_pre]:p-5 [&_pre]:rounded-2xl [&_pre]:whitespace-pre-wrap [&_pre]:break-words [&_pre]:my-5",
  "[&_hr]:border-slate-100 [&_hr]:my-6",
  // Tables always fit the card — wrap cell text, never force horizontal scroll
  "[&_table]:w-full [&_table]:max-w-full [&_table]:border-collapse [&_table]:table-fixed [&_table]:my-3 [&_table]:text-[12px] sm:[&_table]:text-[13px]",
  "[&_th]:px-1.5 sm:[&_th]:px-2 [&_th]:py-1.5 [&_th]:text-left [&_th]:font-semibold [&_th]:align-top [&_th]:break-words [&_th]:whitespace-normal",
  "[&_td]:px-1.5 sm:[&_td]:px-2 [&_td]:py-1.5 [&_td]:align-top [&_td]:break-words [&_td]:whitespace-normal [&_td]:text-slate-700",
].join(" ");

export default function NoticeDetail() {
  const { id } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const { placementUser } = useAuth();
  const [notice, setNotice] = useState(location.state?.notice || null);
  const [loading, setLoading] = useState(!notice);
  const [error, setError] = useState("");

  useEffect(() => {
    if (notice) return;
    if (!placementUser) {
      setError("Not logged in to placement portal");
      setLoading(false);
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const result = await placementApi.notices(placementUser.username, 0, 50);
        if (cancelled) return;
        if (result.data?.error) {
          setError(result.data.error);
          return;
        }
        const list = result.data?._embedded?.entityModels || [];
        const found = list.find((n) => String(n.id) === String(id));
        if (!found) {
          setError("Notice not found");
          return;
        }
        setNotice(found);
      } catch (err) {
        if (!cancelled) setError(err.message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [id, notice, placementUser]);

  if (loading) return <Loading label="Loading notice…" />;
  if (error) return <ErrorBox message={error} onRetry={() => navigate("/placement/notices")} />;
  if (!notice) return <ErrorBox message="Notice not found" onRetry={() => navigate("/placement/notices")} />;

  const rawContent = getNoticeContent(notice);
  const content = isHtml(rawContent) ? sanitizeNoticeHtml(rawContent) : rawContent;
  const html = isHtml(content);
  const links = extractLinks(content);
  const title = notice.title || notice.subject || "Untitled Notice";
  const createdDate = notice.createdDate;
  const relative = formatRelative(createdDate);
  const category = notice.category || notice.type || notice.notificationType || "";
  const sender = notice.createdBy || notice.sender || notice.author || notice.from || "";

  return (
    <div className="pt-4 pb-12 max-w-3xl lg:max-w-5xl xl:max-w-6xl mx-auto w-full overflow-x-hidden">
      <button
        onClick={() => navigate("/placement/notices")}
        className="inline-flex items-center gap-2 text-slate-500 hover:text-[#1A1A1A] font-semibold text-sm mb-6 cursor-pointer transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-0.5 transition-transform" />
        Back to Notices
      </button>

      <div className="bg-[#1A1A1A] rounded-[24px] sm:rounded-[32px] p-6 sm:p-8 md:p-10 lg:p-12 text-white relative overflow-hidden mb-6 shadow-md min-h-[200px] lg:min-h-[260px]">
        <div className="absolute right-0 top-0 bottom-0 w-[42%] sm:w-[45%] md:w-[48%] lg:w-[40%] opacity-80 mix-blend-screen pointer-events-none flex items-center justify-end py-4 pr-3 sm:pr-5 lg:pr-8">
          <img
            src="/assets/push-notifications_5z1s.svg"
            alt=""
            className="w-full h-full object-contain object-right"
          />
        </div>

        <div className="relative z-10 w-[58%] sm:w-[55%] md:max-w-md lg:max-w-xl lg:w-[55%]">
          <div className="flex items-center gap-2 mb-3 flex-wrap">
            <span className="px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider bg-white/10 text-white/80 backdrop-blur-sm">
              Notice
            </span>
            {category && (
              <span className="px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider bg-white/10 text-white/70 backdrop-blur-sm">
                {category.replace(/_/g, " ")}
              </span>
            )}
          </div>
          <h1 className="text-xl sm:text-2xl md:text-[26px] lg:text-3xl font-display font-bold leading-tight break-words mb-5">
            {title}
          </h1>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 pt-5 border-t border-white/10">
            {createdDate && (
              <HeroMeta
                icon={<Calendar size={15} />}
                label="Posted"
                value={new Date(createdDate).toLocaleDateString("en-IN", {
                  day: "numeric",
                  month: "short",
                  year: "numeric",
                })}
                sub={relative && `(${relative})`}
              />
            )}
            {sender && <HeroMeta icon={<User size={15} />} label="From" value={sender} />}
            {links.length > 0 && (
              <HeroMeta
                icon={<Link2 size={15} />}
                label="Links"
                value={`${links.length} attached`}
              />
            )}
          </div>
        </div>
      </div>

      <div className="bg-white rounded-[24px] p-5 sm:p-7 md:p-9 lg:p-10 border border-slate-200/60 shadow-sm overflow-x-hidden">
        <div className="flex items-center gap-3 mb-6 pb-5 border-b border-slate-100">
          <div className="w-10 h-10 lg:w-11 lg:h-11 rounded-xl bg-lavender/60 flex items-center justify-center overflow-hidden p-1.5 flex-shrink-0">
            <img
              src="/assets/push-notifications_5z1s.svg"
              alt=""
              className="w-full h-full object-contain"
            />
          </div>
          <div>
            <h3 className="font-display font-bold text-lg lg:text-xl text-[#1A1A1A] leading-tight">Notice Details</h3>
            <p className="text-[11px] lg:text-xs text-slate-400 font-medium mt-0.5">Full announcement body</p>
          </div>
        </div>

        {content ? (
          html ? (
            <div
              className={NOTICE_PROSE}
              dangerouslySetInnerHTML={{ __html: content }}
            />
          ) : (
            <p className="text-[14px] md:text-[15px] text-slate-700 leading-relaxed whitespace-pre-wrap break-words">
              {content}
            </p>
          )
        ) : (
          <div className="text-center py-10">
            <img
              src="/assets/unread-messages_hdpw.svg"
              alt=""
              className="w-28 h-28 mx-auto mb-3 opacity-80"
            />
            <p className="text-slate-400 text-sm font-medium">No content available for this notice.</p>
          </div>
        )}
      </div>

      {links.length > 0 && (
        <div className="bg-white rounded-[24px] p-5 sm:p-7 md:p-8 border border-slate-200/60 shadow-sm mt-6">
          <div className="flex items-center gap-2 mb-4">
            <div className="w-8 h-8 rounded-lg bg-blue-50 flex items-center justify-center text-blue-500">
              <Link2 size={18} />
            </div>
            <h3 className="font-display font-bold text-lg text-[#1A1A1A]">
              Links {links.length > 1 && <span className="text-slate-400 font-normal">({links.length})</span>}
            </h3>
          </div>
          <div className="flex flex-col gap-2.5">
            {links.map((url, i) => (
              <a
                key={i}
                href={url}
                target="_blank"
                rel="noopener noreferrer"
                className="group flex items-center gap-3 px-4 py-3 rounded-xl bg-slate-50 hover:bg-blue-50 border border-slate-200/60 hover:border-blue-200 transition-all"
              >
                <div className="w-9 h-9 rounded-lg bg-white flex items-center justify-center flex-shrink-0 border border-slate-200 group-hover:border-blue-200 group-hover:bg-blue-100 transition-colors">
                  <ExternalLink size={15} className="text-slate-400 group-hover:text-blue-600 transition-colors" />
                </div>
                <span className="flex-1 text-[13px] font-semibold text-slate-700 group-hover:text-blue-700 transition-colors break-all">
                  {url}
                </span>
              </a>
            ))}
          </div>
        </div>
      )}

      {createdDate && (
        <div className="flex items-center justify-center gap-2 mt-8 text-[12px] text-slate-400 font-mono">
          <Clock size={12} />
          <span>
            Posted on{" "}
            {new Date(createdDate).toLocaleString("en-IN", {
              day: "numeric",
              month: "short",
              year: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            })}
          </span>
        </div>
      )}
    </div>
  );
}

function HeroMeta({ icon, label, value, sub }) {
  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center gap-1.5 text-white/50">
        {icon}
        <span className="text-[10px] sm:text-[11px] font-bold uppercase tracking-wide">{label}</span>
      </div>
      <span className="text-[13px] sm:text-[14px] font-bold text-white break-words">{value}</span>
      {sub && <span className="text-[10px] text-white/40 font-medium">{sub}</span>}
    </div>
  );
}
