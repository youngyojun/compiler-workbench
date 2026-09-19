#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports
{
  printf 'recorded_utc='; date -u +%FT%TZ
  printf 'git_commit='; git rev-parse HEAD 2>/dev/null || true
  uname -a
  command -v lscpu >/dev/null && lscpu || true
  command -v free >/dev/null && free -h || true
  df -h .
  clang-21 --version 2>/dev/null || true
  mlir-opt-21 --version 2>/dev/null || true
  cmake --version 2>/dev/null || true
  rustc --version 2>/dev/null || true
  if [[ -x .venv/bin/python ]]; then
    .venv/bin/python -c 'import sys, torch; print(sys.version); print(torch.__version__, torch.version.cuda)'
  fi
  command -v nvidia-smi >/dev/null && nvidia-smi || true
} > reports/environment.txt
printf 'Wrote reports/environment.txt. Review hostname and identifiers before publishing.\n'
