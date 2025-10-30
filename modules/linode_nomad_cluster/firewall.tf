resource "linode_firewall" "cluster_server_firewall" {
  label           = "${var.cluster_name}-server"
  tags            = local.common_tags
  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  # ICMP inbound
  inbound {
    label    = "allow-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4 = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips,
    )
    description = "Allow inbound ICMP (ping) for diagnostics and monitoring"
  }

  # SSH inbound
  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4 = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips
    )
    description = "Allow inbound SSH access for management"
  }

  # Consul inbound rules
  inbound {
    label    = "consul-api"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8501"
    ipv4 = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips
    )
    description = "Allow inbound Consul API traffic (TCP 8501)"
  }

  inbound {
    label    = "consul-grpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8503"
    ipv4 = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips
    )
    description = "Allow inbound Consul gRPC traffic (TCP 8503)"
  }

  inbound {
    label    = "consul-server-rpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8300"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Consul server RPC (TCP 8300)"
  }

  inbound {
    label    = "consul-serf-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8301"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Consul Serf LAN (TCP 8301)"
  }

  inbound {
    label    = "consul-serf-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "8301"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Consul Serf LAN (UDP 8301)"
  }

  # Nomad inbound rules
  inbound {
    label    = "nomad-api"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "4646"
    ipv4 = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips
    )
    description = "Allow inbound Nomad API traffic (TCP 4646)"
  }

  inbound {
    label    = "nomad-rpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "4647"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Nomad RPC traffic (TCP 4647)"
  }

  inbound {
    label    = "nomad-serf"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "4648"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Nomad Serf LAN (TCP 4648)"
  }

  inbound {
    label    = "nomad-serf-wan-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "4648"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Nomad Serf WAN (TCP 4648)"
  }

  inbound {
    label    = "nomad-serf-wan-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "4648"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Nomad Serf WAN (UDP 4648)"
  }
}

resource "linode_firewall" "nodegroup_default_firewall" {
  label = "${var.cluster_name}-ng"
  tags  = local.common_tags

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  # ICMP inbound
  inbound {
    label    = "allow-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4 = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips,
    )
    description = "Allow inbound ICMP (ping) for diagnostics and monitoring"
  }

  # HTTP/HTTPS inbound
  inbound {
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
    description = "Allow inbound HTTP traffic (TCP 80) from anywhere"
  }

  inbound {
    label    = "allow-https"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "443"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
    description = "Allow inbound HTTPS traffic (TCP 443) from anywhere"
  }

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4 = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips
    )
    description = "Allow inbound SSH access for management"
  }

  # Internal network traffic
  inbound {
    label    = "allow-internal-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4 = concat(
      [var.nomad_client_network_cidr],
    )
  description = "Allow all inbound TCP traffic between client nodes"
  }

  inbound {
    label    = "allow-internal-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4 = concat(
      [var.nomad_client_network_cidr],
    )
  description = "Allow all inbound UDP traffic between client nodes"
  }

  ## Consul/Nomad inbound rules
  inbound {
    label    = "consul-api"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8501"
    ipv4     = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips
    )
    description = "Allow inbound Consul API traffic (TCP 8501)"
  }

  inbound {
    label    = "consul-grpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8503"
    ipv4     = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips
    )
    description = "Allow inbound Consul gRPC traffic (TCP 8503)"
  }

  inbound {
    label    = "consul-serf-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8301"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Consul Serf LAN (TCP 8301)"
  }

  inbound {
    label    = "consul-serf-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "8301"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Consul Serf LAN (UDP 8301)"
  }

  inbound {
    label    = "nomad-api"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "4646"
    ipv4     = concat(
      [var.network_cidr],
      var.firewall_cluster_management_source_ips
    )
    description = "Allow inbound Nomad API traffic (TCP 4646)"
  }

  inbound {
    label    = "nomad-rpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "4647"
    ipv4 = concat(
      [var.network_cidr],
    )
    description = "Allow inbound Nomad RPC traffic (TCP 4647)"
  }
}

output "nodegroup_default_firewall_id" {
  value = linode_firewall.nodegroup_default_firewall.id
}
