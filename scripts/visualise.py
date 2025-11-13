#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt
import sys
from pathlib import Path

# -------------------------
# Arguments
# -------------------------
if len(sys.argv) < 3:
    print("Usage: python3 visualise.py <gpu_benchmark_folder> <cpu_benchmark_folder>")
    print("Example: python3 visualise.py ../benchmarks/benchmark_1 ../benchmarks_cpu/benchmark_1")
    sys.exit(1)

gpu_folder = Path(sys.argv[1])
cpu_folder = Path(sys.argv[2])

# Validate folders exist
if not gpu_folder.exists():
    print(f"Error: GPU benchmark folder not found: {gpu_folder}")
    sys.exit(1)

if not cpu_folder.exists():
    print(f"Error: CPU benchmark folder not found: {cpu_folder}")
    sys.exit(1)

# -------------------------
# Find CSV files
# -------------------------
gpu_csv = next(gpu_folder.glob("results_*.csv"), None)
cpu_csv = next(cpu_folder.glob("results_*.csv"), None)

if not gpu_csv:
    print(f"Error: Could not find CSV file in GPU benchmark folder: {gpu_folder}")
    sys.exit(1)

if not cpu_csv:
    print(f"Error: Could not find CSV file in CPU benchmark folder: {cpu_folder}")
    sys.exit(1)

# -------------------------
# Load data
# -------------------------
try:
    gpu_df = pd.read_csv(gpu_csv)
    cpu_df = pd.read_csv(cpu_csv)
except Exception as e:
    print(f"Error: Failed to read CSV files: {e}")
    sys.exit(1)

# Validate required columns
required_cols = ['model', 'test_name', 'tokens_per_sec', 'seconds', 'cpu_percent', 'mem_mb']
for col in required_cols:
    if col not in gpu_df.columns:
        print(f"Error: Missing required column '{col}' in GPU CSV")
        sys.exit(1)
    if col not in cpu_df.columns:
        print(f"Error: Missing required column '{col}' in CPU CSV")
        sys.exit(1)

# Ensure same tests and models for alignment
common_tests = sorted(set(gpu_df['test_name']).intersection(cpu_df['test_name']))
common_models = sorted(set(gpu_df['model']).intersection(cpu_df['model']))

if not common_tests:
    print("Error: No common test names found between GPU and CPU benchmarks")
    sys.exit(1)

if not common_models:
    print("Error: No common models found between GPU and CPU benchmarks")
    sys.exit(1)

print(f"Found {len(common_models)} common models and {len(common_tests)} common tests")

# -------------------------
# Plotting
# -------------------------
def plot_metric(metric, ylabel, title, filename):
    try:
        plt.figure(figsize=(12,6))
        for test in common_tests:
            # Filter and sort by model to ensure alignment
            gpu_test_data = gpu_df[(gpu_df['test_name']==test) & (gpu_df['model'].isin(common_models))]
            cpu_test_data = cpu_df[(cpu_df['test_name']==test) & (cpu_df['model'].isin(common_models))]
            
            # Sort by model order in common_models
            gpu_test_data = gpu_test_data.set_index('model').reindex(common_models).reset_index()
            cpu_test_data = cpu_test_data.set_index('model').reindex(common_models).reset_index()
            
            gpu_vals = gpu_test_data[metric].fillna(0)
            cpu_vals = cpu_test_data[metric].fillna(0)
            
            x = range(len(common_models))
            plt.plot(x, gpu_vals, marker='o', label=f"{test} GPU")
            plt.plot(x, cpu_vals, marker='x', linestyle='--', label=f"{test} CPU")
        
        plt.xticks(range(len(common_models)), common_models, rotation=45, ha='right')
        plt.ylabel(ylabel)
        plt.title(title)
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig(filename, dpi=150)
        plt.close()
        print(f"🖼️ Saved plot: {filename}")
    except Exception as e:
        print(f"Error creating plot {filename}: {e}")

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
