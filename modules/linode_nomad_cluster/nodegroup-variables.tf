variable "nodegroups" {
  description = "The list of nodegroups to create"
  type = list(object({
    name                 = string
    client_count         = number
    client_image         = string
    external_volume_size = optional(number, 0)
    node_type            = string
    recursors            = optional(list(string), ["1.1.1.1", "1.0.0.1"])
    node_pool            = optional(string, "default")
    nomad_apt_version    = optional(string, "")
    consul_apt_version   = optional(string, "")
    cni_version          = optional(string, "")
    common_tags          = optional(list(string), [])
  }))

  validation {
    condition     = length([for n in var.nodegroups : n.name]) == length(distinct([for n in var.nodegroups : n.name]))
    error_message = "Nodegroup names must be unique"
  }
}
