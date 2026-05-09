variable "environment_id" {
  type    = string
  default = "dev"
}

variable "service_inventory_file" {
  type = any
}

variable "service_inventory" {
  type = map(object({
    ip       = string
    ssh_port = number
    hostname = string
  }))
}

variable "vm_asset_dir" {
  description = "Base directory on VM to store configuration files"
  type        = string
}

variable "trigger_atlantis" {
  type = string
}

variable "ssh_user" {
  description = "OS user that have sudo permission"
  type        = string
  default     = "vhv_admin"
}

variable "process_user" {
  description = "OS user that have sudo permission"
  type        = string
  default     = "vhv_admin"
}

variable "ssh_key" {
  description = "SSH private key in Atlantis Pod"
  type        = string
  default     = "/home/vhv_admin/.ssh/id_ed25519"
}