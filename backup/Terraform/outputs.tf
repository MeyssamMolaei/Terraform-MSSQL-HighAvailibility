# output "postgres_ip" {
#   value = docker_container.postgres.network_data[0].ip_address
# }

# output "airflow_url" {
#   value = "http://${docker_container.airflow.network_data[0].ip_address}:8080"
# }

# output "haproxy_mssql_url" {
#   value = "${docker_container.haproxy.network_data[0].ip_address}:1444"
# }
