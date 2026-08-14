#!/usr/bin/env python3
"""Read-only EARS and verification-traceability validator."""

from __future__ import annotations

import argparse
import json
import re
import tomllib
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

REQUIREMENT_LINE = re.compile(
    r"^\s*(?:[-*]\s+)?(?:\*\*)?(?P<id>REQ-\d{3,})(?:\*\*)?\s*"
    r"(?::|[-\u2013\u2014])\s*(?P<text>.+?)\s*$"
)
SHALL = re.compile(r"\bshall\b", re.IGNORECASE)
NON_NORMATIVE = re.compile(r"\b(?:should|may|must)\b", re.IGNORECASE)
DEFAULTS: dict[str, Any] = {
    "spec_glob": "specs/*/spec.md",
    "traceability_file": "traceability.toml",
    "require_test_files": True,
    "test_command": "",
    "production_roots": ["src", "app", "lib"],
    "test_roots": ["tests"],
    "source_extensions": [
        ".c",
        ".cc",
        ".cpp",
        ".cs",
        ".go",
        ".java",
        ".js",
        ".jsx",
        ".kt",
        ".php",
        ".ps1",
        ".py",
        ".rb",
        ".rs",
        ".ts",
        ".tsx",
    ],
}


@dataclass(frozen=True)
class Finding:
    code: str
    message: str
    path: str
    requirement: str | None = None
    line: int | None = None
    severity: str = "error"


@dataclass(frozen=True)
class Requirement:
    identifier: str
    text: str
    path: Path
    line: int


def _relative(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root).as_posix()
    except ValueError:
        return str(path.resolve())


def _finding(
    root: Path,
    code: str,
    message: str,
    path: Path,
    requirement: str | None = None,
    line: int | None = None,
    severity: str = "error",
) -> Finding:
    return Finding(code, message, _relative(path, root), requirement, line, severity)


def load_config(root: Path) -> tuple[dict[str, Any], list[Finding]]:
    config = dict(DEFAULTS)
    path = root / ".specify" / "ears-sdd.toml"
    if not path.exists():
        return config, [
            _finding(root, "CONFIG_MISSING", "Create .specify/ears-sdd.toml from the sample.", path)
        ]
    try:
        loaded = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, tomllib.TOMLDecodeError) as error:
        return config, [_finding(root, "CONFIG_INVALID", str(error), path)]
    if not isinstance(loaded, dict):
        return config, [
            _finding(root, "CONFIG_INVALID", "Configuration must be a TOML table.", path)
        ]
    config.update(loaded)
    return config, []


def discover_specs(root: Path, config: dict[str, Any], feature: str | None) -> list[Path]:
    if feature:
        candidate = (root / feature).resolve()
        if candidate.is_dir():
            candidate /= "spec.md"
        return [candidate]

    active = root / ".specify" / "feature.json"
    if active.exists():
        try:
            data = json.loads(active.read_text(encoding="utf-8"))
            directory = data.get("feature_directory")
            if isinstance(directory, str) and directory:
                candidate = Path(directory)
                if not candidate.is_absolute():
                    candidate = root / candidate
                candidate = candidate.resolve() / "spec.md"
                if candidate.exists():
                    return [candidate]
        except (OSError, UnicodeError, json.JSONDecodeError):
            pass

    pattern = config.get("spec_glob", DEFAULTS["spec_glob"])
    if not isinstance(pattern, str) or not pattern:
        return []
    return sorted(path.resolve() for path in root.glob(pattern) if path.is_file())


def parse_requirements(root: Path, spec_path: Path) -> tuple[list[Requirement], list[Finding]]:
    if not spec_path.is_file():
        return [], [_finding(root, "SPEC_MISSING", "Specification file not found.", spec_path)]
    try:
        lines = spec_path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as error:
        return [], [_finding(root, "SPEC_UNREADABLE", str(error), spec_path)]

    requirements: list[Requirement] = []
    findings: list[Finding] = []
    seen: set[str] = set()
    for number, line in enumerate(lines, 1):
        match = REQUIREMENT_LINE.match(line)
        if not match:
            continue
        identifier = match.group("id")
        text = match.group("text").strip().strip("*")
        if identifier in seen:
            findings.append(
                _finding(
                    root,
                    "REQ_DUPLICATE",
                    "Requirement identifier is duplicated in this specification.",
                    spec_path,
                    identifier,
                    number,
                )
            )
            continue
        seen.add(identifier)
        requirement = Requirement(identifier, text, spec_path, number)
        requirements.append(requirement)
        findings.extend(validate_ears(root, requirement))

    if not requirements:
        findings.append(
            _finding(
                root,
                "REQ_NONE",
                "No requirements matching `REQ-NNN: <EARS sentence>` were found.",
                spec_path,
            )
        )
    return requirements, findings


def validate_ears(root: Path, requirement: Requirement) -> list[Finding]:
    findings: list[Finding] = []
    sentence = requirement.text.strip()
    lower = sentence.casefold()
    shall_count = len(SHALL.findall(sentence))
    if shall_count != 1:
        findings.append(
            _finding(
                root,
                "EARS_SHALL",
                f"EARS requires exactly one `shall`; found {shall_count}.",
                requirement.path,
                requirement.identifier,
                requirement.line,
            )
        )
    non_normative = NON_NORMATIVE.search(sentence)
    if non_normative:
        findings.append(
            _finding(
                root,
                "EARS_MODAL",
                f"Use `shall`, not `{non_normative.group(0)}`.",
                requirement.path,
                requirement.identifier,
                requirement.line,
            )
        )

    shall_match = SHALL.search(sentence)
    if shall_match is None:
        return findings
    subject = sentence[: shall_match.start()].strip(" ,")
    response = sentence[shall_match.end() :].strip(" .")
    if not subject or not response:
        findings.append(
            _finding(
                root,
                "EARS_INCOMPLETE",
                "The requirement needs both a system subject and an observable response.",
                requirement.path,
                requirement.identifier,
                requirement.line,
            )
        )

    if lower.startswith(("when ", "while ", "where ")):
        comma = sentence.find(",")
        if comma < 0 or (shall_match and comma > shall_match.start()):
            findings.append(
                _finding(
                    root,
                    "EARS_CLAUSE",
                    "The EARS condition must end with a comma before the system response.",
                    requirement.path,
                    requirement.identifier,
                    requirement.line,
                )
            )
    elif lower.startswith("if "):
        if ", then " not in lower[: shall_match.start() + 1]:
            findings.append(
                _finding(
                    root,
                    "EARS_UNWANTED",
                    "Unwanted-behavior form must use `If <condition>, then <system> shall ...`.",
                    requirement.path,
                    requirement.identifier,
                    requirement.line,
                )
            )
    elif lower.startswith(("when", "while", "where", "if")):
        findings.append(
            _finding(
                root,
                "EARS_PREFIX",
                "Use a complete EARS prefix followed by a space.",
                requirement.path,
                requirement.identifier,
                requirement.line,
            )
        )
    return findings


def load_traceability(
    root: Path, spec_path: Path, config: dict[str, Any]
) -> tuple[dict[str, Any], list[Finding]]:
    name = config.get("traceability_file", DEFAULTS["traceability_file"])
    path = spec_path.parent / str(name)
    if not path.is_file():
        return {}, [_finding(root, "TRACE_MISSING", "Traceability file not found.", path)]
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, tomllib.TOMLDecodeError) as error:
        return {}, [_finding(root, "TRACE_INVALID", str(error), path)]
    entries = data.get("requirements", {})
    if not isinstance(entries, dict):
        return {}, [_finding(root, "TRACE_INVALID", "`requirements` must be a TOML table.", path)]
    return entries, []


def _test_path(selector: str) -> str:
    return selector.split("::", 1)[0].split("#", 1)[0]


def validate_traceability(
    root: Path,
    spec_path: Path,
    requirements: list[Requirement],
    config: dict[str, Any],
) -> list[Finding]:
    entries, findings = load_traceability(root, spec_path, config)
    if findings:
        return findings
    path = spec_path.parent / str(config.get("traceability_file", "traceability.toml"))
    identifiers = {requirement.identifier for requirement in requirements}
    for identifier in sorted(identifiers - set(entries)):
        findings.append(
            _finding(
                root,
                "TRACE_MISSING_REQ",
                "Requirement has no verification mapping.",
                path,
                identifier,
            )
        )
    for identifier in sorted(set(entries) - identifiers):
        findings.append(
            _finding(
                root,
                "TRACE_UNKNOWN_REQ",
                "Mapping refers to an unknown requirement.",
                path,
                identifier,
            )
        )

    test_roots = tuple(
        str(item).replace("\\", "/").rstrip("/") + "/" for item in config.get("test_roots", [])
    )
    require_files = bool(config.get("require_test_files", True))
    for identifier in sorted(identifiers & set(entries)):
        entry = entries[identifier]
        if not isinstance(entry, dict):
            findings.append(
                _finding(root, "TRACE_ENTRY", "Mapping must be a TOML table.", path, identifier)
            )
            continue
        verification = entry.get("verification")
        if verification == "automated":
            tests = entry.get("tests")
            if (
                not isinstance(tests, list)
                or not tests
                or not all(isinstance(item, str) and item for item in tests)
            ):
                findings.append(
                    _finding(
                        root,
                        "TRACE_TESTS",
                        "Automated verification requires a non-empty `tests` list.",
                        path,
                        identifier,
                    )
                )
                continue
            for selector in tests:
                relative = _test_path(selector).replace("\\", "/").lstrip("./")
                if test_roots and not relative.startswith(test_roots):
                    findings.append(
                        _finding(
                            root,
                            "TRACE_TEST_ROOT",
                            f"Test selector is outside configured test roots: {selector}",
                            path,
                            identifier,
                        )
                    )
                if require_files and not (root / relative).is_file():
                    findings.append(
                        _finding(
                            root,
                            "TRACE_TEST_FILE",
                            f"Referenced test file does not exist: {relative}",
                            path,
                            identifier,
                        )
                    )
        elif verification == "manual":
            rationale = entry.get("rationale")
            if not isinstance(rationale, str) or len(rationale.strip()) < 20:
                findings.append(
                    _finding(
                        root,
                        "TRACE_MANUAL",
                        "Manual verification requires a concrete rationale "
                        "of at least 20 characters.",
                        path,
                        identifier,
                    )
                )
        else:
            findings.append(
                _finding(
                    root,
                    "TRACE_MODE",
                    "`verification` must be `automated` or `manual`.",
                    path,
                    identifier,
                )
            )
    return findings


def _normalized(value: str) -> str:
    return " ".join(value.casefold().split())


def validate_separation(
    root: Path, requirements: list[Requirement], config: dict[str, Any]
) -> list[Finding]:
    findings: list[Finding] = []
    extensions = {str(item).casefold() for item in config.get("source_extensions", [])}
    for root_name in config.get("production_roots", []):
        production_root = (root / str(root_name)).resolve()
        if not production_root.is_dir():
            continue
        for path in production_root.rglob("*"):
            if not path.is_file() or path.suffix.casefold() not in extensions:
                continue
            try:
                if path.stat().st_size > 2_000_000:
                    continue
                content = path.read_text(encoding="utf-8")
            except (OSError, UnicodeError):
                continue
            normalized_content = _normalized(content)
            lines = content.splitlines()
            for requirement in requirements:
                for number, line in enumerate(lines, 1):
                    if re.search(rf"\b{re.escape(requirement.identifier)}\b", line):
                        findings.append(
                            _finding(
                                root,
                                "CODE_REQ_ID",
                                "Production code contains a requirement ID; keep traceability "
                                "in tests and artifacts.",
                                path,
                                requirement.identifier,
                                number,
                            )
                        )
                normalized_requirement = _normalized(requirement.text)
                if (
                    len(normalized_requirement) >= 40
                    and normalized_requirement in normalized_content
                ):
                    findings.append(
                        _finding(
                            root,
                            "CODE_REQ_PROSE",
                            "Production code contains copied requirement prose.",
                            path,
                            requirement.identifier,
                        )
                    )
    return findings


def validate_project(root: Path, phase: str, feature: str | None) -> dict[str, Any]:
    root = root.resolve()
    config, findings = load_config(root)
    specs = discover_specs(root, config, feature)
    if not specs:
        findings.append(
            _finding(
                root, "SPEC_NONE", "No specification matched the configured feature or glob.", root
            )
        )

    feature_results: list[dict[str, Any]] = []
    all_requirements: list[Requirement] = []
    for spec_path in specs:
        requirements, spec_findings = parse_requirements(root, spec_path)
        findings.extend(spec_findings)
        all_requirements.extend(requirements)
        if phase in {"plan", "tasks", "final"}:
            findings.extend(validate_traceability(root, spec_path, requirements, config))
        feature_results.append(
            {
                "spec": _relative(spec_path, root),
                "requirements": len(requirements),
            }
        )

    if phase == "final":
        test_command = config.get("test_command")
        if not isinstance(test_command, str) or not test_command.strip():
            findings.append(
                _finding(
                    root,
                    "TEST_COMMAND",
                    "Set the consuming project's real `test_command` before the final gate.",
                    root / ".specify" / "ears-sdd.toml",
                )
            )
        findings.extend(validate_separation(root, all_requirements, config))

    errors = sum(finding.severity == "error" for finding in findings)
    warnings = sum(finding.severity == "warning" for finding in findings)
    return {
        "ok": errors == 0,
        "phase": phase,
        "project": str(root),
        "features": feature_results,
        "summary": {
            "features": len(feature_results),
            "requirements": len(all_requirements),
            "errors": errors,
            "warnings": warnings,
        },
        "findings": [asdict(finding) for finding in findings],
    }


def print_human(result: dict[str, Any], status_only: bool = False) -> None:
    summary = result["summary"]
    state = "PASS" if result["ok"] else "FAIL"
    print(f"EARS/TDD {result['phase']} gate: {state}")
    print(
        f"Features: {summary['features']}  Requirements: {summary['requirements']}  "
        f"Errors: {summary['errors']}  Warnings: {summary['warnings']}"
    )
    if status_only and not result["findings"]:
        return
    for finding in result["findings"]:
        location = finding["path"]
        if finding["line"]:
            location += f":{finding['line']}"
        requirement = f" [{finding['requirement']}]" if finding["requirement"] else ""
        print(f"- {finding['code']}{requirement} {location}: {finding['message']}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ears-sdd")
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "status"):
        child = subparsers.add_parser(name)
        child.add_argument("--project", default=".")
        child.add_argument("--feature")
        child.add_argument("--phase", choices=("spec", "plan", "tasks", "final"), default="final")
        child.add_argument("--json", action="store_true")
    return parser


def main(arguments: list[str] | None = None) -> int:
    args = build_parser().parse_args(arguments)
    result = validate_project(Path(args.project), args.phase, args.feature)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print_human(result, status_only=args.command == "status")
    if args.command == "status":
        return 0
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
