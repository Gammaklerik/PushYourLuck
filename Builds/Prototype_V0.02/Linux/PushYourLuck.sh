#!/bin/sh
printf '\033c\033]0;%s\a' PushYourLuck
base_path="$(dirname "$(realpath "$0")")"
"$base_path/PushYourLuck.x86_64" "$@"
