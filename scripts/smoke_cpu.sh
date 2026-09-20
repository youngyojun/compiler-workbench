#!/usr/bin/env bash
# Run inside the Codespace after setup_python_cpu.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$HOME/.local/bin:/usr/lib/llvm-21/bin:$PATH"

test "$(uname -m)" = x86_64
clang-21 --version
mlir-opt-21 --version
llvm-config-21 --version
mlir-translate-21 --version
lli-21 --version
/usr/lib/llvm-21/bin/FileCheck --version

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
cat > "$SMOKE_DIR/mul_one.check" <<'CHECK'
// CHECK-LABEL: func.func @mul_one
// CHECK-NOT: arith.muli
// CHECK: return
CHECK
/usr/lib/llvm-21/bin/FileCheck "$SMOKE_DIR/mul_one.check" --input-file="$SMOKE_DIR/mul_one.mlir"

# Verify headers, CMake package discovery, and linking for later C++ MLIR work.
mkdir -p "$SMOKE_DIR/mlir"
cat > "$SMOKE_DIR/mlir/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(workbench_mlir_smoke LANGUAGES C CXX)
find_package(LLVM REQUIRED CONFIG)
find_package(MLIR REQUIRED CONFIG)
if(NOT LLVM_VERSION_MAJOR EQUAL 21)
  message(FATAL_ERROR "Expected LLVM/MLIR 21")
endif()
add_executable(mlir_smoke main.cpp)
target_compile_features(mlir_smoke PRIVATE cxx_std_17)
target_include_directories(mlir_smoke SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS} ${MLIR_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})
target_link_libraries(mlir_smoke PRIVATE MLIRIR)
CMAKE
cat > "$SMOKE_DIR/mlir/main.cpp" <<'CPP'
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/MLIRContext.h"
int main() {
  mlir::MLIRContext context;
  return mlir::IntegerType::get(&context, 32).getWidth() == 32 ? 0 : 1;
}
CPP
cmake -S "$SMOKE_DIR/mlir" -B "$SMOKE_DIR/mlir/build" -G Ninja \
  -DCMAKE_C_COMPILER=clang-21 -DCMAKE_CXX_COMPILER=clang++-21 \
  -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm -DMLIR_DIR=/usr/lib/llvm-21/lib/cmake/mlir
cmake --build "$SMOKE_DIR/mlir/build" --parallel 2
"$SMOKE_DIR/mlir/build/mlir_smoke"

# No registry access or project files are needed for the Rust smoke test.
mkdir -p "$SMOKE_DIR/rust/src"
cat > "$SMOKE_DIR/rust/Cargo.toml" <<'TOML'
[package]
name = "workbench-smoke"
version = "0.1.0"
edition = "2021"
TOML
cat > "$SMOKE_DIR/rust/src/main.rs" <<'RUST'
fn sum(values: &[i32]) -> i32 {
    values.iter().sum()
}

fn main() {
    assert_eq!(sum(&[1, 2, 3]), 6);
}

#[cfg(test)]
mod tests {
    #[test]
    fn sums_values() {
        assert_eq!(super::sum(&[1, 2, 3]), 6);
    }
}
RUST
rustc +stable --version
rust-analyzer +stable --version
cargo +stable run --offline --manifest-path "$SMOKE_DIR/rust/Cargo.toml"
cargo +stable test --offline --manifest-path "$SMOKE_DIR/rust/Cargo.toml"
cargo +stable fmt --manifest-path "$SMOKE_DIR/rust/Cargo.toml" -- --check
cargo +stable clippy --offline --manifest-path "$SMOKE_DIR/rust/Cargo.toml" --all-targets -- -D warnings

.venv/bin/python - <<'PY'
import io
import numpy as np
import scipy
import pandas
import sklearn
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from PIL import Image
import fastapi
import uvicorn
import httpx
import torch
assert torch.version.cuda is None, 'Expected CPU-only PyTorch'
x = torch.tensor(2.0, requires_grad=True)
x.square().backward()
assert x.grad.item() == 4.0
# Exercise the headless plot/image path used by the graphics and ML tracks.
figure, axes = plt.subplots()
axes.plot(np.arange(3))
with io.BytesIO() as output:
    figure.savefig(output, format='png')
    output.seek(0)
    with Image.open(output) as rendered:
        assert rendered.format == 'PNG'
        rendered.load()
plt.close(figure)
print({'torch': torch.__version__, 'gradient': x.grad.item()})
PY
.venv/bin/python -m pytest --version
.venv/bin/python -m ruff --version
.venv/bin/python -m unittest discover -s tests -v
printf 'PASS: C++ sanitizers, MLIR CMake build and FileCheck, Rust build/test/fmt/clippy, CPU autograd, headless graphics\n'
