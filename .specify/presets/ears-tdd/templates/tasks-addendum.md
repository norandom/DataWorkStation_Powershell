## Mandatory verification tasks

Tests are not optional. For each `REQ-NNN`, add a failing-test task before its implementation task,
then a passing-test/refactor task. Every task that changes behavior MUST name the requirements it
implements and the test selectors that verify them.

Before implementation, run the human command `ears-sdd validate --phase tasks`. Agents use the
same command with `--json`.
