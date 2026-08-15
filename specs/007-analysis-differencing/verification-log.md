# Verification Log: Analysis Differencing

| Date | Scope | Result | Notes |
|---|---|---|---|
| 2026-08-15 | EARS spec, plan, tasks, and final gates | PASS | 22 requirements; zero errors or warnings. Graph-based BinExport/BinDiff matching is primary; queryable code is a separate sidecar. |
| 2026-08-15 | Focused contracts | PASS | 125 assertions in PowerShell 7.6.4 and Windows PowerShell 5.1.26100.9168. |
| 2026-08-15 | Pester adapter | PASS | 15/15 in parallel PowerShell 7 and 15/15 in sequential Windows PowerShell compatibility mode. |
| 2026-08-15 | Real plan smoke | PASS | Both runtimes created equivalent plan-only cases with `PrimaryComparison=structural-graph` and `Execution=not-run`; temporary cases were removed. |
| 2026-08-15 | Existing malware regression | PASS | Complete 261-assertion container suite and focused rootless-container analysis suite. |
| 2026-08-15 | Synthetic graph SQL | PASS | Official BinDiff-shaped schema, aggregate match counts, bounded sidecar projection, address joins, explicit connection close, and byte-for-byte canonical database immutability. |
| 2026-08-15 | Python and PowerShell lint | PASS | Ruff passed; PowerShell lint passed for 128 files. |
| 2026-08-15 | Publication checks | PASS | Strict MkDocs, Tricky human/JSON capability smoke, and all repository skill validators passed. |
| 2026-08-15 | Approved image rebuild and benign graph run | PASS | Rootless local image `461fc9238c2a713f71e625dc598ce51987ba649322233429a0bcef2316f50419` is compliant with inventory `70A1CEA27FB356483C7D532D6FF32B40F0AA12923D09ECF14D3AE9B38038A82E` and context `3877B3109148B9AFB30B5AFD53EF96666C77D9E1CE41EA93CA9BEB2CD87C40CB`. Repository-owned MSVC fixtures produced two BinExports, canonical `baseline_vs_candidate.BinDiff`, and bounded `binary-analysis.sqlite` in case `binary-diff-20260815-192754641-90e6ec`. The bounded report was complete with structural similarity `0.540343671558936`, confidence `0.973403006423134`, three matched functions, one changed function, zero failures, `Execution=not-run`, and `Verdict=undetermined`. SC-003 through SC-005 passed live; the deterministic synthetic graph-query suite covers SC-006 without opening raw databases on the host. |
