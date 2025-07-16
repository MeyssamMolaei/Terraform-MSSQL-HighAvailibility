

# # MSSQL PRIMARY
# resource "docker_container" "mssql_primary" {
#   name  = "mssql_primary"
#   hostname  = "mssql_primary"
#   image = "mcr.microsoft.com/mssql/server:2022-latest"
#   env = [
#     "ACCEPT_EULA=Y",
#     "SA_PASSWORD=${var.sa_password}",
#     "MSSQL_AGENT_ENABLED=true",
#     "MSSQL_ENABLE_HADR=1"
#   ]
#   ports {
#     internal = 1433
#     external = 14331
#   }
#   ports {
#     internal = 5022
#     external = 50221
#   }
#   networks_advanced {
#     name = docker_network.shared_net.name
#   }
#   mounts {
#     target = "/var/opt/mssql/shared"
#     source = "mssql-server-shared"
#     type   = "volume"
#   }
#   mounts {
#     target = "/var/opt/mssql/backup"
#     source = "mssql-server-backup"
#     type   = "volume"
#   }
# }

resource "docker_container" "mssql_primary" {
  name     = "mssql_primary"
  hostname = "mssql_primary"
  image    = "mcr.microsoft.com/mssql/server:2022-latest"
  env = [
    "SA_PASSWORD=YourStrongPassw0rd",
    "ACCEPT_EULA=Y",
    "MSSQL_AGENT_ENABLED=true",
    "INIT_WAIT=0",
    "MSSQL_ENABLE_HADR=1"
  ]
  ports {
    internal = 1433
    external = 14331
  }
  mounts {
    target = "/var/opt/mssql/shared"
    source = docker_volume.mssql_server_shared.name
    type   = "volume"
  }
  mounts {
    target = "/var/opt/mssql/backup"
    source = docker_volume.mssql_server_backup.name
    type   = "volume"
  }
  volumes {
    host_path      = "/Volume/Docker/haproxy_data/conf/setup-primary.sh"
    container_path = "/setup-primary.sh"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.shared_net.name
  }
}


# # MSSQL SECONDARY
# resource "docker_container" "mssql_secondary" {
#   name  = "mssql_secondary"
#   hostname  = "mssql_secondary"
#   image = "mcr.microsoft.com/mssql/server:2022-latest"
#   env = [
#     "ACCEPT_EULA=Y",
#     "SA_PASSWORD=${var.sa_password}",
#     "MSSQL_AGENT_ENABLED=true",
#     "MSSQL_ENABLE_HADR=1"
#   ]
#   ports {
#     internal = 5022
#     external = 50222
#   }
#   ports {
#     internal = 1433
#     external = 14332
#   }
#   networks_advanced {
#     name = docker_network.shared_net.name
#   }
#   mounts {
#     target = "/var/opt/mssql/shared"
#     source = "mssql-server-shared"
#     type   = "volume"
#   }
#   mounts {
#     target = "/var/opt/mssql/backup"
#     source = "mssql-server-backup"
#     type   = "volume"
#   }
# }

resource "docker_container" "mssql_secondary" {
  name     = "mssql_secondary"
  hostname = "mssql_secondary"
  image    = "mcr.microsoft.com/mssql/server:2022-latest"

  env = [
    "SA_PASSWORD=YourStrongPassw0rd",
    "ACCEPT_EULA=Y",
    "MSSQL_AGENT_ENABLED=true",
    # "INIT_SCRIPT=aoag_secondary.sql",
    "INIT_WAIT=0",
    "MSSQL_ENABLE_HADR=1",
]

  ports {
    internal = 1433
    external = 14332
  }
  volumes {
    host_path      = "/Volume/Docker/haproxy_data/conf/setup-secondary.sh"
    container_path = "/setup-secondary.sh"
    read_only      = true
  }

  mounts {
    target = "/var/opt/mssql/shared"
    source = docker_volume.mssql_server_shared.name
    type   = "volume"
  }

  mounts {
    target = "/var/opt/mssql/backup"
    source = docker_volume.mssql_server_backup.name
    type   = "volume"
  }

  networks_advanced {
    name = docker_network.shared_net.name
  }
}


# HAProxy
resource "docker_image" "haproxy" {
  name = "haproxy:latest"
}

resource "docker_container" "haproxy" {
  name  = "haproxy"
  image = docker_image.haproxy.name
  ports {
    internal = 1433
    external = 1433
  }
  volumes {
    host_path      = "/Volume/Docker/haproxy_data/conf/"
    container_path = "/usr/local/etc/haproxy/"
    read_only      = true
  }
  networks_advanced {
    name = docker_network.shared_net.name
  }
  depends_on = [null_resource.copy_script_haproxy]
}



resource "null_resource" "setup_primary" {
  depends_on = [docker_container.mssql_primary]

  provisioner "remote-exec" {
    inline = [
      "wait 30",
      # "docker cp /Volume/Docker/haproxy_data/conf/setup-primary.sh mssql_primary:/setup-primary.sh",
      # "docker exec --user 0 mssql_primary chmod +x /setup-primary.sh",
      "docker exec --user 0 mssql_primary /bin/bash /setup-primary.sh"
    ]

    connection {
      type     = "ssh"
      host     = var.remote_host
      user     = var.remote_user
      private_key = file(var.ssh_key)
    }
  }
}



resource "null_resource" "setup_secondary" {
  # depends_on = [docker_container.mssql_secondary, null_resource.setup_primary]
  depends_on = [docker_container.mssql_secondary]

  provisioner "remote-exec" {
    inline = [
      "wait 0",
      # "docker cp /Volume/Docker/haproxy_data/conf/setup-secondary.sh mssql_secondary:/setup-secondary.sh",
      # "docker exec --user 0 mssql_secondary chmod +x /setup-secondary.sh",
      "docker exec --user 0 mssql_secondary /bin/bash /setup-secondary.sh"
    ]

    connection {
      type     = "ssh"
      host     = var.remote_host
      user     = var.remote_user
      private_key = file(var.ssh_key)
    }
  }
}