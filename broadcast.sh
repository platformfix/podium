#!/bin/sh
# Serves the live-terminal-broadcast page and streams the shell history file
# over the same connection via websocketd. Runs as podium's broadcast
# sidecar container; the page and the WebSocket endpoint are vendored in
# this image (assets/broadcast.html) rather than fetched from anywhere.
set -eu

PORT="${BROADCAST_PORT:-1088}"
HISTFILE="${BROADCAST_HISTFILE:-/home/k8s/.zsh_history}"

# $HOME is mounted read-only in this sidecar, so wait for the shell
# container to create the history file rather than touch-ing it ourselves.
until [ -f "$HISTFILE" ]; do sleep 1; done

exec websocketd --port="$PORT" --staticdir=/opt/podium/broadcast \
  sh -c "tail -n +1 -f '$HISTFILE'"
