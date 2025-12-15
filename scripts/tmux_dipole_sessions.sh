SESSION="dipole-$PID"
REGFILE="/tmp/dipole_regs.txt"

echo "(waiting for registers...)" > "$REGFILE"

# Left pane: run dipole internal REPL
tmux new-session -d -s "$SESSION" \
    "dipole internal-repl '$TARGET'"

# Right pane: redraw registers
tmux split-window -h -t "$SESSION:0" \
    'while true; do clear; cat "/tmp/dipole_regs.txt"; sleep 0.1; done'

tmux select-pane -t "$SESSION:0.0"
tmux attach -t "$SESSION"
