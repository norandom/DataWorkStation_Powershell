---
name: diagnose-http
description: Diagnose HTTP status errors, TLS negotiation and application authentication failures on Windows using existing logs and bounded WebIO ETW evidence. Use when a service opens but an operation fails, including Office Store errors. Route DNS timeouts and packet drops to diagnose-network; an error dialog alone is not a crash.
---

# Diagnose HTTP and authentication

Read `../../../docs/workflows/http-authentication.md` for commands, parameters, provider coverage
and redaction limits. Keep application-specific fixes out of the generic capture tool.

1. Record actual user/SID, executable/build, account type without account identifiers, reproduction
   time and working-machine comparison. Verify which HKCU/profile is being inspected. Check an
   exact build/error combination early for known regressions, distinguishing reports from confirmation.
2. Inspect existing ETL, HTTP summaries, runtime logs and Tricky notes. Add evidence with
   `tricky add <case> -Path <artifact> -Json`; read `tricky inspect <case> -Json`.
3. Identify the missing fact: transport failure, TLS result, HTTP status or application rejection.
   Validate the application HTTP stack; WebIO is useful for supported Windows clients, not universal.
4. If capture is necessary, propose `http-debug-start <name> -ProcessName <process> -Seconds 90 -MaxSizeMiB 32 -Plan`.
   Explain system-wide raw collection, process-filtered output, secret-bearing ETL and automatic stop.
   Start only within explicit user authorization. Do not repeat authorization already given for that scope.
5. Validate coverage before asking for another reproduction. Running status is not event coverage.
   Use `http-debug-summary <name> -Json`; empty, wrong-process or lost-event evidence is inconclusive.
   A test request requires authorization and must exercise the relevant stack and a known endpoint.
6. Stop/remove the collector with `http-debug-stop <name>`, including after automatic expiry.
   Compare the full request sequence before using `-FailuresOnly`. Distinguish a 401 challenge from
   a final failure, routine TLS progress from failure, and process restarts from one long instance.
7. Export only the summary allowlist. Never display raw event Messages, headers, tokens or bodies.
   WebIO HTTP plaintext is not TLS packet decryption. PID selection is an analysis filter, not capture isolation.
8. Record observation, hypothesis, contradiction and next test with `tricky note`; include backup,
   expected result and rollback decision for every authorized change. Successful TLS plus an HTTP
   rejection moves the investigation toward HTTP/authentication. Do not continue TLS/privacy toggles
   or broad cache resets without a new falsifiable reason. Update `tricky report <case> -Json`.
