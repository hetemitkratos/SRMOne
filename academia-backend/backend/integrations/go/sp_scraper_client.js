import { existsSync } from "node:fs";
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const GO_SCRAPER_DIR = path.join(ROOT_DIR, "academia-scraper");
const DEFAULT_SP_BINARY = process.platform === "win32"
  ? path.join(GO_SCRAPER_DIR, "studentportal.exe")
  : path.join(GO_SCRAPER_DIR, "studentportal");

function resolveSPScraperInvocation() {
  const explicitBinary = process.env.STUDENT_PORTAL_SCRAPER_BIN?.trim();
  if (explicitBinary) {
    return { command: explicitBinary, args: [], cwd: GO_SCRAPER_DIR, source: "env-binary" };
  }

  if (existsSync(DEFAULT_SP_BINARY)) {
    return { command: DEFAULT_SP_BINARY, args: [], cwd: GO_SCRAPER_DIR, source: "default-binary" };
  }

  return { command: "go", args: ["run", "./cmd/studentportal"], cwd: GO_SCRAPER_DIR, source: "go-run" };
}

function runSPInvocation(invocation, payload, timeoutMs) {
  return new Promise((resolve, reject) => {
    const child = spawn(invocation.command, invocation.args, {
      cwd: invocation.cwd,
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env },
    });

    let stdout = "";
    let stderr = "";
    let finished = false;
    const timer = setTimeout(() => {
      if (finished) return;
      finished = true;
      child.kill("SIGTERM");
      reject(new Error(`student portal scraper timed out after ${timeoutMs}ms`));
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      reject(error);
    });

    child.on("close", (code) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);

      let parsed = null;
      try {
        parsed = stdout.trim() ? JSON.parse(stdout) : null;
      } catch (error) {
        reject(new Error(`could not parse student portal scraper JSON: ${error.message}\n${stdout}`));
        return;
      }

      resolve({
        exitCode: code,
        stderr,
        runtime: invocation.source,
        parsed,
      });
    });

    child.stdin.write(JSON.stringify(payload));
    child.stdin.end();
  });
}

export function getStudentPortalScraperRuntime() {
  return resolveSPScraperInvocation();
}

export async function runStudentPortalScraper(payload, { timeoutMs = 60000 } = {}) {
  const primary = resolveSPScraperInvocation();
  try {
    return await runSPInvocation(primary, payload, timeoutMs);
  } catch (error) {
    const canFallbackToBinary =
      primary.source === "go-run" &&
      existsSync(DEFAULT_SP_BINARY);

    if (!canFallbackToBinary) throw error;

    return runSPInvocation(
      { command: DEFAULT_SP_BINARY, args: [], cwd: GO_SCRAPER_DIR, source: "fallback-binary" },
      payload,
      timeoutMs,
    );
  }
}
