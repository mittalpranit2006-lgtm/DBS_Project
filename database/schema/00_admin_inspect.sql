-- Read-only inspection if 00_admin_preflight.sql reports that SVR_APP exists.
-- Run from a fresh SYSTEM connection to XEPDB1. No user or object is changed.
SET ECHO OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
BEGIN
  IF USER <> 'SYSTEM' OR SYS_CONTEXT('USERENV','CON_NAME') <> 'XEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20001, 'Expected SYSTEM connected to XEPDB1; no inspection run');
  END IF;
END;
/

SELECT USER AS admin_username,
       SYS_CONTEXT('USERENV','CON_NAME') AS container_name,
       SYS_CONTEXT('USERENV','SERVICE_NAME') AS service_name FROM dual;
SELECT username, account_status, default_tablespace, temporary_tablespace
  FROM dba_users WHERE username='SVR_APP';
SELECT tablespace_name, bytes, max_bytes
  FROM dba_ts_quotas WHERE username='SVR_APP' ORDER BY tablespace_name;
SELECT privilege, admin_option FROM dba_sys_privs
 WHERE grantee='SVR_APP' ORDER BY privilege;
SELECT granted_role, admin_option, default_role FROM dba_role_privs
 WHERE grantee='SVR_APP' ORDER BY granted_role;
SELECT owner, table_name, privilege, grantor FROM dba_tab_privs
 WHERE grantee='SVR_APP' ORDER BY owner, table_name, privilege;
SELECT object_type, object_name, status FROM dba_objects
 WHERE owner='SVR_APP' ORDER BY object_type, object_name;
