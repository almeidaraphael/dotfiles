#!/usr/bin/env bash
# Shows what's playing when media is active; otherwise a quote that stays
# fixed for the whole lock session (seeded on hyprlock's own PID, which is
# stable across this script's periodic re-invocation but different every
# time a new hyprlock process actually starts) so the quote doesn't reroll
# on every tick.
if playerctl status 2>/dev/null | grep -q Playing; then
    printf '  %s\n' "$(playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null)"
    exit 0
fi

QUOTES_FILE="$HOME/.config/hypr/lock-quotes.txt"
mapfile -t QUOTES < "$QUOTES_FILE"

pid=$(pgrep -x hyprlock | head -1)
idx=$(( ${pid:-$$} % ${#QUOTES[@]} ))
printf '%s\n' "${QUOTES[$idx]}"
