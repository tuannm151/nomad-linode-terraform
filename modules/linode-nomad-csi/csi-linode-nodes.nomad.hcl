job "csi-linode-nodes" {
  type        = "system"
  namespace   = "${var.namespace}"

  group "nodes" {
    network {
      mode = "host"
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
        DRIVER_ROLE = "nodeserver"
      }

      csi_plugin {
        id        = "csi-linode"
        type      = "node"
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