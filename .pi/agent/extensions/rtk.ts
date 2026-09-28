// Pi extension: let RTK decide which bash commands can be compacted.
// Based on RTK's Pi hook (Apache-2.0): https://github.com/rtk-ai/rtk/tree/develop/hooks/pi
import type { BashToolCallEvent, ExtensionAPI, ToolCallEvent } from "@earendil-works/pi-coding-agent";

function isBashCall(event: ToolCallEvent): event is BashToolCallEvent {
  return event.toolName === "bash";
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isBashCall(event) || process.env.RTK_DISABLED === "1") return;

    const command = event.input.command;
    if (typeof command !== "string" || !command.trim() || command.startsWith("rtk ")) return;

    try {
      const result = await pi.exec("rtk", ["rewrite", command], {
        timeout: 2000,
        signal: ctx.signal,
      });
      // 0: rewrite; 1: no match; 3: advisory rewrite.
      if (!result.killed && (result.code === 0 || result.code === 3)) {
        const rewritten = result.stdout.trim();
        if (rewritten && rewritten !== command) event.input.command = rewritten;
      }
    } catch {
      // Fail open if RTK is unavailable: run the original command.
    }
  });
}
