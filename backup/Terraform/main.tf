
resource "docker_network" "shared_net" {
  name = "shared_net"
}

# PostgreSQL
resource "docker_volume" "pg_data" {
  name       = "pg_data"
  driver_opts = {
    type   = "none"
    device = "/Volume/Docker/pg_data"
    o      = "bind"
  }
}


resource "docker_container" "postgres" {
  name  = "postgres"
  image = "postgres:latest"
  networks_advanced {
    name = docker_network.shared_net.name
  }
  lifecycle {
    create_before_destroy = true
  }
  volumes {
    volume_name    = docker_volume.pg_data.name
    container_path = "/var/lib/postgresql/data"
  }
  ports {
    internal = 5432
    external = 5432
  }
  env = [
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=${var.postgres_db}"
  ]
  depends_on = [docker_volume.pg_data]
}

# Alpine for DB Init
resource "null_resource" "copy_script_alpine" {
  triggers = {
    script_hash = filesha256("${path.module}/scripts/init_script.sh")
  }
  provisioner "file" {
    source      = "${path.module}/scripts/init_script.sh"
    destination = "/Volume/Docker/alpine_data/init_script.sh"

    connection {
      type     = "ssh"
      host     = var.remote_host
      user     = var.remote_user
      private_key = file(var.ssh_key)
    }
  }
  depends_on = [docker_container.postgres]
}

resource "docker_volume" "alpine_data" {
  name       = "alpine_data"
  driver_opts = {
    type   = "none"
    device = "/Volume/Docker/alpine_data"
    o      = "bind"
  }
}
resource "docker_container" "alpine_init" {
  name    = "alpine_init"
  image   = "alpine"
  command = ["sleep", "600"]

  networks_advanced {
    name = docker_network.shared_net.name
  }
  volumes {
    volume_name    = docker_volume.alpine_data.name
    container_path = "/Volume/Docker/alpine_data"
  }
  depends_on = [null_resource.copy_script_alpine]
}

resource "null_resource" "init_script_on_remote_docker" {
  provisioner "remote-exec" {
    inline = [
      "docker exec alpine_init chmod +x /Volume/Docker/alpine_data/init_script.sh",
      "docker exec alpine_init /Volume/Docker/alpine_data/init_script.sh"
    ]

    connection {
      type     = "ssh"
      host     = var.remote_host
      user     = var.remote_user
      private_key = file(var.ssh_key)
    }
  }

  depends_on = [docker_container.alpine_init]
}


# MSSQL Volumes
resource "docker_volume" "mssql_data" {
  count = 4
  name  = "mssql_data_${count.index}"
  driver_opts = {
    type   = "none"
    device = "/Volume/Docker/mssql_data_${count.index}"
    o      = "bind"
  }
  depends_on = [null_resource.init_script_on_remote_docker]
}

# MSSQL Containers
resource "docker_container" "mssql" {
  count = 4
  name  = "mssql_${count.index}"
  # container_name = "mssql_${count.index}"
  image = "mcr.microsoft.com/mssql/server:2022-latest"
  networks_advanced {
    name = docker_network.shared_net.name
  }
  volumes {
    volume_name    = docker_volume.mssql_data[count.index].name
    container_path = "/var/opt/mssql"
  }
  ports {
    internal = 1433
    external = 1420 + count.index
  }
  env = [
    "ACCEPT_EULA=Y",
    "SA_PASSWORD=YourStrong!Passw0rd"
  ]
  depends_on = [docker_volume.mssql_data]
}

# Airflow
resource "docker_container" "airflow" {
  name  = "airflow"
  image = "apache/airflow:2.7.1"
  networks_advanced {
    name = docker_network.shared_net.name
  }
  ports {
    internal = 8080
    external = 8080
  }
  env = [
    "AIRFLOW__CORE__EXECUTOR=SequentialExecutor",
    "AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${var.postgres_user}:${var.postgres_password}@postgres:5432/${var.postgres_db}"
  ]
  # depends_on = [docker_container.postgres, docker_container.mssql, docker_container.haproxy]
  depends_on = [docker_container.postgres, docker_container.mssql]
}

# HAProxy Config
resource "null_resource" "copy_script_haproxy" {
  triggers = {
    script_hash = filesha256("${path.module}/conf/haproxy.cfg")
  }
  provisioner "file" {
    source      = "${path.module}/conf/haproxy.cfg"
    destination = "/Volume/Docker/haproxy_data/conf/haproxy.cfg"

    connection {
      type     = "ssh"
      host     = var.remote_host
      user     = var.remote_user
      private_key = file(var.ssh_key)
    }
  }
  depends_on = [docker_container.mssql]
}

# Docker volume for haproxy config
resource "docker_container" "haproxy" {
  name  = "haproxy"
  image = "haproxy:latest"
  networks_advanced {
    name = docker_network.shared_net.name
  }

  ports {
    internal = 1433
    external = 1433
  }

  command = [
    "haproxy",
    "-f",
    "/usr/local/etc/haproxy/haproxy.cfg"
  ]

  volumes {
    host_path      = "/Volume/Docker/haproxy_data/conf/"
    container_path = "/usr/local/etc/haproxy/"
    read_only      = true
  }
  depends_on = [docker_container.mssql]
}

# resource "null_resource" "destroy_alpine" {
#  provisioner "remote-exec" {
#     inline = [
#       "docker rm -f ${docker_container.alpine_init.name}"
#     ]
#     connection {
#       type     = "ssh"
#       host     = var.remote_host
#       user     = var.remote_user
#       private_key = file(var.ssh_key)
#     }
#   }
#   depends_on = [docker_container.alpine_init]
#   lifecycle {
#     create_before_destroy = true
#   }
  
# }
