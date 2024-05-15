#!/bin/bash
ddcutil setvcp 10 "$@" --noverify --bus 9 &
ddcutil setvcp 10 "$@" --noverify --bus 10 &
