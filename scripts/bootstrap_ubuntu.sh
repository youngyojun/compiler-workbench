#!/usr/bin/env bash
# Remote Ubuntu 24.04 only. Installs CPU tools; does not create cloud resources.
set -Eeuo pipefail
trap 'status=$?; printf "Bootstrap failed at line %s (exit %s).\n" "$LINENO" "$status" >&2; exit "$status"' ERR
if [[ ! -r /etc/os-release ]]; then
  echo 'Expected Ubuntu 24.04; run this script inside the Codespace.' >&2
  exit 2
fi
source /etc/os-release
if [[ "${ID:-}" != ubuntu || "${VERSION_ID:-}" != 24.04 ]]; then
  echo 'Expected Ubuntu 24.04; stop rather than changing repositories on another OS.' >&2
  exit 2
fi
if [[ $(uname -m) != x86_64 ]]; then
  echo 'Expected x86_64 for the CPU lab.' >&2
  exit 2
fi
SUDO=(); [[ $(id -u) -eq 0 ]] || SUDO=(sudo)
APT=("${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get
  -o Acquire::Retries=3 -o DPkg::Lock::Timeout=120)
"${APT[@]}" update
# Recover incomplete dependency installation on reruns; never remove packages to resolve it.
"${APT[@]}" --fix-broken install -y --no-remove --no-install-recommends
"${APT[@]}" install -y --no-install-recommends \
  ca-certificates curl gnupg git gh openssh-client build-essential cmake ninja-build \
  gdb ccache pkg-config python3 python3-venv python3-dev tmux ripgrep jq rsync unzip
KEY=$(mktemp); trap 'rm -f "$KEY" "$KEY.gpg"' EXIT
curl --fail --show-error --location --retry 3 https://apt.llvm.org/llvm-snapshot.gpg.key -o "$KEY"
FPR=$(gpg --show-keys --with-colons "$KEY" | awk -F: '$1=="fpr" {print $10; exit}')
EXPECTED='6084F3CF814B57C1CF12EFD515CF4D18AF4F7421'
if [[ "$FPR" != "$EXPECTED" ]]; then
  echo 'LLVM signing key changed. Verify it on apt.llvm.org before proceeding.' >&2
  exit 3
fi
gpg --batch --yes --dearmor --output "$KEY.gpg" "$KEY"
"${SUDO[@]}" install -m 0644 "$KEY.gpg" /usr/share/keyrings/llvm-archive-keyring.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] https://apt.llvm.org/noble/ llvm-toolchain-noble-21 main' | \
  "${SUDO[@]}" tee /etc/apt/sources.list.d/llvm21.list >/dev/null
"${APT[@]}" update
"${APT[@]}" install -y --no-install-recommends \
  clang-21 libclang-rt-21-dev clangd-21 clang-format-21 clang-tidy-21 lld-21 lldb-21 \
  llvm-21 llvm-21-dev llvm-21-tools libmlir-21-dev mlir-21-tools
ccache --max-size=2G
python3 -m venv "$HOME/.venvs/uv-tool"
"$HOME/.venvs/uv-tool/bin/python" -m pip --disable-pip-version-check install uv
mkdir -p "$HOME/.local/bin"
ln -sfn "$HOME/.venvs/uv-tool/bin/uv" "$HOME/.local/bin/uv"
printf '\nSystem tools installed.\n'
clang-21 --version
mlir-opt-21 --version
