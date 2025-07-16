#!/bin/bash
# apt update > /dev/null
# apt -y install curl netcat iputils-ping
# curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc
# curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | tee /etc/apt/sources.list.d/mssql-release.list
# apt update > /dev/null
# apt -y install mssql-tools18 openssh-client
# echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bash_profile
# source ~/.bash_profile

chown -R mssql:mssql /var/opt/mssql/backup /var/opt/mssql/shared
chmod -R 770 /var/opt/mssql/backup /var/opt/mssql/shared


echo "Waiting for SQL Primary Server..."
# until /opt/mssql-tools18/bin/sqlcmd -S mssql_primary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "SELECT 1" > /dev/null 2>&1
# do
#   sleep 2
# done
# echo "Primary SQL Server is ready."
# sleep 30
# while ! nc -z mssql_primary 1234; do
#   sleep 1
# done
python3 -c "import socket, time; exec('while True:\n try: socket.create_connection((\"mssql_primary\", 1234), timeout=1); break\n except OSError: print(\".\", end=\"\", flush=True); time.sleep(1)')"



echo "Waiting for SQL Slave Server..."
until /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "SELECT 1" > /dev/null 2>&1
do
  sleep 2
done
echo "Slave SQL Server is ready."


# Create endpoint
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
USE [master];
GO

-- 1. Create login and user for AOAG
IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'ag_login')
BEGIN
    CREATE LOGIN ag_login WITH PASSWORD = 'YourStrongPassw0rd';
END
CREATE USER aoag_user FOR LOGIN ag_login;
GO

-- 2. Create master key and certificate from primary's backup
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStrongPassw0rd';
END
GO

IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'ag_certificate')
BEGIN
    CREATE CERTIFICATE ag_certificate
        AUTHORIZATION ag_user
        FROM FILE = '/var/opt/mssql/shared/ag_certificate.cert'
        WITH PRIVATE KEY (
          FILE = '/var/opt/mssql/shared/ag_certificate.key',
          DECRYPTION BY PASSWORD = 'YourStrongPassw0rd'
        );
END
GO

-- 3. Create the HADR endpoint
IF NOT EXISTS (SELECT * FROM sys.endpoints WHERE name = 'Hadr_endpoint')
BEGIN
    CREATE ENDPOINT [Hadr_endpoint]
      STATE = STARTED
      AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ALL)
      FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE ag_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
      );
END

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [ag_login];
GO

-- 4. Join the availability group
ALTER AVAILABILITY GROUP [AG1] JOIN WITH (CLUSTER_TYPE = NONE);
GO

ALTER AVAILABILITY GROUP [AG1] GRANT CREATE ANY DATABASE;
GO
"
#v7