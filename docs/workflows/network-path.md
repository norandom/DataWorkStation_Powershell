# Network path

Check DNS and IPv6 first, followed by the firewall and the process that owns the transport endpoint.
For HTTP status, TLS negotiation or authentication failures, use the
[HTTP workflow](http-authentication.md) to inspect application-layer events.

```powershell
ports
port 8080
connections
firewall-status
```

If endpoint state is insufficient, record a focused in-box PktMon capture:

```powershell
pcap-debug-start api -Port 8080,8081 -Seconds 90 -MaxSizeMiB 64 -Plan
# After authorizing capture, omit -Plan.
pcap-debug-start api -Port 8080,8081 -Seconds 90 -MaxSizeMiB 64
# reproduce
pcap-stop api
pcap-protocols ./pcap-api
pcap-dns ./pcap-api
pcap-ipv6 ./pcap-api
pcap-firewall ./pcap-api
pcap-failures ./pcap-api
```

The capture produces ETL and PCAPNG without installing Wireshark. The query commands identify the
endpoints, protocols, ports, and failures in the PktMon ETL. PCAPNG is the portable interchange
artifact.

`-Seconds` is 5–600 (default 90); a hidden, detached helper stops/converts the capture at the deadline.
`-MaxSizeMiB` is 16–1024 (default 64). `-PacketSizeBytes` defaults to 256; zero records full packets,
which can include sensitive payloads. `-Json` is available on capture start/stop/status/counters.
`-Plan` performs no privileged capture action. Stop is repeatable after completion and conversion
can be retried after a conversion failure. The wrapper refuses existing/unrecognized filters and
active sessions rather than replacing them. Ownership checks currently recognize English PktMon
status/filter output and fail closed on other formats. If automatic cleanup fails, inspect
`autostop-error.txt` and current PktMon state before retrying; never stop an unrelated capture.

The managed firewall defaults inbound traffic to Block and allows TCP 22 for SSH, 3389 for RDP,
8080/8081 for HTTP/application services, and UDP 41641 for direct Tailscale transport. The Tailscale
interface is unrestricted. Listener notifications and expert-created local application rules are
honored on Domain, Private, and Public profiles; traffic with no matching rule remains blocked.
Verify the exact current profile and rule state with `firewall-status`.
