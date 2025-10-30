terraform {
  required_providers {
    linode = {
      source = "linode/linode"
      version = "~> 3.5.0"
    }

    random = {
      source = "hashicorp/random"
      version = "~> 3.7"
    }

    tls = {
      source = "hashicorp/tls"
      version = "~> 4.1.0"
    }

    http = {
      source = "hashicorp/http"
      version = "~> 3.5.0"
    }
  }
}



