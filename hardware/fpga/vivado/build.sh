#!/usr/bin/bash

vivado -nojournal -log vivado.log -mode batch -source ../vivado.tcl -tclargs "$1" "$2" "$3" "$4" "$5"
