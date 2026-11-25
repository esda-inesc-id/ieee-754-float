# ieee-754-float

IEEE-754 floating-point units in Verilog, parameterized in word and exponent
width (binary32 by default), with subnormals and the five IEEE-754 rounding modes,
selected at run time.
The user guide is `doc/ieee754_float_ug.pdf`.

| Unit   | Function                          | Latency (binary32) |
|--------|-----------------------------------|--------------------|
| `fadd` | Addition                          | 5, pipelined       |
| `fmul` | Multiplication                    | 4, pipelined       |
| `fdiv` | Division                          | 30, iterative      |
| `fmac` | Sum of a stream of products       | 8, after the last product |
| `ffma` | Fused multiply-add, a*b + c       | 6, pipelined       |
| `fpu`  | Add, subtract, multiply, divide   | 5; division 30     |

`sw_model` holds a bit-accurate C model of the units, with C++ types, a Python
wrapper, a math library built on the model (`sqrt`, `exp`, `log`) and examples.
`sw_model/study` holds an accuracy study of `fmac` against FMA chains, separate
multiply and add, and an exact accumulator (`make -C sw_model fmac-accuracy`,
needs MPFR).

## Usage

```bash
make help                    # list the targets
make sim CORE=fmul           # run a unit's directed testbench
make test-smoke CORE=fdiv    # 1,000 TestFloat vectors per operation
make test-regular CORE=fdiv  # TestFloat level 1
make test-full CORE=fmac     # smoke, then regular with all 6.1M mulAdd vectors
make coverage CORE=fmac      # regular tests in Verilator, with a coverage report
make test                    # smoke, then regular; all units without CORE
make fpga-build CORE=fmac    # Vivado out-of-context place and route
make syn-build CORE=fadd     # Genus ASIC synthesis
make run CPROG=fft           # run an example of the software model
make run PYPROG=<program>    # run a Python program of the software model
make sw-test                 # software model tests
make sw-check                # software model against the RTL
make doc                     # build the user guide
make clean                   # remove generated files
```

`SIMULATOR` selects `icarus` (default), `xezim`, `xsim`, `xcelium` or `verilator`.
Xcelium and Genus run on `CADENCE_SERVER` and Vivado on `VIVADO_SERVER`; an
empty server runs the tool locally.
