variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "common_tags" {
  type    = list(string)
  default = ["managed_by=terraform"]
}

variable "nomad_server_apt_version" {
  description = "The version of Nomad to install using apt package manager for Nomad server. Leave empty to install the latest version"
  type        = string
  default     = ""
}

variable "consul_server_apt_version" {
  description = "The version of Consul to install using apt package manager for Consul server. Leave empty to install the latest version"
  type        = string
  default     = ""
}

variable "cni_version" {
  description = "The version of CNI to install"
  type        = string
  default     = "1.2.3"
}

variable "linode_region" {
  description = "The region for the Linode Nomad cluster"
  type        = string
}

variable "network_cidr" {
  description = "The CIDR for the cluster in the Linode Cloud"
  type        = string
}

variable "nomad_server_network_cidr" {
  description = "The CIDR for the Nomad servers subnet in the Linode Cloud. Must be a subnet of the network_cidr"
  type        = string
}

variable "nomad_client_network_cidr" {
  description = "The CIDR for the Nomad clients subnet in the Linode Cloud. Must be a subnet of the network_cidr"
  type        = string
}

variable "server_count" {
  description = "The number of Nomad bootstrap servers to create"
  type        = number

  validation {
    condition     = var.server_count % 2 == 1
    error_message = "The number of servers must be an odd number (e.g. 1, 3, 5, 7)"
  }
}

variable "server_config" {
  description = "The configuration for the Nomad bootstrap servers"

  type = object({
    server_type          = string
    external_volume_size = optional(number, 0)
    image                = optional(string, "linode/ubuntu24.04")
    recursors            = optional(list(string), ["1.1.1.1", "1.0.0.1"])
  })
}

variable "cluster_authorized_ssh_keys" {
  description = "The SSH authorized keys to add to the Nomad servers"
  type        = list(string)
  default     = []
}

variable "disable_api_ssl_verification" {
  description = "Whether to disable api ssl verification (skip mTLS verification) for Nomad client and Consul client"
  type        = bool
  default     = false
}

variable "consul_server_additional_dns_names" {
  description = "Additional DNS names to include in the Consul server TLS certificate"
  type        = list(string)
  default     = []
}

variable "nomad_server_additional_dns_names" {
  description = "Additional DNS names to include in the Nomad server TLS certificate"
  type        = list(string)
  default     = []
}

variable "tls_validity_period_hours" {
  description = "The validity period of the TLS certificates in hours"
  type        = number
  default     = 175200 # 20 years
}

variable "firewall_cluster_management_source_ips" {
  description = "List of IPs or CIDRs that are allowed to manage the cluster (via SSH, Consul API, Nomad API). Default to [\"0.0.0.0/0\"]"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}


