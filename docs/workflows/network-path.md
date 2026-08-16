# Network path

Check DNS and IPv6 first, followed by the firewall and the process that owns the transport endpoint.

```powershell
ports
port 8080
connections
firewall-status
```

If endpoint state is insufficient, record a focused in-box PktMon capture:

```powershell
pcap-debug-start api -Port 8080,8081
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

The managed firewall defaults inbound traffic to Block and allows TCP 22 for SSH, 3389 for RDP,
8080/8081 for HTTP/application services, and UDP 41641 for direct Tailscale transport. The Tailscale
interface is unrestricted. Listener notifications and expert-created local application rules are
honored on Domain, Private, and Public profiles; traffic with no matching rule remains blocked.
Verify the exact current profile and rule state with `firewall-status`.
