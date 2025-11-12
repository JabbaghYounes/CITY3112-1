#!/bin/bash
# tmux_quad_record.sh — start a 4-pane tmux layout, each recording with asciinema

SESSION_NAME="quadrec"
RECORD_DIR="$HOME/recordings"
TIMESTAMP=$(date +%F_%H-%M-%S)

mkdir -p "$RECORD_DIR"

# Launch detached tmux session
tmux new-session -d -s "$SESSION_NAME" "bash"

# Split the window into 4 panes (2x2 grid)
tmux split-window -h -t "$SESSION_NAME":0
tmux split-window -v -t "$SESSION_NAME":0.0
tmux split-window -v -t "$SESSION_NAME":0.1

# Start asciinema in each pane
tmux send-keys -t "$SESSION_NAME":0.0 \
  "asciinema rec $RECORD_DIR/pane1_${TIMESTAMP}.cast" C-m
tmux send-keys -t "$SESSION_NAME":0.1 \
  "asciinema rec $RECORD_DIR/pane2_${TIMESTAMP}.cast" C-m
tmux send-keys -t "$SESSION_NAME":0.2 \
  "asciinema rec $RECORD_DIR/pane3_${TIMESTAMP}.cast" C-m
tmux send-keys -t "$SESSION_NAME":0.3 \
  "asciinema rec $RECORD_DIR/pane4_${TIMESTAMP}.cast" C-m

# Attach so you can see the layout
tmux attach -t "$SESSION_NAME"
