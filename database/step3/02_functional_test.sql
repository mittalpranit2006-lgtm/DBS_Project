SET ECHO ON VERIFY OFF SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE
  n NUMBER;
BEGIN
  IF USER<>'SVR_APP' OR SYS_CONTEXT('USERENV','CON_NAME')<>'XEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20200,'Wrong account/container'); END IF;
  SELECT COUNT(*) INTO n FROM RENTAL; IF n<>10 THEN RAISE_APPLICATION_ERROR(-20201,'Baseline RENTAL count changed'); END IF;
  SELECT COUNT(*) INTO n FROM PAYMENT; IF n<>10 THEN RAISE_APPLICATION_ERROR(-20202,'Baseline PAYMENT count changed'); END IF;
END;
/
SAVEPOINT step3_test;
DECLARE
  v_id NUMBER; v_payment NUMBER; v_final NUMBER; v_rate NUMBER;
  v_start TIMESTAMP:=CAST(SYSTIMESTAMP AS TIMESTAMP)-INTERVAL '1' HOUR;
  v_expected TIMESTAMP:=v_start+INTERVAL '24' HOUR;
  v_old_address VARCHAR2(240); v_address VARCHAR2(240); v_status VARCHAR2(16);
  v_count NUMBER; v_sum NUMBER;
  PROCEDURE expect_failure(p_code NUMBER, p_label VARCHAR2, p_actual NUMBER, p_message VARCHAR2) IS
  BEGIN
    IF p_actual<>p_code THEN
      RAISE_APPLICATION_ERROR(-20210,p_label||': wrong error '||p_actual||' '||p_message);
    END IF;
    DBMS_OUTPUT.PUT_LINE('PASS expected failure '||p_label||' '||p_code);
  END;
BEGIN
  IF SVR_WORKFLOW.CALCULATE_CHARGE(v_start,v_start,2000)<>2000 OR
     SVR_WORKFLOW.CALCULATE_CHARGE(v_start,v_start+INTERVAL '24' HOUR,2000)<>2000 OR
     SVR_WORKFLOW.CALCULATE_CHARGE(v_start,v_start+INTERVAL '24' HOUR+INTERVAL '1' SECOND,2000)<>4000 THEN
    RAISE_APPLICATION_ERROR(-20211,'Charge boundaries failed'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS charge boundaries: 0h=2000, 24h=2000, 24h+1s=4000');

  SELECT Address INTO v_old_address FROM CUSTOMER WHERE Customer_ID=1003;
  UPDATE CUSTOMER SET Address='STEP3 PRIOR WORK' WHERE Customer_ID=1003;
  BEGIN
    SVR_WORKFLOW.START_RENTAL(1003,3001,2003,v_start,v_expected,v_id);
    RAISE_APPLICATION_ERROR(-20212,'Unavailable vehicle accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20112,'unavailable vehicle',SQLCODE,SQLERRM); END;
  SELECT Address INTO v_address FROM CUSTOMER WHERE Customer_ID=1003;
  IF v_address<>'STEP3 PRIOR WORK' THEN RAISE_APPLICATION_ERROR(-20213,'Prior caller work lost'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS failed procedure preserved earlier caller UPDATE');

  BEGIN
    SVR_WORKFLOW.START_RENTAL(1003,3003,2003,v_start,v_start,v_payment);
    RAISE_APPLICATION_ERROR(-20235,'Zero-length rental accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20111,'invalid rental dates',SQLCODE,SQLERRM); END;
  BEGIN
    SVR_WORKFLOW.START_RENTAL(1003,3003,2004,v_start,v_expected,v_payment);
    RAISE_APPLICATION_ERROR(-20236,'Other-branch employee accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20114,'employee branch',SQLCODE,SQLERRM); END;
  BEGIN
    SVR_WORKFLOW.START_RENTAL(1003,3003,2003,TIMESTAMP '2026-10-11 09:00:00',
      TIMESTAMP '2026-10-12 09:00:00',v_payment);
    RAISE_APPLICATION_ERROR(-20237,'Historical interval overlap accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20115,'historical overlap',SQLCODE,SQLERRM); END;

  SVR_WORKFLOW.START_RENTAL(1003,3003,2003,v_start,v_expected,v_id);
  SELECT Availability_Status INTO v_status FROM VEHICLE WHERE Vehicle_ID=3003;
  IF v_status<>'Rented' THEN RAISE_APPLICATION_ERROR(-20214,'Start did not rent vehicle'); END IF;
  SELECT Daily_Rate_Snapshot INTO v_rate FROM RENTAL WHERE Rental_ID=v_id;
  IF v_rate<>2000 OR SVR_WORKFLOW.OUTSTANDING_BALANCE(v_id)<>2000 THEN
    RAISE_APPLICATION_ERROR(-20215,'Snapshot or initial balance wrong'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS start rental '||v_id||', Rented, rate snapshot 2000');

  BEGIN
    SVR_WORKFLOW.START_RENTAL(1003,3003,2003,v_start,v_expected,v_payment);
    RAISE_APPLICATION_ERROR(-20216,'Duplicate active rental accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20112,'duplicate active vehicle',SQLCODE,SQLERRM); END;

  UPDATE VEHICLE_TYPE SET Daily_Rate=2100 WHERE Type_ID=3;
  SELECT Daily_Rate_Snapshot INTO v_rate FROM RENTAL WHERE Rental_ID=v_id;
  IF v_rate<>2000 THEN RAISE_APPLICATION_ERROR(-20217,'Historical rate snapshot changed'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS changing type rate retained rental snapshot 2000');

  SVR_WORKFLOW.RECORD_PAYMENT(v_id,500,'UPI',v_start+INTERVAL '30' MINUTE,v_payment);
  IF SVR_WORKFLOW.OUTSTANDING_BALANCE(v_id)<>1500 THEN
    RAISE_APPLICATION_ERROR(-20218,'Partial payment balance wrong'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS partial payment '||v_payment||', balance 1500');
  BEGIN
    SVR_WORKFLOW.RECORD_PAYMENT(v_id,1600,'UPI',v_start+INTERVAL '30' MINUTE,v_payment);
    RAISE_APPLICATION_ERROR(-20219,'Overpayment accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20144,'overpayment',SQLCODE,SQLERRM); END;

  SVR_WORKFLOW.RECORD_RETURN(v_id,CAST(SYSTIMESTAMP AS TIMESTAMP),v_final);
  SELECT Availability_Status INTO v_status FROM VEHICLE WHERE Vehicle_ID=3003;
  IF v_final<>2000 OR v_status<>'Available' OR SVR_WORKFLOW.OUTSTANDING_BALANCE(v_id)<>1500 THEN
    RAISE_APPLICATION_ERROR(-20220,'Return amount/status/balance wrong'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS return final 2000, vehicle Available, balance 1500');
  BEGIN
    SVR_WORKFLOW.RECORD_RETURN(v_id,CAST(SYSTIMESTAMP AS TIMESTAMP),v_final);
    RAISE_APPLICATION_ERROR(-20221,'Repeat return accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20116,'repeat return',SQLCODE,SQLERRM); END;

  BEGIN
    UPDATE VEHICLE SET Availability_Status='Rented' WHERE Vehicle_ID=3003;
    RAISE_APPLICATION_ERROR(-20225,'Direct vehicle Rented update accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20163,'direct vehicle status UPDATE',SQLCODE,SQLERRM); END;
  UPDATE VEHICLE SET Availability_Status='Maintenance' WHERE Vehicle_ID=3003;
  BEGIN
    SVR_WORKFLOW.START_RENTAL(1003,3003,2003,v_start,v_expected,v_payment);
    RAISE_APPLICATION_ERROR(-20226,'Maintenance vehicle rented');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20112,'maintenance preservation',SQLCODE,SQLERRM); END;
  SELECT Availability_Status INTO v_status FROM VEHICLE WHERE Vehicle_ID=3003;
  IF v_status<>'Maintenance' THEN RAISE_APPLICATION_ERROR(-20227,'Maintenance status changed'); END IF;
  UPDATE VEHICLE SET Availability_Status='Available' WHERE Vehicle_ID=3003;

  BEGIN
    INSERT INTO RENTAL VALUES(7900,1005,3005,2005,'Active',v_start,v_expected,NULL,3500,3500);
    RAISE_APPLICATION_ERROR(-20228,'Direct Active insert accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20132,'direct Active INSERT',SQLCODE,SQLERRM); END;
  BEGIN
    INSERT INTO PAYMENT VALUES(8900,5001,v_start+INTERVAL '30' MINUTE,1300,'UPI','Completed');
    RAISE_APPLICATION_ERROR(-20229,'Direct overpayment accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20144,'direct overpayment INSERT',SQLCODE,SQLERRM); END;
  INSERT INTO PAYMENT VALUES(8901,5001,v_start+INTERVAL '30' MINUTE,100,'UPI','Completed');
  DBMS_OUTPUT.PUT_LINE('PASS valid direct payment INSERT guarded; all test payments roll back');
  BEGIN
    INSERT INTO PAYMENT VALUES(8902,5001,v_start+INTERVAL '30' MINUTE,100,'UPI','Pending');
    RAISE_APPLICATION_ERROR(-20238,'Pending payment accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20141,'unsupported payment status',SQLCODE,SQLERRM); END;

  SVR_WORKFLOW.START_RENTAL(1005,3005,2005,v_start,v_start+INTERVAL '48' HOUR,v_payment);
  SVR_WORKFLOW.RECORD_PAYMENT(v_payment,5000,'UPI',v_start+INTERVAL '30' MINUTE,v_final);
  BEGIN
    SVR_WORKFLOW.RECORD_RETURN(v_payment,CAST(SYSTIMESTAMP AS TIMESTAMP),v_final);
    RAISE_APPLICATION_ERROR(-20233,'Return below prepaid amount accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20118,'return below prepaid',SQLCODE,SQLERRM); END;
  SELECT Availability_Status INTO v_status FROM VEHICLE WHERE Vehicle_ID=3005;
  IF v_status<>'Rented' THEN RAISE_APPLICATION_ERROR(-20234,'Failed return changed vehicle status'); END IF;

  BEGIN
    UPDATE PAYMENT SET Amount=Amount+1 WHERE Payment_ID=6001;
    RAISE_APPLICATION_ERROR(-20222,'Direct payment update accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20140,'direct payment UPDATE',SQLCODE,SQLERRM); END;
  BEGIN
    DELETE FROM PAYMENT WHERE Payment_ID=6001;
    RAISE_APPLICATION_ERROR(-20223,'Direct payment delete accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20140,'direct payment DELETE',SQLCODE,SQLERRM); END;
  BEGIN
    DELETE FROM RENTAL WHERE Rental_ID=5003;
    RAISE_APPLICATION_ERROR(-20224,'Direct rental delete accepted');
  EXCEPTION WHEN OTHERS THEN expect_failure(-20136,'direct rental DELETE',SQLCODE,SQLERRM); END;

  SVR_WORKFLOW.OVERDUE_REPORT(CAST(SYSTIMESTAMP AS TIMESTAMP),v_count,v_sum);
  DBMS_OUTPUT.PUT_LINE('PASS overdue explicit cursor rows='||v_count||' estimated outstanding='||v_sum);
END;
/
ROLLBACK TO step3_test;
DECLARE
  n NUMBER; v_status VARCHAR2(16); v_rate NUMBER; v_address VARCHAR2(240);
BEGIN
  SELECT COUNT(*) INTO n FROM RENTAL; IF n<>10 THEN RAISE_APPLICATION_ERROR(-20230,'RENTAL rollback count wrong'); END IF;
  SELECT COUNT(*) INTO n FROM PAYMENT; IF n<>10 THEN RAISE_APPLICATION_ERROR(-20231,'PAYMENT rollback count wrong'); END IF;
  SELECT Availability_Status INTO v_status FROM VEHICLE WHERE Vehicle_ID=3003;
  SELECT Daily_Rate INTO v_rate FROM VEHICLE_TYPE WHERE Type_ID=3;
  SELECT Address INTO v_address FROM CUSTOMER WHERE Customer_ID=1003;
  IF v_status<>'Available' OR v_rate<>2000 OR v_address='STEP3 PRIOR WORK' THEN
    RAISE_APPLICATION_ERROR(-20232,'Rollback did not restore seed'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS rollback restored seed: RENTAL=10 PAYMENT=10 vehicle Available rate=2000');
END;
/
