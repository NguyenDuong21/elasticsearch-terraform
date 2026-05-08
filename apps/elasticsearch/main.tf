terraform {
  required_version = ">= 1.4"
}

############################################################
# Load inventory
############################################################

locals {
  inventory = yamldecode(file("${path.module}/inventory.yaml"))
}

# module "common_service_manager" {
#   source = "../../modules/common_service_manager"

#   environment_id         = var.environment_id
#   service_inventory_file = local.inventory


#   service_inventory = module.common_service_manager.service_inventory
#   trigger_atlantis = "20260506-01"
#   ssh_user        = "admin"
#   ssh_private_key = "/home/admin/.ssh/id_ed25519"
# }

module "common_asset_manager" {
  source = "../../modules/common_asset_manager"

  environment_id         = var.environment_id
  service_inventory_file = local.inventory

  # Lấy output từ service_manager
  service_inventory = module.common_asset_manager.service_inventory

  git_asset_dir = "assets"
  vm_asset_dir  = "/home/admin/elasticsearch"

  ssh_user        = "admin"
  ssh_private_key = "/home/admin/.ssh/id_ed25519"
}
