#!/bin/sh

LOCK_FILE="/tmp/eww-calendar.lock"

main() {
    # Run eww daemon if not running
    if [[ ! $(pidof eww) ]]; then
        eww -c $HOME/.config/eww/bar daemon
        sleep 1
    fi

    # Open widgets
    if [[ ! -f "$LOCK_FILE" ]]; then
        touch "$LOCK_FILE"
        eww -c $HOME/.config/eww/bar open calendar
    else
        eww -c $HOME/.config/eww/bar close calendar
        rm "$LOCK_FILE"
    fi
}

main
