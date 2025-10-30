data "linode_instances" "bootstrap" {
  filter {
    name   = "tags"
    values = ["bootstrap_server"]
  }

  filter {
    name   = "tags"
    values = ["cluster=${var.cluster_name}"]
  }
}

locals {
  common_tags = concat(
    var.common_tags,
    ["cluster=${var.cluster_name}"]
  )
  nomad_servers_private_ipv4 = [for i in range(var.server_count) : cidrhost(var.nomad_server_network_cidr, i + 2)]
  bootstrap_server_labels    = data.linode_instances.bootstrap.instances.*.label
}

resource "linode_instance" "server" {
  count  = var.server_count
  label  = "${var.cluster_name}-server-${count.index}"
  region = var.linode_region
  type   = var.server_config.server_type
  image  = var.server_config.image

  authorized_keys = var.cluster_authorized_ssh_keys

  tags = concat(
    local.common_tags,
    [
      "nomad_instance_role=server"
    ],
    length(data.linode_instances.bootstrap.instances) == 0 || contains(local.bootstrap_server_labels, "${var.cluster_name}-server-${count.index}") ? [
      "bootstrap_server"
    ] : []
  )

  private_ip = true

  firewall_id = linode_firewall.cluster_server_firewall.id

  interface {
    purpose = "public"
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.server_subnet.id
    ipv4 {
      vpc = local.nomad_servers_private_ipv4[count.index]
      nat_1_1 = "any"
    }
    primary = true
  }

  placement_group {
    id = linode_placement_group.nomad_nodes.id
  }

  metadata {
    user_data = base64gzip(format("%s\n%s", "#cloud-config", yamlencode({
      package_update             = true,
      package_upgrade            = true,
      package_reboot_if_required = true,
      write_files = [
        {
          path = "/opt/nomad/nomad-installation.sh"
          content = templatefile("${path.module}/scripts/nomad-installation.sh",
            {
              nomad_apt_version  = var.nomad_server_apt_version
              consul_apt_version = var.consul_server_apt_version
              cni_version        = var.cni_version
              role               = "server"
            }
          )
        },
        {
          path = "/opt/nomad/nomad-server-setup.sh",
          content = templatefile("${path.module}/scripts/nomad-server-setup.sh",
            {
              datacenter_name          = var.cluster_name
              node_name                = "${var.cluster_name}-server-${count.index}"
              recursors                = "[${join(", ", [for ip in var.server_config.recursors : format("%q", ip)])}]"
              nomad_server_subnet_cidr = var.nomad_server_network_cidr
              bootstrap_expect         = length(data.linode_instances.bootstrap.instances) == 0 ? var.server_count : length(data.linode_instances.bootstrap.instances)
              retry_join               = "[${join(", ", [for i in local.nomad_servers_private_ipv4 : format("%q", i)])}]"
              disable_api_ssl_verification = var.disable_api_ssl_verification

              consul_ca                 = tls_self_signed_cert.consul_ca.cert_pem
              consul_server_private_key = tls_private_key.consul_server[count.index].private_key_pem
              consul_server_cert        = tls_locally_signed_cert.consul_server[count.index].cert_pem

              nomad_ca                 = tls_self_signed_cert.nomad_ca.cert_pem
              global_server_nomad_cert = tls_locally_signed_cert.nomad_server_global.cert_pem
              global_server_nomad_key  = tls_private_key.nomad_server_global.private_key_pem

              consul_admin_token_id            = random_uuid.consul_admin_token_id.result
              consul_admin_token_secret        = random_uuid.consul_admin_token_secret.result
              consul_agent_dns_token_id        = random_uuid.consul_agent_dns_token_id.result
              consul_agent_dns_token_secret    = random_uuid.consul_agent_dns_token_secret.result
              nomad_server_consul_token_id     = random_uuid.nomad_server_consul_token_id.result
              nomad_server_consul_token_secret = random_uuid.nomad_server_consul_token_secret.result
              nomad_client_consul_token_id     = random_uuid.nomad_client_consul_token_id.result
              consul_nomad_client_token_secret = random_uuid.consul_nomad_client_token_secret.result

              consul_gossip_encryption_key = random_id.consul-gossip-key.b64_std
              nomad_gossip_encryption_key  = random_id.nomad-gossip-key.b64_std
            }
          ),
        }
      ],
      runcmd = [
        "bash /opt/nomad/nomad-installation.sh",
        "bash /opt/nomad/nomad-server-setup.sh"
      ]
      }))
    )
  }

  lifecycle {
    ignore_changes = [
      authorized_keys
    ]
  }
}

resource "linode_volume" "nomad_server_volume" {
  count = var.server_config.external_volume_size > 0 ? var.server_count : 0

  label     = "${var.cluster_name}-server-${count.index}"
  size      = var.server_config.external_volume_size
  region    = var.linode_region
  linode_id = linode_instance.server[count.index].id
  tags = concat(
    local.common_tags,
    [
      "nomad_instance_role=server"
    ]
  )
}

