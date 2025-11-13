#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

# -------------------------
# Project directories
# -------------------------
PROJECT_DIR = Path(__file__).resolve().parent.parent
GPU_ROOT = PROJECT_DIR / "benchmarks"
CPU_ROOT = PROJECT_DIR / "benchmarks_cpu"

# -------------------------
# Collect all benchmark CSVs
# -------------------------
def load_csvs(root):
    csvs = []
    if not root.exists():
        print(f"Warning: Directory {root} does not exist")
        return pd.DataFrame()
    
    for folder in sorted(root.glob("benchmark_*")):
        csv_file = next(folder.glob("results_*.csv"), None)
        if csv_file:
            try:
                df = pd.read_csv(csv_file)
                if not df.empty:
                    df['benchmark'] = folder.name
                    csvs.append(df)
            except Exception as e:
                print(f"Warning: Failed to load {csv_file}: {e}")
                continue
    if csvs:
        return pd.concat(csvs, ignore_index=True)
    return pd.DataFrame()

gpu_df = load_csvs(GPU_ROOT)
cpu_df = load_csvs(CPU_ROOT)

if gpu_df.empty and cpu_df.empty:
    print("No benchmark results found.")
    print(f"Checked directories: {GPU_ROOT} and {CPU_ROOT}")
    exit(1)

# -------------------------
# Consolidate models and tests
# -------------------------
if not gpu_df.empty and not cpu_df.empty:
    common_models = sorted(set(gpu_df['model']).union(cpu_df['model']))
    common_tests = sorted(set(gpu_df['test_name']).union(cpu_df['test_name']))
elif not gpu_df.empty:
    common_models = sorted(gpu_df['model'].unique())
    common_tests = sorted(gpu_df['test_name'].unique())
elif not cpu_df.empty:
    common_models = sorted(cpu_df['model'].unique())
    common_tests = sorted(cpu_df['test_name'].unique())
else:
    common_models = []
    common_tests = []

print(f"Found {len(common_models)} models and {len(common_tests)} tests.\n")

# -------------------------
# Summary Table
# -------------------------
def summary_table(df, device):
    print(f"===== {device} Summary =====")
    table = df.groupby(['model','test_name']).agg({
        'tokens':'mean',
        'tokens_per_sec':'mean',
        'seconds':'mean',
        'cpu_percent':'mean',
        'mem_mb':'mean',
        'vram_mb':'mean'
    }).round(2)
    print(table)
    print("\n")

if not gpu_df.empty:
    summary_table(gpu_df, "GPU")
if not cpu_df.empty:
    summary_table(cpu_df, "CPU")

# -------------------------
# Combined Plots
# -------------------------
def plot_metric(metric, ylabel, title, filename):
    try:
        plt.figure(figsize=(12,6))
        for test in common_tests:
            gpu_vals = []
            cpu_vals = []
            for model in common_models:
                if not gpu_df.empty and metric in gpu_df.columns:
                    gpu_data = gpu_df[(gpu_df.model==model) & (gpu_df.test_name==test)][metric]
                    gpu_val = gpu_data.mean() if not gpu_data.empty else 0
                else:
                    gpu_val = 0
                
                if not cpu_df.empty and metric in cpu_df.columns:
                    cpu_data = cpu_df[(cpu_df.model==model) & (cpu_df.test_name==test)][metric]
                    cpu_val = cpu_data.mean() if not cpu_data.empty else 0
                else:
                    cpu_val = 0
                
                gpu_vals.append(gpu_val if pd.notna(gpu_val) else 0)
                cpu_vals.append(cpu_val if pd.notna(cpu_val) else 0)
            
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

# Create plots folder
PLOT_DIR = PROJECT_DIR / "benchmark_summary_plots"
PLOT_DIR.mkdir(exist_ok=True)

plot_metric("tokens_per_sec", "Tokens per Second", "Tokens/sec CPU vs GPU", PLOT_DIR / "tokens_per_sec.png")
plot_metric("seconds", "Latency (s)", "Latency CPU vs GPU", PLOT_DIR / "latency.png")
plot_metric("cpu_percent", "CPU (%)", "CPU Usage CPU vs GPU", PLOT_DIR / "cpu_usage.png")
plot_metric("mem_mb", "Memory Usage (MB)", "RAM Usage CPU vs GPU", PLOT_DIR / "memory_usage.png")

print(f"✅ All consolidated plots saved in: {PLOT_DIR}")
