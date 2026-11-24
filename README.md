# float

IEEE-754 floating-point units in Verilog: adder (`fadd`), multiplier (`fmul`),
divider (`fdiv`), multiply-accumulate (`fmac`) and a combined unit (`fpu`).
The user guide is `doc/ieee754_float_ug.pdf`.

## Usage

```bash
make help                    # list the targets
make sim CORE=fmul           # run a core's testbench
make test                    # smoke tests, then regular tests if they pass
make test-smoke CORE=fdiv    # smoke tests of one core
make fpga-build CORE=fmac    # Vivado out-of-context place and route
make syn-build CORE=fadd     # Genus ASIC synthesis
make run CPROG=fft           # run an example of the software model
make run PYPROG=<program>    # run a Python program of the software model
make clean                   # remove generated files
```

`SIMULATOR` selects `icarus` (default), `xezim`, `xsim` or `xcelium`.
