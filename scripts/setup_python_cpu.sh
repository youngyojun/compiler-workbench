#!/usr/bin/env bash
# Run from this repository root, after bootstrap. Separate from GPU environment.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
command -v uv >/dev/null || { echo 'Install uv first.' >&2; exit 2; }
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python 'torch==2.13.0' \
  --index-url https://download.pytorch.org/whl/cpu
uv pip install --python .venv/bin/python -r requirements.cpu.in
mkdir -p reports
uv pip freeze --python .venv/bin/python > reports/requirements.cpu.resolved.txt
.venv/bin/python - <<'PY'
import torch
assert torch.version.cuda is None, 'This is the CPU environment, not the GPU one.'
x = torch.tensor([2.0], requires_grad=True)
x.square().sum().backward()
assert x.grad.item() == 4.0
print({'torch': torch.__version__, 'cuda': torch.version.cuda, 'autograd': 'passed'})
PY
