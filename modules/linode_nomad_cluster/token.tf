resource "random_uuid" "consul_admin_token_id" {}

resource "random_uuid" "consul_admin_token_secret" {}

resource "random_uuid" "consul_agent_dns_token_id" {}

resource "random_uuid" "consul_agent_dns_token_secret" {}

resource "random_uuid" "nomad_server_consul_token_id" {}

resource "random_uuid" "nomad_server_consul_token_secret" {}

resource "random_uuid" "nomad_client_consul_token_id" {}

resource "random_uuid" "consul_nomad_client_token_secret" {}

resource "random_id" "nomad-gossip-key" {
  byte_length = 32
}

resource "random_id" "consul-gossip-key" {
  byte_length = 32
}

output "consul_gossip_encryption_key" {
    value = random_id.consul-gossip-key.b64_std
}

output "consul_agent_dns_token_secret" {
    value = random_uuid.consul_agent_dns_token_secret.result
}

output "consul_nomad_client_token_secret" {
    value = random_uuid.consul_nomad_client_token_secret.result
}

output "consul_admin_token_secret" {
    value = random_uuid.consul_admin_token_secret.result
}
