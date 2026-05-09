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

resource "terraform_data" "es_prepare" {
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

  # prepare softlink for elasticsearch package and copy certs
  provisioner "remote-exec" {
    inline = [
      "sudo find /tmp -name 'terraform_*.sh' -type f -mmin +60 -exec rm -f {} + || true",
      "if [ ! -d ${var.es_install_dir}/elasticsearch-${var.elasticsearch_version} ] && [ -f /tmp/${var.elasticsearch_package} ]; then tar -xzf /tmp/${var.elasticsearch_package} -C ${var.es_install_dir}; fi",
      "ln -sfn ${var.es_install_dir}/elasticsearch-${var.elasticsearch_version} ${var.es_install_dir}/elasticsearch",
      "mkdir -p ${var.es_install_dir}/elasticsearch/config/cert"
    ]
  }
  
  provisioner "file" {
    source      = "certs/"
    destination = "${var.es_install_dir}/elasticsearch/config/cert"
  }

}

module "common_asset_manager" {
  source = "../modules/common_asset_manager"

  environment_id         = var.environment_id
  service_inventory_file = var.service_inventory_file

  # Lấy output từ service_manager
  service_inventory = module.common_asset_manager.service_inventory

  git_asset_dir = "assets"
  vm_asset_dir  = "/home/vhv_admin/elasticsearch"

  ssh_user        = var.ssh_user
  ssh_private_key = var.ssh_key
  depends_on = [
    terraform_data.es_prepare
  ]
}

resource "terraform_data" "es_configure" {
  for_each = var.service_inventory

  triggers_replace = [var.trigger_atlantis]

  depends_on = [
    module.common_asset_manager
  ]

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_key)
    host        = each.value.ip
    port        = each.value.ssh_port
    timeout     = "2m"
  }

  # prepare hosts file, directories, limits.conf, sysctl.conf and elasticsearch.yml
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
		"sudo chown -R ${var.process_user}:${var.process_user} /data/",

		# Update limits.conf
		"sudo sed -i '/# BEGIN ELASTICSEARCH LIMITS/,/# END ELASTICSEARCH LIMITS/d' /etc/security/limits.conf || true",

    "sudo tee -a /etc/security/limits.conf > /dev/null <<'EOF'",
    "# BEGIN ELASTICSEARCH LIMITS",
    "${var.process_user} - nofile 65536",
    "${var.process_user} - nproc 65536",
    "${var.process_user} - memlock unlimited",
    "# END ELASTICSEARCH LIMITS",
    "EOF",

		# Update sysctl.conf
		"sudo sed -i '/vm.max_map_count/d' /etc/sysctl.conf",
    "echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf",
    "sudo sysctl -w vm.max_map_count=262144",
	
      # Replace discovery.seed_hosts
		"echo '${local.es_hosts_block}' > /tmp/test_nodes.txt",
		"sudo sed -i 's|^discovery.seed_hosts:.*|discovery.seed_hosts: ${local.es_node_names}|' ${var.es_install_dir}/elasticsearch/config/elasticsearch.yml",

		# Replace cluster.initial_master_nodes
		"sudo sed -i 's|^cluster.initial_master_nodes:.*|cluster.initial_master_nodes: ${local.es_node_names}|' ${var.es_install_dir}/elasticsearch/config/elasticsearch.yml",
		"sudo chown -R ${var.process_user}:${var.process_user} ${var.es_install_dir}/elasticsearch-*",
		"sudo chown -h ${var.process_user}:${var.process_user} ${var.es_install_dir}/elasticsearch",
		"sudo mv ${var.es_install_dir}/elasticsearch/elasticsearch.service /etc/systemd/system/elasticsearch.service || true",

		# Reload systemd
		"sudo systemctl daemon-reload"
	
    ]
  }
}