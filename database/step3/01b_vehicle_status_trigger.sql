-- Incremental Step 3 addition. Run once as SVR_APP; do not rerun 01_objects.sql.
SET ECHO ON VERIFY OFF SERVEROUTPUT ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE n NUMBER;
BEGIN
  IF USER<>'SVR_APP' OR SYS_CONTEXT('USERENV','CON_NAME')<>'XEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20160,'Wrong account/container'); END IF;
  SELECT COUNT(*) INTO n FROM USER_OBJECTS WHERE OBJECT_NAME='TRG_SVR_VEHICLE_STATUS';
  IF n<>0 THEN RAISE_APPLICATION_ERROR(-20161,'Vehicle trigger already exists; inspect first'); END IF;
END;
/
CREATE OR REPLACE TRIGGER TRG_SVR_VEHICLE_STATUS
BEFORE UPDATE OF Availability_Status,Type_ID,Branch_ID ON VEHICLE FOR EACH ROW
BEGIN
  IF :OLD.Availability_Status='Rented' AND
     (:NEW.Type_ID<>:OLD.Type_ID OR :NEW.Branch_ID<>:OLD.Branch_ID) THEN
    RAISE_APPLICATION_ERROR(-20162,'Cannot move or retype a rented vehicle');
  END IF;
  IF :NEW.Availability_Status<>:OLD.Availability_Status THEN
    IF :OLD.Availability_Status='Available' AND :NEW.Availability_Status='Rented'
       AND SVR_WORKFLOW.MODE_NAME='START' THEN NULL;
    ELSIF :OLD.Availability_Status='Rented' AND :NEW.Availability_Status='Available'
       AND SVR_WORKFLOW.MODE_NAME='RETURN' THEN NULL;
    ELSIF :OLD.Availability_Status='Available' AND :NEW.Availability_Status='Maintenance' THEN NULL;
    ELSIF :OLD.Availability_Status='Maintenance' AND :NEW.Availability_Status='Available' THEN NULL;
    ELSE RAISE_APPLICATION_ERROR(-20163,'Vehicle status transition must use rental workflow');
    END IF;
  END IF;
END;
/
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM USER_OBJECTS WHERE OBJECT_NAME='TRG_SVR_VEHICLE_STATUS'
    AND OBJECT_TYPE='TRIGGER' AND STATUS='VALID';
  IF n<>1 THEN RAISE_APPLICATION_ERROR(-20164,'Vehicle status trigger invalid; inspect USER_ERRORS'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS vehicle status trigger VALID');
END;
/
