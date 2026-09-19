# Feature Specification: HTTP diagnostics

## User Story

As a workstation operator, I can distinguish HTTP authentication failures from transport failures using bounded captures and credential-safe summaries of existing evidence.

## Requirements

- **REQ-001**: When a capture plan is requested, the system shall report bounded capture parameters without starting a capture.
- **REQ-002**: When HTTP evidence is summarized, the system shall exclude credential values and URL paths from the output.
- **REQ-003**: When request handles or process identifiers are reused, the system shall correlate events with the matching request attempt and process instance.
- **REQ-004**: When evidence lacks target HTTP requests, the system shall report insufficient coverage.
- **REQ-005**: When a Tricky case is reported, the system shall include its structured investigation notes.

## Scope

The focused HTTP skill inspects existing evidence before explicit WebIO ETW capture. Native capture is bounded by time and size. Raw ETL can contain credentials and remains local. Export uses a strict field allowlist; TLS metadata is not decrypted packet payload. Packet capture supports bounded plans and an owned-session stop helper.
