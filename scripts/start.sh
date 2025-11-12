#!/usr/bin/env bash
# ==========================================================
# start.sh — Launch tmux + Asciinema 4-pane benchmark session
# ==========================================================

SESSION_NAME="quadrec"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RECORD_BASE="$PROJECT_DIR/recordings"

mkdir -p "$RECORD_BASE"
cd "$RECORD_BASE" || exit 1

NEXT_ID=$(find . -maxdepth 1 -type d -name 'recording_*' | wc -l)
NEXT_ID=$((NEXT_ID + 1))
RECORD_DIR="$RECORD_BASE/recording_$NEXT_ID"
mkdir -p "$RECORD_DIR"

TIMESTAMP=$(date +%F_%H-%M-%S)

echo "=========================================================="
echo " Starting tmux recording session: $SESSION_NAME"
echo " Project dir:  $PROJECT_DIR"
echo " Record dir:   $RECORD_DIR"
echo " Timestamp:    $TIMESTAMP"
echo "=========================================================="

# Kill any existing session
tmux has-session -t "$SESSION_NAME" 2>/dev/null && tmux kill-session -t "$SESSION_NAME"

# Launch tmux detached
tmux new-session -d -s "$SESSION_NAME" "bash"

# Create 2×2 grid
tmux split-window -h -t "$SESSION_NAME":0.0
tmux split-window -v -t "$SESSION_NAME":0.0
tmux split-window -v -t "$SESSION_NAME":0.1
tmux select-layout -t "$SESSION_NAME":0 tiled

# Pane assignments
tmux send-keys -t "$SESSION_NAME":0.0 \
  "asciinema rec '$RECORD_DIR/pane0_${TIMESTAMP}.cast' -c 'bash'" C-m
tmux send-keys -t "$SESSION_NAME":0.1 \
  "asciinema rec '$RECORD_DIR/htop_${TIMESTAMP}.cast' -c 'htop'" C-m
tmux send-keys -t "$SESSION_NAME":0.2 \
  "asciinema rec '$RECORD_DIR/gpu_${TIMESTAMP}.cast' -c 'watch -n1 rocm-smi'" C-m
tmux send-keys -t "$SESSION_NAME":0.3 \
  "asciinema rec '$RECORD_DIR/sys_${TIMESTAMP}.cast' -c 'watch -n1 sensors'" C-m

# Attach
tmux attach -t "$SESSION_NAME"
