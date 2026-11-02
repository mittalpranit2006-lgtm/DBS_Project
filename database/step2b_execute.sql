-- One-time Step 2B runner. Launch from SQL*Plus /nolog with the project
-- directory as current directory. The first action is a fresh SYSTEM login.
-- Passwords are entered only at SQL*Plus hidden prompts. Never spool admin setup.
-- Every called script has its own account/container guard and fail-fast SQL handler.
SET ECHO OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CONNECT SYSTEM@"DESKTOP-FFIRV71:1521/xepdb1"
PROMPT STEP2B ADMIN PREFLIGHT
@database/schema/00_admin_preflight.sql
PROMPT STEP2B ADMIN SETUP
@database/schema/01_admin_setup.sql

PROMPT STEP2B CONNECT PROJECT USER - enter SVR_APP password privately
CONNECT SVR_APP@"DESKTOP-FFIRV71:1521/xepdb1"
SPOOL evidence/step2b-project.log
SHOW USER
SELECT SYS_CONTEXT('USERENV','CON_NAME') AS container_name,
       SYS_CONTEXT('USERENV','SERVICE_NAME') AS service_name FROM dual;

PROMPT STEP2B SCHEMA START
@database/schema/02_tables.sql
PROMPT STEP2B SEED START
@database/seed/01_seed.sql
PROMPT STEP2B VERIFICATION START
@database/verification/01_verify.sql
PROMPT STEP2B FIFTEEN SELECTS START
@database/queries/01_select_demos.sql
COMMIT;
BEGIN
  IF USER <> 'SVR_APP' OR SYS_CONTEXT('USERENV','CON_NAME') <> 'XEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20301,'Seed commit did not finish in SVR_APP / XEPDB1');
  END IF;
  DBMS_OUTPUT.PUT_LINE('PASS seed committed after verification and fifteen SELECTs.');
END;
/
SPOOL OFF

PROMPT STEP2B FRESH PROJECT CONNECTION - enter SVR_APP password privately
CONNECT SVR_APP@"DESKTOP-FFIRV71:1521/xepdb1"
SPOOL evidence/step2b-negative-rollback.log
SHOW USER
SELECT SYS_CONTEXT('USERENV','CON_NAME') AS container_name FROM dual;
PROMPT STEP2B NEGATIVE AND ROLLBACK START
@database/verification/02_negative_rollback.sql
PROMPT STEP2B FINAL VERIFICATION START
@database/verification/01_verify.sql
BEGIN
  IF USER <> 'SVR_APP' OR SYS_CONTEXT('USERENV','CON_NAME') <> 'XEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20300,'Step 2B did not finish in SVR_APP / XEPDB1');
  END IF;
  DBMS_OUTPUT.PUT_LINE('STEP2B COMPLETE - inspect both evidence logs for SP2, ORA and PLS errors.');
END;
/
SPOOL OFF
