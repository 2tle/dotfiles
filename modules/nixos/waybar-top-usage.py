"""Small /proc-based CPU and memory modules for Waybar (no extra daemon)."""

import html
import json
import os
from pathlib import Path
import re
import sys
import time

PROC = Path("/proc")
BAR_WIDTH = 16
SAMPLE_SECONDS = 0.35


def cpu_counters():
    fields = (PROC / "stat").read_text().splitlines()[0].split()[1:]
    ticks = [int(value) for value in fields]
    # guest time is already included in user/nice; iowait is not busy work.
    total = sum(ticks[:8])
    idle = ticks[3] + ticks[4]
    return total, idle


def processes():
    result = {}
    for path in PROC.iterdir():
        if not path.name.isdecimal():
            continue
        try:
            stat = (path / "stat").read_text()
            end = stat.rfind(")")
            fields = stat[end + 2 :].split()
            # Fields start at state (3); utime=14, stime=15, rss=24.
            result[int(path.name)] = (
                int(fields[11]) + int(fields[12]),
                int(fields[21]) * os.sysconf("SC_PAGE_SIZE"),
                stat[stat.index("(") + 1 : end],
            )
        except (OSError, ValueError, IndexError):
            # Processes may exit or deny access while we are sampling.
            continue
    return result


def display_name(path):
    return re.sub(r"^[a-z0-9]{32}-", "", os.path.basename(path))


def process_name(pid, comm):
    if not (comm.startswith(".") or comm == "MainThread" or comm.startswith("python")
            or comm in {"node", "bash", "sh"} or re.fullmatch(r"[a-z0-9]{15}", comm)):
        return comm
    try:
        args = (PROC / str(pid) / "cmdline").read_bytes().split(b"\0")
        if comm.startswith(".") and args:
            # /proc/comm is truncated at 15 bytes, but argv[0] has the full name.
            name = display_name(args[0].decode(errors="replace")).removeprefix(".")
            return name.removesuffix("-wrapped").removesuffix("-wrap")
        for arg in args[1:]:
            name = display_name(arg.decode(errors="replace"))
            if name and not name.startswith("-") and not name.startswith("python") and name not in {"node", "bash", "sh"}:
                return name
    except OSError:
        pass
    return comm.removeprefix(".") if comm.startswith(".") else comm


def memory_info():
    values = {}
    for line in (PROC / "meminfo").read_text().splitlines():
        key, _, value = line.partition(":")
        if key in {"MemTotal", "MemAvailable", "SwapTotal", "SwapFree"}:
            values[key] = int(value.split()[0]) * 1024
    return values


def bar(percent):
    filled = max(0, min(BAR_WIDTH, round(percent * BAR_WIDTH / 100)))
    return (
        "<span foreground='#6cbf90'>" + "━" * filled + "</span>"
        + "<span foreground='#8793a3'>" + "━" * (BAR_WIDTH - filled) + "</span>"
        + f"  {percent:.0f}%"
    )


def rows(totals, suffix):
    lines = []
    for name, value in sorted(totals.items(), key=lambda item: item[1], reverse=True)[:7]:
        # Process names can contain Pango markup, so never inject them unescaped.
        safe_name = html.escape(name[:20])
        lines.append(f"{value:>6.1f}{suffix}  {safe_name}")
    return "\n".join(lines) if lines else "No active processes"


def cpu_module():
    before_total, before_idle = cpu_counters()
    before = processes()
    time.sleep(SAMPLE_SECONDS)
    after_total, after_idle = cpu_counters()
    after = processes()
    delta_total = max(1, after_total - before_total)
    percent = max(0.0, min(100.0, (1 - (after_idle - before_idle) / delta_total) * 100))
    totals = {}
    for pid, (ticks, _, comm) in after.items():
        if pid not in before:
            continue
        delta = ticks - before[pid][0]
        if delta <= 0:
            continue
        name = process_name(pid, comm)
        totals[name] = totals.get(name, 0.0) + delta / delta_total * 100
    tooltip = (
        "<b><span foreground='#e5a567'>CPU</span></b>\n"
        + bar(percent) + "\n\n"
        + "<span font_family='monospace'>" + rows(totals, "%") + "</span>\n\n"
        + "Load: " + "  ".join(f"{value:.2f}" for value in os.getloadavg())
    )
    return {"text": f"{percent:.0f}%", "tooltip": tooltip}


def memory_module():
    info = memory_info()
    total = info["MemTotal"]
    used = max(0, total - info["MemAvailable"])
    percent = used / total * 100 if total else 0
    totals = {}
    for pid, (_, rss, comm) in processes().items():
        if rss <= 0:
            continue
        name = process_name(pid, comm)
        totals[name] = totals.get(name, 0) + rss / 1024**3
    swap_used = info["SwapTotal"] - info["SwapFree"]
    tooltip = (
        "<b><span foreground='#8bb9dd'>MEMORY</span></b>\n"
        + bar(percent) + "\n\n"
        + "<span font_family='monospace'>" + rows(totals, "G") + "</span>\n\n"
        + f"Swap: {swap_used / 1024**3:.1f}G / {info['SwapTotal'] / 1024**3:.1f}G"
        + "\nRSS includes shared pages"
    )
    return {"text": f"{used / 1024**3:.1f}G", "tooltip": tooltip}


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in {"cpu", "memory"}:
        sys.exit("usage: waybar-top-usage {cpu|memory}")
    print(json.dumps(cpu_module() if sys.argv[1] == "cpu" else memory_module(), ensure_ascii=False))
