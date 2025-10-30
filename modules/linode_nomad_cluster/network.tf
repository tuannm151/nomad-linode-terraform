resource "linode_vpc" "vpc" {
    label = "${var.cluster_name}-network"
    region = var.linode_region
}

resource "linode_vpc_subnet" "server_subnet" {
    vpc_id = linode_vpc.vpc.id
    label = "${var.cluster_name}-server-subnet"
    ipv4 = var.nomad_server_network_cidr
}

resource "linode_vpc_subnet" "client_subnet" {
    vpc_id = linode_vpc.vpc.id
    label = "${var.cluster_name}-client-subnet"
    ipv4 = var.nomad_client_network_cidr
}

resource "linode_placement_group" "nomad_nodes" {
    label = "${var.cluster_name}-nodes-pg"
    region = var.linode_region
    placement_group_type = "anti_affinity:local"
}

