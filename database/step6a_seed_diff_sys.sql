-- Read-only fallback for the original 81-row seed comparison, using local OS DBA authentication.
SET ECHO OFF VERIFY OFF
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = SVR_APP;
SPOOL evidence/step6a-seed-diff-sys.log
SELECT USER AS audit_account,
       SYS_CONTEXT('USERENV','CON_NAME') AS container_name,
       SYS_CONTEXT('USERENV','CURRENT_SCHEMA') AS compared_schema
  FROM dual;
@database/verification/step6a_seed_diff.sql
SPOOL OFF
EXIT SUCCESS
