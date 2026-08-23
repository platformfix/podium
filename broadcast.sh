#!/bin/sh
# Serves the live-terminal-broadcast page and streams the shell history file
# over the same connection via websocketd. Runs as podium's broadcast
# sidecar container; the page and the WebSocket endpoint are vendored in
# this image (assets/broadcast.html) rather than fetched from anywhere.
set -eu

PORT="${BROADCAST_PORT:-1088}"
HISTFILE="${BROADCAST_HISTFILE:-/home/k8s/.zsh_history}"

touch "$HISTFILE"
exec websocketd --port="$PORT" --staticdir=/opt/podium/broadcast \
  sh -c "tail -n +1 -f '$HISTFILE'"
