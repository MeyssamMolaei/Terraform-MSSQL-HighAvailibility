-- Enable AG and prepare endpoints
ALTER EVENT SESSION AlwaysOn_health ON SERVER STATE = START;
GO
ALTER AVAILABILITY GROUP [ag_group] JOIN;
GO
