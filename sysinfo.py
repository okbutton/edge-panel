#!/usr/bin/env python3
"""Prints this computer's CPU, memory, GPU, network and disk use as one JSON line every
few seconds (the first argument; 2 by default), until it's stopped.

Reads /proc and /sys, so it costs next to nothing. NVIDIA GPUs are read with nvidia-smi,
AMD and Intel ones from /sys. Standard library only.
"""
import glob
import json
import os
import shutil
import socket
import subprocess
import sys
import time


def read(path, default=""):
    try:
        with open(path) as file:
            return file.read().strip()
    except OSError:
        return default


def cpu_times():
    """Busy and total jiffies for the whole CPU, then each core."""
    times = []
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        values = [int(value) for value in line.split()[1:]]
        idle = values[3] + values[4]
        times.append((sum(values) - idle, sum(values)))
    return times


def cpu_model():
    for line in read("/proc/cpuinfo").splitlines():
        if line.startswith("model name"):
            return line.split(":", 1)[1].strip()
    return ""


def cpu_temperature():
    """The CPU package's temperature, from the first hwmon chip that knows it."""
    for chip in ("k10temp", "coretemp", "zenpower", "cpu_thermal"):
        for hwmon in glob.glob("/sys/class/hwmon/hwmon*"):
            if read(f"{hwmon}/name") == chip:
                value = read(f"{hwmon}/temp1_input")
                if value:
                    return int(value) / 1000
    return None


def cpu_frequency():
    speeds = [int(read(path, "0")) for path in glob.glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq")]
    return max(speeds) / 1e6 if speeds else None


def memory():
    info = {}
    for line in read("/proc/meminfo").splitlines():
        key, value = line.split(":", 1)
        info[key] = int(value.split()[0]) * 1024
    return {
        "total": info["MemTotal"],
        "used": info["MemTotal"] - info["MemAvailable"],
        "swapTotal": info.get("SwapTotal", 0),
        "swapUsed": info.get("SwapTotal", 0) - info.get("SwapFree", 0),
    }


def gpu():
    if shutil.which("nvidia-smi"):
        try:
            output = subprocess.run(
                ["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
                 "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=5).stdout
            name, usage, used, total, temperature, power = [part.strip() for part in output.splitlines()[0].split(",")]
            number = lambda text: float(text) if text.replace(".", "", 1).isdigit() else None
            return {"name": name.replace("NVIDIA GeForce ", ""), "usage": number(usage),
                    "memUsed": number(used) * 2**20, "memTotal": number(total) * 2**20,
                    "temperature": number(temperature), "power": number(power)}
        except (OSError, ValueError, IndexError, TypeError, subprocess.SubprocessError):
            pass
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]")):
        device = f"{card}/device"
        busy = read(f"{device}/gpu_busy_percent")
        if not busy:
            continue
        temperature = None
        for hwmon in glob.glob(f"{device}/hwmon/hwmon*"):
            value = read(f"{hwmon}/temp1_input")
            if value:
                temperature = int(value) / 1000
        return {"name": "GPU", "usage": float(busy),
                "memUsed": int(read(f"{device}/mem_info_vram_used", "0")),
                "memTotal": int(read(f"{device}/mem_info_vram_total", "0")),
                "temperature": temperature, "power": None}
    return None


def default_interface():
    for line in read("/proc/net/route").splitlines()[1:]:
        fields = line.split()
        if fields[1] == "00000000":
            return fields[0]
    return None


def interface_address():
    """This computer's address on the network, from the route a packet out would take."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(("192.0.2.1", 9))
            return probe.getsockname()[0]
    except OSError:
        return ""


def network_bytes(interface):
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, values = line.split(":", 1)
        if name.strip() == interface:
            values = values.split()
            return int(values[0]), int(values[8])
    return 0, 0


def disks():
    """Each real filesystem once, however many subvolumes or bind mounts it has."""
    seen = set()
    found = []
    for line in read("/proc/mounts").splitlines():
        device, mount, kind = line.split()[:3]
        if not device.startswith("/dev/") or kind in ("squashfs", "iso9660") or device in seen:
            continue
        mount = mount.replace("\\040", " ")
        try:
            stats = os.statvfs(mount)
        except OSError:
            continue
        seen.add(device)
        total = stats.f_blocks * stats.f_frsize
        found.append({"mount": mount, "type": kind, "total": total,
                      "used": total - stats.f_bfree * stats.f_frsize})
    return found


def disk_bytes():
    """Bytes read and written by whole disks, not their partitions."""
    read_bytes = written = 0
    for line in read("/proc/diskstats").splitlines():
        fields = line.split()
        name = fields[2]
        if not os.path.exists(f"/sys/block/{name}/device"):
            continue
        read_bytes += int(fields[5]) * 512
        written += int(fields[9]) * 512
    return read_bytes, written


CLOCK_TICKS = os.sysconf("SC_CLK_TCK")
PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")


def process_times():
    """CPU time used so far by each process, with its name and resident memory."""
    found = {}
    for entry in os.scandir("/proc"):
        if not entry.name.isdigit():
            continue
        stat = read(f"/proc/{entry.name}/stat")
        if not stat:
            continue
        # The name sits in brackets and may hold spaces, so split after it.
        name = stat[stat.find("(") + 1:stat.rfind(")")]
        fields = stat[stat.rfind(")") + 2:].split()
        found[int(entry.name)] = {"name": name, "ticks": int(fields[11]) + int(fields[12]),
                                  "memory": int(fields[21]) * PAGE_SIZE}
    return found


def top_processes(now, before, elapsed, count=12):
    """The busiest programs since the last reading. Processes with the same name, like
    Chrome's many, add up to one row. 100% is one core, as in top."""
    programs = {}
    for pid, process in now.items():
        old = before.get(pid)
        if not old or old["name"] != process["name"]:
            continue
        usage = 100 * (process["ticks"] - old["ticks"]) / CLOCK_TICKS / elapsed
        program = programs.setdefault(process["name"],
                                      {"name": process["name"], "pid": pid, "count": 0, "cpu": 0, "memory": 0})
        program["count"] += 1
        program["cpu"] += usage
        program["memory"] += process["memory"]
        program["pid"] = min(program["pid"], pid)
    busiest = sorted(programs.values(), key=lambda program: (program["cpu"], program["memory"]), reverse=True)
    return busiest[:count]


def main():
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else 2
    model = cpu_model()
    host = socket.gethostname()
    previous = None
    while True:
        now = time.monotonic()
        interface = default_interface()
        sample = {"cpu": cpu_times(), "net": network_bytes(interface), "disk": disk_bytes(),
                  "processes": process_times(), "time": now}
        if previous:
            elapsed = now - previous["time"]
            usage = [100 * (busy - old_busy) / max(1, total - old_total)
                     for (busy, total), (old_busy, old_total) in zip(sample["cpu"], previous["cpu"])]
            print(json.dumps({
                "host": host,
                "uptime": float(read("/proc/uptime", "0 0").split()[0]),
                "cpu": {"model": model, "usage": usage[0], "cores": usage[1:],
                        "temperature": cpu_temperature(), "frequency": cpu_frequency(),
                        "load": float(read("/proc/loadavg", "0").split()[0])},
                "memory": memory(),
                "gpu": gpu(),
                "network": {"interface": interface or "", "address": interface_address(),
                            "down": max(0, sample["net"][0] - previous["net"][0]) / elapsed,
                            "up": max(0, sample["net"][1] - previous["net"][1]) / elapsed},
                "disks": disks(),
                "processes": top_processes(sample["processes"], previous["processes"], elapsed),
                "io": {"read": max(0, sample["disk"][0] - previous["disk"][0]) / elapsed,
                       "write": max(0, sample["disk"][1] - previous["disk"][1]) / elapsed},
            }), flush=True)
        # The first reading only sets a baseline, so take the second one soon after.
        time.sleep(interval if previous else 0.5)
        previous = sample


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        # Stopped by the panel: quietly, without Python complaining at exit.
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
