# output "mssql_primary" {
#   value = docker_container.mssql[0].name
# }

# output "mssql_secondary" {
#   value = docker_container.mssql[1].name
# }

output "haproxy_listener" {
  value = "tcp://${docker_container.haproxy.network_data[0].ip_address}:1433"
}
