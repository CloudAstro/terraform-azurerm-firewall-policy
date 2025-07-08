<!-- BEGINNING OF PRE-COMMIT-OPENTOFU DOCS HOOK -->
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

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-afwp-example"
  location = "germanywestcentral"
}

module "vnet" {
  source = "CloudAstro/virtual-network/azurerm"

  name                = "vnet-example"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

module "snet" {
  source = "CloudAstro/subnet/azurerm"

  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = module.vnet.virtual_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_user_assigned_identity" "this" {
  location            = azurerm_resource_group.rg.location
  name                = "user-managed-identity"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_ip_group" "source_ip_group" {
  name                = "ipg-source-health-check"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_ip_group" "destination_ip_group" {
  name                = "ipg-destination-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

module "public_ip" {
  source = "CloudAstro/public-ip/azurerm"

  name                = "public-ip-fwp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  zones               = ["1", "2", "3"]
}

module "firewall" {
  source = "CloudAstro/firewall/azurerm"

  name                = "firewall-example"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = module.firewall_policy.firewall_policy.id

  ip_configuration = {
    ip1 = {
      name                 = "configuration1"
      subnet_id            = module.snet.subnet.id
      public_ip_address_id = module.public_ip.publicip.id
    }
  }
}

module "firewall_policy" {
  source = "../.."

  location                          = azurerm_resource_group.rg.location
  name                              = "my-firewall-policy"
  resource_group_name               = azurerm_resource_group.rg.name
  base_policy_id                    = null
  private_ip_ranges                 = ["10.0.0.0/8", "192.168.1.0/24", "100.64.0.0/10"]
  auto_learn_private_ranges_enabled = true
  sku                               = "Premium"
  threat_intelligence_mode          = "Alert"
  sql_redirect_allowed              = false

  tags = {
    environment = "dev"
    owner       = "team-network"
  }

  dns = {
    proxy_enabled = false
    servers       = ["8.8.8.8", "1.1.1.1"]
  }

  identity = {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  intrusion_detection = {
    mode           = "Alert"
    private_ranges = ["10.0.0.0/8"]
    signature_overrides = [
      {
        id    = "200001"
        state = "Deny"
      }
    ]

    traffic_bypass = [
      {
        name                  = "bypass-example"
        protocol              = "TCP"
        description           = "Allow bypass for health checks"
        destination_ip_groups = [azurerm_ip_group.destination_ip_group.id]
        destination_ports     = ["80", "443"]
        source_ip_groups      = [azurerm_ip_group.source_ip_group.id]
      }
    ]
  }

  threat_intelligence_allowlist = {
    fqdns        = ["example.com"]
    ip_addresses = ["10.0.0.0/16", "192.168.1.25", ]
  }

  explicit_proxy = {
    enabled         = true
    http_port       = 3128
    https_port      = 3129
    enable_pac_file = false
    pac_file_port   = 8080
  }

  rule_collection_group = {
    rule1 = {
      name     = "example-rule-collection-group"
      priority = 100

      application_rule_collections = {
        application-access = {
          name     = "application-access"
          action   = "Allow"
          priority = 100

          rules = [
            {
              name                  = "allow-full-feature-access"
              description           = "Demonstrates usage of all supported fields in application rule"
              source_ip_groups      = [azurerm_ip_group.source_ip_group.id]
              destination_urls      = ["dev.azure.com", "login.microsoftonline.com"]
              destination_fqdn_tags = ["AzureActiveDirectory", "WindowsUpdate"]
              terminate_tls         = true
              web_categories        = ["Finance", "SocialNetworking"]

              protocols = [
                {
                  type = "Http"
                  port = 80
                },
                {
                  type = "Https"
                  port = 443
                }
              ]

              http_headers = [
                {
                  name  = "X-Environment"
                  value = "Production"
                },
                {
                  name  = "X-Custom-Header"
                  value = "FirewallPolicyDemo"
                }
              ]
            }
          ]
        }
      }

      nat_rule_collections = {
        nat-rule-collection-1 = {
          name     = "nat-rule-collection"
          priority = 300
          action   = "Dnat"

          rules = [
            {
              name                = "dnat-ssh"
              description         = "NAT rule using translated IP address"
              protocols           = ["TCP", "UDP"]
              source_ip_groups    = [azurerm_ip_group.source_ip_group.id]
              destination_address = module.public_ip.publicip.ip_address
              destination_ports   = ["3389"]
              translated_address  = "10.0.1.4"
              translated_port     = "3389"
            },
            {
              name                = "nat-rule-fqdn-translation"
              description         = "NAT rule using translated FQDN"
              protocols           = ["TCP"]
              source_ip_groups    = [azurerm_ip_group.source_ip_group.id]
              destination_address = module.public_ip.publicip.ip_address
              destination_ports   = ["443"]
              translated_fqdn     = "internal-app.contoso.com"
              translated_port     = "443"
            }
          ]
        }
      }

      network_rule_collections = {
        network-collection-1 = {
          name     = "network-rule-collection"
          priority = 200
          action   = "Allow"

          rules = [
            {
              name                  = "network-rule-complete-1"
              description           = "Allow TCP and UDP traffic to specific IPs and ports"
              protocols             = ["TCP", "UDP"]
              source_ip_groups      = [azurerm_ip_group.source_ip_group.id]
              destination_ports     = ["443", "80", "22"]
              destination_ip_groups = [azurerm_ip_group.destination_ip_group.id]
            },
            {
              name                  = "network-rule-complete-2"
              description           = "Allow ICMP traffic with minimal source"
              protocols             = ["ICMP"]
              source_addresses      = ["172.16.0.0/16"]
              destination_ports     = ["*"]
              destination_addresses = ["*"]
            },
            {
              name                  = "network-rule-complete-3"
              description           = "Allow all protocols using service tags"
              protocols             = ["Any"]
              source_ip_groups      = [azurerm_ip_group.source_ip_group.id]
              destination_ports     = ["1433"]
              destination_addresses = ["Sql.EastUS"]
            }
          ]
        }
      }
    }
  }
}
```
<!-- markdownlint-disable MD033 -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_firewall_policy.firewall_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy) | resource |
| [azurerm_firewall_policy_rule_collection_group.rule_collection_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group) | resource |

<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | * `location` - (Required) The Azure Region where the Firewall Policy should exist. Changing this forces a new Firewall Policy to be created.<br/><br/>  Example Input:<pre>location = "germanywestcentral"</pre> | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | * `name` - (Required) The name which should be used for this Firewall Policy. Changing this forces a new Firewall Policy to be created.<br/><br/>  Example Input:<pre>name = "azure-firewall-policy"</pre> | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | * `resource_group_name` - (Required) The name of the Resource Group where the Firewall Policy should exist. Changing this forces a new Firewall Policy to be created.<br/><br/>  Example Input:<pre>resource_group_name = "rg-azure-firewall"</pre> | `string` | n/a | yes |
| <a name="input_auto_learn_private_ranges_enabled"></a> [auto\_learn\_private\_ranges\_enabled](#input\_auto\_learn\_private\_ranges\_enabled) | * `auto_learn_private_ranges_enabled` - (Optional) Whether enable auto learn private ip range.<br/><br/>  Example Input:<pre>auto_learn_private_ranges_enabled = false</pre> | `bool` | `false` | no |
| <a name="input_base_policy_id"></a> [base\_policy\_id](#input\_base\_policy\_id) | * `base_policy_id` - (Optional) The ID of the base Firewall Policy.<br/><br/>  Example Input:<pre>base_policy_id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.Network/firewallPolicies/<base_policy_name>"</pre> | `string` | `null` | no |
| <a name="input_dns"></a> [dns](#input\_dns) | * `dns` - (Optional) A `dns` block as defined below.<br/>   * `proxy_enabled` - (Optional) Whether to enable DNS proxy on Firewalls attached to this Firewall Policy? Defaults to `false`.<br/>   * `servers` - (Optional) A list of custom DNS servers' IP addresses.<br/><br/>  Example Input:<pre>dns = {<br/>    proxy_enabled = false<br/>    servers       = ["8.8.8.8", "8.8.4.4"]<br/>  }</pre> | <pre>object({<br/>    proxy_enabled = optional(bool, false)<br/>    servers       = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_explicit_proxy"></a> [explicit\_proxy](#input\_explicit\_proxy) | * `explicit_proxy` - (Optional) A `explicit_proxy` block as defined below.<br/>    * `enabled` - (Optional) Whether the explicit proxy is enabled for this Firewall Policy.<br/>    * `http_port` - (Optional) The port number for explicit http protocol.<br/>    * `https_port` - (Optional) The port number for explicit proxy https protocol.<br/>    * `enable_pac_file` - (Optional) Whether the pac file port and url need to be provided.<br/>    * `pac_file_port` - (Optional) Specifies a port number for firewall to serve PAC file.<br/>    * `pac_file` - (Optional) Specifies a SAS URL for PAC file.<br/><br/>  Example Input:<pre>explicit_proxy = {<br/>    enabled         = true<br/>    http_port       = 8080<br/>    https_port      = 8443<br/>    enable_pac_file = true<br/>    pac_file_port   = 9000<br/>    pac_file        = "https://example.blob.core.windows.net/pacfiles/firewall-config.pac?sas_token_here"<br/>  }</pre> | <pre>object({<br/>    enabled         = optional(bool)<br/>    http_port       = optional(number)<br/>    https_port      = optional(number)<br/>    enable_pac_file = optional(bool)<br/>    pac_file_port   = optional(number)<br/>    pac_file        = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_identity"></a> [identity](#input\_identity) | * `identity` - (Optional) An `identity` block as defined below:<br/>   * `type` - (Required) Specifies the type of Managed Service Identity that should be configured on this Firewall Policy. Only possible value is `UserAssigned`.<br/>   * `identity_ids` - (Optional) Specifies a list of User Assigned Managed Identity IDs to be assigned to this Firewall Policy.<br/><br/>  Example Input:<pre>identity = {<br/>    type         = "UserAssigned"<br/>    identity_ids = [<br/>      "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{identity-name}"<br/>    ]<br/>  }</pre> | <pre>object({<br/>    type         = string<br/>    identity_ids = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_insights"></a> [insights](#input\_insights) | * `insights` - (Optional) An `insights` block as defined below.<br/>  * `enabled` - (Required) Whether the insights functionality is enabled for this Firewall Policy.<br/>  * `default_log_analytics_workspace_id` - (Required) The ID of the default Log Analytics Workspace that the Firewalls associated with this Firewall Policy will send their logs to, when there is no location matches in the `log_analytics_workspace`.<br/>  * `retention_in_days` - (Optional) The log retention period in days.<br/>  * `log_analytics_workspace` - (Optional) A list of `log_analytics_workspace` block as defined below.<br/>    * `id` - (Required) The ID of the Log Analytics Workspace that the Firewalls associated with this Firewall Policy will send their logs to when their locations match the `firewall_location`.<br/>    * `firewall_location` - (Required) The location of the Firewalls, that when matches this Log Analytics Workspace will be used to consume their logs.<br/><br/>  Example Input:<pre>insights = {<br/>    enabled                            = true<br/>    default_log_analytics_workspace_id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.OperationalInsights/workspaces/default-log-analytics"<br/>    retention_in_days                  = 90<br/>    log_analytics_workspace = [<br/>      {<br/>        id                = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.OperationalInsights/workspaces/eastus-log-analytics"<br/>        firewall_location = "eastus"<br/>      }<br/>    ]<br/>  }</pre> | <pre>object({<br/>    enabled                            = bool<br/>    default_log_analytics_workspace_id = string<br/>    retention_in_days                  = optional(number, 30)<br/>    log_analytics_workspace = optional(list(object({<br/>      id                = string<br/>      firewall_location = string<br/>    })))<br/>  })</pre> | `null` | no |
| <a name="input_intrusion_detection"></a> [intrusion\_detection](#input\_intrusion\_detection) | * `intrusion_detection` - (Optional) A `intrusion_detection` block as defined below.<br/>    * `mode` - (Optional) In which mode you want to run intrusion detection: `Off`, `Alert` or `Deny`.<br/>    * `signature_overrides` - (Optional) One or more `signature_overrides` blocks as defined below.<br/>      * `id` - (Optional) 12-digit number (id) which identifies your signature.<br/>      * `state` - (Optional) state can be any of `Off`, `Alert` or `Deny`.<br/>    * `traffic_bypass` - (Optional) One or more `traffic_bypass` blocks as defined below.<br/>      * `name` - (Required) The name which should be used for this bypass traffic setting.<br/>      * `protocol` - (Required) The protocols any of `ANY`, `TCP`, `ICMP`, `UDP` that shall be bypassed by intrusion detection.<br/>      * `description` - (Optional) The description for this bypass traffic setting.<br/>      * `destination_addresses` - (Optional) Specifies a list of destination IP addresses that shall be bypassed by intrusion detection.<br/>      * `destination_ip_groups` - (Optional) Specifies a list of destination IP groups that shall be bypassed by intrusion detection.<br/>      * `destination_ports` - (Optional) Specifies a list of destination IP ports that shall be bypassed by intrusion detection.<br/>      * `source_addresses` - (Optional) Specifies a list of source addresses that shall be bypassed by intrusion detection.<br/>      * `source_ip_groups` - (Optional) Specifies a list of source IP groups that shall be bypassed by intrusion detection.<br/>    * `private_ranges` - (Optional) A list of Private IP address ranges to identify traffic direction. By default, only ranges defined by IANA RFC 1918 are considered private IP addresses.<br/><br/>  Example Input:<pre>intrusion_detection = {<br/>    mode                = "Alert"<br/>    signature_overrides = [<br/>      {<br/>       id    = "123456789012"<br/>       state = "Deny" <br/>      }<br/>    ]<br/>    traffic_bypass = [<br/>      {<br/>        name                  = "example-bypass"<br/>        protocol              = "TCP"<br/>        description           = "Bypass for specific traffic"<br/>        destination_addresses = ["10.1.0.0/16", "203.0.113.5"]<br/>        destination_ip_groups = []<br/>        destination_ports     = ["80", "443"]<br/>        source_addresses      = ["192.168.1.0/24"]<br/>        source_ip_groups      = []<br/>      }<br/>    ]<br/>    private_ranges = ["10.0.0.0/24", "192.168.1.0/24"]<br/>  }</pre> | <pre>object({<br/>    mode = optional(string, "Off")<br/>    signature_overrides = optional(list(object({<br/>      id    = optional(string)<br/>      state = optional(string, "Alert")<br/>    })))<br/>    traffic_bypass = optional(list(object({<br/>      name                  = string<br/>      protocol              = string<br/>      description           = optional(string)<br/>      destination_addresses = optional(list(string))<br/>      destination_ip_groups = optional(list(string))<br/>      destination_ports     = optional(list(string))<br/>      source_addresses      = optional(list(string))<br/>      source_ip_groups      = optional(list(string))<br/>    })))<br/>    private_ranges = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_private_ip_ranges"></a> [private\_ip\_ranges](#input\_private\_ip\_ranges) | * `private_ip_ranges` - (Optional) A list of private IP ranges to which traffic will not be SNAT.<br/><br/>  Example Input:<pre>private_ip_ranges = ["10.0.0.0/24", "192.168.1.0/24"]</pre> | `list(string)` | `null` | no |
| <a name="input_rule_collection_group"></a> [rule\_collection\_group](#input\_rule\_collection\_group) | * `rule_collection_group` - (Optional) Manages a Firewall Policy Rule Collection Group.<br/>  * `name` - (Required) The name which should be used for this Firewall Policy Rule Collection Group. Changing this forces a new Firewall Policy Rule Collection Group to be created.<br/>  * `firewall_policy_id` - (Required) The ID of the Firewall Policy where the Firewall Policy Rule Collection Group should exist. Changing this forces a new Firewall Policy Rule Collection Group to be created.<br/>  * `priority` - (Required) The priority of the Firewall Policy Rule Collection Group. The range is 100-65000.<br/>  * `application_rule_collection` - (Optional) One or more `application_rule_collection` blocks as defined below.<br/>    * `name` - (Required) The name which should be used for this application rule collection.<br/>    * `action` - (Required) The action to take for the application rules in this collection. Possible values are `Allow` and `Deny`.<br/>    * `priority` - (Required) The priority of the application rule collection. The range is `100` - `65000`.<br/>    * `rule` - (Required) One or more `application_rule` blocks as defined below.<br/>      * `name` - (Required) The name which should be used for this rule.<br/>      * `description` - (Optional) The description which should be used for this rule.<br/>      * `source_addresses` - (Optional) Specifies a list of source IP addresses (including CIDR, IP range and `*`).<br/>      * `source_ip_groups` - (Optional) Specifies a list of source IP groups.<br/>      * `destination_addresses` - (Optional) Specifies a list of destination IP addresses (including CIDR, IP range and `*`).<br/>      * `destination_urls` - (Optional) Specifies a list of destination URLs for which policy should hold. Needs Premium SKU for Firewall Policy. Conflicts with `destination_fqdns`.<br/>      * `destination_fqdns` - (Optional) Specifies a list of destination FQDNs. Conflicts with `destination_urls`.<br/>      * `destination_fqdn_tags` - (Optional) Specifies a list of destination FQDN tags.<br/>      * `terminate_tls` - (Optional) Boolean specifying if TLS shall be terminated (true) or not (false). Must be `true` when using `destination_urls`. Needs Premium SKU for Firewall Policy.<br/>      * `web_categories` - (Optional) Specifies a list of web categories to which access is denied or allowed depending on the value of `action` above. Needs Premium SKU for Firewall Policy.<br/>      * `protocols` - (Optional) One or more `protocols` blocks as defined below.<br/>        * `type` - (Required) Protocol type. Possible values are `Http` and `Https`.<br/>        * `port` - (Required) Port number of the protocol. Range is 0-64000.<br/>      * `http_headers` - (Optional) Specifies a list of HTTP/HTTPS headers to insert. One or more `http_headers` blocks as defined below.<br/>        * `name` - (Required) Specifies the name of the header.<br/>        * `value` - (Required) Specifies the value of the value.<br/>  * `nat_rule_collection` - (Optional) One or more `nat_rule_collection` blocks as defined below.<br/>    * `name` - (Required) The name which should be used for this NAT rule collection.<br/>    * `action` - (Required) The action to take for the NAT rules in this collection. Currently, the only possible value is `Dnat`.<br/>    * `priority` - (Required) The priority of the NAT rule collection. The range is `100` - `65000`.<br/>    * `rule` - (Required) A `nat_rule` block as defined below.<br/>      * `name` - (Required) The name which should be used for this rule.<br/>      * `description` - (Optional) The description which should be used for this rule.<br/>      * `protocols` - (Required) Specifies a list of network protocols this rule applies to. Possible values are `TCP`, `UDP`.<br/>      * `source_addresses` - (Optional) Specifies a list of source IP addresses (including CIDR, IP range and `*`).<br/>      * `source_ip_groups` - (Optional) Specifies a list of source IP groups.<br/>      * `destination_address` - (Optional) The destination IP address (including CIDR).<br/>      * `destination_ports` - (Optional) Specifies a list of destination ports. Only one destination port is supported in a NAT rule.<br/>      * `translated_address` - (Optional) Specifies the translated address.<br/>      * `translated_fqdn` - (Optional) Specifies the translated FQDN.<br/>   <br/>       ~> **NOTE:** Exactly one of `translated_address` and `translated_fqdn` should be set.<br/>      * `translated_port` - (Required) Specifies the translated port.<br/>  * `network_rule_collection` - (Optional) One or more `network_rule_collection` blocks as defined below.<br/>    * `name` - (Required) The name which should be used for this network rule collection.<br/>    * `action` - (Required) The action to take for the network rules in this collection. Possible values are `Allow` and `Deny`.<br/>    * `priority` - (Required) The priority of the network rule collection. The range is `100` - `65000`.<br/>    * `rule` - (Required) One or more `network_rule` blocks as defined below.<br/>      * `name` - (Required) The name which should be used for this rule.<br/>      * `description` - (Optional) The description which should be used for this rule.<br/>      * `protocols` - (Required) Specifies a list of network protocols this rule applies to. Possible values are `Any`, `TCP`, `UDP`, `ICMP`.<br/>      * `destination_ports` - (Required) Specifies a list of destination ports.<br/>      * `source_addresses` - (Optional) Specifies a list of source IP addresses (including CIDR, IP range and `*`).<br/>      * `source_ip_groups` - (Optional) Specifies a list of source IP groups.<br/>      * `destination_addresses` - (Optional) Specifies a list of destination IP addresses (including CIDR, IP range and `*`) or Service Tags.<br/>      * `destination_ip_groups` - (Optional) Specifies a list of destination IP groups.<br/>      * `destination_fqdns` - (Optional) Specifies a list of destination FQDNs.<br/><br/>  Example Input:<pre>rule_collection_group = {<br/>   rule1 = {<br/>    name                = "example-rule-group"<br/>    firewall_policy_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Network/firewallPolicies/policy-example"<br/>    priority            = 100<br/><br/>    application_rule_collections = [<br/>      {<br/>        name     = "example-app-rule-collection"<br/>        action   = "Allow"<br/>        priority = 200<br/>        rule = [<br/>          {<br/>            name              = "Allow-to-Microsoft"<br/>            description       = "Allow traffic to Microsoft.com"<br/>            source_addresses  = ["10.0.0.0/24"]<br/>            destination_fqdns = ["*.microsoft.com"]<br/>            protocols = [<br/>              {<br/>                type = "Https"<br/>                port = 443<br/>              }<br/>            ]<br/>            http_headers = [<br/>              {<br/>               name  = "X-Custom-Header"<br/>               value = "ExampleValue"<br/>              }<br/>            ]<br/>          }<br/>        ]<br/>      }<br/>    ]<br/>    nat_rule_collections = [<br/>      {<br/>        name        = "example-nat-rule-collection"<br/>        action      = "Dnat"<br/>        priority    = 300<br/>        rule = [<br/>          {<br/>            name                = "nat"<br/>            protocols           = ["TCP", "UDP"]<br/>            source_addresses    = ["10.0.0.1", "10.0.0.2"]<br/>            destination_address = "10.2.0.4"<br/>            destination_ports   = ["80"]<br/>            translated_address  = "192.168.0.1"<br/>            translated_port     = "8080"<br/>          }<br/>        ]<br/>      }<br/>    ]<br/>    network_rule_collections = [<br/>      {<br/>        name     = "example-network-rule-collection"<br/>        action   = "Allow"<br/>        priority = 400<br/>        rule = [<br/>          {<br/>            name                  = "Outbound-To-Internet"<br/>            description           = "Allow traffic outbound to the Internet"<br/>            protocols             = ["TCP"]<br/>            source_addresses      = ["10.0.0.0/24"]<br/>            destination_addresses = ["0.0.0.0/0"]<br/>            destination_ports     = ["443"]<br/>          }<br/>        ]<br/>      }<br/>    ]<br/>   }<br/>  }</pre> | <pre>map(object({<br/>    name     = string<br/>    priority = number<br/>    application_rule_collections = optional(map(object({<br/>      name     = string<br/>      action   = string<br/>      priority = number<br/>      rules = list(object({<br/>        name                  = string<br/>        description           = optional(string)<br/>        source_addresses      = optional(list(string))<br/>        source_ip_groups      = optional(list(string))<br/>        destination_addresses = optional(list(string))<br/>        destination_urls      = optional(list(string))<br/>        destination_fqdns     = optional(list(string))<br/>        destination_fqdn_tags = optional(list(string))<br/>        terminate_tls         = optional(bool, false)<br/>        web_categories        = optional(list(string))<br/>        protocols = optional(list(object({<br/>          type = string<br/>          port = number<br/>        })))<br/>        http_headers = optional(list(object({<br/>          name  = string<br/>          value = string<br/>        })))<br/>      }))<br/>    })))<br/>    network_rule_collections = optional(map(object({<br/>      name     = string<br/>      action   = string<br/>      priority = number<br/>      rules = list(object({<br/>        name                  = string<br/>        description           = optional(string)<br/>        protocols             = list(string)<br/>        destination_ports     = list(string)<br/>        source_addresses      = optional(list(string))<br/>        source_ip_groups      = optional(list(string))<br/>        destination_addresses = optional(list(string))<br/>        destination_ip_groups = optional(list(string))<br/>        destination_fqdns     = optional(list(string))<br/>      }))<br/>    })))<br/>    nat_rule_collections = optional(map(object({<br/>      name     = string<br/>      priority = number<br/>      action   = string<br/>      rules = list(object({<br/>        name                = string<br/>        description         = optional(string)<br/>        protocols           = list(string)<br/>        source_addresses    = optional(list(string))<br/>        source_ip_groups    = optional(list(string))<br/>        destination_address = optional(string)<br/>        destination_ports   = optional(list(string))<br/>        translated_address  = optional(string)<br/>        translated_fqdn     = optional(string)<br/>        translated_port     = string<br/>      }))<br/>    })))<br/>  }))</pre> | `null` | no |
| <a name="input_sku"></a> [sku](#input\_sku) | * `sku` - (Optional) The SKU Tier of the Firewall Policy. Possible values are `Standard`, `Premium` and `Basic`. Defaults to `Standard`. Changing this forces a new Firewall Policy to be created.<br/><br/>  Example Input:<pre>sku = "Standard"</pre> | `string` | `"Standard"` | no |
| <a name="input_sql_redirect_allowed"></a> [sql\_redirect\_allowed](#input\_sql\_redirect\_allowed) | * `sql_redirect_allowed` - (Optional) Whether SQL Redirect traffic filtering is allowed. Enabling this flag requires no rule using ports between `11000`-`11999`.<br/> <br/>  Example Input:<pre>sql_redirect_allowed = false</pre> | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | * `tags` - (Optional) A mapping of tags to assign to the resource.<br/><br/>  Example Input:<pre>tags = {<br/>    env     = test<br/>    region  = gwc<br/>  }</pre> | `map(string)` | `null` | no |
| <a name="input_threat_intelligence_allowlist"></a> [threat\_intelligence\_allowlist](#input\_threat\_intelligence\_allowlist) | * `threat_intelligence_allowlist` - (Optional) A `threat_intelligence_allowlist` block as defined below.<br/>   * `fqdns` - (Optional) A list of FQDNs that will be skipped for threat detection.<br/>   * `ip_addresses` - (Optional) A list of IP addresses or CIDR ranges that will be skipped for threat detection.<br/><br/>  Example Input:<pre>threat_intelligence_allowlist = {<br/>    fqdns        = ["example.com", "trusted.example.com"]<br/>    ip_addresses = ["192.168.1.1", "10.0.0.0/24"]<br/>  }</pre> | <pre>object({<br/>    fqdns        = optional(list(string))<br/>    ip_addresses = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_threat_intelligence_mode"></a> [threat\_intelligence\_mode](#input\_threat\_intelligence\_mode) | * `threat_intelligence_mode` - (Optional) The operation mode for Threat Intelligence. Possible values are `Alert`, `Deny` and `Off`. Defaults to `Alert`.<br/><br/>  Example Input:<pre>threat_intelligence_mode = "Alert"</pre> | `string` | `"Alert"` | no |
| <a name="input_tls_certificate"></a> [tls\_certificate](#input\_tls\_certificate) | * `tls_certificate` - (Optional) A `tls_certificate` block as defined below.<br/>   * `key_vault_secret_id` - (Required) The ID of the Key Vault, where the secret or certificate is stored.<br/>   * `name` - (Required) The name of the certificate.<br/><br/>  Example Input:<pre>tls_certificate = {<br/>    key_vault_secret_id = "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.KeyVault/vaults/{vault-name}/secrets/{certificate-name}"<br/>    name                = "example-certificate"<br/>  }</pre> | <pre>object({<br/>    key_vault_secret_id = string<br/>    name                = string<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_firewall_policy"></a> [firewall\_policy](#output\_firewall\_policy) | * `location` - (Required) The Azure Region where the Firewall Policy should exist. Changing this forces a new Firewall Policy to be created.<br/> * `name` - (Required) The name which should be used for this Firewall Policy. Changing this forces a new Firewall Policy to be created.<br/> * `resource_group_name` - (Required) The name of the Resource Group where the Firewall Policy should exist. Changing this forces a new Firewall Policy to be created.<br/> * `base_policy_id` - (Optional) The ID of the base Firewall Policy.<br/> * `dns` - (Optional) A `dns` block as defined below.<br/>  * `proxy_enabled` - (Optional) Whether to enable DNS proxy on Firewalls attached to this Firewall Policy? Defaults to `false`.<br/>  * `servers` - (Optional) A list of custom DNS servers' IP addresses.<br/> * `identity` - (Optional) An `identity` block as defined below.<br/>  * `type` - (Required) Specifies the type of Managed Service Identity that should be configured on this Firewall Policy. Only possible value is `UserAssigned`.<br/>  * `identity_ids` - (Optional) Specifies a list of User Assigned Managed Identity IDs to be assigned to this Firewall Policy.<br/> * `insights` - (Optional) An `insights` block as defined below.<br/>  * `enabled` - (Required) Whether the insights functionality is enabled for this Firewall Policy.<br/>  * `default_log_analytics_workspace_id` - (Required) The ID of the default Log Analytics Workspace that the Firewalls associated with this Firewall Policy will send their logs to, when there is no location matches in the `log_analytics_workspace`.<br/>  * `retention_in_days` - (Optional) The log retention period in days.<br/>  * `log_analytics_workspace` - (Optional) A list of `log_analytics_workspace` block as defined below.<br/>   * `id` - (Required) The ID of the Log Analytics Workspace that the Firewalls associated with this Firewall Policy will send their logs to when their locations match the `firewall_location`.<br/>   * `firewall_location` - (Required) The location of the Firewalls, that when matches this Log Analytics Workspace will be used to consume their logs.<br/> * `intrusion_detection` - (Optional) A `intrusion_detection` block as defined below.<br/>  * `mode` - (Optional) In which mode you want to run intrusion detection: `Off`, `Alert` or `Deny`.<br/>  * `signature_overrides` - (Optional) One or more `signature_overrides` blocks as defined below.<br/>   * `id` - (Optional) 12-digit number (id) which identifies your signature.<br/>   * `state` - (Optional) state can be any of `Off`, `Alert` or `Deny`.<br/>  * `traffic_bypass` - (Optional) One or more `traffic_bypass` blocks as defined below.<br/>    * `name` - (Required) The name which should be used for this bypass traffic setting.<br/>    * `protocol` - (Required) The protocols any of `ANY`, `TCP`, `ICMP`, `UDP` that shall be bypassed by intrusion detection.<br/>    * `description` - (Optional) The description for this bypass traffic setting.<br/>    * `destination_addresses` - (Optional) Specifies a list of destination IP addresses that shall be bypassed by intrusion detection.<br/>    * `destination_ip_groups` - (Optional) Specifies a list of destination IP groups that shall be bypassed by intrusion detection.<br/>    * `destination_ports` - (Optional) Specifies a list of destination IP ports that shall be bypassed by intrusion detection.<br/>    * `source_addresses` - (Optional) Specifies a list of source addresses that shall be bypassed by intrusion detection.<br/>    * `source_ip_groups` - (Optional) Specifies a list of source IP groups that shall be bypassed by intrusion detection.<br/>  * `private_ranges` - (Optional) A list of Private IP address ranges to identify traffic direction. By default, only ranges defined by IANA RFC 1918 are considered private IP addresses.<br/> * `private_ip_ranges` - (Optional) A list of private IP ranges to which traffic will not be SNAT.<br/> * `auto_learn_private_ranges_enabled` - (Optional) Whether enable auto learn private ip range.<br/> * `sku` - (Optional) The SKU Tier of the Firewall Policy. Possible values are `Standard`, `Premium` and `Basic`. Defaults to `Standard`. Changing this forces a new Firewall Policy to be created.<br/> * `tags` - (Optional) A mapping of tags which should be assigned to the Firewall Policy.<br/> * `threat_intelligence_allowlist` - (Optional) A `threat_intelligence_allowlist` block as defined below.<br/>  * `fqdns` - (Optional) A list of FQDNs that will be skipped for threat detection.<br/>  * `ip_addresses` - (Optional) A list of IP addresses or CIDR ranges that will be skipped for threat detection.<br/> * `threat_intelligence_mode` - (Optional) The operation mode for Threat Intelligence. Possible values are `Alert`, `Deny` and `Off`. Defaults to `Alert`.<br/> * `tls_certificate` - (Optional) A `tls_certificate` block as defined below.<br/>  * `key_vault_secret_id` - (Required) The Secret Identifier (URI) of the certificate stored in Azure Key Vault, either as a secret or certificate.<br/>  * `name` - (Required) The  name of the certificate.<br/> * `sql_redirect_allowed` - (Optional) Whether SQL Redirect traffic filtering is allowed. Enabling this flag requires no rule using ports between `11000`-`11999`.<br/> * `explicit_proxy` - (Optional) A `explicit_proxy` block as defined below.<br/>  * `enabled` - (Optional) Whether the explicit proxy is enabled for this Firewall Policy.<br/>  * `http_port` - (Optional) The port number for explicit http protocol.<br/>  * `https_port` - (Optional) The port number for explicit proxy https protocol.<br/>  * `enable_pac_file` - (Optional) Whether the pac file port and url need to be provided.<br/>  * `pac_file_port` - (Optional) Specifies a port number for firewall to serve PAC file.<br/>  * `pac_file` - (Optional) Specifies a SAS URL for PAC file.<br/><br/> Example Input:<pre>output "name" {<br/>  value = module.module_name.firewall_policy.name<br/> }</pre> |

## Modules

No modules.


## Additional Information
For more information about Azure Firewall Policies and configurations, refer to the [Azure Firewall Policies documentation](https://learn.microsoft.com/en-us/azure/firewall-policy/tutorial-firewall-deploy-portal-policy/). This module is designed to manage an Azure Firewall Policies, including Application and Network Rules.

## Resources
- [AzureRM Terraform Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/2.55.0/docs/resources/firewall_policy)
- [Azure Firewall Policy Overview](https://learn.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal-policy/)

## Notes
- Group rules logically into collections (e.g., separate application and network rules). Use descriptive names for easy identification.
- Use parent and child policies wisely. Ensure the parent policy contains common baseline rules, and child policies only override or extend where necessary.
- Ensure there are no conflicting rules in the same or different policies, as this can lead to unexpected behavior.
- Always test new policies or updates in a non-production environment before applying them to live firewalls.
- Activate threat intelligence-based filtering to block or alert on traffic from known malicious sources.
- Avoid overly granular rules that may increase complexity and management overhead
- Validate your Terraform configuration to ensure that Azure Firewall Policy is created and configured correctly.

## License
This module is licensed under the MIT License. See the [LICENSE](./LICENSE) file for more details.
<!-- END OF PRE-COMMIT-OPENTOFU DOCS HOOK -->