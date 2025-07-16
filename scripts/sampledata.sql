USE [Sales];
GO

CREATE TABLE CUSTOMER(
    [CustomerID] INT NOT NULL, 
    [SalesAmount] DECIMAL NOT NULL
);
GO

INSERT INTO CUSTOMER (CustomerID, SalesAmount) 
     VALUES (1,100),(2,200),(3,300);

-- 2. Switch the database to FULL recovery and take a backup
ALTER DATABASE [Sales] SET RECOVERY FULL;
GO

BACKUP DATABASE [Sales] 
  TO DISK = N'/var/opt/mssql/backup/Sales.bak' 
  WITH NOFORMAT, NOINIT,  
       NAME = N'Sales-Full Database Backup', 
       SKIP, NOREWIND, NOUNLOAD,  STATS = 10;
GO

