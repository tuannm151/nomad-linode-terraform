# add linode node_balancer
resource "linode_nodebalancer" "cluster_lb" {
  region = var.linode_region
  label = "${var.cluster_name}-lb"
  tags = local.common_tags
}

resource "linode_nodebalancer_config" "nomad_http" {
  nodebalancer_id = linode_nodebalancer.cluster_lb.id
  port = 80
  protocol = "tcp"
  algorithm = "roundrobin"
  check = "connection"
  check_path = "/"
  check_interval = 15
  check_timeout = 5
  check_attempts = 3
}

resource "linode_nodebalancer_config" "nomad_https" {
  nodebalancer_id = linode_nodebalancer.cluster_lb.id
  port = 443
  protocol = "tcp"
  algorithm = "roundrobin"
  check = "connection"
  check_path = "/"
  check_interval = 15
  check_timeout = 5
  check_attempts = 3
}

resource "linode_nodebalancer_config" "nomad_api" {
  nodebalancer_id = linode_nodebalancer.cluster_lb.id
  port = 4646
  protocol = "tcp"
  algorithm = "roundrobin"
  check = "connection"
  check_path = "/"
  check_interval = 15
  check_timeout = 5
  check_attempts = 3
}

resource "linode_nodebalancer_config" "consul_api" {
  nodebalancer_id = linode_nodebalancer.cluster_lb.id
  port = 8501
  protocol = "tcp"
  algorithm = "roundrobin"
  check = "connection"
  check_path = "/"
  check_interval = 15
  check_timeout = 5
  check_attempts = 3
}

resource "linode_nodebalancer_node" "nomad_client_http" {
  for_each = { for idx, instance in linode_instance.client : idx => instance }

  nodebalancer_id = linode_nodebalancer.cluster_lb.id
  label           = "${each.value.label}"
  config_id       = linode_nodebalancer_config.nomad_http.id
  address         = "${each.value.private_ip_address}:80"
}

resource "linode_nodebalancer_node" "nomad_client_https" {
  for_each = { for idx, instance in linode_instance.client : idx => instance }

  nodebalancer_id = linode_nodebalancer.cluster_lb.id
  label           = "${each.value.label}"
  config_id       = linode_nodebalancer_config.nomad_https.id
  address         = "${each.value.private_ip_address}:443"
}

resource "linode_nodebalancer_node" "nomad_api" {
  for_each = { for idx, instance in linode_instance.server : idx => instance }

  nodebalancer_id = linode_nodebalancer.cluster_lb.id
  label           = "${each.value.label}"
  config_id       = linode_nodebalancer_config.nomad_api.id
  address         = "${each.value.private_ip_address}:4646"
}

resource "linode_nodebalancer_node" "consul_api" {
  for_each = { for idx, instance in linode_instance.server : idx => instance }

  nodebalancer_id = linode_nodebalancer.cluster_lb.id
  label           = "${each.value.label}"
  config_id       = linode_nodebalancer_config.consul_api.id
  address         = "${each.value.private_ip_address}:8501"
}

output "load_balancer_ip" {
  value = linode_nodebalancer.cluster_lb.ipv4
}