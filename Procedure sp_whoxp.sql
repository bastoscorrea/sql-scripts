CREATE PROCEDURE [dbo].[sp_whoxp] ( @DetailFlag BIT = 0 ) AS         
BEGIN        
   DECLARE @i INT, @SpID INT, @NumProcesses INT,        
           @EventType NVARCHAR(100), @EventInfo NVARCHAR(1000)        
        
   CREATE TABLE #InputBuffer ( EventType NVARCHAR(100), Parameters int, EventInfo NVARCHAR(2000))        
        
   CREATE TABLE #Processes ( SPID INT, ECID INT, DBName VARCHAR(80), Command VARCHAR(50), Query VARCHAR(MAX), Duration NUMERIC(16,5),         
                             Login VARCHAR(100), HostName VARCHAR(100), BlkBy INT, Status VARCHAR(100), WaitType VARCHAR(100), TranCount INT,         
                             LockCount INT, LockType VARCHAR(100), LockMode VARCHAR(100), LockStatus VARCHAR(100), PercentComplete INT, EstCompTime DATETIME,         
                             CPU INT, [IO] INT, Reads INT, Writes INT, LastRead DATETIME, LastWrite DATETIME, StartTime DATETIME, LastBatch DATETIME,         
                             ProgramName VARCHAR(200),        
                             InputEventInfo VARCHAR(MAX),        
                             InnerQuery VARCHAR(MAX),        
                             ID INT NOT NULL IDENTITY(1,1) PRIMARY KEY )        
        
   INSERT #Processes ( SPID, ECID, DBName, Command, Query, Duration, Login, HostName, Status, BlkBy, WaitType, TranCount,         
                       LockCount, LockType, LockMode, LockStatus, PercentComplete, EstCompTime,         
                       CPU, [IO], Reads, Writes, LastRead, LastWrite, StartTime, LastBatch, ProgramName, InnerQuery )        
   SELECT p.spid AS [SPID], p.ecid        
         ,DB_NAME(p.dbid) AS [DBName]        
         ,p.cmd AS [Command]        
         ,COALESCE(OBJECT_NAME(txt.objectID,txt.DBID),        
            CASE        
               WHEN txt.encrypted = 1 THEN 'Encrypted'        
               WHEN r.session_id IS NULL THEN txt.text        
               ELSE LTRIM(SUBSTRING(txt.text, r.statement_start_offset / 2 + 1,((CASE WHEN r.statement_end_offset = -1 THEN DATALENGTH(txt.text) ELSE r.statement_end_offset END) - r.statement_start_offset) / 2))        
            END) AS [Query]        
         ,CONVERT(NUMERIC(16,5), CAST(DATEDIFF(ms, p.last_batch,  GETDATE()) AS FLOAT) / 1000) AS Duration        
         ,p.loginame AS [Login]        
         ,p.hostname AS [HostName]        
         ,p.status AS [Status]        
         ,p.blocked AS [BlkBy]        
         ,r.wait_type AS [WaitType]        
         ,ISNULL(t.trancount,0) AS [TranCount]        
         ,ISNULL(l.lockcount,0) AS [LockCount]        
         ,l.resource_type AS [LockType]        
         ,l.request_mode AS [LockMode]        
         ,l.request_status AS [LockStatus]        
         ,r.percent_complete AS [PercentComplete]        
         ,r.estimated_completion_time AS [EstCompTime]        
         ,p.cpu AS [CPU]        
         ,p.physical_io AS [IO]        
         ,c.num_reads AS [Reads]        
         ,c.num_writes AS [Writes]        
         ,c.last_read AS [LastRead]        
         ,c.last_write AS [LastWrite]        
         ,p.login_time AS [StartTime]        
         ,p.last_batch AS [LastBatch]        
         ,p.PROGRAM_NAME AS [ProgramName]        
         ,SUBSTRING( InnerTxt.text,  COALESCE(NULLIF(P.stmt_start / 2, 0), 1),            
                              CASE P.stmt_end         
                                   WHEN -1 THEN DATALENGTH(InnerTxt.text)         
                                   ELSE (P.stmt_end / 2 - P.stmt_start / 2)             
                              END ) AS InnerQuery        
   FROM sys.sysprocesses p        
   INNER JOIN sys.dm_exec_connections c (NOLOCK) ON c.session_id = p.spid        
   CROSS APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) AS txt        
   CROSS APPLY sys.dm_exec_sql_text(p.sql_handle ) AS InnerTxt        
--   CROSS APPLY ::fn_get_sql ( P.sql_handle ) AS InnerTxt        
   LEFT JOIN sys.dm_exec_requests r ON c.session_id = r.session_id      
   LEFT OUTER JOIN (        
                     SELECT session_id        
                           ,database_id = MAX(database_id)        
                           ,trancount = COUNT(*)        
                     FROM sys.dm_tran_session_transactions t        
                INNER JOIN sys.dm_tran_database_transactions dt ON t.transaction_id = dt.transaction_id        
                     GROUP BY session_id        
                   ) t ON t.session_id = p.spid        
   LEFT OUTER JOIN (         
                     SELECT request_session_id        
                           ,database_id = MAX(resource_database_id)        
                           ,resource_type        
                           ,request_status        
                           ,request_mode        
                           ,lockcount = COUNT(*)        
                     FROM sys.dm_tran_locks (NOLOCK)        
                     GROUP BY request_session_id, resource_type, request_mode, request_status        
   ) l ON p.spid = l.request_session_id  AND ( (l.request_mode NOT IN ('S', 'IS') AND l.resource_type IN ('TABLE',  'DATABASE')) OR @DetailFlag = 1)        
   WHERE p.spid <> @@SPID AND p.cmd <> 'AWAITING COMMAND'        
         AND ( p.ecid = 0 OR @DetailFlag = 1 )        
   ORDER BY Duration DESC, IO DESC, CPU DESC        
   SELECT @NumProcesses = @@ROWCOUNT        
        
   IF @DetailFlag = 1         
   BEGIN        
      SET @i = 1        
      WHILE @i <= @NumProcesses        
      BEGIN        
         SELECT @SpID = SPID FROM #Processes WHERE ID = @i        
        
         INSERT INTO #InputBuffer ( EventType, Parameters, EventInfo )        
         EXECUTE('DBCC INPUTBUFFER(' + @SpID + ')')        
               
         SELECT @EventType = EventType, @EventInfo = EventInfo FROM #InputBuffer         
        
         UPDATE #Processes         
         SET InputEventInfo = @EventInfo         
         WHERE ID = @i        
               
         TRUNCATE TABLE #InputBuffer         
         SET @i = @i + 1        
      END        
   END        
        
   IF @DetailFlag = 0              
      SELECT SPID, ECID, DBName, Command, Query, InnerQuery, Duration,         
             Login, HostName, Status, BlkBy, WaitType, TranCount,         
             LockCount, LockType, LockMode, LockStatus, PercentComplete, EstCompTime,         
             CPU, [IO], Reads, Writes, LastRead, LastWrite, StartTime, LastBatch, ProgramName        
      FROM #Processes        
      ORDER BY ID        
   ELSE        
      SELECT SPID, ECID, DBName, Command, InputEventInfo, Query, InnerQuery, Duration,         
             Login, HostName, Status, BlkBy, WaitType, TranCount,         
             LockCount, LockType, LockMode, LockStatus, PercentComplete, EstCompTime,         
             CPU, [IO], Reads, Writes, LastRead, LastWrite, StartTime, LastBatch, ProgramName        
      FROM #Processes        
      ORDER BY ID        
              
   DROP TABLE #Processes, #InputBuffer        
END
GO