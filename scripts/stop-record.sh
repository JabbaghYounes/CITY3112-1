#!/bin/bash
#stop all asciinema recordings and tmux panes

SESSION_NAME="quadrec"

echo "Stopping all recordings in tmux session '$SESSION_NAME'..."

# Gracefully send 'exit' to each pane
for i in 0 1 2 3; do
  tmux send-keys -t ${SESSION_NAME}:0.$i "exit" C-m
done

sleep 1

# Close tmux session
tmux kill-session -t "$SESSION_NAME" 2>/dev/null && \
  echo "Session '$SESSION_NAME' closed." || \
  echo "Session not found or already closed."

