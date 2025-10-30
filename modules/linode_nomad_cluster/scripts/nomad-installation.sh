#!/usr/bin/env bash

# ---
# Add HashiCorp repository
# ---

# Install the prerequisites
apt install -yq curl wget gpg coreutils

# Add the HashiCorp repository
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# ---
# Install Nomad
# ---

apt update
if [ "${nomad_apt_version}" != "" ]; then
  apt install -yq nomad=${nomad_apt_version}
else
  apt install -yq nomad
fi


# ---
# Install Consul
# ---
if [ "${consul_apt_version}" != "" ]; then
  apt install -yq consul=${consul_apt_version}
else
  apt install -yq consul
fi

if [ "${role}" == "client" ]; then
  # Install the CNI plugins for Nomad
  if [ -z "${cni_version}" ]; then
    cni_version=$(curl -s https://api.github.com/repos/containernetworking/plugins/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
  fi
  curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v${cni_version}/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64 )-v${cni_version}.tgz"
  mkdir -p /opt/cni/bin
  tar -C /opt/cni/bin -xzf cni-plugins.tgz

  # Add iptables rules for the bridge network
  tee /etc/sysctl.d/bridge.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-arptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

  modprobe br_netfilter
  sysctl -p /etc/sysctl.d/bridge.conf

  # ---
  # Install Docker
  # ---

  curl -fsSL https://get.docker.com | sudo sh -s -- --quiet
fi

