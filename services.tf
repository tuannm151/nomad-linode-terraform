provider "consul" {
  address  = "https://${module.linode_nomad_cluster.load_balancer_ip}:8501"
  token    = module.linode_nomad_cluster.consul_admin_token_secret
  ca_pem   = module.linode_nomad_cluster.consul_ca_cert
  cert_pem = module.linode_nomad_cluster.consul_cli_cert
  key_pem  = module.linode_nomad_cluster.consul_cli_key
}

resource "null_resource" "wait_consul_ready" {
  provisioner "local-exec" {
    command = <<EOT
      until nc -z ${module.linode_nomad_cluster.load_balancer_ip} 8501; do
        echo "Waiting for Consul to be ready..."
        sleep 5
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [module.linode_nomad_cluster]
}

data "consul_keys" "nomad_bootstrap_token" {
  key {
    name = "nomad_bootstrap_token"
    path = "nomad_bootstrap_token"
  }

  depends_on = [null_resource.wait_consul_ready]
}

provider "nomad" {
  address   = "https://${module.linode_nomad_cluster.load_balancer_ip}:4646"
  secret_id = data.consul_keys.nomad_bootstrap_token.var.nomad_bootstrap_token
  ca_pem    = module.linode_nomad_cluster.nomad_ca_cert
  cert_pem  = module.linode_nomad_cluster.nomad_cli_cert
  key_pem   = module.linode_nomad_cluster.nomad_cli_key
}

resource "null_resource" "wait_nomad_ready" {
  provisioner "local-exec" {
    command = <<EOT
      until nc -z ${module.linode_nomad_cluster.load_balancer_ip} 4646; do
        echo "Waiting for Nomad to be ready..."
        sleep 5
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [data.consul_keys.nomad_bootstrap_token]
}

resource "nomad_namespace" "system" {
  name = "system"
}

module "traefik-nomad" {
  source = "./modules/traefik-nomad"

  providers = {
    consul = consul
    nomad  = nomad
  }

  nomad_domain  = "nomad-${local.cluster_name}.${local.primary_domain}"
  consul_domain = "consul-${local.cluster_name}.${local.primary_domain}"

  namespace = nomad_namespace.system.name
  nomad_ca_cert = module.linode_nomad_cluster.nomad_ca_cert
  nomad_client_tls_cert = module.linode_nomad_cluster.nomad_cli_cert
  nomad_client_tls_key  = module.linode_nomad_cluster.nomad_cli_key
  consul_ca_cert = module.linode_nomad_cluster.consul_ca_cert
  consul_client_tls_cert = module.linode_nomad_cluster.consul_cli_cert
  consul_client_tls_key  = module.linode_nomad_cluster.consul_cli_key

  depends_on = [ null_resource.wait_nomad_ready ]
}

module "linode-nomad-csi" {
  source = "./modules/linode-nomad-csi"

  providers = {
    nomad = nomad
  }

  namespace = nomad_namespace.system.name
  linode_region = local.linode_region
  linode_volume_token = var.linode_volume_token

  depends_on = [ null_resource.wait_nomad_ready ]
}
