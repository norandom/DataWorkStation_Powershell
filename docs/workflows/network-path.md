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

The managed firewall allows inbound TCP 22 for SSH, 3389 for RDP, and 8080/8081 for HTTP/application services on physical networks. The Tailscale interface is unrestricted, direct Tailscale transport uses UDP 41641, and other inbound TCP/UDP ports on physical interfaces are blocked. Verify the exact current rules with `firewall-status`.
