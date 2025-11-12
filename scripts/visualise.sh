#!/usr/bin/env python3
# ==========================================================
# Benchmark Visualiser
# ==========================================================
import os
import sys
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime

# Paths
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RESULT_DIR = os.path.join(PROJECT_DIR, "benchmarks")
PLOT_DIR = os.path.join(RESULT_DIR, "plots")
os.makedirs(PLOT_DIR, exist_ok=True)

# Find CSV files
csv_files = sorted(
    [os.path.join(RESULT_DIR, f) for f in os.listdir(RESULT_DIR) if f.endswith(".csv")]
)

if not csv_files:
    print("❌ No benchmark CSV files found in:", RESULT_DIR)
    sys.exit(1)

print("📊 Found CSV files:")
for i, f in enumerate(csv_files):
    print(f"  [{i+1}] {os.path.basename(f)}")

# Load selected CSV (default latest)
csv_path = csv_files[-1]
if len(sys.argv) > 1:
    try:
        csv_path = csv_files[int(sys.argv[1]) - 1]
    except (IndexError, ValueError):
        print("⚠️ Invalid selection, using latest file instead.")

print(f"\n📈 Using benchmark data: {os.path.basename(csv_path)}\n")

# Load data
df = pd.read_csv(csv_path)

# Clean & convert
df["tokens_per_sec"] = pd.to_numeric(df["tokens_per_sec"], errors="coerce")
df["seconds"] = pd.to_numeric(df["seconds"], errors="coerce")
df["cpu_percent"] = pd.to_numeric(df["cpu_percent"], errors="coerce")
df["mem_mb"] = pd.to_numeric(df["mem_mb"], errors="coerce")
df["vram_mb"] = pd.to_numeric(df["vram_mb"], errors="coerce")

# Compute model averages
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

# Save summary table
summary_csv = os.path.join(RESULT_DIR, "summary_" + datetime.now().strftime("%F_%H-%M-%S") + ".csv")
summary.to_csv(summary_csv, index=False)
print(f"✅ Summary table saved: {summary_csv}")

# --- Plot Helper ---
def save_plot(fig, name):
    path = os.path.join(PLOT_DIR, f"{name}.png")
    fig.savefig(path, bbox_inches="tight", dpi=150)
    print(f"🖼️  Saved: {path}")

# --- Tokens/sec by model/test ---
fig, ax = plt.subplots(figsize=(10, 6))
for test_name, group in summary.groupby("test_name"):
    ax.bar(group["model"], group["tokens_per_sec"], label=test_name)
ax.set_ylabel("Tokens per Second")
ax.set_xlabel("Model")
ax.set_title("Tokens/sec by Model and Test Type")
ax.legend()
plt.xticks(rotation=45, ha="right")
save_plot(fig, "tokens_per_sec")
plt.close(fig)

# --- Latency ---
fig, ax = plt.subplots(figsize=(10, 6))
for test_name, group in summary.groupby("test_name"):
    ax.bar(group["model"], group["seconds"], label=test_name)
ax.set_ylabel("Average Latency (s)")
ax.set_xlabel("Model")
ax.set_title("Average Latency per Model/Test")
ax.legend()
plt.xticks(rotation=45, ha="right")
save_plot(fig, "latency")
plt.close(fig)

# --- CPU Usage ---
fig, ax = plt.subplots(figsize=(10, 6))
for test_name, group in summary.groupby("test_name"):
    ax.bar(group["model"], group["cpu_percent"], label=test_name)
ax.set_ylabel("CPU Usage (%)")
ax.set_xlabel("Model")
ax.set_title("Average CPU Load per Model/Test")
ax.legend()
plt.xticks(rotation=45, ha="right")
save_plot(fig, "cpu_usage")
plt.close(fig)

# --- Memory / VRAM Stacked ---
fig, ax = plt.subplots(figsize=(10, 6))
width = 0.6
mem_avg = summary.groupby("model")[["mem_mb", "vram_mb"]].mean()
mem_avg.plot(kind="bar", stacked=True, ax=ax, width=width)
ax.set_ylabel("MB Used")
ax.set_xlabel("Model")
ax.set_title("Memory and VRAM Usage per Model (avg)")
plt.xticks(rotation=45, ha="right")
save_plot(fig, "memory_usage")
plt.close(fig)

print("\n✅ All plots generated in:", PLOT_DIR)
print("   → tokens_per_sec.png, latency.png, cpu_usage.png, memory_usage.png")
