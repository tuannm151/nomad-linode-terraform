variable "linode_token" {
    description = "The Linode API token with events:read_write, firewalls:read_write, linodes:read_write, nodebalancers:read_write, volumes:read_write, vpc:read_write scopes"
    type        = string
}

variable "linode_volume_token" {
    description = "The Linode volume token with linodes:read_write and volumes:read_write scopes. Should be long lived token for CSI driver to manage volumes."
    type        = string
}

variable "cluster_authorized_ssh_keys" {
    description = "A list of SSH public keys to authorize for SSH access to the Linode instances."
    type        = list(string)
}
