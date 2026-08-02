import { Building2, RefreshCw, ExternalLink, Search } from "lucide-react";
import React, { useState, useMemo, useEffect, useRef, useCallback } from "react";
import { usePlacementData } from "../hooks/usePlacementData.js";
import Loading from "../components/Loading.jsx";
import ErrorBox from "../components/ErrorBox.jsx";

const CARD_THEMES = [
  {
    key: "mint",
    iconBg: "#BDE3D5",
    accent: "#5B9E8B",
    accentSoft: "rgba(189, 227, 213, 0.35)",
  },
  {
    key: "lavender",
    iconBg: "#C7C9E0",
    accent: "#6E7196",
    accentSoft: "rgba(199, 201, 224, 0.4)",
  },
  {
    key: "terracotta",
    iconBg: "#D97757",
    accent: "#D97757",
    accentSoft: "rgba(217, 119, 87, 0.35)",
  },
  {
    key: "beige",
    iconBg: "#E6D5C3",
    accent: "#A38565",
    accentSoft: "rgba(230, 213, 195, 0.45)",
  },
];

const COMPANY_AVATARS = [
  "/assets/developer-avatar_f6ac.svg",
  "/assets/designer-avatar_n5q8.svg",
  "/assets/finance-guy-avatar_vhop.svg",
  "/assets/professional-woman-avatar_ivds.svg",
  "/assets/businesswoman-avatar_ktl2.svg",
  "/assets/indie-hacker-avatar_b3wy.svg",
  "/assets/professor-avatar_y9ai.svg",
  "/assets/young-man-avatar_wgbd.svg",
  "/assets/cool-guy-avatar_qjc4.svg",
  "/assets/deep-thinker-avatar_6xg6.svg",
  "/assets/friendly-guy-avatar_dqp5.svg",
  "/assets/stylish-girl-avatar_m8po.svg",
];

function hashSeed(value = "") {
  let hash = 0;
  const str = String(value);
  for (let i = 0; i < str.length; i += 1) {
    hash = (hash * 31 + str.charCodeAt(i)) >>> 0;
  }
  return hash;
}

function getCardStyle(company, index = 0) {
  const seed = hashSeed(`${company.name || ""}|${company.id || index}`);
  return {
    theme: CARD_THEMES[seed % CARD_THEMES.length],
    motif: seed % 6,
    avatar: COMPANY_AVATARS[seed % COMPANY_AVATARS.length],
  };
}

const CardMotif = React.memo(function CardMotif({ motif, color }) {
  const common = {
    className: "absolute -bottom-6 -right-4 w-[82%] h-[95%] pointer-events-none",
    "aria-hidden": true,
    preserveAspectRatio: "xMaxYMax meet",
  };
  switch (motif) {
    case 0:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          <path d="M10 180C45 140 70 120 105 100C140 80 165 45 200 15" stroke={color} strokeWidth="5" opacity="0.55" />
          <path d="M0 195C40 155 75 128 115 108C155 88 175 55 205 35" stroke={color} strokeWidth="4" opacity="0.38" />
          <path d="M25 200C55 165 90 142 130 122C170 102 185 70 210 55" stroke={color} strokeWidth="3.5" opacity="0.28" />
          <path d="M40 205C70 175 105 155 145 138C185 120 198 88 215 75" stroke={color} strokeWidth="3" opacity="0.2" />
        </svg>
      );
    case 1:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          {Array.from({ length: 10 }).map((_, row) =>
            Array.from({ length: 8 }).map((_, col) => {
              const x = 40 + col * 22 + (row % 2) * 10;
              const y = 20 + row * 18;
              return <circle key={`${row}-${col}`} cx={x} cy={y} r={3 + ((row + col) % 4)} fill={color} opacity={0.28 + ((row + col) % 4) * 0.12} />;
            })
          )}
        </svg>
      );
    case 2:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          <path d="M40 200L200 20V200H40Z" fill={color} opacity="0.2" />
          <path d="M75 200L200 55V200H75Z" fill={color} opacity="0.28" />
          <path d="M110 200L200 95V200H110Z" fill={color} opacity="0.4" />
          <path d="M55 190L190 40" stroke={color} strokeWidth="14" opacity="0.35" />
          <path d="M85 198L198 75" stroke={color} strokeWidth="14" opacity="0.45" />
          <path d="M120 200L200 115" stroke={color} strokeWidth="14" opacity="0.55" />
        </svg>
      );
    case 3:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          {[
            [95, 55, 28], [145, 40, 16], [70, 95, 18], [130, 95, 36],
            [175, 80, 14], [85, 145, 22], [155, 145, 30], [185, 160, 12],
            [55, 160, 14], [115, 175, 20], [170, 50, 10],
          ].map(([cx, cy, r], i) => (
            <circle key={i} cx={cx} cy={cy} r={r} fill={color} opacity={0.22 + (i % 4) * 0.12} />
          ))}
        </svg>
      );
    case 4:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          <circle cx="155" cy="135" r="95" fill={color} opacity="0.18" />
          <circle cx="155" cy="135" r="95" stroke={color} strokeWidth="14" opacity="0.28" strokeDasharray="24 14" />
          <path d="M70 185L195 55" stroke={color} strokeWidth="14" opacity="0.45" />
          <path d="M95 198L205 85" stroke={color} strokeWidth="14" opacity="0.35" />
          <path d="M50 170L175 40" stroke={color} strokeWidth="14" opacity="0.28" />
        </svg>
      );
    default:
      return (
        <svg {...common} viewBox="0 0 200 200" fill="none">
          {Array.from({ length: 40 }).map((_, i) => {
            const x = 45 + (i % 8) * 18;
            const y = 25 + Math.floor(i / 8) * 32 + (i % 2) * 8;
            const rot = (i * 37) % 360;
            return (
              <rect
                key={i}
                x={x}
                y={y}
                width="14"
                height="4.5"
                rx="2"
                fill={color}
                opacity={0.3 + (i % 5) * 0.1}
                transform={`rotate(${rot} ${x + 7} ${y + 2})`}
              />
            );
          })}
        </svg>
      );
  }
});

const CompanyCard = React.memo(function CompanyCard({ c, i }) {
  const { theme, motif, avatar } = getCardStyle(c, i);

  return (
    <div className="group relative text-left w-full min-h-[230px] rounded-[28px] bg-[#1A1A1A] text-white p-6 overflow-hidden transition-transform duration-200 hover:scale-[1.015] active:scale-[0.99] shadow-[0_10px_30px_rgba(26,26,26,0.18)] flex flex-col justify-between">
      <CardMotif motif={motif} color={theme.accent} />

      <div className="relative z-10 flex flex-col gap-4 flex-1">
        <div
          className="w-14 h-14 rounded-2xl flex items-center justify-center overflow-hidden flex-shrink-0 border border-white/10"
          style={{ backgroundColor: c.imageUrl ? "white" : theme.iconBg }}
        >
          {c.imageUrl ? (
            <img src={c.imageUrl} alt={c.name} className="w-full h-full object-contain p-1" />
          ) : (
            <img src={avatar} alt="" className="w-10 h-10 object-contain" />
          )}
        </div>
        
        <div className="pr-10">
          <h3 className="font-display font-bold text-[22px] leading-tight text-white line-clamp-2">
            {c.name}
          </h3>
          {c.description && (
            <p className="mt-2 text-[14px] font-medium text-white/70 line-clamp-2">
              {c.description}
            </p>
          )}
        </div>
      </div>
      
      {c.webSiteLink && (
        <div className="relative z-10 mt-6 flex items-start">
          <a
            href={c.webSiteLink}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12px] font-bold transition-colors"
            style={{ backgroundColor: theme.accentSoft, color: theme.accent === "#D97757" ? "#F4F0EB" : "#1A1A1A" }}
            onClick={(e) => e.stopPropagation()}
          >
            Visit Website <ExternalLink size={12} />
          </a>
        </div>
      )}
    </div>
  );
});

export default function Companies() {
  const { data, loading, error, refetch } = usePlacementData("companies");
  const [inputValue, setInputValue] = useState("");
  const [search, setSearch] = useState("");
  const [visibleCount, setVisibleCount] = useState(15);
  const observerRef = useRef(null);

  // Debounce the search input
  useEffect(() => {
    const timer = setTimeout(() => {
      setSearch(inputValue);
    }, 250);
    return () => clearTimeout(timer);
  }, [inputValue]);

  const companies = useMemo(() => {
    const list = data?._embedded?.entityModels || [];
    if (!search) return list;
    return list.filter((c) => c.name?.toLowerCase().includes(search.toLowerCase()));
  }, [data, search]);

  // Reset visible count when search changes
  useEffect(() => {
    setVisibleCount(15);
  }, [search]);

  const loadMoreRef = useCallback((node) => {
    if (observerRef.current) observerRef.current.disconnect();
    
    observerRef.current = new IntersectionObserver(entries => {
      if (entries[0].isIntersecting) {
        setVisibleCount(prev => prev + 15);
      }
    });
    
    if (node) observerRef.current.observe(node);
  }, []);

  const visibleCompanies = useMemo(() => {
    return companies.slice(0, visibleCount);
  }, [companies, visibleCount]);

  if (loading) return <Loading label="Fetching companies…" />;
  if (error) return <ErrorBox message={error} onRetry={refetch} />;

  return (
    <div className="space-y-5 pt-4">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <h2 className="text-2xl font-display font-bold text-[#1A1A1A]">Companies</h2>
        <div className="flex gap-2 sm:gap-3 items-center w-full sm:w-auto">
          <div className="relative flex-1 sm:flex-none">
            <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text" value={inputValue} onChange={(e) => setInputValue(e.target.value)}
              placeholder="Search companies…"
              className="w-full sm:w-64 pl-10 pr-4 py-2.5 sm:py-2 rounded-full text-sm border border-slate-200 bg-white text-slate-900 placeholder:text-slate-400 outline-none focus:border-[#1A1A1A] focus:ring-1 focus:ring-[#1A1A1A] transition-all"
            />
          </div>
          <button onClick={refetch} className="w-10 h-10 sm:w-9 sm:h-9 shrink-0 rounded-full bg-white border border-slate-200 flex items-center justify-center text-slate-500 hover:text-[#1A1A1A] hover:bg-slate-50 cursor-pointer transition-colors shadow-sm">
            <RefreshCw size={15} />
          </button>
        </div>
      </div>

      <p className="text-sm text-slate-500 font-medium">{companies.length} companies</p>

      <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-5 pb-6">
        {visibleCompanies.map((c, i) => (
          <CompanyCard key={c.id || i} c={c} i={i} />
        ))}
      </div>
      
      {/* Intersection observer target for infinite scrolling */}
      {visibleCount < companies.length && (
        <div ref={loadMoreRef} className="h-10 w-full flex items-center justify-center mb-8">
          <Loading label="Loading more companies..." />
        </div>
      )}
    </div>
  );
}
