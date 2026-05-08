terraform {
  required_version = ">= 1.4"

  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = ">= 0.5"
    }
  }
}

############################################################
# Decrypt cert / encrypted files via SOPS
############################################################

data "sops_file" "decrypt_cert" {
  for_each = {
    for k, v in var.service_inventory :
    k => v
    if can(regex("\\.(crt|key|pem|enc)$", v.git_asset_path))
  }

  source_file = each.value.git_asset_path
  input_type  = "raw"
}

############################################################
# Build final asset object (render / decrypt / raw file)
############################################################

locals {

  clusters = var.service_inventory_file.environments[var.environment_id]

  service_manager = {
    for idx in flatten([
      for cluster, vms in local.clusters : [
        for vm in vms : [
          for asset_path in fileset("${var.git_asset_dir}/${cluster}", "**") : {
            key = "${cluster}-${vm.hostname}-${asset_path}"
            val = {
              environment     = var.environment_id
              cluster         = cluster
              ip              = vm.ip
              ssh_port        = vm.ssh_port
              hostname        = vm.hostname
              git_asset_path  = "${var.git_asset_dir}/${cluster}/${asset_path}"
              vm_asset_path   = replace(asset_path, ".tpl", "")
            }
          }
        ]
      ]
    ]) : idx.key => idx.val
  }


  asset_file_manager = {
    for k, v in var.service_inventory :
    k => merge(v, {

      content = (
        endswith(v.git_asset_path, ".tpl") ?
        templatefile(v.git_asset_path, {
          vm_ip   = v.ip,
          vm_host = v.hostname
        }) :

        can(regex("\\.(crt|key|pem|enc)$", v.git_asset_path)) ?
        try(data.sops_file.decrypt_cert[k].raw, "") :

        file(v.git_asset_path)
      )

      vm_asset_path_tmp = "/tmp/atlantis/${v.vm_asset_path}"

      vm_asset_path = v.cluster == "mb_fwlog" ? "/home/scpdev/opensearch/${v.vm_asset_path}" : "${var.vm_asset_dir}/${v.vm_asset_path}"
    })
  }

}

############################################################
# Deploy file to VM
############################################################

# resource "terraform_data" "asset_manager" {
#   for_each = local.asset_file_manager

#   triggers_replace = [
#     sha256(each.value.content)
#   ]

#   connection {
#     type        = "ssh"
#     user        = var.ssh_user
#     private_key = file(var.ssh_private_key)
#     host        = each.value.ip
#     port        = each.value.ssh_port
#     timeout     = var.ssh_timeout
#   }

#   ##########################################################
#   # Create directory on target
#   ##########################################################

#   provisioner "remote-exec" {
#     inline = [
#       "mkdir -p $(dirname ${each.value.vm_asset_path_tmp})"
#     ]
#   }

#   ##########################################################
#   # Upload file to temporary location
#   ##########################################################

#   provisioner "file" {
#     content     = each.value.content
#     destination = each.value.vm_asset_path_tmp
#   }

#   ##########################################################
#   # Move to final location with permission control
#   ##########################################################

#   provisioner "remote-exec" {
#     inline = [
#       "sudo mkdir -p $(dirname ${each.value.vm_asset_path})",
#       "sudo cp -f ${each.value.vm_asset_path_tmp} ${each.value.vm_asset_path}",
#       "sudo chmod 660 ${each.value.vm_asset_path}",
#       # "sudo chown root:root ${each.value.vm_asset_path}"
#     ]
#   }
# }

############################################################
# Output deployed inventory
############################################################

output "service_inventory" {
  description = "Assets deployed to VM"
  value       = local.service_manager
}

