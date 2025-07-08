
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
