#!/usr/bin/env bash
set -Eeuo pipefail

# Open a maximized XFCE terminal with a 3-pane tmux layout and record DISPLAY :1.

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
session=wal-hb-demo
display=${DISPLAY:-:1}
artifact_dir=${ARTIFACT_DIR:-/opt/cursor/artifacts}
mkdir -p "$artifact_dir"
video_path=${VIDEO_PATH:-$artifact_dir/wal_heartbeat_three_pane_demo.mp4}
load_seconds=${WAL_DEMO_LOAD_SECONDS:-20}

export DISPLAY=$display
export WAL_DEMO_LOAD_SECONDS=$load_seconds

# Fresh tmux session: left ops, top-right WAL, bottom-right heartbeat.
tmux -f /exec-daemon/tmux.portal.conf kill-session -t "$session" 2>/dev/null || true
tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$session" -c "$root_dir" -- bash -l
tmux -f /exec-daemon/tmux.portal.conf split-window -h -t "$session:0" -c "$root_dir" -- \
  bash -lc './scripts/watch-slot-wal.sh'
tmux -f /exec-daemon/tmux.portal.conf select-pane -t "$session:0.1"
tmux -f /exec-daemon/tmux.portal.conf split-window -v -t "$session:0" -c "$root_dir" -- \
  bash -lc './scripts/watch-heartbeat-row.sh'
tmux -f /exec-daemon/tmux.portal.conf select-layout -t "$session:0" main-vertical
tmux -f /exec-daemon/tmux.portal.conf select-pane -t "$session:0.0" -T '1 · operations'
tmux -f /exec-daemon/tmux.portal.conf select-pane -t "$session:0.1" -T '2 · slot / retained WAL'
tmux -f /exec-daemon/tmux.portal.conf select-pane -t "$session:0.2" -T '3 · heartbeat row'
tmux -f /exec-daemon/tmux.portal.conf set-option -t "$session" status on
tmux -f /exec-daemon/tmux.portal.conf set-option -t "$session" status-left '#[bold] WAL heartbeat demo '
tmux -f /exec-daemon/tmux.portal.conf set-option -t "$session" status-right ' 1 ops | 2 slot/WAL | 3 heartbeat '
tmux -f /exec-daemon/tmux.portal.conf set-option -t "$session" pane-border-status top
tmux -f /exec-daemon/tmux.portal.conf set-option -t "$session" pane-border-format ' #{pane_index} #{pane_title} '
tmux -f /exec-daemon/tmux.portal.conf select-pane -t "$session:0.0"

# Close prior demo terminals and open one maximized terminal attached to tmux.
pkill -f 'xfce4-terminal.*wal-hb-demo' 2>/dev/null || true
sleep 0.5
xfce4-terminal \
  --title='WAL heartbeat demo' \
  --maximize \
  --hide-menubar \
  --hide-toolbar \
  --command="tmux -f /exec-daemon/tmux.portal.conf attach-session -t $session" &
sleep 2
wmctrl -r 'WAL heartbeat demo' -b add,fullscreen 2>/dev/null || true

# Start screen recording of the desktop.
pkill -f 'ffmpeg.*wal_heartbeat_three_pane' 2>/dev/null || true
rm -f "$video_path"
ffmpeg -y -loglevel error \
  -video_size 1920x1200 \
  -framerate 15 \
  -f x11grab -i "${display}.0" \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
  "$video_path" &
ffmpeg_pid=$!
sleep 2

# Drive the operations pane.
tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$session:0.0" \
  "WAL_DEMO_LOAD_SECONDS=$load_seconds ./scripts/record-wal-heartbeat-demo.sh" C-m

# Approximate total runtime: setup + 2*load + pauses (~110s for 20s loads).
wait_seconds=$((load_seconds * 2 + 100))
printf 'Recording for ~%ss into %s (ffmpeg pid %s)\n' "$wait_seconds" "$video_path" "$ffmpeg_pid"
sleep "$wait_seconds"

# Stop recording cleanly.
kill -INT "$ffmpeg_pid" 2>/dev/null || true
wait "$ffmpeg_pid" 2>/dev/null || true
sleep 1

if [[ ! -s "$video_path" ]]; then
  printf 'Recording failed: %s missing or empty\n' "$video_path" >&2
  exit 1
fi

# Keep the terminal up briefly so the last frame is clean, then leave session running.
printf 'Saved recording: %s (%s)\n' "$video_path" "$(du -h "$video_path" | awk '{print $1}')"
ls -lh "$video_path"
