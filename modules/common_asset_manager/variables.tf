############################################################
# Environment
############################################################

variable "environment_id" {
  description = "Environment identifier (dev, ta, prod, ...)"
  type        = string
}

############################################################
# Inventory
############################################################

variable "service_inventory_file" {
  type        = any
}

variable "service_inventory" {
  description = "Flattened inventory from service_manager module"

  type = map(object({
    environment     = string
    cluster         = string
    ip              = string
    ssh_port        = number
    hostname        = string
    git_asset_path  = string
    vm_asset_path   = string
  }))
}

variable "git_asset_dir" {
  description = "Git repository directory to store configuration files"
  type        = string
}

############################################################
# Asset directories
############################################################

variable "vm_asset_dir" {
  description = "Base directory on VM to store configuration files"
  type        = string
}

############################################################
# SSH configuration
############################################################

variable "ssh_user" {
  description = "SSH user with sudo privilege"
  type        = string
  default     = "atlantis"
}

variable "ssh_private_key" {
  description = "Path to SSH private key file"
  type        = string
  default     = "/home/atlantis/.ssh/id_rsa"
}

variable "ssh_timeout" {
  description = "SSH connection timeout"
  type        = string
  default     = "2m"
}

############################################################
# File permission control
############################################################

variable "file_permission" {
  description = "File permission (chmod)"
  type        = string
  default     = "640"
}

variable "file_owner" {
  description = "File owner"
  type        = string
  default     = "root"
}

variable "file_group" {
  description = "File group"
  type        = string
  default     = "root"
}
