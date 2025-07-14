#!/bin/bash
apt update
apt -y install curl netcat iputils-ping
curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | tee /etc/apt/sources.list.d/mssql-release.list
apt update
apt -y install mssql-tools18

echo "Waiting for SQL Server to start..."
# sleep 40

mkdir -p /var/opt/mssql/backups
mkdir -p /var/opt/mssql/backups
chown -R mssql:mssql /var/opt/mssql/backups
chmod 755 /var/opt/mssql/backups

# Create endpoint
# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
# CREATE ENDPOINT [Hadr_endpoint]
#     AS TCP (LISTENER_PORT = 5022)
#     FOR DATA_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
# "

# Join to AG
# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
# ;ALTER AVAILABILITY GROUP AG1 JOIN;
# "
#v6