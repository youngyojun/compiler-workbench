#!/usr/bin/env bash
# CPU toolchain only; no nightly, cross-compilation targets, or external crates.
set -euo pipefail
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
if ! command -v rustup >/dev/null; then
  RUSTUP_INSTALLER=$(mktemp)
  trap 'rm -f "$RUSTUP_INSTALLER"' EXIT
  curl --proto '=https' --tlsv1.2 --fail --show-error --location --retry 3 \
    https://sh.rustup.rs -o "$RUSTUP_INSTALLER"
  sh "$RUSTUP_INSTALLER" -y --no-modify-path --profile minimal --default-toolchain none
fi
rustup toolchain install stable --profile minimal \
  --component rustfmt --component clippy --component rust-analyzer
rustup default stable
rustc --version
cargo --version
