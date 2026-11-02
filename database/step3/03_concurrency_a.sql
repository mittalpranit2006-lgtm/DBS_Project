SET ECHO ON VERIFY OFF SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE BEGIN IF USER<>'SVR_APP' OR SYS_CONTEXT('USERENV','CON_NAME')<>'XEPDB1' THEN RAISE_APPLICATION_ERROR(-20400,'Wrong account/container'); END IF; END;
/
SELECT SYS_CONTEXT('USERENV','SID') AS SESSION_A_SID, SYSTIMESTAMP AS START_TIME FROM DUAL;
DECLARE v_id NUMBER; v_start TIMESTAMP:=CAST(SYSTIMESTAMP AS TIMESTAMP)-INTERVAL '1' HOUR;
BEGIN
  SVR_WORKFLOW.START_RENTAL(1004,3004,2004,v_start,v_start+INTERVAL '24' HOUR,v_id);
  DBMS_OUTPUT.PUT_LINE('A vehicle rental uncommitted ID='||v_id||' at '||TO_CHAR(SYSTIMESTAMP,'HH24:MI:SS.FF3'));
END;
/
HOST powershell -NoProfile -Command "Set-Content -LiteralPath 'evidence/step3-vehicle-a.flag' -Value ready; while (-not (Test-Path 'evidence/step3-vehicle-b.flag')) { Start-Sleep -Milliseconds 200 }; Start-Sleep -Seconds 4"
ROLLBACK;
SELECT SYSTIMESTAMP AS A_VEHICLE_ROLLBACK_TIME FROM DUAL;
HOST powershell -NoProfile -Command "while (-not (Test-Path 'evidence/step3-vehicle-done.flag')) { Start-Sleep -Milliseconds 200 }"
SELECT Rental_ID FROM RENTAL WHERE Rental_ID=5001 FOR UPDATE;
SELECT SYSTIMESTAMP AS A_PAYMENT_PARENT_LOCK_TIME FROM DUAL;
HOST powershell -NoProfile -Command "Set-Content -LiteralPath 'evidence/step3-payment-a.flag' -Value ready; while (-not (Test-Path 'evidence/step3-payment-b.flag')) { Start-Sleep -Milliseconds 200 }; Start-Sleep -Seconds 4"
COMMIT;
SELECT SYSTIMESTAMP AS A_PAYMENT_PARENT_COMMIT_TIME FROM DUAL;
