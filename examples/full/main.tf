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
