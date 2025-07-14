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
  # depends_on = [docker_container.mssql]
}

resource "null_resource" "copy_setup_primary" {
  triggers = {
    script_hash = filesha256("${path.module}/scripts/setup-primary.sh")
  }
  provisioner "file" {
    source      = "${path.module}/scripts/setup-primary.sh"
    destination = "/Volume/Docker/haproxy_data/conf/setup-primary.sh"

    connection {
      type     = "ssh"
      host     = var.remote_host
      user     = var.remote_user
      private_key = file(var.ssh_key)
    }
  }
  # depends_on = [docker_container.mssql]
}

resource "null_resource" "copy_setup_secondary" {
  triggers = {
    script_hash = filesha256("${path.module}/scripts/setup-secondary.sh")
  }
  provisioner "file" {
    source      = "${path.module}/scripts/setup-secondary.sh"
    destination = "/Volume/Docker/haproxy_data/conf/setup-secondary.sh"

    connection {
      type     = "ssh"
      host     = var.remote_host
      user     = var.remote_user
      private_key = file(var.ssh_key)
    }
  }
  # depends_on = [docker_container.mssql]
}
