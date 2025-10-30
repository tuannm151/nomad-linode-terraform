variable "nomad_domain" {
    description = "The domain for Nomad UI and API"
    type        = string
    default     = ""
}

variable "consul_domain" {
    description = "The domain for Consul UI and API"
    type        = string
    default     = ""
}

variable "traefik_version" {
    description = "The version of Traefik to deploy."
    type        = string
    default     = "latest"
}

variable "traefik_trusted_ips_forward_headers" {
    description = "The trusted IPs/CIDRs for the Forwarded Headers middleware"
    type        = list(string)
    default     = []
}

variable "namespace" {
    description = "The Nomad namespace to deploy Traefik into"
    type        = string
    default     = "default"
}


# TLS certificates for Traefik reverse proxy to communicate with Nomad and Consul API over mTLS
variable "nomad_client_tls_cert" {
  description = "The Nomad client TLS certificate"
  type        = string
}

variable "nomad_client_tls_key" {
  description = "The Nomad client TLS key"
  type        = string
}

variable "nomad_ca_cert" {
  description = "The Nomad CA certificate"
  type        = string
}

variable "consul_client_tls_cert" {
  description = "The Consul client TLS certificate"
  type        = string
}

variable "consul_client_tls_key" {
  description = "The Consul client TLS key"
  type        = string
}

variable "consul_ca_cert" {
  description = "The Consul CA certificate"
  type        = string
}