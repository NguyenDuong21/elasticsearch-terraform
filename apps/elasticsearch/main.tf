terraform {
  required_version = ">= 1.4"
}

############################################################
# Load inventory
############################################################

locals {
  inventory = yamldecode(file("${path.module}/inventory.yaml"))
}

module "common_asset_manager" {
  source = "../../modules/common_asset_manager"

  environment_id         = var.environment_id
  service_inventory_file = local.inventory

  # Lấy output từ service_manager
  service_inventory = module.common_asset_manager.service_inventory

  git_asset_dir = "${path.module}/assets"
  vm_asset_dir  = "/tmp"

  ssh_user        = "dummy"
  ssh_private_key = "/tmp/dummy.pem"
}
