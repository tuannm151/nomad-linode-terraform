#!/usr/bin/env bash

mkdir -p /opt/consul/acl
chown -R consul:consul /opt/consul
chown -R consul:consul /etc/consul.d
chmod 640 /etc/consul.d/consul.hcl

CONSUL_BOOTSTRAP_TOKEN=/tmp/consul-bootstrap-token
NOMAD_BOOTSTRAP_TOKEN=/tmp/nomad-bootstrap-token
NOMAD_ADMIN_TOKEN=/tmp/nomad-admin-token
export CONSUL_CAPATH="/etc/consul.d/consul-ca.pem"
export CONSUL_CLIENT_CERT="/etc/consul.d/server-crt.pem"
export CONSUL_CLIENT_KEY="/etc/consul.d/server-priv-key.pem"

export NOMAD_CAPATH="/etc/nomad.d/nomad-ca.pem"
export NOMAD_CLIENT_CERT="/etc/nomad.d/global-server-nomad.pem"
export NOMAD_CLIENT_KEY="/etc/nomad.d/global-server-nomad-key.pem"

cat > $CONSUL_CAPATH <<EOF
${consul_ca}
EOF

cat > $CONSUL_CLIENT_CERT <<EOF
${consul_server_cert}
EOF

cat > $CONSUL_CLIENT_KEY <<EOF
${consul_server_private_key}
EOF

cat > $NOMAD_CAPATH <<EOF
${nomad_ca}
EOF

cat > $NOMAD_CLIENT_CERT <<EOF
${global_server_nomad_cert}
EOF

cat > $NOMAD_CLIENT_KEY <<EOF
${global_server_nomad_key}
EOF

private_ip=$(ip route get ${nomad_server_subnet_cidr} | grep -oP '(?<=src )[0-9.]+')

if [ "${disable_api_ssl_verification}" = "true" ]; then
    nomad_https_client_verify="false"
    consul_https_verify_incoming="false"
else
    nomad_https_client_verify="true"
    consul_https_verify_incoming="true"
fi

cat > /etc/consul.d/consul.hcl <<EOF
datacenter = "${datacenter_name}"
data_dir = "/opt/consul"

node_name = "${node_name}"

recursors = ${recursors}

bind_addr = "$private_ip"

client_addr = "127.0.0.1 $private_ip"

addresses {
    https = "0.0.0.0"
    grpc_tls = "0.0.0.0"
}

ports {
    https = 8501
    grpc_tls = 8503
}

server = true
bootstrap_expect = ${bootstrap_expect}

ui_config {
    enabled = true
}

service {
    name = "consul"
}

connect {
    enabled = true
}

tls {
    defaults {
        ca_file = "$CONSUL_CAPATH"
        cert_file = "$CONSUL_CLIENT_CERT"
        key_file = "$CONSUL_CLIENT_KEY"
        verify_incoming = true
        verify_outgoing = true
        verify_server_hostname = true
    }
    https {
        verify_incoming = $consul_https_verify_incoming
    }
}

auto_encrypt {
  allow_tls = true
}

acl {
    enabled = true
    default_policy = "deny"
    down_policy = "extend-cache"
}

encrypt = "${consul_gossip_encryption_key}"

retry_join = ${retry_join}
EOF

cat > /opt/consul/acl/consul-nomad-server-policy.hcl <<EOF
agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}

acl  = "write"
mesh = "write"
EOF

cat > /opt/consul/acl/consul-nomad-client-policy.hcl <<EOF
agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}
EOF

cat > /etc/nomad.d/nomad.hcl <<EOF
datacenter = "${datacenter_name}"
data_dir = "/opt/nomad"

name = "${node_name}"

bind_addr = "$private_ip"

server {
    enabled = true
    bootstrap_expect = ${bootstrap_expect}
    encrypt = "${nomad_gossip_encryption_key}"
}

addresses {
    http = "0.0.0.0"
    rpc  = "$private_ip"
    serf = "$private_ip"
}

consul {
    address = "127.0.0.1:8500"
    token = "${nomad_server_consul_token_secret}"
}

acl {
    enabled = true
}

tls {
  http = true
  rpc  = true

  ca_file   = "$NOMAD_CAPATH"
  cert_file = "$NOMAD_CLIENT_CERT"
  key_file  = "$NOMAD_CLIENT_KEY"

  verify_server_hostname = true
  verify_https_client    = $nomad_https_client_verify
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

# Wait until leader has been elected and bootstrap consul ACLs
for i in {1..9}; do
    # capture stdout and stderr
    set +e
    sleep 5
    OUTPUT=$(consul acl bootstrap 2>&1)
    if [ $? -ne 0 ]; then
        echo "consul acl bootstrap: $OUTPUT"
        if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
            echo "consul no cluster leader"
            continue
        else
            echo "consul already bootstrapped"
            break
        fi

    fi
    set -e

    echo "$OUTPUT" | grep -i secretid | awk '{print $2}' > $CONSUL_BOOTSTRAP_TOKEN
    if [ -s $CONSUL_BOOTSTRAP_TOKEN ]; then
        echo "consul bootstrapped"
         # Create consul admin token
        consul acl token create -accessor=${consul_admin_token_id} -secret=${consul_admin_token_secret} -description "Consul admin token" -policy-name "global-management" -token-file=$CONSUL_BOOTSTRAP_TOKEN

        # Create consul agent dns token
        consul acl token create -accessor=${consul_agent_dns_token_id} -secret=${consul_agent_dns_token_secret} -description "Consul agent dns token" -templated-policy "builtin/dns" -token-file=$CONSUL_BOOTSTRAP_TOKEN

        # Create consul nomad server token
        consul acl policy create -name "nomad-server" -rules="@/opt/consul/acl/consul-nomad-server-policy.hcl" -token-file=$CONSUL_BOOTSTRAP_TOKEN
        consul acl token create -accessor=${nomad_server_consul_token_id} -secret=${nomad_server_consul_token_secret} -description "Nomad server token" -policy-name "nomad-server" -token-file=$CONSUL_BOOTSTRAP_TOKEN

        # Create consul nomad client token
        consul acl policy create -name "nomad-client" -rules="@/opt/consul/acl/consul-nomad-client-policy.hcl" -token-file=$CONSUL_BOOTSTRAP_TOKEN
        consul acl token create -accessor=${nomad_client_consul_token_id} -secret=${consul_nomad_client_token_secret} -description "Nomad client token" -policy-name "nomad-client" -token-file=$CONSUL_BOOTSTRAP_TOKEN
        break
    fi
done

systemctl enable nomad && systemctl start nomad

export NOMAD_ADDR="https://127.0.0.1:4646"
# Wait for nomad servers to come up and bootstrap nomad ACL
for i in {1..12}; do
    # capture stdout and stderr
    set +e
    sleep 5
    OUTPUT=$(nomad acl bootstrap 2>&1)
    if [ $? -ne 0 ]; then
        echo "nomad acl bootstrap: $OUTPUT"
        if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
            echo "nomad no cluster leader"
            continue
        else
            echo "nomad already bootstrapped"
            break
        fi
    fi
    set -e

    echo "$OUTPUT" | grep -i secret | awk -F '=' '{print $2}' | xargs | awk 'NF' > $NOMAD_BOOTSTRAP_TOKEN
    if [ -s $NOMAD_BOOTSTRAP_TOKEN ]; then
        echo "nomad bootstrapped"
        consul kv put -token=${consul_admin_token_secret} nomad_bootstrap_token "$(cat $NOMAD_BOOTSTRAP_TOKEN)"
        export NOMAD_TOKEN="$(cat $NOMAD_BOOTSTRAP_TOKEN)"

        # enable memory oversubscription
        nomad operator scheduler set-config -memory-oversubscription=true
        break
    fi
done

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

systemctl restart systemd-resolved
systemctl daemon-reload
