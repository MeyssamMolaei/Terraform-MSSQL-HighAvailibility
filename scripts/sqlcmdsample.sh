#! /bin/sh
sqlcmd -S 192.168.1.179:14331  -U sa -P YourStrongPassw0rd -Q "CREATE DATABASE TestDB"
sqlcmd -S 192.168.1.179:14331 -U sa -P YourStrongPassw0rd -d TestDB -Q "CREATE TABLE Users (Id INT PRIMARY KEY, Name NVARCHAR(100))"
sqlcmd -S 192.168.1.179:14331 -U sa -P YourStrongPassw0rd -d TestDB -Q "INSERT INTO Users (Id, Name) VALUES (1, 'Meyssam')"
sqlcmd -S 192.168.1.179:14331 -U sa -P YourStrongPassw0rd -d TestDB -Q "SELECT * FROM Users"
sqlcmd -S 192.168.1.179:14332 -U sa -P YourStrongPassw0rd -d TestDB -Q "SELECT * FROM Users"

docker exec --user 0 -it mssql_primary /bin/bash


/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "CREATE DATABASE TestDB; ALTER DATABASE TestDB SET RECOVERY FULL;"

/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "BACKUP DATABASE TestDB TO DISK = '/var/opt/mssql/backups/TestDB.bak' WITH INIT;"

docker cp mssql_primary:/var/opt/mssql/backups/TestDB.bak ./TestDB.bak
docker exec --user 0 mssql_secondary mkdir -p /var/opt/mssql/backups/
docker cp ./TestDB.bak mssql_secondary:/var/opt/mssql/backups/TestDB.bak

docker exec -it --user 0 mssql_secondary chmod 766 /var/opt/mssql/backups/TestDB.bak && /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "RESTORE DATABASE TestDB FROM DISK = '/var/opt/mssql/backups/TestDB.bak' WITH NORECOVERY, REPLACE;"


/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q "
CREATE AVAILABILITY GROUP AG1
WITH (CLUSTER_TYPE = NONE)
FOR DATABASE TestDB
REPLICA ON
    'mssql_primary' WITH (
        ENDPOINT_URL = 'tcp://mssql_primary:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC
    ),
    'mssql_secondary' WITH (
        ENDPOINT_URL = 'tcp://mssql_secondary:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC
    );
"

2nd
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
ALTER AVAILABILITY GROUP AG3 JOIN;
"
1st
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
CREATE AVAILABILITY GROUP AG3
WITH (CLUSTER_TYPE = NONE)
FOR DATABASE TestDB
REPLICA ON
    'mssql_primary' WITH (
        ENDPOINT_URL = 'tcp://mssql_primary:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC
    ),
    'mssql_secondary' WITH (
        ENDPOINT_URL = 'tcp://mssql_secondary:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC
    );
"

/opt/mssql-tools18/bin/sqlcmd -S mssql_primary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
CREATE DATABASE TestDB;
ALTER DATABASE TestDB SET RECOVERY FULL;
"
/opt/mssql-tools18/bin/sqlcmd -S mssql_primary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
BACKUP DATABASE TestDB TO DISK = '/var/opt/mssql/backups/TestDB.bak' WITH INIT;
"

docker cp mssql_primary:/var/opt/mssql/backups/TestDB.bak ./TestDB.bak
docker exec --user 0 mssql_secondary mkdir -p /var/opt/mssql/backups
docker exec --user 0 mssql_secondary chmod 766 /var/opt/mssql/backups/TestDB.bak
docker cp ./TestDB.bak mssql_secondary:/var/opt/mssql/backups/TestDB.bak
docker exec --user 0 mssql_secondary ls -l /var/opt/mssql/backups
rm TestDB.bak


/opt/mssql-tools18/bin/sqlcmd -S mssql_secondary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
RESTORE DATABASE TestDB FROM DISK = '/var/opt/mssql/backups/TestDB.bak' WITH NORECOVERY, REPLACE;
"
/opt/mssql-tools18/bin/sqlcmd -S mssql_primary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
CREATE AVAILABILITY GROUP AG3
WITH (CLUSTER_TYPE = NONE)
FOR DATABASE TestDB
REPLICA ON
    'mssql_primary' WITH (
        ENDPOINT_URL = 'tcp://172.18.0.3:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC
    ),
    'mssql_secondary' WITH (
        ENDPOINT_URL = 'tcp://172.18.0.2:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC
    );
"
nc -vz 172.18.0.3 5022

/opt/mssql-tools18/bin/sqlcmd -S mssql_primary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
SELECT name, cluster_type_desc FROM sys.availability_groups;
"
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
IF EXISTS (SELECT * FROM sys.availability_groups WHERE name = 'AG3') DROP AVAILABILITY GROUP AG3;
"
/opt/mssql-tools18/bin/sqlcmd -S mssql_primary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
CREATE ENDPOINT [Hadr_endpoint]
    STATE = STARTED
    AS TCP (LISTENER_PORT = 5022)
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = WINDOWS NEGOTIATE,
        ENCRYPTION = REQUIRED ALGORITHM AES
    );
"
/opt/mssql-tools18/bin/sqlcmd -S mssql_secondary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
ALTER AVAILABILITY GROUP AG3 JOIN;
"
/opt/mssql-tools18/bin/sqlcmd -S mssql_secondary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
IF EXISTS (SELECT * FROM sys.availability_groups WHERE name = 'AG3')
DROP AVAILABILITY GROUP AG3;
"
/opt/mssql-tools18/bin/sqlcmd -S mssql_secondary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
IF EXISTS (SELECT * FROM sys.endpoints WHERE name = 'Hadr_endpoint')
DROP ENDPOINT Hadr_endpoint;
"
/opt/mssql-tools18/bin/sqlcmd -S mssql_secondary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
CREATE ENDPOINT [Hadr_endpoint]
    STATE = STARTED
    AS TCP (LISTENER_PORT = 5022)
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = WINDOWS NEGOTIATE,
        ENCRYPTION = REQUIRED ALGORITHM AES
    );
"

/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
"
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
"
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
"
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
"
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
"
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
"

