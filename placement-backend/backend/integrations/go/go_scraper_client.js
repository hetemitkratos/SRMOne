const { execFile } = require("child_process");
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");

let scraperCommand = null;

function resolveScraperCommand() {
  if (scraperCommand) return scraperCommand;

  // Option 1: Use `go run` if explicitly enabled (for environments without pre-built binary)
  const useGoRun = ["1", "true", "yes"].includes(
    String(process.env.HAVELOC_SCRAPER_USE_GO_RUN || "").toLowerCase()
  );
  if (useGoRun) {
    const goScraperDir = path.join(__dirname, "..", "..", "..", "..", "academia-backend", "academia-scraper");
    scraperCommand = { cmd: "go", args: ["run", "./cmd/haveloc"], cwd: goScraperDir, useSpawn: true };
    return scraperCommand;
  }

  // Option 2: Use explicit binary path from env
  const explicitBinary = process.env.HAVELOC_SCRAPER_BIN?.trim();
  if (explicitBinary && fs.existsSync(explicitBinary)) {
    scraperCommand = { cmd: explicitBinary, args: [] };
    return scraperCommand;
  }

  // Option 3: Search for pre-built binary
  const candidates = [
    path.join(__dirname, "..", "..", "..", "..", "academia-backend", "academia-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "..", "academia-backend", "academia-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "..", "..", "haveloc-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "..", "haveloc-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "haveloc-scraper", "haveloc-scraper.exe"),
    path.join(__dirname, "..", "..", "..", "..", "haveloc-scraper", "haveloc-scraper"),
    path.join(__dirname, "..", "..", "..", "haveloc-scraper", "haveloc-scraper"),
    path.join(__dirname, "..", "..", "haveloc-scraper", "haveloc-scraper"),
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
    const invocation = resolveScraperCommand();
    const { cmd, args, useSpawn, cwd } = invocation;

    if (useSpawn) {
      // Use spawn for `go run` mode (needs cwd option)
      const child = spawn(cmd, args, {
        timeout: timeoutMs,
        cwd,
        windowsHide: true,
        stdio: ["pipe", "pipe", "pipe"],
      });

      let stdout = "";
      let stderr = "";

      child.stdout.on("data", (data) => { stdout += data.toString(); });
      child.stderr.on("data", (data) => { stderr += data.toString(); });

      child.on("error", (err) => {
        reject(new Error(`scraper spawn failed: ${err.message}`));
      });

      child.on("close", (code) => {
        if (code !== 0 && !stdout) {
          reject(new Error(`scraper failed (exit ${code}): ${stderr}`));
          return;
        }
        try {
          const parsed = JSON.parse(stdout);
          resolve({ parsed, stderr });
        } catch (parseErr) {
          reject(new Error(`scraper returned invalid JSON: ${parseErr.message} | stdout: ${stdout.substring(0, 500)}`));
        }
      });

      child.stdin.write(JSON.stringify(payload));
      child.stdin.end();
      return;
    }

    // Use execFile for pre-built binary mode
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
