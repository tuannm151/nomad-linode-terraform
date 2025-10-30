job "csi-linode-controllers" {
  type        = "service"
  namespace   = "${var.namespace}"

  group "controllers" {
    count = 1
    network {
      mode = "host"
    }
    # disable deployments
    update {
      max_parallel = 0
    }

    task "plugin" {
      driver = "docker"

      config {
        image = "linode/linode-blockstorage-csi-driver:${var.csi_version}"
        network_mode = "host"
        privileged = true
      }

      env {
        LINODE_URL = "https://api.linode.com/v4"
        CSI_ENDPOINT = "unix:///csi/csi.sock"
        DRIVER_ROLE = "controller"
      }

      template {
        data = <<EOH
{{ with nomadVar "nomad/jobs/csi-linode-controllers" }}
{{ range $k, $v := . }}
{{ $k }}={{ $v }}
{{ end }}
{{ end }}
EOH
        destination = "secrets/.env"
        env         = true
      }

      csi_plugin {
        id        = "csi-linode"
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 100
        memory = 100
      }
    }
  }
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "csi_version" {
  type    = string
  default = "latest"
}