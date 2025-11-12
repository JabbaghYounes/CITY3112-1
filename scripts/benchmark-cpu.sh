#!/usr/bin/env bash
# ==========================================================
# benchmark_cpu.sh — Ollama ROCm benchmark suite on CPU
# ==========================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_ROOT="$PROJECT_DIR/benchmarks_cpu"
mkdir -p "$RESULT_ROOT"

# --- Auto-increment benchmark folder ---
NEXT_ID=$(find "$RESULT_ROOT" -maxdepth 1 -type d -name 'benchmark_*' | wc -l)
NEXT_ID=$((NEXT_ID + 1))
RUN_DIR="$RESULT_ROOT/benchmark_$NEXT_ID"
mkdir -p "$RUN_DIR"

# --- Log and CSV ---
LOGFILE="$RUN_DIR/benchmark_cpu_$(date +%F_%H-%M-%S).log"
CSVFILE="$RUN_DIR/results_cpu_$(date +%F_%H-%M-%S).csv"

# --- Colors & logging functions ---
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"
timestamp() { date +"[%Y-%m-%d %H:%M:%S]"; }
info()  { echo -e "${GREEN}$(timestamp) [INFO]${RESET} $1" | tee -a "$LOGFILE"; }
warn()  { echo -e "${YELLOW}$(timestamp) [WARN]${RESET} $1" | tee -a "$LOGFILE"; }
error() { echo -e "${RED}$(timestamp) [ERROR]${RESET} $1" | tee -a "$LOGFILE"; }

# --- Ollama API ---
API_URL="http://localhost:11434/api/generate"

# --- Load models from external file ---
MODEL_FILE="$PROJECT_DIR/scripts/models.txt"
if [ ! -f "$MODEL_FILE" ]; then
  error "Models file not found: $MODEL_FILE"
  exit 1
fi
MODELS=($(grep -v '^\s*#' "$MODEL_FILE" | grep -v '^\s*$'))

# --- Load prompts from CSV file ---
PROMPT_FILE="$PROJECT_DIR/scripts/prompts.csv"
if [ ! -f "$PROMPT_FILE" ]; then
  error "Prompts file not found: $PROMPT_FILE"
  exit 1
fi

declare -A PROMPTS
while IFS=, read -r test_name prompt; do
  [[ "$test_name" == "test_name" || -z "$test_name" ]] && continue
  PROMPTS["$test_name"]="$prompt"
done < "$PROMPT_FILE"

# --- CSV Header ---
echo "timestamp,model,test_name,tokens,seconds,tokens_per_sec,cpu_percent,mem_mb,vram_mb" > "$CSVFILE"

# --- Helper functions ---
gpu_metrics() { echo "0"; }  # GPU not used
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

# --- Benchmark start ---
info "===== Ollama CPU Benchmark Run #$NEXT_ID Started ====="
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

    read cpu_before mem_before < <(cpu_mem_usage)
    start=$(date +%s.%N)

    # Force CPU execution by passing device parameter (if supported)
    response=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json" \
      -d "{\"model\": \"$model\", \"prompt\": \"$prompt\", \"device\": \"cpu\", \"stream\": false}")

    end=$(date +%s.%N)
    elapsed=$(echo "$end - $start" | bc)

    output=$(echo "$response" | jq -r '.response')
    tokens=$(echo "$output" | wc -w)
    tokensec=$(echo "scale=2; $tokens / $elapsed" | bc)

    read cpu_after mem_after < <(cpu_mem_usage)
    cpu_avg=$(echo "scale=1; ($cpu_before + $cpu_after)/2" | bc)
    mem_used=$(echo "$mem_after - $mem_before" | bc)
    vram_used=0
    timestamp_now=$(date +%F_%T)

    print_row "$model" "$test" "$tokens" "$tokensec" "$elapsed" "$cpu_avg" "$mem_used" "$vram_used" | tee -a "$LOGFILE"
    echo "$timestamp_now,$model,$test,$tokens,$elapsed,$tokensec,$cpu_avg,$mem_used,$vram_used" >> "$CSVFILE"
  done
done

info "===== CPU Benchmark Run #$NEXT_ID Completed ====="
info "Saved logs and CSV in: $RUN_DIR"
