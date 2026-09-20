#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$HOME/.local/bin:/usr/lib/llvm-21/bin:$PATH"
mkdir -p reports
{
  printf 'recorded_utc='; date -u +%FT%TZ
  printf 'git_commit='; git rev-parse HEAD 2>/dev/null || true
  uname -a
  if [[ -r /etc/os-release ]]; then cat /etc/os-release; fi
  command -v lscpu >/dev/null && lscpu || true
  command -v free >/dev/null && free -h || true
  df -h .
  df -i .
  clang-21 --version 2>/dev/null || true
  mlir-opt-21 --version 2>/dev/null || true
  llvm-config-21 --version 2>/dev/null || true
  /usr/lib/llvm-21/bin/FileCheck --version 2>/dev/null || true
  cmake --version 2>/dev/null || true
  ninja --version 2>/dev/null || true
  "$HOME/.local/bin/uv" --version 2>/dev/null || true
  # Avoid rustup auto-installing a toolchain while collecting failure diagnostics.
  if command -v rustup >/dev/null && rustup toolchain list | grep -q '^stable-'; then
    rustc +stable -Vv 2>/dev/null || true
    cargo +stable --version 2>/dev/null || true
    rustfmt +stable --version 2>/dev/null || true
    cargo +stable clippy --version 2>/dev/null || true
    rust-analyzer +stable --version 2>/dev/null || true
    rustup component list --toolchain stable --installed 2>/dev/null || true
  fi
  if [[ -x .venv/bin/python ]]; then
    .venv/bin/python - <<'PY' || printf 'Python environment unavailable.\n'
import sys
print(sys.version)
try:
    import torch
    print(torch.__version__, torch.version.cuda)
except Exception as error:
    print(f'PyTorch unavailable: {type(error).__name__}: {error}')
PY
  fi
  command -v nvidia-smi >/dev/null && nvidia-smi || true
} > reports/environment.txt
printf 'Wrote reports/environment.txt. Review hostname and identifiers before publishing.\n'
