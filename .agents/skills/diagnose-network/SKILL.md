---
name: diagnose-network
description: Diagnose Windows DNS, IPv6, firewall, open-port, endpoint ownership, TCP/UDP, and reachability failures with built-in PktMon evidence. Use for timeouts, refused connections, wrong address-family selection, blocked traffic, or questions about which process owns a port. Avoid for application CPU or non-network crashes.
---

# Diagnose Network

Follow the workstation's DNS → IPv6 → firewall → transport flow.

## Workflow

1. Read `../../../docs/workflows/network-path.md`.
2. Record target hostname/address, direction, protocol, port, time window, and expected path.
3. Inspect current ownership with `ports`, `port <number>`, and `connections`; inspect `firewall-status` without changing policy.
4. Add any existing PktMon folder, ETL, or PCAPNG to the Tricky case and run `tricky inspect <case> -Json`.
5. Query existing PktMon evidence with `pcap-protocols`, `pcap-dns`, `pcap-ipv6`, `pcap-firewall`, `pcap-ports`, and `pcap-failures` as applicable.
6. Correlate DNS answers, chosen address family, connection attempts, resets/timeouts, firewall drops, listener ownership, and timestamps. State gaps.
7. Only if packet evidence is missing, propose `pcap-debug-start <case> -Port <ports>`, a short reproduction, and `pcap-stop <case>`. Capture is explicit and normally elevated.
8. Update the Tricky report with endpoints, protocols, ports, failures, and the smallest remaining test.

Do not install or require Wireshark. PCAPNG is the portable interchange artifact; the compact queries operate on the PktMon ETL.
