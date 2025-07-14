# Local Nginx Docker Container with Terraform

This Terraform configuration deploys an Nginx container on a local Ubuntu server using Docker.

## Prerequisites

1. Ubuntu 24.04 server with Docker installed
2. Docker daemon configured to accept remote connections
3. Terraform installed on your local machine

## Docker Configuration

To allow Terraform to communicate with Docker, you need to configure Docker to accept remote connections. On your Ubuntu server:

1. Edit the Docker daemon configuration:
```bash
sudo nano /etc/docker/daemon.json
```

2. Add or modify the file to include:
```json
{
  "hosts": ["tcp://0.0.0.0:2375", "unix:///var/run/docker.sock"]
}
```

3. Edit the Docker service file:
```bash
sudo systemctl edit docker.service
```

4. Add the following:
```ini
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
```

5. Restart Docker:
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## Usage

1. Initialize Terraform:
```bash
terraform init
```

2. Review the planned changes:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

4. To destroy the resources:
```bash
terraform destroy
```

## Configuration

The following variables can be customized in `variables.tf` or through command-line flags:

- `nginx_host_port`: The port on the host machine (default: 80)
- `nginx_container_port`: The port inside the container (default: 80)
- `docker_host_ip`: The IP address of your Docker host (default: 192.168.1.179)

## Network Configuration

The container is configured to use Docker's bridge network and is accessible from the local network at http://192.168.1.179:80 (or your configured host and port).