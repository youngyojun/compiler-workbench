#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
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
  cmake --version 2>/dev/null || true
  "$HOME/.local/bin/uv" --version 2>/dev/null || true
  rustc --version 2>/dev/null || true
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
