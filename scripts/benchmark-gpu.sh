#!/usr/bin/env bash
# ==========================================================
# benchmark.sh — Ollama ROCm benchmark suite (with numbered runs)
# ==========================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_ROOT="$PROJECT_DIR/benchmarks"
mkdir -p "$RESULT_ROOT"

# --- Auto-increment benchmark folder ---
NEXT_ID=$(find "$RESULT_ROOT" -maxdepth 1 -type d -name 'benchmark_*' | wc -l)
NEXT_ID=$((NEXT_ID + 1))
RUN_DIR="$RESULT_ROOT/benchmark_$NEXT_ID"
mkdir -p "$RUN_DIR"

LOGFILE="$RUN_DIR/benchmark_$(date +%F_%H-%M-%S).log"
CSVFILE="$RUN_DIR/results_$(date +%F_%H-%M-%S).csv"

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"
timestamp() { date +"[%Y-%m-%d %H:%M:%S]"; }
info()  { echo -e "${GREEN}$(timestamp) [INFO]${RESET} $1" | tee -a "$LOGFILE"; }
warn()  { echo -e "${YELLOW}$(timestamp) [WARN]${RESET} $1" | tee -a "$LOGFILE"; }
error() { echo -e "${RED}$(timestamp) [ERROR]${RESET} $1" | tee -a "$LOGFILE"; }

API_URL="http://localhost:11434/api/generate"

# --- Models to test (standardized with CPU benchmark) ---
MODELS=(
  "gpt-oss:20b"
  "gpt-oss:120b"
  "deepseek-r1:1.5b"
  "deepseek-r1:7b"
  "deepseek-r1:8b"
  "deepseek-r1:14b"
  "deepseek-r1:32b"
  "deepseek-r1:70b"
  "deepseek-r1:671b"
  "kimi-k2:1026b"
)

# --- Prompts to test ---
declare -A PROMPTS=(
  ["reasoning"]="A train leaves Boston at 3 PM traveling 60 mph. Another leaves NYC at 2 PM at 45 mph toward Boston. When do they meet?"
  ["instructions"]="Explain how to securely configure SSH key-based login on Ubuntu, step by step."
  ["codegen"]="Write a Python function using recursion to compute Fibonacci numbers with memoization."
  ["knowledge"]="Who developed the theory of relativity and in which year was it published?"
  ["creative"]="Compose a 40-word poem about a machine learning model dreaming in binary."
  ["logictrap"]="If 5 printers take 5 minutes to print 5 pages, how long do 100 printers take to print 100 pages? Explain logically."
)

echo "timestamp,model,test_name,tokens,seconds,tokens_per_sec,cpu_percent,mem_mb,vram_mb" > "$CSVFILE"

gpu_metrics() {
  if command -v rocm-smi &>/dev/null; then
    rocm-smi --showmemuse --json 2>/dev/null | grep -Eo '"used_memory": [0-9]+' | head -n1 | awk '{print $2}'
  else
    echo "0"
  fi
}

cpu_mem_usage() {
  local pid=$(pgrep -x ollama | head -n1)
  [ -z "$pid" ] && { echo "0 0"; return; }
  ps -p "$pid" -o %cpu=,rss= | awk '{print $1" "$2/1024}'
}

print_header() {
  printf "\n%-20s %-12s %-8s %-10s %-10s %-10s %-10s %-10s\n" \
    "MODEL" "TEST" "TOKENS" "TOK/s" "LAT(s)" "CPU(%)" "RAM(MB)" "VRAM(MB)"
  printf "%0.s-" {1..90}; echo
}

print_row() {
  printf "%-20s %-12s %-8s %-10s %-10s %-10s %-10s %-10s\n" "$@"
}

# Check if Ollama service is running
if ! pgrep -x ollama > /dev/null; then
  error "Ollama service is not running. Please start it first: ollama serve"
  exit 1
fi

# Check if GPU/ROCm is available
if ! command -v rocm-smi &>/dev/null; then
  warn "rocm-smi not found. GPU metrics may not be available."
fi

info "===== Ollama ROCm Benchmark Run #$NEXT_ID Started ====="
print_header | tee -a "$LOGFILE"

for model in "${MODELS[@]}"; do
  info "Benchmarking model: $model"
  if ! ollama list | grep -q "$model"; then
    warn "Model $model not found locally. Pulling..."
    ollama pull "$model" >/dev/null 2>&1 || error "Pull failed: $model"
  fi

  for test in "${!PROMPTS[@]}"; do
    prompt="${PROMPTS[$test]}"
    info "Running test '$test'..."

    vram_before=$(gpu_metrics)
    read cpu_before mem_before < <(cpu_mem_usage)

    start=$(date +%s.%N)
    response=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json" \
      -d "{\"model\": \"$model\", \"prompt\": \"$prompt\", \"stream\": false}")
    end=$(date +%s.%N)

    # Check if API call was successful
    if ! echo "$response" | jq -e '.response' > /dev/null 2>&1; then
      error "API call failed for $model/$test. Response: $response"
      continue
    fi

    elapsed=$(echo "$end - $start" | bc)
    
    # Handle division by zero
    if [ "$(echo "$elapsed <= 0" | bc)" -eq 1 ]; then
      warn "Elapsed time is zero or negative, skipping calculation"
      elapsed="0.01"
    fi

    # Get token count from API response (eval_count = generated tokens)
    tokens=$(echo "$response" | jq -r '.eval_count // 0')
    if [ "$tokens" = "0" ] || [ -z "$tokens" ]; then
      # Fallback: count words if eval_count is not available
      output=$(echo "$response" | jq -r '.response // ""')
      tokens=$(echo "$output" | wc -w)
      warn "Using word count as fallback for token count"
    fi
    
    tokensec=$(echo "scale=2; $tokens / $elapsed" | bc)

    vram_after=$(gpu_metrics)
    read cpu_after mem_after < <(cpu_mem_usage)

    cpu_avg=$(echo "scale=1; ($cpu_before + $cpu_after)/2" | bc)
    mem_used=$(echo "$mem_after - $mem_before" | bc)
    vram_used=$(echo "$vram_after - $vram_before" | bc)
    timestamp_now=$(date +%F_%T)

    print_row "$model" "$test" "$tokens" "$tokensec" "$elapsed" "$cpu_avg" "$mem_used" "$vram_used" | tee -a "$LOGFILE"
    echo "$timestamp_now,$model,$test,$tokens,$elapsed,$tokensec,$cpu_avg,$mem_used,$vram_used" >> "$CSVFILE"
  done
done

info "===== Benchmark Run #$NEXT_ID Completed ====="
info "Saved to: $RUN_DIR"
