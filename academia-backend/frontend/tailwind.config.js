/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
        display: ["Space Grotesk", "Inter", "sans-serif"],
        mono: ["JetBrains Mono", "monospace"],
      },
      colors: {
        ink: {
          900: "#0a0a0f",
          800: "#12121a",
          700: "#1a1a26",
          600: "#242435",
          500: "#2e2e42",
          400: "#3a3a52",
        },
        accent: {
          DEFAULT: "#578ada",
          light: "#7aa8e8",
          dark: "#3d6bb8",
        },
        glow: {
          purple: "#7aa8e8",
          blue: "#60a5fa",
          pink: "#f472b6",
          green: "#34d399",
          amber: "#fbbf24",
          red: "#f87171",
        },
      },
      animation: {
        "fade-in": "fadeIn 0.6s ease-out forwards",
        "slide-up": "slideUp 0.5s ease-out forwards",
        "pulse-slow": "pulse 3s cubic-bezier(0.4,0,0.6,1) infinite",
        "spin-slow": "spin 2s linear infinite",
        "gradient-shift": "gradientShift 8s ease infinite",
      },
      keyframes: {
        fadeIn: {
          "0%": { opacity: 0 },
          "100%": { opacity: 1 },
        },
        slideUp: {
          "0%": { opacity: 0, transform: "translateY(20px)" },
          "100%": { opacity: 1, transform: "translateY(0)" },
        },
        gradientShift: {
          "0%, 100%": { backgroundPosition: "0% 50%" },
          "50%": { backgroundPosition: "100% 50%" },
        },
      },
      backgroundImage: {
        "grid-pattern":
          "linear-gradient(rgba(87,138,218,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(87,138,218,0.05) 1px, transparent 1px)",
      },
    },
  },
  plugins: [],
};
