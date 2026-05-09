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

variable "es_install_dir" {
  description = "Elasticsearch installation directory on the remote VM"
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
  description = "process user that will run elasticsearch service"
  type        = string
  default     = "vhv_admin"
}

variable "elasticsearch_package" {
  description = "Name of the Elasticsearch package"
  type        = string
  default     = "elasticsearch-8.17.3-linux-x86_64.tar.gz"
}

variable "elasticsearch_version" {
  description = "Version of the Elasticsearch package"
  type        = string
  default     = "8.17.3"
}

variable "ssh_key" {
  description = "SSH private key in Atlantis Pod"
  type        = string
  default     = "/home/vhv_admin/.ssh/id_ed25519"
}