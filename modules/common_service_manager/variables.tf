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
    service  = string
    commands = list(string)
    ssh_port = number
  }))
}

variable "trigger_atlantis" {
  type = string
}

variable "ssh_user" {
  description = "OS user that have sudo permission"
  type        = string
  default     = "atlantis"
}

variable "ssh_private_key" {
  description = "SSH private key in Atlantis Pod"
  type        = string
  default     = "/home/atlantis/.ssh/ssh-key.pem"
}