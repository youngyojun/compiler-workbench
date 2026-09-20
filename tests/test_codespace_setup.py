"""Test setup orchestration without installing system packages or using cloud resources."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS = (
    "bootstrap_ubuntu",
    "setup_rust",
    "setup_python_cpu",
    "smoke_cpu",
    "record_environment",
)


class CodespaceSetupTests(unittest.TestCase):
    def run_setup(self, failed_step=None):
        config = json.loads((ROOT / ".devcontainer/devcontainer.json").read_text())
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            shutil.copytree(ROOT / "scripts", workspace / "scripts")
            # Only the installers/checks are stand-ins; execute the actual lifecycle entry point.
            for step in STEPS:
                (workspace / "scripts" / f"{step}.sh").write_text(
                    f"echo {step} >> steps.txt\n"
                    + ("exit 23\n" if step == failed_step else "exit 0\n")
                )
            result = subprocess.run(
                ["bash", "-c", config["postCreateCommand"]],
                cwd=workspace,
                capture_output=True,
                text=True,
                check=False,
            )
            steps = (workspace / "steps.txt").read_text().splitlines()
            return result, steps

    def test_creation_runs_all_steps_before_reporting_ready(self):
        result, steps = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(steps, list(STEPS))
        self.assertIn("READY: CPU development environment", result.stdout)

    def test_failed_install_or_check_stops_setup_and_records_diagnostics(self):
        for index, step in enumerate(STEPS):
            with self.subTest(step=step):
                result, steps = self.run_setup(step)
                self.assertEqual(result.returncode, 23, result.stderr)
                expected = list(STEPS[: index + 1])
                if step != "record_environment":
                    expected.append("record_environment")
                self.assertEqual(steps, expected)
                self.assertIn(step, result.stderr)
                self.assertNotIn("READY:", result.stdout)

    def test_connection_waits_for_complete_setup(self):
        config = json.loads((ROOT / ".devcontainer/devcontainer.json").read_text())
        self.assertEqual(config.get("waitFor"), "postCreateCommand")

    def test_environment_report_survives_a_broken_python(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            (workspace / "scripts").mkdir()
            shutil.copy(ROOT / "scripts/record_environment.sh", workspace / "scripts")
            python = workspace / ".venv/bin/python"
            python.parent.mkdir(parents=True)
            python.write_text("#!/bin/sh\nexit 1\n")
            python.chmod(0o755)
            result = subprocess.run(
                ["bash", "scripts/record_environment.sh"],
                cwd=workspace,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(
                "Python environment unavailable.",
                (workspace / "reports/environment.txt").read_text(),
            )

    def test_python_restores_recorded_versions_and_preserves_them_on_failure(self):
        for restore, fail_freeze in [(False, False), (True, False), (True, True)]:
            with (
                self.subTest(restore=restore, fail_freeze=fail_freeze),
                tempfile.TemporaryDirectory() as directory,
            ):
                workspace = Path(directory)
                (workspace / "scripts").mkdir()
                shutil.copy(ROOT / "scripts/setup_python_cpu.sh", workspace / "scripts")
                shutil.copy(ROOT / "requirements.cpu.in", workspace)
                python = workspace / ".venv/bin/python"
                python.parent.mkdir(parents=True)
                python.write_text("#!/bin/sh\nexit 0\n")
                python.chmod(0o755)
                resolved = workspace / "reports/requirements.cpu.resolved.txt"
                resolved.parent.mkdir()
                versions = "torch==2.13.0+cpu\nnumpy==2.3.0\n"
                if restore:
                    resolved.write_text(versions)
                # Replace only package operations; never download or install during this test.
                shell_env = workspace / "mock_uv.sh"
                shell_env.write_text(
                    "uv() {\n"
                    '  printf "%s\\n" "$*" >> uv-calls.txt\n'
                    '  test "$UV_LINK_MODE" = copy || return 42\n'
                    '  if [[ "$1 $2" == "pip freeze" ]]; then\n'
                    '    printf "torch==2.13.0+cpu\\nnumpy==2.3.0\\n"\n'
                    f"    return {23 if fail_freeze else 0}\n"
                    "  fi\n"
                    "}\n"
                )
                result = subprocess.run(
                    ["bash", "scripts/setup_python_cpu.sh"],
                    cwd=workspace,
                    env={**os.environ, "BASH_ENV": str(shell_env)},
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(
                    result.returncode, 23 if fail_freeze else 0, result.stderr
                )
                calls = (workspace / "uv-calls.txt").read_text()
                source = (
                    "reports/requirements.cpu.resolved.txt"
                    if restore
                    else "requirements.cpu.in"
                )
                self.assertIn(f"-r {source}", calls)
                self.assertNotIn("venv --python", calls)
                self.assertEqual(resolved.read_text(), versions)


if __name__ == "__main__":
    unittest.main()
