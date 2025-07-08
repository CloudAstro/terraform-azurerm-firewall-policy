variable "location" {
  type        = string
  description = <<DESCRIPTION
  * `location` - (Required) The Azure Region where the Firewall Policy should exist. Changing this forces a new Firewall Policy to be created.
  
  Example Input:
  ```
  location = "germanywestcentral"
  ```
  DESCRIPTION
}

variable "name" {
  type        = string
  description = <<DESCRIPTION
  * `name` - (Required) The name which should be used for this Firewall Policy. Changing this forces a new Firewall Policy to be created.
  
  Example Input:
  ```
  name = "azure-firewall-policy"
  ```
  DESCRIPTION
}

variable "resource_group_name" {
  type        = string
  description = <<DESCRIPTION
  * `resource_group_name` - (Required) The name of the Resource Group where the Firewall Policy should exist. Changing this forces a new Firewall Policy to be created.
  
  Example Input:
  ```
  resource_group_name = "rg-azure-firewall"
  ```
  DESCRIPTION
}

variable "base_policy_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
  * `base_policy_id` - (Optional) The ID of the base Firewall Policy.
  
  Example Input:
  ```
  base_policy_id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.Network/firewallPolicies/<base_policy_name>"
  ```
  DESCRIPTION
}

variable "private_ip_ranges" {
  type        = list(string)
  default     = null
  description = <<DESCRIPTION
  * `private_ip_ranges` - (Optional) A list of private IP ranges to which traffic will not be SNAT.
  
  Example Input:
  ```
  private_ip_ranges = ["10.0.0.0/24", "192.168.1.0/24"]
  ```
  DESCRIPTION
}

variable "auto_learn_private_ranges_enabled" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
  * `auto_learn_private_ranges_enabled` - (Optional) Whether enable auto learn private ip range.
  
  Example Input:
  ```
  auto_learn_private_ranges_enabled = false
  ```
  DESCRIPTION
}

variable "sku" {
  type        = string
  default     = "Standard"
  description = <<DESCRIPTION
  * `sku` - (Optional) The SKU Tier of the Firewall Policy. Possible values are `Standard`, `Premium` and `Basic`. Defaults to `Standard`. Changing this forces a new Firewall Policy to be created.
  
  Example Input:
  ```
  sku = "Standard"
  ```
  DESCRIPTION
}

variable "threat_intelligence_mode" {
  type        = string
  default     = "Alert"
  description = <<DESCRIPTION
  * `threat_intelligence_mode` - (Optional) The operation mode for Threat Intelligence. Possible values are `Alert`, `Deny` and `Off`. Defaults to `Alert`.

  Example Input:
  ```
  threat_intelligence_mode = "Alert"
  ```
  DESCRIPTION 
}

variable "sql_redirect_allowed" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
  * `sql_redirect_allowed` - (Optional) Whether SQL Redirect traffic filtering is allowed. Enabling this flag requires no rule using ports between `11000`-`11999`.
 
  Example Input:
  ```
  sql_redirect_allowed = false
  ```
  DESCRIPTION
}

variable "dns" {
  type = object({
    proxy_enabled = optional(bool, false)
    servers       = optional(list(string))
  })
  default     = null
  description = <<DESCRIPTION
  * `dns` - (Optional) A `dns` block as defined below.
   * `proxy_enabled` - (Optional) Whether to enable DNS proxy on Firewalls attached to this Firewall Policy? Defaults to `false`.
   * `servers` - (Optional) A list of custom DNS servers' IP addresses.

  Example Input:
  ```
  dns = {
    proxy_enabled = false
    servers       = ["8.8.8.8", "8.8.4.4"]
  }
  ```
  DESCRIPTION 

}

variable "identity" {
  type = object({
    type         = string
    identity_ids = optional(list(string))
  })
  default     = null
  description = <<DESCRIPTION
  * `identity` - (Optional) An `identity` block as defined below:
   * `type` - (Required) Specifies the type of Managed Service Identity that should be configured on this Firewall Policy. Only possible value is `UserAssigned`.
   * `identity_ids` - (Optional) Specifies a list of User Assigned Managed Identity IDs to be assigned to this Firewall Policy.

  Example Input:
  ```
  identity = {
    type         = "UserAssigned"
    identity_ids = [
      "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{identity-name}"
    ]
  }
  ```
  DESCRIPTION
}

variable "insights" {
  type = object({
    enabled                            = bool
    default_log_analytics_workspace_id = string
    retention_in_days                  = optional(number, 30)
    log_analytics_workspace = optional(list(object({
      id                = string
      firewall_location = string
    })))
  })
  default     = null
  description = <<DESCRIPTION
 * `insights` - (Optional) An `insights` block as defined below.
  * `enabled` - (Required) Whether the insights functionality is enabled for this Firewall Policy.
  * `default_log_analytics_workspace_id` - (Required) The ID of the default Log Analytics Workspace that the Firewalls associated with this Firewall Policy will send their logs to, when there is no location matches in the `log_analytics_workspace`.
  * `retention_in_days` - (Optional) The log retention period in days.
  * `log_analytics_workspace` - (Optional) A list of `log_analytics_workspace` block as defined below.
    * `id` - (Required) The ID of the Log Analytics Workspace that the Firewalls associated with this Firewall Policy will send their logs to when their locations match the `firewall_location`.
    * `firewall_location` - (Required) The location of the Firewalls, that when matches this Log Analytics Workspace will be used to consume their logs.
    
  Example Input:
  ```
  insights = {
    enabled                            = true
    default_log_analytics_workspace_id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.OperationalInsights/workspaces/default-log-analytics"
    retention_in_days                  = 90
    log_analytics_workspace = [
      {
        id                = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.OperationalInsights/workspaces/eastus-log-analytics"
        firewall_location = "eastus"
      }
    ]
  }
  ```
  DESCRIPTION
}

variable "intrusion_detection" {
  type = object({
    mode = optional(string, "Off")
    signature_overrides = optional(list(object({
      id    = optional(string)
      state = optional(string, "Alert")
    })))
    traffic_bypass = optional(list(object({
      name                  = string
      protocol              = string
      description           = optional(string)
      destination_addresses = optional(list(string))
      destination_ip_groups = optional(list(string))
      destination_ports     = optional(list(string))
      source_addresses      = optional(list(string))
      source_ip_groups      = optional(list(string))
    })))
    private_ranges = optional(list(string))
  })
  default     = null
  description = <<DESCRIPTION
  * `intrusion_detection` - (Optional) A `intrusion_detection` block as defined below.
    * `mode` - (Optional) In which mode you want to run intrusion detection: `Off`, `Alert` or `Deny`.
    * `signature_overrides` - (Optional) One or more `signature_overrides` blocks as defined below.
      * `id` - (Optional) 12-digit number (id) which identifies your signature.
      * `state` - (Optional) state can be any of `Off`, `Alert` or `Deny`.
    * `traffic_bypass` - (Optional) One or more `traffic_bypass` blocks as defined below.
      * `name` - (Required) The name which should be used for this bypass traffic setting.
      * `protocol` - (Required) The protocols any of `ANY`, `TCP`, `ICMP`, `UDP` that shall be bypassed by intrusion detection.
      * `description` - (Optional) The description for this bypass traffic setting.
      * `destination_addresses` - (Optional) Specifies a list of destination IP addresses that shall be bypassed by intrusion detection.
      * `destination_ip_groups` - (Optional) Specifies a list of destination IP groups that shall be bypassed by intrusion detection.
      * `destination_ports` - (Optional) Specifies a list of destination IP ports that shall be bypassed by intrusion detection.
      * `source_addresses` - (Optional) Specifies a list of source addresses that shall be bypassed by intrusion detection.
      * `source_ip_groups` - (Optional) Specifies a list of source IP groups that shall be bypassed by intrusion detection.
    * `private_ranges` - (Optional) A list of Private IP address ranges to identify traffic direction. By default, only ranges defined by IANA RFC 1918 are considered private IP addresses.

  Example Input:
  ```
  intrusion_detection = {
    mode                = "Alert"
    signature_overrides = [
      {
       id    = "123456789012"
       state = "Deny" 
      }
    ]
    traffic_bypass = [
      {
        name                  = "example-bypass"
        protocol              = "TCP"
        description           = "Bypass for specific traffic"
        destination_addresses = ["10.1.0.0/16", "203.0.113.5"]
        destination_ip_groups = []
        destination_ports     = ["80", "443"]
        source_addresses      = ["192.168.1.0/24"]
        source_ip_groups      = []
      }
    ]
    private_ranges = ["10.0.0.0/24", "192.168.1.0/24"]
  }
  ```
  DESCRIPTION
}

variable "threat_intelligence_allowlist" {
  type = object({
    fqdns        = optional(list(string))
    ip_addresses = optional(list(string))
  })
  default     = null
  description = <<DESCRIPTION
  * `threat_intelligence_allowlist` - (Optional) A `threat_intelligence_allowlist` block as defined below.
   * `fqdns` - (Optional) A list of FQDNs that will be skipped for threat detection.
   * `ip_addresses` - (Optional) A list of IP addresses or CIDR ranges that will be skipped for threat detection.

  Example Input:
  ```
  threat_intelligence_allowlist = {
    fqdns        = ["example.com", "trusted.example.com"]
    ip_addresses = ["192.168.1.1", "10.0.0.0/24"]
  }
  ```
  DESCRIPTION
}

variable "tls_certificate" {
  type = object({
    key_vault_secret_id = string
    name                = string
  })
  default     = null
  description = <<DESCRIPTION
  * `tls_certificate` - (Optional) A `tls_certificate` block as defined below.
   * `key_vault_secret_id` - (Required) The ID of the Key Vault, where the secret or certificate is stored.
   * `name` - (Required) The name of the certificate.

  Example Input:
  ```
  tls_certificate = {
    key_vault_secret_id = "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.KeyVault/vaults/{vault-name}/secrets/{certificate-name}"
    name                = "example-certificate"
  }
  ```
  DESCRIPTION
}

variable "explicit_proxy" {
  type = object({
    enabled         = optional(bool)
    http_port       = optional(number)
    https_port      = optional(number)
    enable_pac_file = optional(bool)
    pac_file_port   = optional(number)
    pac_file        = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
  * `explicit_proxy` - (Optional) A `explicit_proxy` block as defined below.
    * `enabled` - (Optional) Whether the explicit proxy is enabled for this Firewall Policy.
    * `http_port` - (Optional) The port number for explicit http protocol.
    * `https_port` - (Optional) The port number for explicit proxy https protocol.
    * `enable_pac_file` - (Optional) Whether the pac file port and url need to be provided.
    * `pac_file_port` - (Optional) Specifies a port number for firewall to serve PAC file.
    * `pac_file` - (Optional) Specifies a SAS URL for PAC file.
    
  Example Input:
  ```
  explicit_proxy = {
    enabled         = true
    http_port       = 8080
    https_port      = 8443
    enable_pac_file = true
    pac_file_port   = 9000
    pac_file        = "https://example.blob.core.windows.net/pacfiles/firewall-config.pac?sas_token_here"
  }
  ```
  DESCRIPTION
}

variable "rule_collection_group" {
  type = map(object({
    name     = string
    priority = number
    application_rule_collections = optional(map(object({
      name     = string
      action   = string
      priority = number
      rules = list(object({
        name                  = string
        description           = optional(string)
        source_addresses      = optional(list(string))
        source_ip_groups      = optional(list(string))
        destination_addresses = optional(list(string))
        destination_urls      = optional(list(string))
        destination_fqdns     = optional(list(string))
        destination_fqdn_tags = optional(list(string))
        terminate_tls         = optional(bool, false)
        web_categories        = optional(list(string))
        protocols = optional(list(object({
          type = string
          port = number
        })))
        http_headers = optional(list(object({
          name  = string
          value = string
        })))
      }))
    })))
    network_rule_collections = optional(map(object({
      name     = string
      action   = string
      priority = number
      rules = list(object({
        name                  = string
        description           = optional(string)
        protocols             = list(string)
        destination_ports     = list(string)
        source_addresses      = optional(list(string))
        source_ip_groups      = optional(list(string))
        destination_addresses = optional(list(string))
        destination_ip_groups = optional(list(string))
        destination_fqdns     = optional(list(string))
      }))
    })))
    nat_rule_collections = optional(map(object({
      name     = string
      priority = number
      action   = string
      rules = list(object({
        name                = string
        description         = optional(string)
        protocols           = list(string)
        source_addresses    = optional(list(string))
        source_ip_groups    = optional(list(string))
        destination_address = optional(string)
        destination_ports   = optional(list(string))
        translated_address  = optional(string)
        translated_fqdn     = optional(string)
        translated_port     = string
      }))
    })))
  }))
  default     = null
  description = <<DESCRIPTION
 * `rule_collection_group` - (Optional) Manages a Firewall Policy Rule Collection Group.
  * `name` - (Required) The name which should be used for this Firewall Policy Rule Collection Group. Changing this forces a new Firewall Policy Rule Collection Group to be created.
  * `firewall_policy_id` - (Required) The ID of the Firewall Policy where the Firewall Policy Rule Collection Group should exist. Changing this forces a new Firewall Policy Rule Collection Group to be created.
  * `priority` - (Required) The priority of the Firewall Policy Rule Collection Group. The range is 100-65000.
  * `application_rule_collection` - (Optional) One or more `application_rule_collection` blocks as defined below.
    * `name` - (Required) The name which should be used for this application rule collection.
    * `action` - (Required) The action to take for the application rules in this collection. Possible values are `Allow` and `Deny`.
    * `priority` - (Required) The priority of the application rule collection. The range is `100` - `65000`.
    * `rule` - (Required) One or more `application_rule` blocks as defined below.
      * `name` - (Required) The name which should be used for this rule.
      * `description` - (Optional) The description which should be used for this rule.
      * `source_addresses` - (Optional) Specifies a list of source IP addresses (including CIDR, IP range and `*`).
      * `source_ip_groups` - (Optional) Specifies a list of source IP groups.
      * `destination_addresses` - (Optional) Specifies a list of destination IP addresses (including CIDR, IP range and `*`).
      * `destination_urls` - (Optional) Specifies a list of destination URLs for which policy should hold. Needs Premium SKU for Firewall Policy. Conflicts with `destination_fqdns`.
      * `destination_fqdns` - (Optional) Specifies a list of destination FQDNs. Conflicts with `destination_urls`.
      * `destination_fqdn_tags` - (Optional) Specifies a list of destination FQDN tags.
      * `terminate_tls` - (Optional) Boolean specifying if TLS shall be terminated (true) or not (false). Must be `true` when using `destination_urls`. Needs Premium SKU for Firewall Policy.
      * `web_categories` - (Optional) Specifies a list of web categories to which access is denied or allowed depending on the value of `action` above. Needs Premium SKU for Firewall Policy.
      * `protocols` - (Optional) One or more `protocols` blocks as defined below.
        * `type` - (Required) Protocol type. Possible values are `Http` and `Https`.
        * `port` - (Required) Port number of the protocol. Range is 0-64000.
      * `http_headers` - (Optional) Specifies a list of HTTP/HTTPS headers to insert. One or more `http_headers` blocks as defined below.
        * `name` - (Required) Specifies the name of the header.
        * `value` - (Required) Specifies the value of the value.
  * `nat_rule_collection` - (Optional) One or more `nat_rule_collection` blocks as defined below.
    * `name` - (Required) The name which should be used for this NAT rule collection.
    * `action` - (Required) The action to take for the NAT rules in this collection. Currently, the only possible value is `Dnat`.
    * `priority` - (Required) The priority of the NAT rule collection. The range is `100` - `65000`.
    * `rule` - (Required) A `nat_rule` block as defined below.
      * `name` - (Required) The name which should be used for this rule.
      * `description` - (Optional) The description which should be used for this rule.
      * `protocols` - (Required) Specifies a list of network protocols this rule applies to. Possible values are `TCP`, `UDP`.
      * `source_addresses` - (Optional) Specifies a list of source IP addresses (including CIDR, IP range and `*`).
      * `source_ip_groups` - (Optional) Specifies a list of source IP groups.
      * `destination_address` - (Optional) The destination IP address (including CIDR).
      * `destination_ports` - (Optional) Specifies a list of destination ports. Only one destination port is supported in a NAT rule.
      * `translated_address` - (Optional) Specifies the translated address.
      * `translated_fqdn` - (Optional) Specifies the translated FQDN.
       
       ~> **NOTE:** Exactly one of `translated_address` and `translated_fqdn` should be set.
      * `translated_port` - (Required) Specifies the translated port.
  * `network_rule_collection` - (Optional) One or more `network_rule_collection` blocks as defined below.
    * `name` - (Required) The name which should be used for this network rule collection.
    * `action` - (Required) The action to take for the network rules in this collection. Possible values are `Allow` and `Deny`.
    * `priority` - (Required) The priority of the network rule collection. The range is `100` - `65000`.
    * `rule` - (Required) One or more `network_rule` blocks as defined below.
      * `name` - (Required) The name which should be used for this rule.
      * `description` - (Optional) The description which should be used for this rule.
      * `protocols` - (Required) Specifies a list of network protocols this rule applies to. Possible values are `Any`, `TCP`, `UDP`, `ICMP`.
      * `destination_ports` - (Required) Specifies a list of destination ports.
      * `source_addresses` - (Optional) Specifies a list of source IP addresses (including CIDR, IP range and `*`).
      * `source_ip_groups` - (Optional) Specifies a list of source IP groups.
      * `destination_addresses` - (Optional) Specifies a list of destination IP addresses (including CIDR, IP range and `*`) or Service Tags.
      * `destination_ip_groups` - (Optional) Specifies a list of destination IP groups.
      * `destination_fqdns` - (Optional) Specifies a list of destination FQDNs.
  
  Example Input:
  ```
  rule_collection_group = {
   rule1 = {
    name                = "example-rule-group"
    firewall_policy_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Network/firewallPolicies/policy-example"
    priority            = 100

    application_rule_collections = [
      {
        name     = "example-app-rule-collection"
        action   = "Allow"
        priority = 200
        rule = [
          {
            name              = "Allow-to-Microsoft"
            description       = "Allow traffic to Microsoft.com"
            source_addresses  = ["10.0.0.0/24"]
            destination_fqdns = ["*.microsoft.com"]
            protocols = [
              {
                type = "Https"
                port = 443
              }
            ]
            http_headers = [
              {
               name  = "X-Custom-Header"
               value = "ExampleValue"
              }
            ]
          }
        ]
      }
    ]
    nat_rule_collections = [
      {
        name        = "example-nat-rule-collection"
        action      = "Dnat"
        priority    = 300
        rule = [
          {
            name                = "nat"
            protocols           = ["TCP", "UDP"]
            source_addresses    = ["10.0.0.1", "10.0.0.2"]
            destination_address = "10.2.0.4"
            destination_ports   = ["80"]
            translated_address  = "192.168.0.1"
            translated_port     = "8080"
          }
        ]
      }
    ]
    network_rule_collections = [
      {
        name     = "example-network-rule-collection"
        action   = "Allow"
        priority = 400
        rule = [
          {
            name                  = "Outbound-To-Internet"
            description           = "Allow traffic outbound to the Internet"
            protocols             = ["TCP"]
            source_addresses      = ["10.0.0.0/24"]
            destination_addresses = ["0.0.0.0/0"]
            destination_ports     = ["443"]
          }
        ]
      }
    ]
   }
  }
  ```
  DESCRIPTION
}

variable "tags" {
  type        = map(string)
  default     = null
  description = <<DESCRIPTION
  * `tags` - (Optional) A mapping of tags to assign to the resource.

  Example Input:
  ```
  tags = {
    env     = test
    region  = gwc
  }
  ```
  DESCRIPTION
}