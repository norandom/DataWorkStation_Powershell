#!/usr/bin/env python3
"""Synthetic graph-database tests; no sample, Sandbox, Ghidra, or container is started."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
RUNNER_PATH = REPOSITORY_ROOT / "linux" / "malware-analysis" / "entrypoint.py"
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("malware_static_entrypoint", RUNNER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Unable to load the static-analysis runner")
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class BinaryDiffRunnerTests(unittest.TestCase):
    def test_graph_projection_and_sidecar_preserve_canonical_database(self) -> None:
        with tempfile.TemporaryDirectory(prefix="dws-binary-graph-test-") as directory:
            root = Path(directory)
            canonical = root / RUNNER.BINARY_DIFF_DATABASE
            with closing(sqlite3.connect(canonical)) as connection, connection:
                connection.executescript(
                    """
                    CREATE TABLE metadata(similarity REAL, confidence REAL);
                    CREATE TABLE file(id INTEGER, functions INTEGER, libfunctions INTEGER);
                    CREATE TABLE function(id INTEGER, address1 INTEGER, name1 TEXT, address2 INTEGER,
                        name2 TEXT, similarity REAL, confidence REAL, algorithm INTEGER,
                        basicblocks INTEGER, edges INTEGER, instructions INTEGER);
                    CREATE TABLE basicblock(id INTEGER);
                    CREATE TABLE instruction(address1 INTEGER);
                    CREATE TABLE functionalgorithm(id INTEGER, name TEXT);
                    INSERT INTO metadata VALUES (0.75, 0.90);
                    INSERT INTO file VALUES (1, 3, 0), (2, 4, 0);
                    INSERT INTO functionalgorithm VALUES (1, 'function: call graph edges MD index');
                    INSERT INTO function VALUES
                        (1, 4096, 'old_changed', 8192, 'new_changed', 0.50, 0.40, 1, 4, 5, 20),
                        (2, 4352, 'old_same', 8448, 'new_same', 1.00, 1.00, 1, 2, 1, 8);
                    """
                )
            canonical_before = sha256(canonical)

            metrics, matches, truncated = RUNNER.read_bindiff_projection(canonical, 1)
            self.assertTrue(truncated)
            self.assertEqual(2, metrics["matched_functions"])
            self.assertEqual(1, metrics["changed_functions"])
            self.assertEqual(1, metrics["ambiguous_functions"])
            self.assertEqual("4096", matches[0]["address1"])
            self.assertEqual("8192", matches[0]["address2"])

            jsonl_paths: dict[str, Path] = {}
            inputs: dict[str, tuple[str, Path]] = {}
            for role, address, name in (("Baseline", "4096", "old_changed"), ("Candidate", "8192", "new_changed")):
                source = root / role.casefold()
                source.write_bytes(role.encode("ascii"))
                inputs[role] = (hashlib.sha256(source.read_bytes()).hexdigest().upper(), source)
                records = root / f"{role.casefold()}-analysis.jsonl"
                records.write_text(
                    json.dumps(
                        {
                            "Kind": "Function",
                            "Address": address,
                            "Name": name,
                            "Namespace": "Global",
                            "Signature": "void f(void)",
                            "Size": 8,
                            "DecompileState": "complete",
                            "DecompiledCode": "void f(void) {}",
                            "DecompileError": None,
                        }
                    )
                    + "\n",
                    encoding="utf-8",
                )
                jsonl_paths[role] = records

            sidecar = root / RUNNER.BINARY_ANALYSIS_DATABASE
            state = RUNNER.create_binary_analysis_database(
                sidecar,
                inputs,
                jsonl_paths,
                matches,
                truncated,
                argparse.Namespace(max_records=32, max_string=256, max_artifact=1_048_576),
            )
            self.assertEqual("truncated", state)
            with closing(sqlite3.connect(sidecar)) as connection:
                tables = {
                    row[0]
                    for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")
                }
                self.assertTrue(
                    {
                        "binaries",
                        "functions",
                        "basic_blocks",
                        "instructions",
                        "edges",
                        "calls",
                        "function_matches",
                    }.issubset(tables)
                )
                self.assertEqual(2, connection.execute("SELECT COUNT(*) FROM functions").fetchone()[0])
                self.assertEqual(1, connection.execute("SELECT COUNT(*) FROM function_matches").fetchone()[0])

            self.assertEqual(canonical_before, sha256(canonical), "the canonical BinDiff database changed")


if __name__ == "__main__":
    unittest.main()
