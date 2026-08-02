import React, { useState, useEffect } from 'react';
import { Sparkles } from 'lucide-react';

export default function HolidayGif({ eventName }) {
  const [gifUrl, setGifUrl] = useState(null);
  const [loading, setLoading] = useState(true);
  
  const API_KEY = import.meta.env.VITE_GIPHY_API_KEY;

  useEffect(() => {
    let cancelled = false;

    const fetchGif = async () => {
      // If no API key or no event name, immediately fallback
      if (!API_KEY || !eventName) {
        if (!cancelled) setLoading(false);
        return;
      }

      try {
        // Search Giphy for the event name + celebration with a random offset (top 5)
        const offset = Math.floor(Math.random() * 5);
        // Search Giphy using exactly the event name for better relevance
        const query = encodeURIComponent(eventName);
        const url = `https://api.giphy.com/v1/gifs/search?api_key=${API_KEY}&q=${query}&limit=1&offset=${offset}&rating=g`;
        
        const response = await fetch(url);
        const data = await response.json();

        if (cancelled) return;

        if (data && data.data && data.data.length > 0) {
          // Get the original or a reasonably sized version
          const gif = data.data[0].images.downsized_medium.url || data.data[0].images.original.url;
          setGifUrl(gif);
        }
      } catch (err) {
        console.warn("Failed to fetch holiday GIF from Giphy:", err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    fetchGif();

    return () => {
      cancelled = true;
    };
  }, [eventName, API_KEY]);

  if (loading) {
    return (
      <div className="w-40 h-40 mx-auto mb-6 flex items-center justify-center bg-slate-100 rounded-[24px] animate-pulse">
        <Sparkles className="text-slate-300 w-10 h-10" />
      </div>
    );
  }

  // Fallback to original static SVG if GIF fetching failed or key is missing
  if (!gifUrl) {
    return (
      <img 
        src="/assets/chilling_o2zv.svg" 
        alt="Holiday" 
        className="w-40 h-40 mx-auto mb-6 opacity-90 drop-shadow-sm" 
      />
    );
  }

  return (
    <div className="w-48 h-48 mx-auto mb-6 rounded-[24px] overflow-hidden shadow-md border-4 border-white bg-slate-50">
      <img 
        src={gifUrl} 
        alt={eventName} 
        className="w-full h-full object-cover" 
      />
    </div>
  );
}
