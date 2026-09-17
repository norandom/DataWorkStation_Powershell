"""Exercise Docker deployment planning without modifying a daemon or host."""

import json
import os
import runpy
import unittest
from pathlib import Path
from types import ModuleType
from unittest.mock import Mock, patch

DEPLOY = Path(__file__).resolve().parents[1] / "linux" / "developer_docker.py"


class DockerMtuTests(unittest.TestCase):
    def plan(self, config=None, reinitialize="0"):
        calls = []
        operations = ModuleType("pyinfra.operations")

        def operation(kind):
            def record(**kwargs):
                for key in ("src", "dest"):
                    if isinstance(kwargs.get(key), str):
                        kwargs[key] = kwargs[key].replace("\\", "/")
                if hasattr(kwargs.get("src"), "getvalue"):
                    kwargs["content"] = kwargs["src"].getvalue()
                calls.append((kind, kwargs))
            return record

        for group, names in {
            "files": ["directory", "download", "template", "file", "put", "copy"],
            "server": ["user", "service", "shell"],
            "apt": ["packages"],
        }.items():
            setattr(operations, group, Mock(**{name: operation(f"{group}.{name}") for name in names}))

        def read_text(path, **_kwargs):
            if path.as_posix() == "/etc/os-release":
                return 'VERSION_CODENAME="trixie"\n'
            return config if isinstance(config, str) else json.dumps(config)

        with (
            patch.dict("sys.modules", {"pyinfra": ModuleType("pyinfra"), "pyinfra.operations": operations}),
            patch.dict(os.environ, {
                "DEVELOPER_DOCKER_USER": "developer",
                "DEVELOPER_DOCKER_MTU": "1280",
                "DEVELOPER_DOCKER_REINITIALIZE": reinitialize,
            }),
            patch.object(Path, "exists", return_value=config is not None),
            patch.object(Path, "read_text", read_text),
            patch("subprocess.check_output", return_value="amd64\n"),
        ):
            runpy.run_path(str(DEPLOY))
        return calls

    def test_new_config_is_validated_before_install_and_restart(self):
        calls = self.plan()
        candidate = next(i for i, (_, c) in enumerate(calls) if c.get("dest", "").endswith("candidate.json"))
        validate = next(i for i, (kind, _) in enumerate(calls) if kind == "server.shell")
        install = next(i for i, (_, c) in enumerate(calls) if c.get("dest") == "/etc/docker/daemon.json")
        restart = next(i for i, (_, c) in enumerate(calls) if c.get("service") == "docker.service")
        self.assertLess(candidate, validate)
        self.assertLess(validate, install)
        self.assertLess(install, restart)
        self.assertTrue(calls[restart][1]["restarted"])
        config = json.loads(calls[install][1]["content"])
        self.assertEqual(config["mtu"], 1280)
        self.assertEqual(config["default-network-opts"]["bridge"]["com.docker.network.driver.mtu"], "1280")

    def test_merge_preserves_settings_and_backs_up_before_replacement(self):
        original = {"log-driver": "local", "default-network-opts": {"bridge": {"other": "keep"}}}
        calls = self.plan(original)
        backup = next(i for i, (kind, _) in enumerate(calls) if kind == "files.copy")
        install = next(i for i, (_, c) in enumerate(calls) if c.get("dest") == "/etc/docker/daemon.json")
        self.assertLess(backup, install)
        merged = json.loads(calls[install][1]["content"])
        self.assertEqual(merged["log-driver"], "local")
        self.assertEqual(merged["default-network-opts"]["bridge"]["other"], "keep")

    def test_matching_config_does_not_rewrite_or_restart(self):
        config = {"mtu": 1280, "default-network-opts": {"bridge": {"com.docker.network.driver.mtu": "1280"}}}
        calls = self.plan(config)
        self.assertFalse(any(c.get("dest") == "/etc/docker/daemon.json" for _, c in calls))
        service = next(c for _, c in calls if c.get("service") == "docker.service")
        self.assertFalse(service["restarted"])
        forced = self.plan(config, reinitialize="1")
        self.assertTrue(next(c for _, c in forced if c.get("service") == "docker.service")["restarted"])

    def test_invalid_existing_config_is_not_replaced(self):
        for config in ("invalid-json", "[]", {"default-network-opts": None}):
            with self.subTest(config=config), self.assertRaises((ValueError, TypeError, AttributeError)):
                self.plan(config)


if __name__ == "__main__":
    unittest.main()
