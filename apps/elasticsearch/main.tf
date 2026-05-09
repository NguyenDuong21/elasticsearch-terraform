terraform {
  required_version = ">= 1.4"
}

############################################################
# Load inventory
############################################################

locals {
  inventory = yamldecode(file("${path.module}/inventory.yaml"))
}

module "elasticsearch_installation" {
  source = "../../modules/elasticsearch_installation"

  environment_id         = var.environment_id
  service_inventory_file = local.inventory
  service_inventory      = module.elasticsearch_installation.service_inventory
  trigger_atlantis = "20260514T191000Z"
  es_install_dir  = "/home/vhv_admin"
}
