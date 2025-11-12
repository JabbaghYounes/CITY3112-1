#!/usr/bin/env python3
# ==========================================================
# Visualise specific benchmark run
# ==========================================================
import os
import sys
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BENCH_ROOT = os.path.join(PROJECT_DIR, "benchmarks")

# --- Find available benchmark folders ---
benchmarks = sorted(
    [d for d in os.listdir(BENCH_ROOT) if d.startswith("benchmark_")],
    key=lambda x: int(x.split("_")[1])
)

if not benchmarks:
    print("❌ No benchmark folders found.")
    sys.exit(1)

# --- Select benchmark folder ---
if len(sys.argv) > 1:
    try:
        index = int(sys.argv[1]) - 1
        bench_folder = benchmarks[index]
    except (ValueError, IndexError):
        print("⚠️ Invalid argument. Using latest benchmark instead.")
        bench_folder = benchmarks[-1]
else:
    bench_folder = benchmarks[-1]

RUN_DIR = os.path.join(BENCH_ROOT, bench_folder)
print(f"📊 Visualizing {bench_folder}")

# --- Find CSV ---
csv_files = [f for f in os.listdir(RUN_DIR) if f.endswith(".csv")]
if not csv_files:
    print(f"❌ No CSV files found in {RUN_DIR}")
    sys.exit(1)
csv_path = os.path.join(RUN_DIR, csv_files[0])

# --- Load Data ---
df = pd.read_csv(csv_path)
for col in ["tokens_per_sec", "seconds", "cpu_percent", "mem_mb", "vram_mb"]:
    df[col] = pd.to_numeric(df[col], errors="coerce")

# --- Compute Summary ---
summary = (
    df.groupby(["model", "test_name"])
    .agg({
        "tokens_per_sec": "mean",
        "seconds": "mean",
        "cpu_percent": "mean",
        "mem_mb": "mean",
        "vram_mb": "mean"
    })
    .reset_index()
)

PLOT_DIR = os.path.join(RUN_DIR, "plots")
os.makedirs(PLOT_DIR, exist_ok=True)

# --- Plot Helper ---
def save_plot(fig, name):
    path = os.path.join(PLOT_DIR, f"{name}.png")
    fig.savefig(path, bbox_inches="tight", dpi=150)
    print(f"🖼️ Saved: {path}")

# --- Tokens/sec ---
fig, ax = plt.subplots(figsize=(10, 6))
for test, group in summary.groupby("test_name"):
    ax.bar(group["model"], group["tokens_per_sec"], label=test)
ax.set_title("Tokens/sec by Model and Test")
ax.set_ylabel("Tokens/sec")
ax.legend()
plt.xticks(rotation=45, ha="right")
save_plot(fig, "tokens_per_sec")
plt.close(fig)

# --- Latency ---
fig, ax = plt.subplots(figsize=(10, 6))
for test, group in summary.groupby("test_name"):
    ax.bar(group["model"], group["seconds"], label=test)
ax.set_title("Average Latency (s)")
ax.set_ylabel("Seconds")
ax.legend()
plt.xticks(rotation=45, ha="right")
save_plot(fig, "latency")
plt.close(fig)

# --- CPU Usage ---
fig, ax = plt.subplots(figsize=(10, 6))
for test, group in summary.groupby("test_name"):
    ax.bar(group["model"], group["cpu_percent"], label=test)
ax.set_title("Average CPU Load (%)")
ax.set_ylabel("CPU %")
ax.legend()
plt.xticks(rotation=45, ha="right")
save_plot(fig, "cpu_usage")
plt.close(fig)

# --- Memory / VRAM ---
fig, ax = plt.subplots(figsize=(10, 6))
mem_avg = summary.groupby("model")[["mem_mb", "vram_mb"]].mean()
mem_avg.plot(kind="bar", stacked=True, ax=ax, width=0.6)
ax.set_title("Average RAM and VRAM Usage (MB)")
ax.set_ylabel("MB")
plt.xticks(rotation=45, ha="right")
save_plot(fig, "memory_usage")
plt.close(fig)

print(f"\n✅ Plots saved in {PLOT_DIR}")

