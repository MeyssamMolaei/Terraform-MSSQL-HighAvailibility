#!/bin/bash

# ⚙️ پارامترها
PASSWORD='YourStrongPassw0rd'
DB='TestDB'
AG='AG3'
BACKUP_PATH="/var/opt/mssql/backups/${DB}.bak"

echo "🔧 Step 1: Create HADR endpoint on both replicas"

/opt/mssql-tools18/bin/sqlcmd -S mssql_primary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
CREATE DATABASE $DB;
ALTER DATABASE $DB SET RECOVERY FULL;
"
/opt/mssql-tools18/bin/sqlcmd -S mssql_primary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
BACKUP DATABASE $DB TO DISK = '/var/opt/mssql/backups/$DB.bak' WITH INIT;
"

docker cp mssql_primary:/var/opt/mssql/backups/$DB.bak ./$DB.bak
docker exec --user 0 mssql_secondary mkdir -p /var/opt/mssql/backups
docker exec --user 0 mssql_secondary chmod 766 /var/opt/mssql/backups/$DB.bak
docker cp ./$DB.bak mssql_secondary:/var/opt/mssql/backups/$DB.bak
docker exec --user 0 mssql_secondary ls -l /var/opt/mssql/backups
rm $DB.bak


/opt/mssql-tools18/bin/sqlcmd -S mssql_secondary -U sa -P 'YourStrongPassw0rd' -l 30 -d master -N -C -Q " 
RESTORE DATABASE $DB FROM DISK = '/var/opt/mssql/backups/$DB.bak' WITH NORECOVERY, REPLACE;
"


for NODE in mssql_primary mssql_secondary; do
  docker exec $NODE /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -l 30 -N -C -Q " 
    IF EXISTS (SELECT * FROM sys.endpoints WHERE name = 'Hadr_endpoint')
        DROP ENDPOINT Hadr_endpoint;
    CREATE ENDPOINT [Hadr_endpoint]
    STATE = STARTED
    AS TCP (LISTENER_PORT = 5022)
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = WINDOWS NEGOTIATE,
        ENCRYPTION = REQUIRED ALGORITHM AES
    );
  "
done

echo "✅ Endpoints created."

echo "📦 Step 2: Restore $DB on primary"
docker exec mssql_primary /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -l 30 -N -C -Q " 
  RESTORE DATABASE [$DB]
  FROM DISK = '$BACKUP_PATH'
  WITH MOVE '$DB' TO '/var/opt/mssql/data/${DB}.mdf',
       MOVE '${DB}_log' TO '/var/opt/mssql/data/${DB}_log.ldf',
       NORECOVERY, REPLACE;
"

echo "📤 Step 3: Backup and copy log (optional if seeding)"
# OPTIONAL: For manual setup — if SEEDING_MODE = MANUAL, else skip this step

echo "📥 Step 4: Restore TestDB on secondary"
docker exec mssql_secondary /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -l 30 -N -C -Q " 
  RESTORE DATABASE [$DB]
  FROM DISK = '$BACKUP_PATH'
  WITH MOVE '$DB' TO '/var/opt/mssql/data/${DB}.mdf',
       MOVE '${DB}_log' TO '/var/opt/mssql/data/${DB}_log.ldf',
       NORECOVERY, REPLACE;
"

echo "🧠 Step 5: Set SERVERNAMEs"
docker exec mssql_primary /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -l 30 -N -C -Q " 
  EXEC sp_dropserver @@SERVERNAME;
  EXEC sp_addserver 'mssql_primary', local;"
docker exec mssql_secondary /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -l 30 -N -C -Q " 
  EXEC sp_dropserver @@SERVERNAME;
  EXEC sp_addserver 'mssql_secondary', local;"

echo "🔁 Restarting SQL Servers..."
docker restart mssql_primary
docker restart mssql_secondary

sleep 15

echo "🧱 Step 6: Create AG on primary"
docker exec mssql_primary /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -l 30 -d master -N -C -Q "
CREATE AVAILABILITY GROUP [$AG]
WITH (CLUSTER_TYPE = NONE)
FOR DATABASE [$DB]
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

echo "📡 Step 7: Join AG on secondary"
docker exec mssql_secondary /opt/mssql-tools18/bin/sqlcmd -S mssql_secondary -U sa -P "$PASSWORD" -l 30 -d master -N -C -Q "
ALTER AVAILABILITY GROUP [$AG] JOIN;
"

echo "🚀 Step 8: Start AG on primary"
docker exec mssql_primary /opt/mssql-tools18/bin/sqlcmd -S mssql_primary -U sa -P "$PASSWORD" -l 30 -d master -N -C -Q "
ALTER AVAILABILITY GROUP [$AG] GRANT CREATE ANY DATABASE;
ALTER AVAILABILITY GROUP [$AG] FORCE_FAILOVER_ALLOW_DATA_LOSS;
"

echo "✅ Done! Availability Group [$AG] should now be up and running."
