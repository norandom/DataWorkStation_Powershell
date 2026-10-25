# Plan: WSL memory policy

Use the existing host desired-state script and separate Debian Test/Ensure shell commands. Keep zram initialization in an installed oneshot helper, with LF checkout rules. Register human commands in the capability catalog. Explain logical swap versus physical consumption and distinguish the Linux daemon from the Windows guard.

Validate host declarations, shell syntax, invalid-mode rejection and the deployed trusted Debian state with `tests/Test-WslMemoryPolicy.ps1`. This integration test requires the configured Debian WSL distribution and performs no Ensure or workload termination. Run repository lint, Tricky smoke checks, final specification governance and strict MkDocs build before publishing.
