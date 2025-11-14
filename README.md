# High Performance Computing

Collection of scripts to setup environment, benchmark hardware and visualise results for local hardware testing

## Installation
### Using Git
```bash
git clone https://github.com/JabbaghYounes/CITY3112-1.git
cd CITY3112-1
```

## Usage
### 1. Setup Environment
```bash
chmod +x scripts/*.sh
bash scripts/setup.sh
```
**Note:** After setup completes, reboot your system for ROCm to work properly.

### 2. Start Monitoring Session (Optional)
```bash
cd scripts
./start.sh
```
This launches a tmux session with 4 panes recording system metrics using asciinema.

### 3. Run Benchmarks

**For GPU benchmarks:**
```bash
cd scripts
./benchmark-gpu.sh
```

**For CPU benchmarks:**
```bash
cd scripts
# First, ensure Ollama is running with CPU-only mode:
OLLAMA_NUM_GPU=0 ollama serve &
./benchmark-cpu.sh
```

### 4. Display Results

**Option 1: Consolidated results (all benchmark runs):**
```bash
cd scripts
python3 results.py
```
This generates summary tables and plots comparing all CPU vs GPU runs.

**Option 2: Visualize specific benchmark folders:**
```bash
cd scripts
python3 visualise.py ../benchmarks/benchmark_1 ../benchmarks_cpu/benchmark_1
```

### 5. End Monitoring Session
```bash
cd scripts
./stop.sh
```




