terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.5.0"
    }

    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.5.1"
    }

    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.22.1"
    }
  }
}

provider "linode" {
  token = var.linode_token
}

locals {
  primary_domain = "devopsforge.ovh"
  cluster_name = "prod-1"
  linode_region = "us-sea"
}

module "linode_nomad_cluster" {
  source = "./modules/linode_nomad_cluster"

  providers = {
    linode = linode
  }

  linode_region = local.linode_region

  network_cidr              = "10.82.120.0/24"
  nomad_server_network_cidr = "10.82.120.0/26"
  nomad_client_network_cidr = "10.82.120.192/26"

  cluster_name = local.cluster_name

  disable_api_ssl_verification = "false"

  server_count = 1

  server_config = {
    image       = "linode/ubuntu24.04"
    server_type = "g6-nanode-1"
    external_volume_size = 20
  }

  cluster_authorized_ssh_keys = var.cluster_authorized_ssh_keys

  nodegroups = [
    {
      name         = "default-workload"
      client_count = 1
      client_image = "linode/ubuntu24.04"
      node_type    = "g6-nanode-1"
    },
  ]
}

output "consul_admin_token_secret" {
  value     = module.linode_nomad_cluster.consul_admin_token_secret
}

output "consul_ca_cert" {
  value = module.linode_nomad_cluster.consul_ca_cert
  sensitive = true
}

output "consul_cli_cert" {
  value     = module.linode_nomad_cluster.consul_cli_cert
  sensitive = true
}

output "consul_cli_key" {
  value     = module.linode_nomad_cluster.consul_cli_key
  sensitive = true
}

output "nomad_ca_cert" {
  value = module.linode_nomad_cluster.nomad_ca_cert
  sensitive = true
}

output "nomad_cli_cert" {
  value     = module.linode_nomad_cluster.nomad_cli_cert
  sensitive = true
}

output "nomad_cli_key" {
  value     = module.linode_nomad_cluster.nomad_cli_key
  sensitive = true
}

output "load_balancer_ip" {
  value = module.linode_nomad_cluster.load_balancer_ip
}

output "instructions" {
  value = <<EOF
## Export Consul and Nomad CLI certs (if client ssl verification is enabled):

make output-tls

You can access Consul UI at https://${module.linode_nomad_cluster.load_balancer_ip}:8501 and Nomad UI at https://${module.linode_nomad_cluster.load_balancer_ip}:4646

## To run a TLS proxy:
make start-proxy

Access Consul UI at http://localhost:8501 and Nomad UI at http://localhost:4646

## Stop TLS proxy with:
make stop-proxy

## To Access Consul CLI:
export CONSUL_CACERT="$(pwd)/certs/consul_ca.pem"
export CONSUL_CLIENT_CERT="$(pwd)/certs/consul_cli.crt"
export CONSUL_CLIENT_KEY="$(pwd)/certs/consul_cli.key"
export CONSUL_HTTP_ADDR="https://${module.linode_nomad_cluster.load_balancer_ip}:8501"
export CONSUL_HTTP_TOKEN=$(terraform output -raw consul_admin_token_secret)

## Get Nomad Boootstrap Token from Consul KV Store

consul kv get nomad_bootstrap_token

## To Access Nomad CLI:
export NOMAD_CACERT="$(pwd)/certs/nomad_ca.pem"
export NOMAD_CLIENT_CERT="$(pwd)/certs/nomad_cli.crt"
export NOMAD_CLIENT_KEY="$(pwd)/certs/nomad_cli.key"
export NOMAD_ADDR="https://${module.linode_nomad_cluster.load_balancer_ip}:4646"
export NOMAD_TOKEN=$(consul kv get nomad_bootstrap_token)

nomad node status
EOF
}
