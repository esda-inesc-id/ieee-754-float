#!/usr/bin/env bash
# build.sh <core> <part> <sources> <includes> <defines>
# VIVADO_ENV: script that sets up vivado; VIVADO_LOCK: one vivado per machine

if [ -n "$VIVADO_ENV" ]; then
   source "$VIVADO_ENV" > /dev/null
fi

flock "${VIVADO_LOCK:-/tmp/iob_vivado.lock}" \
   vivado -nojournal -log vivado.log -mode batch \
   -source "$(dirname "$(readlink -f "$0")")/vivado.tcl" -tclargs "$1" "$2" "$3" "$4" "$5"
