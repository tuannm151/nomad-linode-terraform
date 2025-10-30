### CONSUL CLI CERTIFICATES ###
resource "tls_private_key" "consul_cli" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "consul_cli" {
  private_key_pem = tls_private_key.consul_cli.private_key_pem

  dns_names = concat(
    [
      "localhost",
      "consul.service.consul",
    ],
    var.consul_server_additional_dns_names
  )

  subject {
    common_name = "server.${var.cluster_name}.consul"
  }
}

resource "tls_locally_signed_cert" "consul_cli" {
  cert_request_pem   = tls_cert_request.consul_cli.cert_request_pem
  ca_private_key_pem = tls_private_key.consul_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.consul_ca.cert_pem

  validity_period_hours = var.tls_validity_period_hours

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
  ]
}

# Output the certificates for local use
output "consul_cli_cert" {
  value     = tls_locally_signed_cert.consul_cli.cert_pem
  sensitive = true
}

output "consul_cli_key" {
  value     = tls_private_key.consul_cli.private_key_pem
  sensitive = true
}
