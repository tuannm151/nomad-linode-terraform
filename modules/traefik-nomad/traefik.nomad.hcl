job "traefik" {
  type = "system"
  node_pool = "all"
  namespace = "${var.namespace}"

  group "traefik" {

    network {
      port "http" {
        static = 80
        host_network = "public"
      }

      port "https" {
        static = 443
        host_network = "public"
      }
    }

    service {
      name = "traefik"

      port = "http"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "15s"
        timeout  = "3s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:${var.traefik_version}"

        volumes = [
          "local/traefik.yml:/etc/traefik/traefik.yml",
          "local/dynamic.yml:/etc/traefik/dynamic.yml"
        ]

        ports = [
          "http",
          "https"
        ]

        # run the load-certs script before starting traefik
        entrypoint = ["/bin/sh", "-c"]
        args = ["sh local/load-certs.sh && traefik"]
      }

      template {
        data = <<EOH
{{ range nomadVarListSafe "tls" }}
filedir=local/{{ .Path }}
mkdir -p $filedir
{{ with nomadVar .Path }}
echo "{{ .cert }}" > $filedir/cert.crt
echo "{{ .key }}" > $filedir/priv.key
echo "{{ .ca }}" > $filedir/ca.crt
{{ end }}
{{ end }}
EOH
        destination = "local/load-certs.sh"
      }

      template {
        data = <<EOF
api:
  dashboard: false
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    forwardedHeaders:
      trustedIPs:
        - 127.0.0.1/32
        - 10.0.0.0/8
        {{- if env "TRAEFIK_FORWARD_HEADERS_TRUSTED_IPS" }}
        {{- range $element := split "," (env "TRAEFIK_FORWARD_HEADERS_TRUSTED_IPS") }}
        - {{ $element }}
        {{- end }}
        {{- end }}

  metrics:
    address: ":8082"

providers:
  consulCatalog:
    prefix: "traefik"
    exposedByDefault: false
    endpoint:
      address: consul.service.consul:8501
      scheme: "https"
      token: "{{ env "TRAEFIK_CONSUL_CATALOG_TOKEN" }}"
      tls:
        ca: local/tls/clients/consul/ca.crt
        cert: local/tls/clients/consul/cert.crt
        key: local/tls/clients/consul/priv.key
  file:
    directory: /etc/traefik
    watch: true
EOF
        destination = "local/traefik.yml"
      }

      template {
        data = <<EOF
http:
  {{- if or (ne "${var.nomad_domain}" "") (ne "${var.consul_domain}" "") }}
  routers:
    {{- if "${var.nomad_domain}" }}
    nomad:
      rule: Host(`${var.nomad_domain}`)
      entryPoints:
        - websecure
      service: nomad
      tls: {}
    {{- end }}
    {{- if "${var.consul_domain}" }}
    consul:
      rule: Host(`${var.consul_domain}`)
      entryPoints:
        - websecure
      service: consul
      tls: {}
    {{- end }}
  {{- end }}
  services:
    nomad:
      loadBalancer:
        servers:
          - url: "https://nomad.service.consul:4646/"
        serversTransport: nomad
    consul:
      loadBalancer:
        servers:
        - url: "https://consul.service.consul:8501/"
        serversTransport: consul
  serversTransports:
    nomad:
      rootCAs:
        - local/tls/clients/nomad/ca.crt
      certificates:
        - certFile: local/tls/clients/nomad/cert.crt
          keyFile: local/tls/clients/nomad/priv.key
    consul:
      rootCAs:
        - local/tls/clients/consul/ca.crt
      certificates:
        - certFile: local/tls/clients/consul/cert.crt
          keyFile: local/tls/clients/consul/priv.key

{{- if nomadVarList "tls/domains" }}
tls:
  certificates:
{{- range nomadVarList "tls/domains" }}
    - certFile: local/{{ .Path }}/cert.crt
      keyFile: local/{{ .Path }}/priv.key
{{- end }}
{{- end }}
EOF
            destination = "local/dynamic.yml"
        }

      template {
        data = <<EOH
{{ with nomadVar "nomad/jobs/traefik" }}
TRAEFIK_CONSUL_CATALOG_TOKEN={{ .TRAEFIK_CONSUL_CATALOG_TOKEN }}
{{ end }}
EOH
        destination = "secrets/.env"
        env         = true
      }

      env {
        TRAEFIK_FORWARD_HEADERS_TRUSTED_IPS=var.traefik_trusted_ips_forward_headers
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}

variable "namespace" {
  description = "The Nomad namespace to deploy Traefik into"
  type        = string
  default     = "default"
}

variable "traefik_version" {
  description = "The version of Traefik to deploy"
  type        = string
  default     = "latest"
}

variable "traefik_trusted_ips_forward_headers" {
  description = "The trusted IPs for the Forwarded Headers middleware"
  type        = string
  default     = ""
}

variable "nomad_domain" {
  description = "The Nomad domain"
  type        = string
  default     = ""
}

variable "consul_domain" {
  description = "The Consul domain"
  type        = string
  default     = ""
}
