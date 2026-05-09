locals {

  clusters = var.service_inventory_file.environments[var.environment_id]
  service_manager = merge([
    for cluster, vms in local.clusters : {
      for vm in vms :
      "${var.environment_id}-${vm.hostname}" => {
        ip             = vm.ip
        ssh_port       = vm.ssh_port
        hostname        = vm.hostname
      }
    }
  ]...)
  
  es_hosts_lines = [
    for k, v in local.service_manager :
    "${v.ip} ${v.hostname}"
  ]

  es_hosts_block = <<EOT
# BEGIN ELASTICSEARCH CLUSTER
${join("\n", local.es_hosts_lines)}
# END ELASTICSEARCH CLUSTER
EOT
  
  es_node_names = jsonencode([
    for k, v in local.service_manager : v.hostname
  ])
	
}

############################################################
# Output
############################################################

output "service_inventory" {
  value = local.service_manager
}

############################################################
# Execute remote command
############################################################

resource "terraform_data" "common_service_manager" {
  for_each = var.service_inventory

  triggers_replace = [
    var.trigger_atlantis
  ]

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_key)
    host        = each.value.ip
    port        = each.value.ssh_port
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo find /tmp -name 'terraform_*.sh' -type f -mmin +60 -exec rm -f {} + || true"
    ]
  }
  
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.vm_asset_dir}/config/cert"
    ]
  }
  
  provisioner "file" {
    source      = "certs/"
    destination = "${var.vm_asset_dir}/config/cert"
  }

  provisioner "remote-exec" {
    inline = [
		
		# Remove old managed block if exists
		"sudo sed -i '/# BEGIN ELASTICSEARCH CLUSTER/,/# END ELASTICSEARCH CLUSTER/d' /etc/hosts || true",

		# Append fresh block
		"sudo tee -a /etc/hosts > /dev/null <<'EOF'",
		"${local.es_hosts_block}",
		"EOF",	
		
		# Create directories
		"sudo mkdir -p /data/es",
		"sudo mkdir -p /data/logs/es",
		"sudo mkdir -p /data/backup-elk",

		# Change ownership
		"sudo chown -R ${process_user}:${process_user} /data/",

		# Update limits.conf
		"echo '${process_user} - nofile 65536'    | sudo tee -a /etc/security/limits.conf",
		"echo '${process_user} - nproc 65536'     | sudo tee -a /etc/security/limits.conf",
		"echo '${process_user} - memlock unlimited' | sudo tee -a /etc/security/limits.conf",

		# Update sysctl.conf
		"echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf",
		"sudo sysctl -p",
	
      # Replace discovery.seed_hosts
		"echo '${local.es_hosts_block}' > /tmp/test_nodes.txt",
		"sudo sed -i 's|^discovery.seed_hosts:.*|discovery.seed_hosts: ${local.es_node_names}|' ${var.vm_asset_dir}/config/elasticsearch.yml",

		# Replace cluster.initial_master_nodes
		"sudo sed -i 's|^cluster.initial_master_nodes:.*|cluster.initial_master_nodes: ${local.es_node_names}|' ${var.vm_asset_dir}/config/elasticsearch.yml",
		
		
		"sudo mv ${var.vm_asset_dir}/elasticsearch.service /etc/systemd/system/elasticsearch.service",

		# Reload systemd
		"sudo systemctl daemon-reload"
	
    ]
  }
}
