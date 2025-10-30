### NOMAD CA CERTIFICATE ###
resource "tls_private_key" "nomad_ca" {
  algorithm   = "RSA"
  rsa_bits = "2048"
}

resource "tls_self_signed_cert" "nomad_ca" {
  is_ca_certificate = true
  validity_period_hours = var.tls_validity_period_hours

  private_key_pem = tls_private_key.nomad_ca.private_key_pem

  subject {
    common_name = "nomad-ca"
  }

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

### NOMAD SERVER CERTIFICATE ###
resource "tls_private_key" "nomad_server_global" {
  algorithm   = "RSA"
  rsa_bits = "2048"
}

resource "tls_cert_request" "nomad_server_global" {
  private_key_pem = tls_private_key.nomad_server_global.private_key_pem

  ip_addresses = [
    "127.0.0.1",
    linode_nodebalancer.cluster_lb.ipv4
  ]

  dns_names = concat(
    [
      "localhost",
      "nomad.service.consul",
      "server.global.nomad"
    ],
    var.nomad_server_additional_dns_names
  )

  subject {
    common_name = "server.global.nomad"
  }
}

resource "tls_locally_signed_cert" "nomad_server_global" {
  cert_request_pem   = tls_cert_request.nomad_server_global.cert_request_pem

  ca_private_key_pem = tls_private_key.nomad_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.nomad_ca.cert_pem

  validity_period_hours = var.tls_validity_period_hours

  allowed_uses = [
    "client_auth",
    "server_auth",
  ]
}

### NOMAD CLIENT CERTIFICATE ###
resource "tls_private_key" "nomad_client_global" {
  algorithm   = "RSA"
  rsa_bits = "2048"
}

resource "tls_cert_request" "nomad_client_global" {
  private_key_pem = tls_private_key.nomad_client_global.private_key_pem

  ip_addresses = [
    "127.0.0.1",
  ]

  dns_names = concat(
    [
      "localhost",
      "client.global.nomad"
    ],
  )

  subject {
    common_name = "client.global.nomad"
  }
}

resource "tls_locally_signed_cert" "nomad_client_global" {
  cert_request_pem   = tls_cert_request.nomad_client_global.cert_request_pem

  ca_private_key_pem = tls_private_key.nomad_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.nomad_ca.cert_pem

  validity_period_hours = var.tls_validity_period_hours

  allowed_uses = [
    "client_auth",
  ]
}

output "nomad_ca_cert" {
    value = tls_self_signed_cert.nomad_ca.cert_pem
    sensitive = true
}

output "nomad_client_global_cert" {
    value = tls_locally_signed_cert.nomad_client_global.cert_pem
    sensitive = true
}

output "nomad_client_global_private_key" {
    value = tls_private_key.nomad_client_global.private_key_pem
    sensitive = true
}
 
