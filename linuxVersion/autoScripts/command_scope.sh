#!/bin/bash
exec systemd-run --user --scope --quiet --collect --expand-environment=no -p MemoryMax=6G -p TasksMax=4096 choom -n 1000 -- /bin/bash -c "$1"
