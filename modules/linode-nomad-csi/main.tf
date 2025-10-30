terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = ">= 2.4"
    }
  }
}

resource "nomad_job" "csi-linode-nodes" {
  jobspec = file("${path.module}/csi-linode-nodes.nomad.hcl")
  hcl2 {
    vars = {
      namespace = var.namespace
      csi_version = var.csi_version
    }
  }
}

resource "nomad_job" "csi-linode-controller" {
  jobspec = file("${path.module}/csi-linode-controller.nomad.hcl")

  hcl2 {
    vars = {
      namespace = var.namespace
      csi_version = var.csi_version
    }
  }
}

resource "nomad_variable" "csi-linode-controllers" {
  path = "nomad/jobs/csi-linode-controllers"
  items = {
    LINODE_TOKEN = var.linode_volume_token
    REGION      = var.linode_region
  }
  namespace = var.namespace
}

variable "namespace" {
    description = "The Nomad namespace to deploy the CSI jobs into"
    type    = string
    default = "default"
}

variable "csi_version" {
  type    = string
  default = "latest"
}

variable "linode_volume_token" {
    description = "The Linode API token for the CSI driver to manage volumes. You can also update in nomad/jobs/csi-linode-controllers variables."
    type        = string
    default = "example"
}

variable "linode_region" {
    description = "The Linode region to create volume"
    type        = string
}
