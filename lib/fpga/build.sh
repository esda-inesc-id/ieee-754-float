#!/usr/bin/bash

vivado -nojournal -log vivado.log -mode batch -source "$(dirname "$(readlink -f "$0")")/vivado.tcl" -tclargs "$1" "$2" "$3" "$4" "$5"
