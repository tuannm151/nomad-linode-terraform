#!/usr/bin/env bash

chown -R consul:consul /opt/consul
chown -R consul:consul /etc/consul.d
chmod 640 /etc/consul.d/consul.hcl

export CONSUL_CAPATH="/etc/consul.d/consul-ca.pem"

export NOMAD_CAPATH="/etc/nomad.d/nomad-ca.pem"
export NOMAD_CLIENT_CERT="/etc/nomad.d/global-client-nomad.pem"
export NOMAD_CLIENT_KEY="/etc/nomad.d/global-client-nomad-key.pem"

cat > $CONSUL_CAPATH <<EOF
${consul_ca}
EOF

cat > $NOMAD_CAPATH <<EOF
${nomad_ca}
EOF

cat > $NOMAD_CLIENT_CERT <<EOF
${global_client_nomad_cert}
EOF

cat > $NOMAD_CLIENT_KEY <<EOF
${global_client_nomad_key}
EOF

public_interface=$(ip route | grep default | awk '{print $5}')

# find current private ip from the private cidr
private_ip=$(ip route get ${nomad_client_subnet_cidr} | grep -oP '(?<=src )[0-9.]+')

cat > /etc/consul.d/consul.hcl <<EOF
datacenter = "${datacenter_name}"
data_dir = "/opt/consul"

node_name = "${node_name}"

recursors = ${recursors}

bind_addr = "$private_ip"

client_addr = "127.0.0.1"

connect {
    enabled = true
}

tls {
  defaults {
    ca_file = "$CONSUL_CAPATH"
    verify_incoming = true
    verify_outgoing = true
    verify_server_hostname = true
  }
}

auto_encrypt = {
  tls = true
}

acl {
    enabled = true
    default_policy = "deny"
    down_policy = "extend-cache"
    tokens {
        dns = "${consul_agent_dns_token_secret}"
        default = "${consul_nomad_client_token_secret}"
    }
}

ui_config {
    enabled = false
}

encrypt = "${consul_gossip_encryption_key}"

retry_join = ${retry_join}
EOF

# ---
# Nomad configuration
# ---

cat > /etc/nomad.d/nomad.hcl <<EOF
datacenter = "${datacenter_name}"
data_dir = "/opt/nomad"

bind_addr = "$private_ip"

name = "${node_name}"

client {
    enabled = true
    node_pool = "${nomad_node_pool}"
    options {
        "driver.raw_exec.enable" = "1"
        "docker.privileged.enabled" = "true"
    }
    
    host_network "private" {
        cidr = "${nomad_client_subnet_cidr}"
    }

    host_network "public" {
        interface = "eth0"
    }
}

tls {
  http = true
  rpc  = true

  ca_file   = "$NOMAD_CAPATH"
  cert_file = "$NOMAD_CLIENT_CERT"
  key_file  = "$NOMAD_CLIENT_KEY"

  verify_server_hostname = true
  verify_https_client    = true
}

plugin "docker" {
  config {
    allow_privileged = true

    volumes {
      enabled = true
    }

    extra_labels = ["job_name", "job_id", "task_group_name", "task_name", "namespace", "node_name", "node_id"]
  }
}

consul {
    address = "127.0.0.1:8500"
    token = "${consul_nomad_client_token_secret}"
}

ui {
    enabled = false
}

acl {
    enabled = true
}

telemetry {
  collection_interval = "10s"
  disable_hostname = false
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
EOF

systemctl enable consul && systemctl start consul

systemctl enable nomad && systemctl start nomad

## setup dns
apt install -yq systemd-resolved
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/consul.conf <<EOF
[Resolve]
DNS=127.0.0.1:8600
DNSSEC=false
Domains=~consul
DNSStubListener=yes
DNSStubListenerExtra=172.17.0.1
EOF

cat > /etc/docker/daemon.json <<EOF
{
  "dns": ["172.17.0.1"]
}
EOF

systemctl restart systemd-resolved
systemctl daemon-reload
systemctl restart docker
