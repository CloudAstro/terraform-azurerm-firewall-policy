# Azure Firewall Policy Terraform Module

[![Changelog](https://img.shields.io/badge/changelog-release-green.svg)](CHANGELOG.md) [![Notice](https://img.shields.io/badge/notice-copyright-blue.svg)](NOTICE) [![Apache V2 License](https://img.shields.io/badge/license-Apache%20V2-orange.svg)](LICENSE) [![OpenTofu Registry](https://img.shields.io/badge/opentofu-registry-yellow.svg)](https://search.opentofu.org/module/cloudastro/firewall-policy/azurerm/)

This module manages an Azure Firewall with key security features like RBAC, threat intelligence, app and NAT rules, and network access settings.

## Features
- **Application and Network Rules:** Allows filtering of traffic by fully qualified domain names (FQDNs) for HTTP/S and other protocols, as well as by IP addresses, ports, and protocols.
- **Threat Intelligence:** Alerts and denies traffic from/to known malicious IP addresses and domains.
- **DNS Proxy and Custom DNS:** Processes and forwards DNS queries from virtual networks to your desired DNS server, and allows configuration of custom DNS settings.
- **Web Categories:** Allows administrators to filter outbound user access to the internet based on categories (e.g., social networking, search engines, gambling).
- **URL Filtering: Allows administrators to filter outbound access to specific URLs, not just FQDNs.
- **Intrusion Detection and Prevention System (IDPS):** Monitors network activities for malicious activity, logs information about this activity, reports it, and optionally attempts to block it.
- **Transport Layer Security (TLS) Inspection:** Decrypts outbound traffic, processes the data, then encrypts the data and sends it to the destination.

## Example Usage

This example provisions an Azure Firewall with Azure Policy with essential security settings for application rules, NAT rules, and threat intelligence.
