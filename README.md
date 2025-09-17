# float

## How to use

First, **clone the repository recursively** to ensure all submodules are included:

```bash
git clone --init --recursive <repository_url>
```

Then, to simulate the various modules, use the following commands:

  * **Floating-point unit (FPU):**

    ```bash
    make sim-clean sim TOP_MODULE=ieee754_fpu
    ```

  * **Adder:**

    ```bash
    make sim-clean sim TOP_MODULE=ieee754_add
    ```

  * **Multiplier:**

    ```bash
    make sim-clean sim TOP_MODULE=ieee754_mul
    ```

  * **Divider:**

    ```bash
    make sim-clean sim TOP_MODULE=ieee754_div
    ```

  * **Multiply-Accumulate (MAC):**

    ```bash
    make sim-clean sim TOP_MODULE=ieee754_mac
    ```

-----

## Configuration

To select the floating-point format, edit the testbench file and pass the parameters **DATA\_W** (word length) and **EXP\_W** (exponent length).
