const { execFile } = require("child_process");
const path = require("path");
const fs = require("fs");

let scraperCommand = null;

function resolveScraperCommand() {
  if (scraperCommand) return scraperCommand;

  const candidates = [
    path.join(__dirname, "..", "..", "..", "..", "academia-backend", "academia-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "..", "academia-backend", "academia-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "..", "..", "haveloc-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "..", "haveloc-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "haveloc-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "..", "..", "haveloc-scraper", "haveloc-scraper"),
    path.join(__dirname, "..", "..", "..", "haveloc-scraper", "haveloc-scraper"),
    "haveloc-scraper",
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      scraperCommand = { cmd: candidate, args: [] };
      return scraperCommand;
    }
  }

  scraperCommand = { cmd: "haveloc-scraper", args: [] };
  return scraperCommand;
}

function runScraper(payload, timeoutMs = 120000) {
  return new Promise((resolve, reject) => {
    const { cmd, args } = resolveScraperCommand();
    const child = execFile(
      cmd,
      args,
      {
        timeout: timeoutMs,
        maxBuffer: 100 * 1024 * 1024,
        windowsHide: true,
      },
      (err, stdout, stderr) => {
        if (err && !stdout) {
          reject(new Error(`scraper failed: ${err.message}${stderr ? ` | ${stderr}` : ""}`));
          return;
        }
        try {
          const parsed = JSON.parse(stdout);
          resolve({ parsed, stderr });
        } catch (parseErr) {
          reject(new Error(`scraper returned invalid JSON: ${parseErr.message} | stdout: ${stdout.substring(0, 500)}`));
        }
      }
    );

    child.stdin.write(JSON.stringify(payload));
    child.stdin.end();
  });
}

module.exports = { runScraper };
