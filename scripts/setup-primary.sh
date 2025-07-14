#!/bin/bash
apt update
apt -y install curl netcat iputils-ping
curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | tee /etc/apt/sources.list.d/mssql-release.list
apt update
apt -y install mssql-tools18 openssh-client
# echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bash_profile
# source ~/.bash_profile

# Sleep to ensure SQL Server is ready
echo "Waiting for MSSQL to start..."
# sleep 40

# Create a test DB
# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
# CREATE DATABASE TestDB;
# ALTER DATABASE TestDB SET RECOVERY FULL;
# BACKUP DATABASE TestDB TO DISK = '/var/opt/mssql/backups/TestDB.bak' WITH INIT;
# "


# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
# ALTER DATABASE TestDB3 SET RECOVERY FULL;
# GO
# USE TestDB3;
# GO
# CREATE TABLE dbo.DemoTable (ID INT PRIMARY KEY, Name NVARCHAR(50));
# GO
# "

# Backup for AG requirement
mkdir -p /var/opt/mssql/backups
mkdir -p /var/opt/mssql/backups
chown -R mssql:mssql /var/opt/mssql/backups
chmod 755 /var/opt/mssql/backups
# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
# BACKUP DATABASE TestDB3 TO DISK = '/var/opt/mssql/backups/TestDB3.bak' WITH FORMAT;
# "

# Create endpoint
# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
# CREATE ENDPOINT [Hadr_endpoint]
#     AS TCP (LISTENER_PORT = 5022)
#     FOR DATA_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
# "

# Create AG
# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
# CREATE AVAILABILITY GROUP AG1
# WITH (CLUSTER_TYPE = NONE)
# FOR DATABASE TestDB3
# REPLICA ON
#     'mssql_primary' WITH (
#         ENDPOINT_URL = 'tcp://mssql_primary:5022',
#         AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
#         FAILOVER_MODE = MANUAL,
#         SEEDING_MODE = AUTOMATIC
#     ),
#     'mssql_secondary' WITH (
#         ENDPOINT_URL = 'tcp://mssql_secondary:5022',
#         AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
#         FAILOVER_MODE = MANUAL,
#         SEEDING_MODE = AUTOMATIC
#     );
# "

# IP_ADDR=$(hostname -I | awk '{print $1}')
# echo $IP_ADDR
# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
# ;ALTER AVAILABILITY GROUP AG1
# ADD LISTENER 'ag-listener'
# WITH (
#     IP = ('$IP_ADDR'),
#     PORT = 1433
# );
# "
#v6