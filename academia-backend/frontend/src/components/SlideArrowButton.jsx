import { ArrowRight } from "lucide-react";

export default function SlideArrowButton({
  text = "Get Started",
  primaryColor = "#f97316",
  className = "",
  onClick,
  ...props
}) {
  return (
    <button
      onClick={onClick}
      className={`group relative inline-flex h-[48px] items-center rounded-full bg-white border border-slate-200/80 shadow-sm hover:shadow-md transition-all duration-300 cursor-pointer overflow-hidden p-[2px] ${className}`}
      {...props}
    >
      {/* Smooth Expanding Orange Fill */}
      <div
        className="absolute left-[2px] top-[2px] h-[42px] w-[42px] rounded-full transition-all duration-300 ease-out group-hover:w-[calc(100%-4px)]"
        style={{ backgroundColor: primaryColor }}
      />

      {/* Circle Arrow Icon */}
      <div className="relative z-10 flex h-[42px] w-[42px] shrink-0 items-center justify-center text-white">
        <ArrowRight size={18} className="transition-transform duration-300 group-hover:translate-x-0.5" />
      </div>

      {/* Button Text */}
      <span className="relative z-10 pr-5 pl-2 font-bold text-[15px] text-slate-900 transition-colors duration-300 group-hover:text-white select-none">
        {text}
      </span>
    </button>
  );
}
