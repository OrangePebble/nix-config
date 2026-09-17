import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFile, readdir } from "node:fs/promises";

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/** Stop only Pi's direct DonSeTch MCP supervisor child, never a standalone CLI.
 * The original DonSeTch extension notices the exit and starts a new MCP process
 * lazily on the next web_fetch call. */
async function restartPiDonsetchMcp(): Promise<void> {
  const entries = await readdir("/proc", { withFileTypes: true });
  const children = await Promise.all(
    entries
      .filter((entry) => entry.isDirectory() && /^\d+$/.test(entry.name))
      .map(async (entry) => {
        try {
          const [stat, cmdline] = await Promise.all([
            readFile(`/proc/${entry.name}/stat`, "utf8"),
            readFile(`/proc/${entry.name}/cmdline`, "utf8"),
          ]);
          // `comm` may contain spaces/parentheses: parse fields after its final `)`.
          const fields = stat
            .slice(stat.lastIndexOf(")") + 1)
            .trim()
            .split(/\s+/);
          return {
            pid: Number(entry.name),
            parentPid: Number(fields[1]), // state is field 0; PPID is field 1
            cmdline,
          };
        } catch {
          return undefined; // Process exited while enumerating.
        }
      }),
  );

  let stopped = false;
  for (const child of children) {
    if (
      child?.parentPid === process.pid &&
      child.cmdline.includes("/donsetch/binaries/donsetch\0mcp\0--supervised")
    ) {
      try {
        process.kill(child.pid, "SIGTERM");
        stopped = true;
      } catch {
        // The process may have exited between discovery and signalling.
      }
    }
  }
  // Give the original extension's child-process exit handler time to clear its
  // `proc` reference before the original web_fetch execute() starts.
  if (stopped) await sleep(350);
}

/**
 * The external tool adapter serializes omitted optional string fields as "".
 * DonSeTch treats their presence as intentional (`focus: ""`, for example),
 * which makes an otherwise valid browser-action fetch produce no selected
 * content. Restore MCP's optional-field semantics before DonSeTch receives
 * the call.
 *
 * Browser-action calls also get a fresh session-owned MCP/Ghost process. This
 * avoids reusing a wedged Ghost after a DevTools startup timeout, without
 * reloading Pi or changing the installed DonSeTch package.
 */
export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    const input = event.input as Record<string, unknown>;

    if (event.toolName === "web_crawl") {
      // Like web_fetch's optional strings, the tool adapter emits an empty
      // resume token rather than omitting it. DonSeTch correctly interprets
      // any supplied token as a resume request, so remove the empty value.
      if (typeof input.resume === "string" && input.resume.trim() === "") {
        delete input.resume;
      }
      return;
    }

    if (event.toolName !== "web_fetch") return;
    for (const key of [
      "focus",
      "section",
      "selector",
      "must_contain",
      "shot",
    ]) {
      if (typeof input[key] === "string" && input[key].trim() === "") {
        delete input[key];
      }
    }

    if (Array.isArray(input.actions) && input.actions.length > 0) {
      await restartPiDonsetchMcp();
    }
  });

  // A normal fetch may still escalate to Ghost and time out. Reset immediately
  // after that failure so the following request gets a clean daemon as well.
  pi.on("tool_result", async (event) => {
    if (event.toolName !== "web_fetch") return;
    const text = event.content
      .map((block: any) => (block.type === "text" ? block.text : ""))
      .join("");
    if (/ghost:\s*devtools ws timeout/i.test(text)) {
      await restartPiDonsetchMcp();
    }
  });
}
