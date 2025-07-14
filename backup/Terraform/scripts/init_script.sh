#!/bin/sh
# version 3
# Install PostgreSQL client tools if not already present
echo "Installing PostgreSQL client..."
apk update && apk add --no-cache postgresql15-client

# Connection parameters
PGHOST=postgres
PGPORT=5432
PGUSER=testuser
PGPASSWORD=testpass
PGDATABASE=testdb

export PGPASSWORD

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be available..."
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER"; do
  sleep 2
done

# Create tables and insert data
echo "Creating tables and inserting data..."

for i in $(seq 1 5); do
  TABLE="bulk_table_$i"
  echo "Creating $TABLE..."
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "CREATE TABLE IF NOT EXISTS $TABLE (id SERIAL PRIMARY KEY, name TEXT, value INT);"

  echo "Inserting 100 rows into $TABLE..."
  for j in $(seq 1 100); do
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "INSERT INTO $TABLE (name, value) VALUES ('Item_$j', $j);" > /dev/null
  done
done

echo "Data initialization complete."
