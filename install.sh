#!/usr/bin/env bash
#
# Install the open-source tools of this repository and of the repositories built on it
# (posit, pt-float), on Ubuntu: Icarus Verilog, Verilator and xezim (simulation), the C
# toolchain and MPFR (software model and study), TeX Live (user guide), and SoftPosit
# (posit tests). TestFloat is cloned and built by the first TestFloat run.
#
# The commercial tools are not installed; install them separately when needed:
#   Vivado (make fpga-build), Cadence Genus (make syn-build), Xcelium and SpyGlass.
#
# Usage: ./install.sh [options]
#
# Options:
#   --no-doc  Skip TeX Live (about 1 GB).
#   -h, --help
#             Show this help and exit.
#
set -euo pipefail

cd "$(dirname "$0")"

# Source-built tool versions and install location (the versions of the CI)
VERILATOR_TAG=v5.054
XEZIM_TAG=0.11.7
PREFIX=${PREFIX:-$HOME/.local}

#------------------------------------------------------------
# Arguments
#------------------------------------------------------------
INSTALL_DOC=1
for arg in "$@"; do
    case "$arg" in
    --no-doc)
        INSTALL_DOC=0
        ;;
    -h | --help)
        sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "Unknown option: $arg (see ./install.sh --help)" >&2
        exit 1
        ;;
    esac
done

# Use sudo only when not already root
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

# Temporary build directories, removed on exit
TMP_DIRS=()
trap 'rm -rf "${TMP_DIRS[@]}"' EXIT

#------------------------------------------------------------
# System packages (apt)
#------------------------------------------------------------
echo "==> Installing apt packages"
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
APT_PKGS=(
    build-essential git curl python3 python3-pip python3-venv python3-dev
    iverilog gtkwave
    libmpfr-dev libgmp-dev
    # Verilator build
    autoconf flex bison help2man libfl-dev ccache
    # xezim build
    clang llvm
)
if [ "$INSTALL_DOC" -eq 1 ]; then
    APT_PKGS+=(latexmk texlive-latex-recommended texlive-latex-extra
        texlive-fonts-recommended texlive-pictures)
fi
$SUDO apt-get install -y -qq "${APT_PKGS[@]}"

mkdir -p "$PREFIX/bin"
USER_PATH=$PATH
export PATH="$PREFIX/bin:$HOME/.cargo/bin:$PATH"

#------------------------------------------------------------
# Verilator (from source: Ubuntu's release is too old)
#------------------------------------------------------------
if verilator --version 2>/dev/null | grep -q "Verilator ${VERILATOR_TAG#v} "; then
    echo "==> Verilator $VERILATOR_TAG already installed, skipping"
else
    echo "==> Building Verilator $VERILATOR_TAG into $PREFIX"
    SRC=$(mktemp -d)
    TMP_DIRS+=("$SRC")
    git clone -q --depth 1 --branch "$VERILATOR_TAG" https://github.com/verilator/verilator "$SRC"
    (cd "$SRC" && autoconf && ./configure --prefix="$PREFIX" && make -j"$(nproc)" && make install)
fi

#------------------------------------------------------------
# xezim (from source, with Rust's cargo)
#------------------------------------------------------------
if command -v xezim >/dev/null 2>&1; then
    echo "==> xezim already installed ($(command -v xezim)), skipping"
else
    echo "==> Building xezim $XEZIM_TAG into $PREFIX"
    if ! command -v cargo >/dev/null 2>&1; then
        curl -sSf https://sh.rustup.rs | sh -s -- -y -q --profile minimal
    fi
    cargo install -q --git https://github.com/aionhw/xezim --tag "$XEZIM_TAG" --locked --root "$PREFIX"
fi

#------------------------------------------------------------
# Python packages (pip, user site)
#------------------------------------------------------------
echo "==> Installing Python packages"
# SoftPosit, the posit standard's reference library (posit tests); built from source
PIP_FLAGS=(--user -q)
if python3 -m pip install --help | grep -q break-system-packages; then
    PIP_FLAGS+=(--break-system-packages)
fi
python3 -m pip install "${PIP_FLAGS[@]}" softposit

echo "==> Done."
case ":$USER_PATH:" in
*":$PREFIX/bin:"*) ;;
*) echo "Add $PREFIX/bin to your PATH." ;;
esac
