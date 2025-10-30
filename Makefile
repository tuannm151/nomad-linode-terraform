consul_ca_cert = certs/consul_ca.pem
consul_cli_key = certs/consul_cli.key
consul_cli_cert = certs/consul_cli.crt

nomad_ca_cert = certs/nomad_ca.pem
nomad_cli_key = certs/nomad_cli.key
nomad_cli_cert = certs/nomad_cli.crt

server_address_string = $(shell terraform output -json load_balancer_ip)
output-tls:
	@echo "Generating TLS certificates..."
	mkdir -p certs
	terraform output -raw consul_ca_cert > $(consul_ca_cert)
	terraform output -raw consul_cli_key > $(consul_cli_key)
	terraform output -raw consul_cli_cert > $(consul_cli_cert)

	terraform output -raw nomad_ca_cert > $(nomad_ca_cert)
	terraform output -raw nomad_cli_key > $(nomad_cli_key)
	terraform output -raw nomad_cli_cert > $(nomad_cli_cert)

start-proxy:
	SERVER_ADDRS=$(server_address_string) docker compose -f tls-proxy/docker-compose.yml up -d  --force-recreate
stop-proxy:
	docker compose -f tls-proxy/docker-compose.yml down