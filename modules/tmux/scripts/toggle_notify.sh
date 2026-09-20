#!/usr/bin/env bash
# Inspired by https://github.com/rickstaa/tmux-notify
# The created file is then used by zsh to know if it should send a notification when a command exits.
dir="$XDG_CACHE_HOME/tmux/notify"
pane_id=$(tmux display-message -p '#{pane_id}' | tr -d %)
pane_file="$dir/$pane_id"
mkdir "$dir"
# If file doesn't exist.
if [ ! -f "$pane_file" ]; then
    touch "$pane_file"
    tmux display-message "Monitoring pane."
else
    rm "$pane_file"
    tmux display-message "Not monitoring pane."
fi

