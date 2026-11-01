#!/bin/sh
exec pwsh -NoProfile -File "$(dirname "$0")/tools/start-server.ps1" -Play "$@"
