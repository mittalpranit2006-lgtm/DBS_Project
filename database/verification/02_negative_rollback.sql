-- Optional later demonstration. Use a fresh SVR_APP session after 01_verify.sql.
-- Expected errors are handled in PL/SQL. All demo DML is rolled back.
SET ECHO OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
SET AUTOCOMMIT OFF
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE
BEGIN
  IF USER <> 'SVR_APP' OR SYS_CONTEXT('USERENV', 'CON_NAME') <> 'XEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20010, 'Expected SVR_APP in XEPDB1; no demo DML run');
  END IF;
END;
/
SAVEPOINT svr_demo_start;
DECLARE
BEGIN
  INSERT INTO CUSTOMER (Customer_ID,First_Name,Last_Name,Email,License_No,Address)
    VALUES (1999,'Demo','Disposable','demo.disposable@example.test','DL-FIC-1999','Temporary demo address');
  IF SQL%ROWCOUNT <> 1 THEN RAISE_APPLICATION_ERROR(-20210,'Disposable INSERT affected unexpected rows'); END IF;
  UPDATE CUSTOMER SET Address='Updated temporary address' WHERE Customer_ID=1999;
  IF SQL%ROWCOUNT <> 1 THEN RAISE_APPLICATION_ERROR(-20211,'Disposable UPDATE affected unexpected rows'); END IF;
  DELETE FROM CUSTOMER WHERE Customer_ID=1999;
  IF SQL%ROWCOUNT <> 1 THEN RAISE_APPLICATION_ERROR(-20212,'Disposable DELETE affected unexpected rows'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS disposable INSERT, UPDATE and DELETE affected one row each');
END;
/

DECLARE
BEGIN
  BEGIN
    INSERT INTO CUSTOMER_PHONE VALUES (999999,'9990000999');
    RAISE_APPLICATION_ERROR(-20201,'Foreign-key test unexpectedly accepted');
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE <> -2291 THEN RAISE; END IF;
    DBMS_OUTPUT.PUT_LINE('PASS expected FK rejection');
  END;
  BEGIN
    INSERT INTO CUSTOMER_PHONE VALUES (1001,'9990000001');
    RAISE_APPLICATION_ERROR(-20202,'Composite-key test unexpectedly accepted');
  EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('PASS expected composite-key rejection');
  END;
  BEGIN
    INSERT INTO RENTAL VALUES (5999,1001,3003,2003,'Unknown',
      TO_TIMESTAMP('2026-10-01 09:00:00','YYYY-MM-DD HH24:MI:SS'),
      TO_TIMESTAMP('2026-10-02 09:00:00','YYYY-MM-DD HH24:MI:SS'),NULL,2000,2000);
    RAISE_APPLICATION_ERROR(-20203,'Status CHECK test unexpectedly accepted');
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE <> -2290 THEN RAISE; END IF;
    DBMS_OUTPUT.PUT_LINE('PASS expected status CHECK rejection');
  END;
END;
/

ROLLBACK TO svr_demo_start;
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM CUSTOMER WHERE Customer_ID=1999;
  IF v_count <> 0 THEN RAISE_APPLICATION_ERROR(-20213,'Disposable customer remains after rollback'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS disposable customer absent after rollback');
END;
/
ROLLBACK;
BEGIN
  DBMS_OUTPUT.PUT_LINE('PASS negative tests and disposable INSERT/UPDATE/DELETE rolled back.');
END;
/
