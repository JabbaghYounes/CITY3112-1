#!/bin/bash
SESSION_NAME="quadrec"

# Gracefully tell each pane to exit
for i in 0 1 2 3; do
  tmux send-keys -t ${SESSION_NAME}:0.$i "exit" C-m
done
