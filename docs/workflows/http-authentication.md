# HTTP, TLS and authentication failures

Use application-level HTTP evidence when a service opens but an operation fails, particularly
for HTTP 401/403 responses. Use [packet diagnostics](network-path.md) for DNS failures,
connection timeouts, resets and drops. A process that displays an error has not necessarily crashed.

## Human commands

```powershell
tricky new office-store -Problem 'Office Store add-in installation fails' -Target WINWORD.EXE
# Inspect and add existing evidence before recording more.
http-debug-start office-store -ProcessName WINWORD -Profile HttpAuth -Seconds 90 -MaxSizeMiB 32 -Plan
# After authorizing the displayed capture, run the same command without -Plan.
http-debug-start office-store -ProcessName WINWORD -Profile HttpAuth -Seconds 90 -MaxSizeMiB 32
http-debug-status office-store
# Reproduce once, then stop early or let the native 90-second limit stop recording.
http-debug-stop office-store
http-debug-summary office-store
http-debug-summary office-store -FailuresOnly -Json
# Use the actual CaptureDirectory from Start/Status, for example:
tricky add office-store -Path 'D:\Traces\http-office-store\http-summary.json'
tricky note office-store -NoteType Observation -Message 'Installation returns 401 after successful TLS.'
tricky note office-store -NoteType Hypothesis -Message 'The service rejects this client credential; cause unconfirmed.'
tricky report office-store
```

The standalone entry point works without reloading the profile:

```powershell
pwsh -NoProfile -File .\scripts\Invoke-HttpDiagnostics.ps1 -Action Start -Name office-store -ProcessName WINWORD -WorkingDirectory D:\Traces -Plan -Json
# For an authorized capture, prefix the same command with sudo and omit -Plan.
pwsh -NoProfile -File .\scripts\Invoke-HttpDiagnostics.ps1 -Action Summary -Name office-store -WorkingDirectory D:\Traces -Json
```

| Parameter | Contract |
|---|---|
| `-ProcessName` / `-ProcessId` | Start requires one selector. Name follows observed process starts/restarts; ID selects only the original process instance. Start snapshots current process IDs, start times and versions. |
| `-Profile HttpAuth` | WebIO HTTP/TLS events plus kernel process lifecycle events. WebIO was the useful provider in the Office investigation; WinHTTP-only recording missed the HTTP requests. |
| `-Profile TlsHandshake` | WebIO security keyword plus process lifecycle. HTTP request coverage may be absent by design. Validate on the target Windows/application build. |
| `-Seconds` | 5–600, default 90. Native logman run limit survives terminal/agent exit. |
| `-MaxSizeMiB` | 16–256, default 32; circular ETL. Old events can be overwritten. |
| `-WorkingDirectory` | Trace root; defaults to configured `Paths.Traces`. Each name gets a new `http-<name>` directory. Existing directories are never overwritten. |
| `-Plan` | Start only; displays scope, target snapshot, context and privileges without creating a collector or directory. |
| `-HostName`, `-From`, `-To` | Summary filters. Host is an exact match to the HTTP Host header, including port if present. Time range selects request start times. Transport rows remain process/time-scoped, not host-scoped. |
| `-FailuresOnly` | Shows HTTP 400+ responses and transport error candidates. Also inspect the full summary to see authentication challenges followed by successful retries. |
| `-Json` | Structured output. Default output is readable tables. |

Start, Stop and Status wrappers use sudo explicitly. Summary and Plan do not. Stop removes only
the generated collector and is repeatable after completion. Automatic expiry stops recording;
run Stop afterward to remove the stopped collector. No protection, TLS setting or account cache changes.

## Coverage before conclusions

Status reports whether the collector is running, not whether it captured the failure. After a
bounded validation capture, Summary reports `NoProviderEvents`, `NoTargetEvents`, `NoHttpRequests`
or `RequestsObserved`; `NoMatchingRequests` means requests exist outside the selected host/time window.
A header-only ETL cannot prove the absence of a failure. `LostEvents: null`
means loss information was unavailable. Process lifecycle events establish instance boundaries;
missing lifecycle events, including circular overwrites, limit attribution. Unmapped events and
unmatched responses are counted rather than silently assigned to a target.

Before requesting repeated reproductions, validate the provider against an explicitly authorized
test request through the same HTTP stack if needed. A WinHTTP probe does not validate Chromium,
libcurl or every application stack. Do not invent service hostnames. This command does not send probes.

Inspect the existing artifact first; if it is insufficient, choose the next provider based on the
application's HTTP implementation. Do not enable every network tracer or attach a debugger by default.

## Plaintext visibility and redaction

WebIO logs HTTP inside the application, before encryption and after decryption. This is **not
PCAP decryption**. PktMon records packets; encrypted packet payloads remain encrypted.
See [Microsoft's WinHTTP tracing guidance](https://learn.microsoft.com/en-us/windows/win32/winhttp/collect-traces).

The ETL providers capture system-wide, including other applications. Process selection filters
the exported summary, not collection. Both profiles can record secrets in raw ETLs. Keep originals
local with appropriately restricted filesystem permissions; share the allowlisted summary instead.

The summary exports only destination host, method, response code, timing, process instance and
credential/cookie presence. **All URL paths, queries, header values and bodies are omitted**;
there is no switch to print credentials. Do not dump raw event Messages to a terminal or conversation.
Bearer, Basic, `t=...` and unknown Authorization formats all receive the same treatment.

TLS progress (`SEC_I_CONTINUE_NEEDED`, incomplete records) and pending I/O are not final failures.
A 401 is an observed response: correlate later responses and the application outcome before
calling it the final authentication failure. Successful TLS followed by an HTTP error redirects
the investigation toward application/authentication behavior; it does not justify weakening TLS.

## Agent workflow and experimental changes

Use the focused `diagnose-http` skill after the human commands above are available. Record the
actual user/SID, process/build, comparison with a working machine and exact reproduction window.
Search an exact build/error combination early when it could identify a regression.

Use `tricky note` for Observation, Hypothesis, Contradiction, Change, Result and NextStep. For each
change, record original value, backup path, predicted effect, retry result and rollback decision.
One variable per test. A changed credential that still fails contradicts simple stale-token reuse;
it does not prove a specific product defect. Do not repeat ineffective resets.
