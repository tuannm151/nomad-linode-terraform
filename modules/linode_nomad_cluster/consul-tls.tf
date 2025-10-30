### CONSUL CA CERTIFICATE ###
resource "tls_private_key" "consul_ca" {
  algorithm   = "RSA"
  rsa_bits = "2048"
}

resource "tls_self_signed_cert" "consul_ca" {
  is_ca_certificate = true
  validity_period_hours = var.tls_validity_period_hours

  private_key_pem = tls_private_key.consul_ca.private_key_pem

  subject {
    common_name = "consul-ca"
  }

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

### CONSUL SERVER CERTIFICATE ###
resource "tls_private_key" "consul_server" {
  count = var.server_count
  algorithm   = "RSA"
  rsa_bits = "2048"
}

resource "tls_cert_request" "consul_server" {
  count = var.server_count

  private_key_pem = tls_private_key.consul_server[count.index].private_key_pem

  ip_addresses = [
    "127.0.0.1",
    linode_nodebalancer.cluster_lb.ipv4
  ]

  dns_names = concat(
    [
      "localhost",
      "consul.service.consul",
      "server.${var.cluster_name}.consul"
    ],
    var.consul_server_additional_dns_names
  )

  subject {
    common_name = "server.${var.cluster_name}.consul"
  }
}

resource "tls_locally_signed_cert" "consul_server" {
  count = var.server_count
  cert_request_pem   = tls_cert_request.consul_server[count.index].cert_request_pem

  ca_private_key_pem = tls_private_key.consul_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.consul_ca.cert_pem

  validity_period_hours = var.tls_validity_period_hours

  allowed_uses = [
    "client_auth",
    "server_auth"
  ]
}

output "consul_ca_cert" {
    value = tls_self_signed_cert.consul_ca.cert_pem
    sensitive = true
}

