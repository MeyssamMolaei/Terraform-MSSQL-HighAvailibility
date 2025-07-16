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

echo "Waiting for Primary SQL Server..."
until /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "SELECT 1" > /dev/null 2>&1
do
  sleep 2
done
echo "Primary SQL Server is ready."

# Create a test DB
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
-- AG_PRIMARY

-- 1. Create and seed a sample database
USE [master];
GO

CREATE DATABASE Sales;
GO

-- 3. Create logins and a certificate for the AOAG
USE [master];
GO

CREATE LOGIN ag_login WITH PASSWORD = 'YourStrongPassw0rd';
CREATE USER ag_user FOR LOGIN ag_login;

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStrongPassw0rd';
GO

CREATE CERTIFICATE ag_certificate WITH SUBJECT = 'ag_certificate';

BACKUP CERTIFICATE ag_certificate TO FILE = '/var/opt/mssql/shared/ag_certificate.cert' WITH PRIVATE KEY ( FILE = '/var/opt/mssql/shared/ag_certificate.key', ENCRYPTION BY PASSWORD = 'YourStrongPassw0rd');
GO
BACKUP DATABASE [Sales] TO  DISK = N'/var/opt/mssql/data/Sales-2025716-13-34-32.bak' WITH NOFORMAT, NOINIT,  NAME = N'Sales-2025716-13-34-32', NOSKIP, REWIND, NOUNLOAD,  STATS = 10, CHECKSUM, CONTINUE_AFTER_ERROR
GO
declare @backupSetId as int
GO
select @backupSetId = position from msdb..backupset where database_name=N'Sales' and backup_set_id=(select max(backup_set_id) from msdb..backupset where database_name=N'Sales' )
GO
if @backupSetId is null begin raiserror(N'Verify failed. Backup information for database ''Sales'' not found.', 16, 1) end
GO
RESTORE VERIFYONLY FROM  DISK = N'/var/opt/mssql/data/Sales-2025716-13-34-32.bak' WITH  FILE = @backupSetId,  NOUNLOAD
GO


-- 4. Create an HADR endpoint on port 5022
CREATE ENDPOINT [Hadr_endpoint]
  STATE = STARTED
  AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ALL)
  FOR DATA_MIRRORING (
    ROLE = ALL,
    AUTHENTICATION = CERTIFICATE ag_certificate,
    ENCRYPTION = REQUIRED ALGORITHM AES
  );

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [ag_login];
GO

-- 5. Create the Availability Group
DECLARE @cmd AS NVARCHAR(MAX);
SET @cmd = '
CREATE AVAILABILITY GROUP [AG1]
WITH (
    CLUSTER_TYPE = NONE
)
FOR REPLICA ON
N''mssql_primary'' WITH
(
    ENDPOINT_URL = N''tcp://mssql_primary:5022'',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    SEEDING_MODE = AUTOMATIC,
    FAILOVER_MODE = MANUAL,
    SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
),
N''mssql_secondary'' WITH
(
    ENDPOINT_URL = N''tcp://mssql_secondary:5022'',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    SEEDING_MODE = AUTOMATIC,
    FAILOVER_MODE = MANUAL,
    SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
);';

DECLARE @create_ag AS NVARCHAR(MAX);
SELECT @create_ag = REPLACE(@cmd, '', @@SERVERNAME);

EXEC sp_executesql @create_ag;

-- 6. Add the Sales database to AG after a short delay
WAITFOR DELAY '00:00:10';

ALTER AVAILABILITY GROUP [AG1] ADD DATABASE [Sales];
GO
;
"


python3 -c "import socket, time; s=socket.socket(); s.bind(('0.0.0.0',1234)); s.listen(); print('Listening...'); time.sleep(10); s.close(); print('Done')"

#v7