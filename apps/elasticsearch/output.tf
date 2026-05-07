output "inventory_loaded" {
  value = local.inventory
}

output "service_inventory" {
  value = module.common_asset_manager.service_inventory
}
