"""Python wrapper of the C model (libieee754.so).

The library path is taken from the IEEE754_LIB environment variable, or defaults to
sw_model/build/libieee754.so.
"""

import ctypes
import os

# Rounding modes, encoded as the rnd_mode input of the units
RNE, RTZ, RDN, RUP, RMM = range(5)

_lib = None


def _library():
    global _lib
    if _lib is not None:
        return _lib
    default = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build",
                           "libieee754.so")
    lib = ctypes.CDLL(os.environ.get("IEEE754_LIB", default))
    u64, cint = ctypes.c_uint64, ctypes.c_int
    for name in ("add", "sub", "mul", "div"):
        func = getattr(lib, f"ieee754_{name}")
        func.argtypes = [u64, u64, cint, cint]
        func.restype = u64
    lib.ieee754_set_rounding.argtypes = [cint]
    lib.ieee754_set_rounding.restype = None
    lib.ieee754_get_rounding.argtypes = []
    lib.ieee754_get_rounding.restype = cint
    lib.ieee754_format_ok.argtypes = [cint, cint]
    lib.ieee754_format_ok.restype = cint
    lib.ieee754_from_double.argtypes = [ctypes.c_double, cint, cint]
    lib.ieee754_from_double.restype = u64
    lib.ieee754_to_double.argtypes = [u64, cint, cint]
    lib.ieee754_to_double.restype = ctypes.c_double
    lib.ieee754_mac_new.argtypes = [cint, cint, cint, cint]
    lib.ieee754_mac_new.restype = ctypes.c_void_p
    lib.ieee754_mac_free.argtypes = [ctypes.c_void_p]
    lib.ieee754_mac_free.restype = None
    lib.ieee754_mac_push.argtypes = [ctypes.c_void_p, u64, u64]
    lib.ieee754_mac_push.restype = None
    lib.ieee754_mac_result.argtypes = [ctypes.c_void_p]
    lib.ieee754_mac_result.restype = u64
    _lib = lib
    return lib


def set_rounding(mode):
    """Sets the rounding mode of later operations and fmac products (RNE by default)."""
    _library().ieee754_set_rounding(mode)


def get_rounding():
    return _library().ieee754_get_rounding()


class Rounding:
    """Context manager that sets the rounding mode and restores the previous one."""

    def __init__(self, mode):
        self.mode = mode
        self._saved = None

    def __enter__(self):
        self._saved = get_rounding()
        set_rounding(self.mode)
        return self

    def __exit__(self, *exc):
        set_rounding(self._saved)


class Mac:
    """Streaming fmac: push products, then read the result of the stream."""

    def __init__(self, data_w=32, exp_w=8, lguard_w=0, rguard_w=0):
        self._lib = _library()
        self._handle = self._lib.ieee754_mac_new(data_w, exp_w, lguard_w, rguard_w)
        if not self._handle:
            raise ValueError("unsupported fmac configuration")

    def push(self, a, b):
        self._lib.ieee754_mac_push(self._handle, a, b)

    def result(self):
        return self._lib.ieee754_mac_result(self._handle)

    def close(self):
        if self._handle:
            self._lib.ieee754_mac_free(self._handle)
            self._handle = None

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def __del__(self):
        self.close()


class Format:
    """Operations on raw encodings of one floating-point format."""

    def __init__(self, data_w=32, exp_w=8):
        self._lib = _library()
        if not self._lib.ieee754_format_ok(data_w, exp_w):
            raise ValueError(f"unsupported format {data_w}/{exp_w}")
        self.data_w = data_w
        self.exp_w = exp_w

    def add(self, a, b):
        return self._lib.ieee754_add(a, b, self.data_w, self.exp_w)

    def sub(self, a, b):
        return self._lib.ieee754_sub(a, b, self.data_w, self.exp_w)

    def mul(self, a, b):
        return self._lib.ieee754_mul(a, b, self.data_w, self.exp_w)

    def div(self, a, b):
        return self._lib.ieee754_div(a, b, self.data_w, self.exp_w)

    def from_double(self, value):
        return self._lib.ieee754_from_double(value, self.data_w, self.exp_w)

    def to_double(self, bits):
        return self._lib.ieee754_to_double(bits, self.data_w, self.exp_w)

    def mac(self, terms, lguard_w=0, rguard_w=0):
        """Returns the fmac result of a stream of (a, b) encodings."""
        with Mac(self.data_w, self.exp_w, lguard_w, rguard_w) as mac:
            for a, b in terms:
                mac.push(a, b)
            return mac.result()
