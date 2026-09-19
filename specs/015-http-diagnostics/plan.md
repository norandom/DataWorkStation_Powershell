# Implementation Plan: HTTP diagnostics

Use scripts/Invoke-HttpDiagnostics.ps1 for the human command, scripts/HttpDiagnostics.ps1 for summary parsing, profile wrappers for convenience, and the http-authentication route for skills. Existing ETL fixtures validate correlation, redaction, coverage and Tricky notes without live capture.

| Requirement | Verification |
|---|---|
| REQ-001 | tests/Test-HttpDiagnostics.ps1#All |
| REQ-002 | tests/Test-HttpDiagnostics.ps1#All |
| REQ-003 | tests/Test-HttpDiagnostics.ps1#All |
| REQ-004 | tests/Test-HttpDiagnostics.ps1#All |
| REQ-005 | tests/Test-HttpDiagnostics.ps1#All |
