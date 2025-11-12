#!/bin/bash
#start 4-pane tmux layout, record each pane with asciinema

SESSION_NAME="quadrec"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"     # go one level up from scripts/
RECORD_BASE="$PROJECT_DIR/recordings"

# Create recordings folder and increment subdirectory
mkdir -p "$RECORD_BASE"
cd "$RECORD_BASE" || exit 1
NEXT_ID=$(find . -maxdepth 1 -type d -name 'recording_*' | wc -l)
NEXT_ID=$((NEXT_ID + 1))
RECORD_DIR="$RECORD_BASE/recording_$NEXT_ID"
mkdir -p "$RECORD_DIR"

TIMESTAMP=$(date +%F_%H-%M-%S)

echo "Starting tmux recording session:"
echo "  Project: $PROJECT_DIR"
echo "  Record dir: $RECORD_DIR"
echo "  Timestamp: $TIMESTAMP"
echo

# Kill previous session if exists
tmux has-session -t "$SESSION_NAME" 2>/dev/null && tmux kill-session -t "$SESSION_NAME"

# Launch tmux detached
tmux new-session -d -s "$SESSION_NAME" "bash"

# Proper 2x2 split layout
tmux split-window -h -t "$SESSION_NAME":0.0       # split right
tmux split-window -v -t "$SESSION_NAME":0.0       # bottom-left
tmux split-window -v -t "$SESSION_NAME":0.1       # bottom-right
tmux select-layout -t "$SESSION_NAME":0 tiled     # enforce 2x2 grid

# Start asciinema in each pane
tmux send-keys -t "$SESSION_NAME":0.0 \
  "asciinema rec '$RECORD_DIR/pane1_${TIMESTAMP}.cast'" C-m
tmux send-keys -t "$SESSION_NAME":0.1 \
  "asciinema rec '$RECORD_DIR/pane2_${TIMESTAMP}.cast'" C-m
tmux send-keys -t "$SESSION_NAME":0.2 \
  "asciinema rec '$RECORD_DIR/pane3_${TIMESTAMP}.cast'" C-m
tmux send-keys -t "$SESSION_NAME":0.3 \
  "asciinema rec '$RECORD_DIR/pane4_${TIMESTAMP}.cast'" C-m

# Attach to session
tmux attach -t "$SESSION_NAME"

