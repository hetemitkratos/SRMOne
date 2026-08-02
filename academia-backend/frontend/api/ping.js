/**
 * Vercel Serverless Function — Keep-Alive Ping
 *
 * Triggered by Vercel Cron every 14 minutes to prevent the Render
 * academia backend from spinning down (Render free tier sleeps after 15 min).
 *
 * This keeps the core backend (login, attendance, timetable) warm 24/7
 * while staying within the 750 free hours/month limit.
 *
 * The placement backend is intentionally NOT pinged — it sleeps and
 * cold-starts only when a user accesses placements (~30s wait, acceptable).
 */

export default async function handler(req, res) {
  const backendUrl = process.env.ACADEMIA_BACKEND_URL;

  if (!backendUrl) {
    return res.status(500).json({
      success: false,
      error: "ACADEMIA_BACKEND_URL not set",
    });
  }

  const healthUrl = `${backendUrl}/health`;
  const startTime = Date.now();

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);

    const response = await fetch(healthUrl, {
      method: "GET",
      signal: controller.signal,
      headers: { "User-Agent": "HackTrackr-KeepAlive/1.0" },
    });

    clearTimeout(timeout);

    const elapsed = Date.now() - startTime;

    if (response.ok) {
      return res.status(200).json({
        success: true,
        pinged: healthUrl,
        status: response.status,
        elapsedMs: elapsed,
        timestamp: new Date().toISOString(),
      });
    } else {
      return res.status(502).json({
        success: false,
        error: `Backend responded with ${response.status}`,
        pinged: healthUrl,
        elapsedMs: elapsed,
      });
    }
  } catch (err) {
    const elapsed = Date.now() - startTime;
    return res.status(502).json({
      success: false,
      error: err.message || "Ping failed",
      pinged: healthUrl,
      elapsedMs: elapsed,
    });
  }
}
