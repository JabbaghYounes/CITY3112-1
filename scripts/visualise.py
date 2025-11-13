#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt
import sys
from pathlib import Path

# -------------------------
# Arguments
# -------------------------
if len(sys.argv) < 3:
    print("Usage: python visualize_benchmarks.py <gpu_benchmark_folder> <cpu_benchmark_folder>")
    sys.exit(1)

gpu_folder = Path(sys.argv[1])
cpu_folder = Path(sys.argv[2])

# -------------------------
# Find CSV files
# -------------------------
gpu_csv = next(gpu_folder.glob("results_*.csv"), None)
cpu_csv = next(cpu_folder.glob("results_*.csv"), None)

if not gpu_csv or not cpu_csv:
    print("Error: Could not find CSV files in the provided benchmark folders.")
    sys.exit(1)

# -------------------------
# Load data
# -------------------------
gpu_df = pd.read_csv(gpu_csv)
cpu_df = pd.read_csv(cpu_csv)

# Ensure same tests and models for alignment
common_tests = sorted(set(gpu_df['test_name']).intersection(cpu_df['test_name']))
common_models = sorted(set(gpu_df['model']).intersection(cpu_df['model']))

# -------------------------
# Plotting
# -------------------------
def plot_metric(metric, ylabel, title, filename):
    plt.figure(figsize=(12,6))
    for test in common_tests:
        gpu_vals = gpu_df[gpu_df['test_name']==test].sort_values('model')[metric]
        cpu_vals = cpu_df[cpu_df['test_name']==test].sort_values('model')[metric]
        x = range(len(common_models))
        plt.plot(x, gpu_vals, marker='o', label=f"{test} GPU")
        plt.plot(x, cpu_vals, marker='x', linestyle='--', label=f"{test} CPU")
    plt.xticks(range(len(common_models)), common_models, rotation=45, ha='right')
    plt.ylabel(ylabel)
    plt.title(title)
    plt.legend()
    plt.tight_layout()
    plt.savefig(filename)
    plt.close()
    print(f"🖼️ Saved plot: {filename}")

# Create plots subfolders
gpu_plots = gpu_folder / "plots"
cpu_plots = cpu_folder / "plots"
gpu_plots.mkdir(exist_ok=True)
cpu_plots.mkdir(exist_ok=True)

# Plot tokens/sec
plot_metric("tokens_per_sec", "Tokens per Second", "Tokens/sec CPU vs GPU", gpu_plots / "tokens_per_sec.png")

# Plot latency
plot_metric("seconds", "Latency (s)", "Latency CPU vs GPU", gpu_plots / "latency.png")

# Plot CPU %
plot_metric("cpu_percent", "CPU (%)", "CPU Usage CPU vs GPU", gpu_plots / "cpu_usage.png")

# Plot memory usage (RAM)
plot_metric("mem_mb", "RAM (MB)", "Memory Usage CPU vs GPU", gpu_plots / "memory_usage.png")

print(f"✅ All plots saved in: {gpu_plots}")
