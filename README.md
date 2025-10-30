# Nomad/Consul Infrastructure on Linode

This project provisions a production-ready Nomad cluster with Consul service mesh on Linode using Terraform for infrastructure-as-code.

## Architecture

The infrastructure consists of:

1. **Core Infrastructure** (`linode.tf`): Cluster configuration
   - Linode VPC and networking
   - Nomad servers and clients
   - Consul servers with ACLs
   - Load balancer for external access
   - TLS certificates for mTLS communication
   - Firewall rules

2. **Platform Services** (`services.tf`): Essential services
   - Traefik reverse proxy/ingress controller
   - Linode CSI driver for persistent volumes
   - Nomad namespaces

### Technology Stack

- **Orchestration**: HashiCorp Nomad
- **Service Mesh**: HashiCorp Consul
- **Cloud Provider**: Linode
- **IaC Tool**: Terraform
- **Ingress**: Traefik
- **Storage**: Linode Block Storage via CSI driver

## Prerequisites

### Required Tools

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Nomad CLI](https://www.nomadproject.io/downloads) (for cluster management)
- [Consul CLI](https://www.consul.io/downloads) (for service mesh management)

### Installation

```bash
# Homebrew (macOS/Linux)
brew install terraform nomad consul

### Linode API Tokens

You need two Linode API tokens:

1. **Main Token** (`linode_token`):
   - Scopes: `events:read_write`, `firewalls:read_write`, `linodes:read_write`, `nodebalancers:read_write`, `volumes:read_write`, `vpc:read_write`
   - Used for provisioning infrastructure

2. **Volume Token** (`linode_volume_token`):
   - Scopes: `linodes:read_write`, `volumes:read_write`
   - Should be a long-lived token for the CSI driver
   - Used by the CSI controller to manage persistent volumes

Create tokens at: https://cloud.linode.com/profile/tokens

## Configuration

### 1. Create `terraform.tfvars`

Create a `terraform.tfvars` file in the project root:

```hcl
linode_token        = "your-linode-api-token"
linode_volume_token = "your-long-lived-volume-token"
cluster_authorized_ssh_keys = [
  "your-public-ssh-key"
]
```

**⚠️ Important**: This file is gitignored. Never commit tokens to version control.

### 2. Customize Cluster Settings

Edit the `locals` block in `linode.tf` to customize:

```hcl
locals {
  primary_domain = "devopsforge.ovh"  # Your domain
  cluster_name   = "prod-1"           # Cluster identifier
  linode_region  = "us-sea"           # Linode region (us-sea, us-east, etc.)
}
```

### 3. Adjust Cluster Sizing

Modify the module configuration in `linode.tf`:

```hcl
module "linode_nomad_cluster" {
  # Network configuration
  network_cidr              = "10.82.120.0/24"
  nomad_server_network_cidr = "10.82.120.0/26"
  nomad_client_network_cidr = "10.82.120.192/26"

  # Number of server nodes
  server_count = 1  # Use 3 or 5 for production

  # Server instance type
  server_config = {
    image                = "linode/ubuntu24.04"
    server_type          = "g6-nanode-1"  # Smallest instance
    external_volume_size = 20              # GB
  }

  # SSH keys for access
  cluster_authorized_ssh_keys = [
    "ssh-ed25519 AAAAC3Nza... your-key-here"
  ]

  # Worker node groups
  nodegroups = [
    {
      name         = "default-workload"
      client_count = 1               # Number of workers
      client_image = "linode/ubuntu24.04"
      node_type    = "g6-nanode-1"   # Instance type
    },
  ]
}
```

## Deployment

### Step 1: Initialize Terraform

```bash
terraform init
```

This downloads all required providers and modules.

### Step 2: Plan Infrastructure

```bash
terraform plan
```

Review the planned changes. You should see resources for:
- VPC and subnets
- Linode instances (servers and clients)
- Load balancer
- Firewall rules
- TLS certificates
- Various configuration resources

### Step 3: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. The deployment takes 5-10 minutes and includes:

1. Creating VPC and networking
2. Provisioning Nomad/Consul servers
3. Provisioning Nomad client nodes
4. Configuring load balancer
5. Generating TLS certificates
6. Setting up ACL tokens
7. Deploying platform services (Traefik, CSI driver)

### Step 4: Export TLS Certificates

```bash
make output-tls
```

This extracts TLS certificates to the `certs/` directory for CLI access.

## Accessing the Cluster

### Web UIs

After deployment, access the web interfaces:

- **Nomad UI**: `https://<load-balancer-ip>:4646`
- **Consul UI**: `https://<load-balancer-ip>:8501`

Get the load balancer IP:

```bash
terraform output load_balancer_ip
```

### CLI Access

#### 1. Export TLS Certificates

```bash
make output-tls
```

#### 2. Set Environment Variables

```bash
# Get the load balancer IP
export LB_IP=$(terraform output -raw load_balancer_ip)

# Consul CLI configuration
export CONSUL_CACERT="$(pwd)/certs/consul_ca.pem"
export CONSUL_CLIENT_CERT="$(pwd)/certs/consul_cli.crt"
export CONSUL_CLIENT_KEY="$(pwd)/certs/consul_cli.key"
export CONSUL_HTTP_ADDR="https://${LB_IP}:8501"
export CONSUL_HTTP_TOKEN=$(terraform output -raw consul_admin_token_secret)

# Get Nomad bootstrap token from Consul
export NOMAD_TOKEN=$(consul kv get nomad_bootstrap_token)

# Nomad CLI configuration
export NOMAD_CACERT="$(pwd)/certs/nomad_ca.pem"
export NOMAD_CLIENT_CERT="$(pwd)/certs/nomad_cli.crt"
export NOMAD_CLIENT_KEY="$(pwd)/certs/nomad_cli.key"
export NOMAD_ADDR="https://${LB_IP}:4646"
```

#### 3. Verify Connectivity

```bash
# Check Consul members
consul members

# Check Nomad nodes
nomad node status

# Check Nomad servers
nomad server members

# List Consul services
consul catalog services

# View Nomad job status
nomad job status
```

## Project Structure

```
.
├── README.md                   # This file
├── linode.tf                   # Main infrastructure definition
├── services.tf                 # Platform services (Traefik, CSI)
├── variables.tf                # Variable definitions
├── terraform.tfvars            # Variable values (gitignored)
├── Makefile                    # Common operations
├── .gitignore                  # Git ignore patterns
│
├── modules/                    # Reusable Terraform modules
│   ├── linode_nomad_cluster/   # Main cluster module
│   │   ├── cluster-server.tf   # Server node configuration
│   │   ├── consul-cli-tls.tf   # Consul CLI certificates
│   │   ├── consul-tls.tf       # Consul server certificates
│   │   ├── firewall.tf         # Firewall rules
│   │   ├── loadbalancer.tf     # Load balancer configuration
│   │   ├── network.tf          # VPC and networking
│   │   ├── nodegroup.tf        # Worker node groups
│   │   ├── nomad-cli-tls.tf    # Nomad CLI certificates
│   │   ├── nomad-tls.tf        # Nomad server certificates
│   │   ├── token.tf            # ACL token generation
│   │   ├── variables.tf        # Module variables
│   │   └── scripts/            # Cloud-init scripts
│   │       ├── nomad-installation.sh
│   │       ├── nomad-server-setup.sh
│   │       └── nomad-client-setup.sh
│   │
│   ├── traefik-nomad/          # Traefik ingress controller
│   │   ├── main.tf             # Traefik resources
│   │   ├── traefik.nomad.hcl   # Nomad job specification
│   │   └── variables.tf        # Module variables
│   │
│   └── linode-nomad-csi/       # CSI driver for volumes
│       ├── main.tf             # CSI resources
│       ├── csi-linode-controller.nomad.hcl
│       └── csi-linode-nodes.nomad.hcl
│
├── certs/                      # TLS certificates (gitignored)
│   ├── consul_ca.pem           # Consul CA certificate
│   ├── consul_cli.crt          # Consul client certificate
│   ├── consul_cli.key          # Consul client key
│   ├── nomad_ca.pem            # Nomad CA certificate
│   ├── nomad_cli.crt           # Nomad client certificate
│   └── nomad_cli.key           # Nomad client key
│
├── tls-proxy/                  # Local TLS proxy (optional)
│   ├── docker-compose.yml      # Docker Compose configuration
│   ├── traefik.yml             # Traefik static config
│   └── dynamic.yml             # Traefik dynamic config
│
└── .terraform/                 # Terraform working directory
    ├── modules/                # Downloaded modules
    └── providers/              # Provider binaries
```

## Makefile Commands

Common operations are available via Make:

```bash
# Export TLS certificates for CLI access
make output-tls
```

You can also add more targets to the Makefile:

```makefile
.PHONY: init plan apply destroy output-tls clean

init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply

destroy:
	terraform destroy

output-tls:
	mkdir -p certs
	terraform output -raw consul_ca_cert > certs/consul_ca.pem
	terraform output -raw consul_cli_cert > certs/consul_cli.crt
	terraform output -raw consul_cli_key > certs/consul_cli.key
	terraform output -raw nomad_ca_cert > certs/nomad_ca.pem
	terraform output -raw nomad_cli_cert > certs/nomad_cli.crt
	terraform output -raw nomad_cli_key > certs/nomad_cli.key

clean:
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -rf certs/
```

## Security

### TLS/mTLS

All communication is encrypted:

- **Nomad**: mTLS between servers, clients, and CLI
- **Consul**: mTLS between servers, clients, and CLI
- **Traefik**: TLS termination for ingress traffic
- **API Access**: All API endpoints require valid client certificates

### ACLs

- **Consul ACLs**: Enabled by default with bootstrap token
- **Nomad ACLs**: Enabled by default with bootstrap token stored in Consul KV
- **Token Management**: Admin tokens required for all operations

### Firewall

The infrastructure includes Linode Cloud Firewall with:

- Restricted inbound access to essential ports only
- Allow internal cluster communication on private network
- Allow load balancer health checks
- SSH access restricted to authorized keys
- Deny all other traffic by default

### SSL Verification

The configuration includes `disable_api_ssl_verification = "true"` for development. For production:

1. Remove or set to `"false"` in `linode.tf`
2. Ensure proper DNS configuration
3. Use valid SSL certificates

## Modules Documentation

### linode_nomad_cluster

Core module that provisions the complete Nomad/Consul cluster.

**Inputs:**
- `linode_region` - Linode datacenter region
- `network_cidr` - VPC CIDR block
- `cluster_name` - Unique cluster identifier
- `server_count` - Number of Nomad/Consul servers (1, 3, or 5)
- `server_config` - Server instance configuration
- `nodegroups` - List of worker node groups
- `cluster_authorized_ssh_keys` - SSH public keys for access

**Outputs:**
- `load_balancer_ip` - Public IP for cluster access
- `consul_admin_token_secret` - Consul admin ACL token
- `consul_ca_cert`, `consul_cli_cert`, `consul_cli_key` - Consul TLS certificates
- `nomad_ca_cert`, `nomad_cli_cert`, `nomad_cli_key` - Nomad TLS certificates

### traefik-nomad

Deploys Traefik as the ingress controller with:

- Consul ACL policy and token for service discovery
- Nomad variables for TLS certificates
- Nomad job specification for Traefik deployment
- Consul Connect integration
- HTTP/HTTPS routing
- Automatic service discovery

**Features:**
- Dynamic configuration from Consul
- Let's Encrypt integration (optional)
- Access logs and metrics
- HTTP to HTTPS redirect
- Consul Connect native integration

### linode-nomad-csi

Deploys Linode Container Storage Interface driver:

- CSI controller for volume provisioning
- CSI node plugin on each client
- Nomad variables for Linode API token
- Support for dynamic volume provisioning

**Capabilities:**
- Create/delete volumes
- Attach/detach volumes
- Mount/unmount volumes
- Volume snapshots (planned)

## Using Persistent Volumes

### Creating Volumes

After the CSI driver is deployed, create volumes using Terraform:

```hcl
resource "nomad_csi_volume" "postgres" {
  plugin_id = "csi-linode"
  name      = "postgres-data"
  volume_id = "postgres-data"
  namespace = "default"
  
  capacity_min = "10G"
  capacity_max = "10G"

  capability {
    access_mode     = "single-node-writer"
    attachment_mode = "file-system"
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

Or via Nomad CLI:

```bash
cat > volume.hcl <<EOF
id        = "postgres-data"
name      = "postgres-data"
type      = "csi"
plugin_id = "csi-linode"

capacity_min = "10G"
capacity_max = "10G"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}
EOF

nomad volume create volume.hcl
```

### Using Volumes in Jobs

Mount volumes in your Nomad job specifications:

```hcl
job "postgres" {
  datacenters = ["dc1"]
  
  group "db" {
    volume "data" {
      type      = "csi"
      source    = "postgres-data"
      read_only = false
    }
    
    task "postgres" {
      driver = "docker"
      
      config {
        image = "postgres:15"
      }
      
      volume_mount {
        volume      = "data"
        destination = "/var/lib/postgresql/data"
      }
      
      env {
        POSTGRES_PASSWORD = "changeme"
      }
    }
  }
}
```

## DNS Configuration

For production use, configure DNS records pointing to your load balancer:

```
# A records
nomad-prod-1.devopsforge.ovh     A    <load-balancer-ip>
consul-prod-1.devopsforge.ovh    A    <load-balancer-ip>

# (Optional) Wildcard for services
*.prod-1.devopsforge.ovh         A    <load-balancer-ip>
```

The wildcard record allows Traefik to route to services based on hostname.

## Managing TLS Certificates for Services

### Adding Custom Domain Certificates

The Traefik module stores TLS certificates in Nomad variables under the `tls/domains` path. To add certificates for additional domains:

#### 1. Prepare Your Certificates

Obtain SSL/TLS certificates for your domain from:
- Let's Encrypt (via certbot)
- Your certificate authority
- Self-signed certificates (for testing)

You'll need:
- Certificate file (`.crt` or `.pem`)
- Private key file (`.key`)

#### 2. Add Certificates

##### Via Nomad UI
1. Access Nomad UI
2. Navigate to "Variables" > Create Variable
3. Set the path to `tls/domains/your-domain-com` (without dots)
4. Add two items:
   - `cert`: Certificate content
   - `key`: Private key content
5. Save the variable in same namespace as Traefik (usually `system`)

##### Via Nomad CLI
```bash
# Set environment variables for Nomad CLI (if not already set)
export NOMAD_ADDR="https://$(terraform output -raw load_balancer_ip):4646"
export NOMAD_TOKEN=$(consul kv get nomad_bootstrap_token)
export NOMAD_CACERT="$(pwd)/certs/nomad_ca.pem"
export NOMAD_CLIENT_CERT="$(pwd)/certs/nomad_cli.crt"
export NOMAD_CLIENT_KEY="$(pwd)/certs/nomad_cli.key"

# Create a variable for your domain
nomad var put \
  -namespace=system \
  tls/domains/example.com \
  cert=@/path/to/example.com.crt \
  key=@/path/to/example.com.key
```
##### Via Terraform

```hcl
resource "nomad_variable" "tls_example_com" {
  path      = "tls/domains/example.com"
  namespace = nomad_namespace.system.name

  items = {
    cert = file("${path.module}/certs/example.com.crt")
    key  = file("${path.module}/certs/example.com.key")
  }
}
```

Then apply:

```bash
terraform apply
```

#### 4. Update Traefik Configuration

After adding certificates, restart Traefik to pick up the new certificates:

```bash
# Restart the Traefik job
nomad job restart traefik
```

#### 5. Configure Service to Use Custom Domain

Update your Nomad job to use the custom domain:

```hcl
job "myapp" {
  # ...
  
  group "web" {
    service {
      name = "myapp"
      port = "http"
      
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.myapp.rule=Host(`app.example.com`)",
        "traefik.http.routers.myapp.tls=true",
      ]
    }
    
    # ...
  }
}
```

### Managing Multiple Domains

For multiple domains, add each as a separate variable:

```bash
# Add multiple domains
nomad var put -namespace=system tls/domains/example.com cert=@example.com.crt key=@example.com.key
nomad var put -namespace=system tls/domains/api.example.com cert=@api.example.com.crt key=@api.example.com.key
nomad var put -namespace=system tls/domains/app.example.com cert=@app.example.com.crt key=@app.example.com.key
```

### Wildcard Certificates

For wildcard certificates (e.g., `*.example.com`):

```bash
nomad var put \
  -namespace=system \
  tls/domains/wildcard.example.com \
  cert=@/path/to/wildcard.example.com.crt \
  key=@/path/to/wildcard.example.com.key
```

Services can then use any subdomain:

```hcl
tags = [
  "traefik.enable=true",
  "traefik.http.routers.myapp.rule=Host(`anything.example.com`)",
  "traefik.http.routers.myapp.tls=true",
]
```

### Certificate Renewal

When renewing certificates:

```bash
# Update the variable with new certificate
nomad var put \
  -namespace=system \
  tls/domains/example.com \
  cert=@/path/to/renewed-example.com.crt \
  key=@/path/to/renewed-example.com.key

# Restart Traefik to reload certificates
nomad job restart traefik
```

### Viewing Stored Certificates

```bash
# List all certificate variables
nomad var list -namespace=system tls/domains

# View a specific certificate variable (metadata only, keys are sensitive)
nomad var get -namespace=system tls/domains/example-com
```

### Automated Certificate Management with Let's Encrypt

For automated certificate management, consider:

1. **ACME (Let's Encrypt) in Traefik**: Enable Traefik's built-in ACME support
2. **cert-manager**: Deploy cert-manager as a Nomad job
3. **External Renewal Script**: Use certbot in a periodic Nomad job

Example periodic job for certificate renewal:

```hcl
job "cert-renewal" {
  type = "batch"
  
  periodic {
    cron             = "0 0 * * 0"  # Weekly on Sunday
    prohibit_overlap = true
  }
  
  group "renew" {
    task "certbot" {
      driver = "docker"
      
      config {
        image = "certbot/certbot"
        args = [
          "renew",
          "--webroot",
          "--webroot-path=/var/www/certbot"
        ]
      }
      
      # Upload renewed certificates to Nomad variables
      # (requires additional scripting)
    }
  }
}
```

### Security Best Practices

1. **Never commit private keys** to version control
2. **Use Nomad ACL policies** to restrict access to certificate variables
3. **Rotate certificates** before expiration
4. **Use strong encryption** for certificate storage
5. **Monitor expiration dates** and set up alerts
6. **Keep backup copies** of certificates in secure storage


## Deploying Applications

### Example: Simple Web Service

Create a Nomad job file `webapp.nomad.hcl`:

```hcl
job "webapp" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 2

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "webapp"
      port = "http"
      
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.webapp.rule=Host(`webapp.prod-1.devopsforge.ovh`)",
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "your-app:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```

Deploy:

```bash
nomad job run webapp.nomad.hcl
```

Access via: `https://webapp.prod-1.devopsforge.ovh`

## Troubleshooting

### Infrastructure Issues

**Problem**: Terraform state conflicts

```bash
# View current state
terraform state list

# Remove corrupted resource
terraform state rm <resource>

# Re-import if needed
terraform import <resource> <id>
```

**Problem**: Cluster nodes not joining

```bash
# SSH into a server node
ssh root@<server-ip>

# Check Nomad logs
journalctl -u nomad -f

# Check Consul logs
journalctl -u consul -f

# Check Nomad status
nomad agent-info

# Check Consul status
consul info
```

**Problem**: Can't connect to cluster

```bash
# Check load balancer IP
terraform output load_balancer_ip

# Test connectivity
curl -k https://<load-balancer-ip>:8501/v1/status/leader

# Check firewall rules
# Login to Linode Cloud Manager and verify firewall configuration
```

### Service Deployment Issues

**Problem**: Nomad token not found

```bash
# The token is stored in Consul KV
consul kv get nomad_bootstrap_token

# If not present, check Consul logs on server nodes
ssh root@<server-ip>
journalctl -u consul -f | grep nomad_bootstrap
```

**Problem**: Traefik not starting

```bash
# Check job status
nomad job status traefik

# View allocation logs
nomad alloc logs <alloc-id>

# Check Consul service registration
consul catalog services
consul catalog service traefik
```

**Problem**: Services not routing through Traefik

```bash
# Check Traefik dashboard (if enabled)
# Check service tags
nomad job inspect <job-name> | jq '.Job.TaskGroups[].Services[].Tags'

# View Traefik logs
nomad alloc logs -job traefik
```

### CSI Driver Issues

**Problem**: Volumes not attaching

```bash
# Check CSI plugin status
nomad plugin status csi-linode

# View controller logs
nomad alloc logs -job linode-csi-controller

# View node plugin logs
nomad alloc logs -job linode-csi-nodes

# Check volume status
nomad volume status
```

**Problem**: Volume creation fails

```bash
# Verify Linode token has correct permissions
# Check Linode API token scopes: linodes:read_write, volumes:read_write

# View detailed volume info
nomad volume status <volume-id>

# Check CSI controller logs for errors
nomad alloc logs -job linode-csi-controller
```

### TLS Certificate Issues

**Problem**: Certificate verification errors

```bash
# Re-export certificates
make output-tls

# Verify certificate validity
openssl x509 -in certs/nomad_cli.crt -text -noout

# Check certificate dates
openssl x509 -in certs/nomad_cli.crt -noout -dates

# Verify certificate chain
openssl verify -CAfile certs/nomad_ca.pem certs/nomad_cli.crt
```

**Problem**: "x509: certificate signed by unknown authority"

This usually means the CA certificate is not being used correctly:

```bash
# Ensure environment variables are set
echo $NOMAD_CACERT
echo $CONSUL_CACERT

# Check file permissions
ls -l certs/

# Re-export certificates
make output-tls
```

## Scaling

### Adding More Worker Nodes

Edit `linode.tf` and increase `client_count`:

```hcl
nodegroups = [
  {
    name         = "default-workload"
    client_count = 3  # Changed from 1
    client_image = "linode/ubuntu24.04"
    node_type    = "g6-nanode-1"
  },
]
```

Apply changes:

```bash
terraform apply
```

### Adding New Node Groups

Add another nodegroup for different workload types:

```hcl
nodegroups = [
  {
    name         = "default-workload"
    client_count = 1
    client_image = "linode/ubuntu24.04"
    node_type    = "g6-nanode-1"
  },
  {
    name         = "high-memory"
    client_count = 1
    client_image = "linode/ubuntu24.04"
    node_type    = "g6-standard-2"  # 4GB RAM
  },
]
```

Then target specific node types in job constraints:

```hcl
job "memory-intensive" {
  constraint {
    attribute = "${node.unique.name}"
    operator  = "regexp"
    value     = "high-memory-.*"
  }
}
```

### Scaling Server Nodes

For production, use 3 or 5 server nodes for high availability:

```hcl
server_count = 3
```

**Note**: Server count should always be odd (1, 3, 5) for Raft consensus.

## Backup and Disaster Recovery

### Consul Snapshots

Regular snapshots of Consul state (includes Nomad state):

```bash
# Create snapshot
consul snapshot save backup-$(date +%Y%m%d).snap

# List snapshots
ls -lh *.snap

# Restore snapshot
consul snapshot restore backup-20241030.snap
```

Automate with cron:

```bash
# Add to crontab
0 2 * * * cd /backups && consul snapshot save consul-$(date +\%Y\%m\%d).snap
```

### Volume Snapshots

Linode volumes can be snapshotted via API or Cloud Manager.

### Terraform State Backup

```bash
# Backup state file
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d)

# For production, use remote state:
# - S3 bucket
# - Terraform Cloud
# - GitLab/GitHub with encryption
```

### Disaster Recovery Steps

1. **Restore Consul snapshot**
2. **Restore volume snapshots**
3. **Redeploy infrastructure** if needed: `terraform apply`
4. **Verify cluster health**: `nomad node status`, `consul members`
5. **Restore applications**: Jobs are stored in Consul state

## Monitoring and Observability

Consider deploying these services as Nomad jobs:

### Prometheus & Grafana

```bash
# Metrics collection and visualization
nomad job run prometheus.nomad.hcl
nomad job run grafana.nomad.hcl
```

### Loki

```bash
# Log aggregation
nomad job run loki.nomad.hcl
```

### Traefik Metrics

Traefik exposes Prometheus metrics on port 8082. Configure Prometheus to scrape:

```yaml
scrape_configs:
  - job_name: 'traefik'
    consul_sd_configs:
      - server: 'localhost:8500'
        services: ['traefik']
```

## Cost Optimization

### Current Configuration Costs (Approximate)

- 1x g6-nanode-1 server: **$5/month**
- 1x g6-nanode-1 client: **$5/month**
- NodeBalancer: **$10/month**
- Volumes: **$0.10/GB/month**

**Total**: ~$20/month + volume costs

### Reducing Costs

1. **Single Node**: Reduce to 1 combined server/client for dev (not recommended for production)
2. **Smaller Instances**: Use g6-nanode-1 (1GB RAM) for testing
3. **Regional Selection**: Some regions may have lower costs
4. **Volume Optimization**: Delete unused volumes
5. **Auto-scaling**: Implement autoscaling to reduce client count during off-hours

### Upgrading for Production

For production workloads:

- **Servers**: 3x g6-standard-2 ($24/month each) = $72/month
- **Clients**: 3x g6-standard-4 ($48/month each) = $144/month
- **NodeBalancer**: $10/month
- **Total**: ~$226/month + volumes

## Upgrading

### Terraform Provider Updates

Update versions in `linode.tf`:

```hcl
terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.6.0"  # Update version
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.6.0"  # Update version
    }
  }
}
```

Then:

```bash
terraform init -upgrade
terraform plan
terraform apply
```

### Nomad/Consul Version Updates

Update installation scripts in `modules/linode_nomad_cluster/scripts/`:

1. Edit `nomad-installation.sh` - update version variables
2. Perform rolling update of nodes
3. Test on client nodes first
4. Update servers one at a time
5. Verify cluster health between updates

## TLS Proxy for Local Development

The `tls-proxy/` directory contains a local Traefik proxy for development:

```bash
cd tls-proxy
docker-compose up -d
```

This creates a local proxy that:
- Terminates TLS locally
- Proxies to remote cluster
- Allows browser access without certificate warnings

Edit `dynamic.yml` to point to your cluster IP.

## Additional Resources

- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Consul Documentation](https://www.consul.io/docs)
- [Terraform Linode Provider](https://registry.terraform.io/providers/linode/linode/latest/docs)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Linode API Documentation](https://www.linode.com/docs/api/)

## Common Use Cases

### Running a Database

```hcl
job "postgres" {
  type = "service"
  
  group "db" {
    volume "data" {
      type   = "csi"
      source = "postgres-data"
    }
    
    task "postgres" {
      driver = "docker"
      config {
        image = "postgres:15"
      }
      
      volume_mount {
        volume      = "data"
        destination = "/var/lib/postgresql/data"
      }
    }
  }
}
```

### Scheduled Jobs (Cron)

```hcl
job "backup" {
  type = "batch"
  
  periodic {
    cron             = "0 2 * * *"
    prohibit_overlap = true
  }
  
  group "backup" {
    task "run" {
      driver = "docker"
      config {
        image = "backup-tool:latest"
      }
    }
  }
}
```

### Multi-Region Services

```hcl
job "api" {
  datacenters = ["dc1", "dc2"]  # Deploy to multiple regions
  
  group "api" {
    count = 2  # 2 instances per datacenter
    # ...
  }
}
```

## Security Best Practices

1. **Rotate Tokens Regularly**: Generate new ACL tokens periodically
2. **Use Namespaces**: Isolate teams/projects with Nomad namespaces
3. **Enable Audit Logging**: Track all API calls
4. **Network Segmentation**: Use VPC for private networking
5. **Least Privilege**: Grant minimal required permissions
6. **Secrets Management**: Use Nomad Variables or Vault for secrets
7. **Regular Updates**: Keep Nomad/Consul updated with security patches
8. **Backup Regularly**: Automate Consul snapshot backups

## Support

For issues related to:

- **Linode**: https://www.linode.com/support/
- **Nomad**: https://discuss.hashicorp.com/c/nomad
- **Consul**: https://discuss.hashicorp.com/c/consul
- **Terraform**: https://discuss.hashicorp.com/c/terraform-core

## License

This infrastructure code is provided as-is for personal/commercial use.

---

**Questions or Issues?** Check the troubleshooting section or consult the official documentation for each component.
