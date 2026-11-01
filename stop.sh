#!/bin/sh
exec pwsh -NoProfile -File "$(dirname "$0")/tools/stop-server.ps1" "$@"
