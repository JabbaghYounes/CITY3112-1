#!/usr/bin/env bash
# ==========================================================
# stop.sh — Stop all Asciinema recordings & tmux session
# ==========================================================

SESSION_NAME="quadrec"

echo "----------------------------------------------------------"
echo "Stopping all recordings in tmux session '$SESSION_NAME'..."
echo "----------------------------------------------------------"

for i in 0 1 2 3; do
  tmux send-keys -t ${SESSION_NAME}:0.$i "exit" C-m
done

# Allow time for Asciinema to close files cleanly
sleep 2

tmux kill-session -t "$SESSION_NAME" 2>/dev/null && \
  echo "Session '$SESSION_NAME' closed successfully." || \
  echo "Session '$SESSION_NAME' not found or already closed."

echo "----------------------------------------------------------"
echo " All recordings finalized under ./recordings/"
echo "----------------------------------------------------------"
