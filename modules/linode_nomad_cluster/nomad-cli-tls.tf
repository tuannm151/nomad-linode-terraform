### NOMAD CLI CLIENT CERTIFICATE ###
resource "tls_private_key" "nomad_cli" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "nomad_cli" {
  private_key_pem = tls_private_key.nomad_cli.private_key_pem

  dns_names = concat(
    [
      "localhost",
      "nomad.service.consul",
    ],
    var.nomad_server_additional_dns_names
  )

  subject {
    common_name = "server.${var.cluster_name}.nomad"
  }
}

resource "tls_locally_signed_cert" "nomad_cli" {
  cert_request_pem   = tls_cert_request.nomad_cli.cert_request_pem
  ca_private_key_pem = tls_private_key.nomad_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.nomad_ca.cert_pem

  validity_period_hours = var.tls_validity_period_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth"
  ]
}

# Output the certificates for local use
output "nomad_cli_cert" {
  value     = tls_locally_signed_cert.nomad_cli.cert_pem
  sensitive = true
}

output "nomad_cli_key" {
  value     = tls_private_key.nomad_cli.private_key_pem
  sensitive = true
}
