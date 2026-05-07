locals {

  ############################################################
  # Load clusters from inventory
  ############################################################

  clusters = var.service_inventory_file.environments[var.environment_id]

  ############################################################
  # Build service manager inventory
  ############################################################

  service_manager = merge([
    for cluster, vms in local.clusters : {
      for vm in vms :
      "${var.environment_id}-${vm.hostname}-${vm.command_action}" => {
        ip             = vm.ip
        ssh_port       = vm.ssh_port
        service        = vm.service
        command_type   = vm.command_type
        command_action = vm.command_action
      }
    }
  ]...)

  ############################################################
  # Command library
  ############################################################

  envoy_command = "sudo docker-compose --project-directory /toast-api-proxy -f /toast-api-proxy/install/docker-compose.yaml"

  command_library = {

    systemctl = {
      status  = ["hostname; systemctl status (SERVICE) --no-pager || true"]
      start   = ["hostname; systemctl start (SERVICE)"]
      restart = ["hostname; systemctl restart (SERVICE)"]
      stop    = ["hostname; systemctl stop (SERVICE)"]
      re-cycle = [
        "hostname",
        "systemctl stop (SERVICE)",
        "sleep 6",
        "systemctl start (SERVICE)",
        "sleep 6",
        "systemctl status (SERVICE) --no-pager || true"
      ]
    }

    envoy = {
      status  = ["sudo docker ps -a || true"]
      start   = ["${local.envoy_command} up -d"]
      restart = [
        "${local.envoy_command} stop",
        "sleep 6",
        "${local.envoy_command} up -d",
        "sleep 6",
        "sudo docker ps -a || true"
      ]
      stop   = ["${local.envoy_command} stop"]
      remove = ["${local.envoy_command} rm --all"]
    }

    nginx = {
      version = [
        "echo '--- NGINX VERSION ---'",
        "/usr/sbin/nginx -v",
        "echo '----------------------'"
      ]
      reload = [
        "sudo /usr/sbin/nginx -t || exit 1",
        "sudo /usr/sbin/nginx -s reload",
        "ps -aux | grep nginx"
      ]
    }

    haproxy = {
      status  = ["sudo docker ps -a || true"]
      restart = ["sudo /usr/local/bin/crm"]
    }

    worker = {
      status = ["ps -aux | grep cmp-fl-logging-worker | grep jar | grep -v grep"]
      restart = [
        "sudo /home/fwdeployer/stop_worker.sh",
        "sudo /home/fwdeployer/start_worker.sh"
      ]
    }
  }

  ############################################################
  # Build command manager
  ############################################################

  command_manager = {
    for k, v in local.service_manager :
    k => {
      ip       = v.ip
      ssh_port = v.ssh_port
      service  = v.service
      commands = [
        for raw_cmd in try(
          local.command_library[v.command_type][v.command_action],
          ["echo ERROR: Invalid Command"]
        ) :
        replace(raw_cmd, "(SERVICE)", v.service)
      ]
    }
  }

}

############################################################
# Output
############################################################

output "service_inventory" {
  value = local.command_manager
}

############################################################
# Execute remote command
############################################################

resource "terraform_data" "common_service_manager" {
  for_each = local.command_manager

  triggers_replace = [
    md5(join(";", each.value.commands)),
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
    inline = each.value.commands
  }
}
