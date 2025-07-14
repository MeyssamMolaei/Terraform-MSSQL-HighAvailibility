#!/bin/bash

# Copy the configuration file
cp /mssql.conf /var/opt/mssql/mssql.conf

# Start SQL Server
/opt/mssql/bin/sqlservr