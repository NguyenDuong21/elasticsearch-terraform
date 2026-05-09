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

  git_asset_dir = "assets"
  vm_asset_dir  = "/home/vhv_admin/elasticsearch"

  ssh_user        = "vhv_admin"
  ssh_private_key = "/home/vhv_admin/.ssh/id_ed25519"
}

/*module "elasticsearch_installation" {
  source = "../../modules/elasticsearch_installation"

  environment_id         = var.environment_id
  service_inventory_file = local.inventory
  service_inventory      = module.elasticsearch_installation.service_inventory
  trigger_atlantis = "20260514T191000Z"
  vm_asset_dir  = "/home/vhv_admin/elasticsearch"
}*/
