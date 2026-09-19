#!/usr/bin/env bash
# Run inside the Codespace after setup_python_cpu.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

test "$(uname -m)" = x86_64
clang-21 --version
mlir-opt-21 --version

SMOKE_DIR=$(mktemp -d)
trap 'rm -rf "$SMOKE_DIR"' EXIT
cat > "$SMOKE_DIR/hello.cpp" <<'CPP'
#include <iostream>
int main() {
  int values[] = {1, 2, 3};
  int sum = 0;
  for (int value : values) sum += value;
  std::cout << sum << '\n';
  return sum == 6 ? 0 : 1;
}
CPP
clang++-21 -std=c++17 -O1 -g -fsanitize=address,undefined \
  -fno-sanitize-recover=all -fno-omit-frame-pointer "$SMOKE_DIR/hello.cpp" -o "$SMOKE_DIR/hello"
"$SMOKE_DIR/hello"
mlir-opt-21 examples/mlir/mul_one.mlir --canonicalize --cse -o "$SMOKE_DIR/mul_one.mlir"
cat "$SMOKE_DIR/mul_one.mlir"

.venv/bin/python - <<'PY'
import torch
assert torch.version.cuda is None, 'Expected CPU-only PyTorch'
x = torch.tensor(2.0, requires_grad=True)
x.square().backward()
assert x.grad.item() == 4.0
print({'torch': torch.__version__, 'gradient': x.grad.item()})
PY
printf 'PASS: C++ with ASan/UBSan, MLIR canonicalize, CPU autograd\n'
