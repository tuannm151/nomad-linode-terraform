locals {
  client_configs = flatten([
    for group in var.nodegroups : [
      for i in range(group.client_count) : {
        name                 = "${group.name}-client-${i}"
        client_image         = group.client_image
        external_volume_size = group.external_volume_size
        node_type            = group.node_type
        node_pool            = group.node_pool
        nomad_apt_version    = group.nomad_apt_version
        consul_apt_version   = group.consul_apt_version
        cni_version          = group.cni_version
        recursors            = group.recursors
        tags = concat(local.common_tags, group.common_tags, [
          "nodegroup=${group.name}",
          "nodepool=${group.node_pool}",
          "nomad_instance_role=client"
        ])
      }
    ]
  ])
}

resource "linode_instance" "client" {
  for_each = {
    for key, config in local.client_configs : config.name => config
  }

  label  = each.value.name
  region = var.linode_region
  type   = each.value.node_type
  image  = each.value.client_image

  authorized_keys = var.cluster_authorized_ssh_keys

  tags = each.value.tags

  private_ip = true

  firewall_id = linode_firewall.nodegroup_default_firewall.id

  interface {
    purpose = "public"
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.client_subnet.id
    ipv4 {
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
              nomad_apt_version  = each.value.nomad_apt_version
              consul_apt_version = each.value.consul_apt_version
              cni_version        = each.value.cni_version
              role               = "client"
            }
          )
        },
        {
          path = "/opt/nomad/nomad-client-setup.sh",
          content = templatefile("${path.module}/scripts/nomad-client-setup.sh",
            {
              datacenter_name          = var.cluster_name
              node_name                = each.value.name
              recursors                = "[${join(", ", [for ip in each.value.recursors : format("%q", ip)])}]"
              nomad_node_pool          = each.value.node_pool
              retry_join               = "[${join(", ", [for i in local.nomad_servers_private_ipv4 : format("%q", i)])}]"
              nomad_client_subnet_cidr = var.nomad_client_network_cidr

              consul_agent_dns_token_secret    = random_uuid.consul_agent_dns_token_secret.result
              consul_nomad_client_token_secret = random_uuid.consul_nomad_client_token_secret.result
              consul_ca                        = tls_self_signed_cert.consul_ca.cert_pem
              nomad_ca                         = tls_self_signed_cert.nomad_ca.cert_pem
              global_client_nomad_cert         = tls_locally_signed_cert.nomad_client_global.cert_pem
              global_client_nomad_key          = tls_private_key.nomad_client_global.private_key_pem

              consul_gossip_encryption_key = random_id.consul-gossip-key.b64_std
            }
          ),
        }
      ],
      runcmd = [
        "bash /opt/nomad/nomad-installation.sh",
        "bash /opt/nomad/nomad-client-setup.sh"
      ]
    })))
  }

  lifecycle {
    ignore_changes = [
      authorized_keys
    ]
  }
}

resource "linode_volume" "client" {
  for_each = {
    for key, config in local.client_configs : config.name => config if config.external_volume_size > 0
  }

  label = each.value.name
  size  = each.value.external_volume_size

  tags = each.value.tags

  linode_id = linode_instance.client[each.key].id
  region    = var.linode_region
}

