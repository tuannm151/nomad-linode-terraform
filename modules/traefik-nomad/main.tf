terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = ">= 2.4"
    }
    consul = {
      source  = "hashicorp/consul"
      version = ">= 2.21"
    }
  }
}

resource "consul_acl_policy" "traefik" {
  name        = "traefik"
  description = "Allow traefik to access consul catalog"

  rules = <<-RULE
      key_prefix "traefik" {
        policy = "write"
      }

      service "traefik" {
        policy = "write"
      }

      agent_prefix "" {
        policy = "read"
      }

      node_prefix "" {
        policy = "read"
      }

      service_prefix "" {
        policy = "read"
      }
    RULE
}

resource "consul_acl_token" "traefik" {
  description = "Traefik"
  policies    = [consul_acl_policy.traefik.name]
}

data "consul_acl_token_secret_id" "traefik" {
  accessor_id = consul_acl_token.traefik.id
}

resource "nomad_acl_policy" "traefik_read_tls" {
  name        = "traefik-read-tls"
  description = "Allow traefik to read TLS variables"

  job_acl {
    namespace = var.namespace
    job_id = nomad_job.traefik.id
  }

  rules_hcl = <<-EOT
namespace "${var.namespace}" {
  policy = "read"

  variables {
    path "tls/*" {
      capabilities = ["list", "read"]
    }
  }
}
EOT
}

resource "nomad_variable" "nomad_client_tls" {
  namespace = var.namespace
  path = "tls/clients/nomad"

  items = {
    cert = var.nomad_client_tls_cert
    key  = var.nomad_client_tls_key
    ca   = var.nomad_ca_cert
  }
}

resource "nomad_variable" "consul_client_tls" {
  namespace = var.namespace
  path = "tls/clients/consul"

  items = {
    cert = var.consul_client_tls_cert
    key  = var.consul_client_tls_key
    ca   = var.consul_ca_cert
  }
}

resource "nomad_variable" "traefik" {
  path = "nomad/jobs/traefik"
  namespace = var.namespace

  items = {
    TRAEFIK_CONSUL_CATALOG_TOKEN = data.consul_acl_token_secret_id.traefik.secret_id
  }

  lifecycle {
    ignore_changes = [items]
  }
}

resource "nomad_job" "traefik" {
  jobspec = file("${path.module}/traefik.nomad.hcl")

  hcl2 {
    vars = {
      namespace              = var.namespace
      nomad_domain           = "${var.nomad_domain}"
      consul_domain          = "${var.consul_domain}"
      traefik_version        = var.traefik_version
      traefik_trusted_ips_forward_headers = join(",", var.traefik_trusted_ips_forward_headers)
    }
  }
}
