#!/usr/bin/env bash
# Complete CPU setup, also safe to rerun manually after resolving a failure.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$HOME/.local/bin:/usr/lib/llvm-21/bin:$PATH"

setup_failed() {
  local status=$?
  trap - ERR
  printf '\nFAILED: %s (exit %s). Setup is incomplete.\n' "$step" "$status" >&2
  if [[ "$step" != record_environment ]]; then
    bash scripts/record_environment.sh || true
  fi
  printf 'Inspect the first error above. For persistent Input/output errors, stop/start the Codespace before retrying.\n' >&2
  printf 'After resolving the cause, rerun: bash scripts/setup_codespace.sh\n' >&2
  exit "$status"
}
trap setup_failed ERR

for step in bootstrap_ubuntu setup_rust setup_python_cpu smoke_cpu record_environment; do
  printf '\n==> %s\n' "$step"
  bash "scripts/$step.sh"
done
printf '\nREADY: CPU development environment; C++, Python, Rust, MLIR development checks, and environment recording passed.\n'
