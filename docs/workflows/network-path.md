# Network path

The default network triage order is DNS, IPv6, then firewall and transport ownership.

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

The capture produces ETL and PCAPNG without installing Wireshark. The query commands answer the basic questions: which endpoints, protocols, ports, and failures occurred. They operate on the PktMon ETL, so PCAPNG is primarily the portable interchange artifact.

The managed firewall allows private-profile inbound traffic from local subnets and explicit external access only to SSH 22, RDP 3389, and application ports 8080/8081. Verify the exact current rules with `firewall-status`.
