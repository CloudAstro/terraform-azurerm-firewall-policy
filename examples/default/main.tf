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

  name                 = "snet-example"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = module.vnet.virtual_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

module "firewall" {
  source = "CloudAstro/firewall/azurerm"

  name                = "firewall-example"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = module.firewall_policy.firewall_policy.id
}

module "firewall_policy" {
  source = "../.."

  location            = azurerm_resource_group.rg.location
  name                = "my-firewall-policy"
  resource_group_name = azurerm_resource_group.rg.name
}
