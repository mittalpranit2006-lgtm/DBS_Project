-- Run once while connected as SVR_APP in XEPDB1. No passwords or COMMIT here.
SET ECHO ON VERIFY OFF SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE
  n NUMBER;
BEGIN
  IF USER <> 'SVR_APP' OR SYS_CONTEXT('USERENV','CON_NAME') <> 'XEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20100,'Expected SVR_APP in XEPDB1');
  END IF;
  SELECT COUNT(*) INTO n FROM USER_OBJECTS WHERE OBJECT_NAME IN
    ('SEQ_SVR_RENTAL','SEQ_SVR_PAYMENT','SVR_WORKFLOW','TRG_SVR_RENTAL','TRG_SVR_PAYMENT');
  IF n <> 0 THEN RAISE_APPLICATION_ERROR(-20101,'Step 3 objects exist; inspect, do not rerun'); END IF;
  SELECT COUNT(*) INTO n FROM USER_TABLES WHERE TABLE_NAME IN
    ('CUSTOMER','CUSTOMER_PHONE','VEHICLE_TYPE','BRANCH','VEHICLE','EMPLOYEE','RENTAL','PAYMENT');
  IF n <> 8 THEN RAISE_APPLICATION_ERROR(-20102,'Expected eight Step 2B tables'); END IF;
END;
/
CREATE SEQUENCE SEQ_SVR_RENTAL START WITH 7000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_SVR_PAYMENT START WITH 8000 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE PACKAGE SVR_WORKFLOW AS
  -- Mode is session state for trigger coordination, not an authorization control.
  FUNCTION MODE_NAME RETURN VARCHAR2;
  FUNCTION CALCULATE_CHARGE(p_start TIMESTAMP, p_end TIMESTAMP, p_rate NUMBER) RETURN NUMBER;
  FUNCTION OUTSTANDING_BALANCE(p_rental_id NUMBER) RETURN NUMBER;
  PROCEDURE START_RENTAL(p_customer_id NUMBER, p_vehicle_id NUMBER, p_employee_id NUMBER,
    p_start TIMESTAMP, p_expected TIMESTAMP, p_rental_id OUT NUMBER);
  PROCEDURE RECORD_RETURN(p_rental_id NUMBER, p_actual TIMESTAMP, p_final_amount OUT NUMBER);
  PROCEDURE RECORD_PAYMENT(p_rental_id NUMBER, p_amount NUMBER, p_method VARCHAR2,
    p_payment_date TIMESTAMP, p_payment_id OUT NUMBER);
  PROCEDURE OVERDUE_REPORT(p_as_of TIMESTAMP, p_count OUT NUMBER, p_estimated_outstanding OUT NUMBER);
END SVR_WORKFLOW;
/

CREATE OR REPLACE PACKAGE BODY SVR_WORKFLOW AS
  g_mode VARCHAR2(12);
  FUNCTION MODE_NAME RETURN VARCHAR2 IS BEGIN RETURN g_mode; END;

  FUNCTION CALCULATE_CHARGE(p_start TIMESTAMP, p_end TIMESTAMP, p_rate NUMBER) RETURN NUMBER IS
  BEGIN
    IF p_start IS NULL OR p_end IS NULL OR p_rate IS NULL OR p_rate <= 0 OR p_end < p_start THEN
      RAISE_APPLICATION_ERROR(-20110,'Invalid billing dates or rate');
    END IF;
    RETURN ROUND(GREATEST(1, CEIL(CAST(p_end AS DATE)-CAST(p_start AS DATE))) * p_rate,2);
  END;

  FUNCTION OUTSTANDING_BALANCE(p_rental_id NUMBER) RETURN NUMBER IS
    v_total NUMBER; v_paid NUMBER;
  BEGIN
    SELECT Total_Amount INTO v_total FROM RENTAL WHERE Rental_ID=p_rental_id;
    SELECT NVL(SUM(Amount),0) INTO v_paid FROM PAYMENT
      WHERE Rental_ID=p_rental_id AND Payment_Status='Completed';
    RETURN v_total-v_paid;
  END;

  PROCEDURE START_RENTAL(p_customer_id NUMBER, p_vehicle_id NUMBER, p_employee_id NUMBER,
    p_start TIMESTAMP, p_expected TIMESTAMP, p_rental_id OUT NUMBER) IS
    v_status VEHICLE.Availability_Status%TYPE; v_type VEHICLE.Type_ID%TYPE;
    v_branch VEHICLE.Branch_ID%TYPE; v_emp_branch EMPLOYEE.Branch_ID%TYPE;
    v_registered CUSTOMER.Registration_Date%TYPE; v_rate VEHICLE_TYPE.Daily_Rate%TYPE;
    v_overlap NUMBER;
  BEGIN
    SAVEPOINT svr_start;
    IF p_start IS NULL OR p_expected IS NULL OR p_expected <= p_start
       OR p_start > CAST(SYSTIMESTAMP AS TIMESTAMP) THEN
      RAISE_APPLICATION_ERROR(-20111,'Invalid rental dates'); END IF;
    SELECT Availability_Status, Type_ID, Branch_ID INTO v_status,v_type,v_branch
      FROM VEHICLE WHERE Vehicle_ID=p_vehicle_id FOR UPDATE WAIT 10;
    IF v_status <> 'Available' THEN RAISE_APPLICATION_ERROR(-20112,'Vehicle unavailable'); END IF;
    SELECT Registration_Date INTO v_registered FROM CUSTOMER WHERE Customer_ID=p_customer_id;
    IF CAST(v_registered AS TIMESTAMP) > p_start THEN
      RAISE_APPLICATION_ERROR(-20113,'Customer registered after rental start'); END IF;
    SELECT Branch_ID INTO v_emp_branch FROM EMPLOYEE WHERE Employee_ID=p_employee_id;
    IF v_emp_branch <> v_branch THEN RAISE_APPLICATION_ERROR(-20114,'Employee belongs to another branch'); END IF;
    SELECT Daily_Rate INTO v_rate FROM VEHICLE_TYPE WHERE Type_ID=v_type;
    SELECT COUNT(*) INTO v_overlap FROM RENTAL WHERE Vehicle_ID=p_vehicle_id
      AND Status_Name IN ('Active','Completed')
      AND Start_Date < p_expected
      AND COALESCE(Actual_Return_Date,Expected_Return_Date) > p_start;
    IF v_overlap > 0 THEN RAISE_APPLICATION_ERROR(-20115,'Rental interval overlaps history'); END IF;
    p_rental_id := SEQ_SVR_RENTAL.NEXTVAL;
    g_mode := 'START';
    INSERT INTO RENTAL(Rental_ID,Customer_ID,Vehicle_ID,Employee_ID,Status_Name,
      Start_Date,Expected_Return_Date,Actual_Return_Date,Total_Amount,Daily_Rate_Snapshot)
      VALUES(p_rental_id,p_customer_id,p_vehicle_id,p_employee_id,'Active',
        p_start,p_expected,NULL,CALCULATE_CHARGE(p_start,p_expected,v_rate),v_rate);
    g_mode := NULL;
  EXCEPTION WHEN OTHERS THEN
    g_mode := NULL; ROLLBACK TO svr_start; RAISE;
  END;

  PROCEDURE RECORD_RETURN(p_rental_id NUMBER, p_actual TIMESTAMP, p_final_amount OUT NUMBER) IS
    v_vehicle NUMBER; v_status VEHICLE.Availability_Status%TYPE;
    v_rental_status RENTAL.Status_Name%TYPE; v_start TIMESTAMP;
    v_rate NUMBER; v_paid NUMBER;
  BEGIN
    SAVEPOINT svr_return;
    -- Unlocked ID lookup, then stable vehicle->rental lock order; recheck after locks.
    SELECT Vehicle_ID INTO v_vehicle FROM RENTAL WHERE Rental_ID=p_rental_id;
    SELECT Availability_Status INTO v_status FROM VEHICLE
      WHERE Vehicle_ID=v_vehicle FOR UPDATE WAIT 10;
    SELECT Status_Name,Start_Date,Daily_Rate_Snapshot INTO v_rental_status,v_start,v_rate
      FROM RENTAL WHERE Rental_ID=p_rental_id AND Vehicle_ID=v_vehicle FOR UPDATE WAIT 10;
    IF v_rental_status <> 'Active' OR v_status <> 'Rented' THEN
      RAISE_APPLICATION_ERROR(-20116,'Rental is not active or vehicle not rented'); END IF;
    IF p_actual IS NULL OR p_actual < v_start OR p_actual > CAST(SYSTIMESTAMP AS TIMESTAMP) THEN
      RAISE_APPLICATION_ERROR(-20117,'Invalid actual return date'); END IF;
    p_final_amount := CALCULATE_CHARGE(v_start,p_actual,v_rate);
    SELECT NVL(SUM(Amount),0) INTO v_paid FROM PAYMENT
      WHERE Rental_ID=p_rental_id AND Payment_Status='Completed';
    IF v_paid > p_final_amount THEN
      RAISE_APPLICATION_ERROR(-20118,'Final charge below collected payments; refund workflow required'); END IF;
    g_mode := 'RETURN';
    UPDATE RENTAL SET Status_Name='Completed', Actual_Return_Date=p_actual,
      Total_Amount=p_final_amount WHERE Rental_ID=p_rental_id;
    g_mode := NULL;
  EXCEPTION WHEN OTHERS THEN
    g_mode := NULL; ROLLBACK TO svr_return; RAISE;
  END;

  PROCEDURE RECORD_PAYMENT(p_rental_id NUMBER, p_amount NUMBER, p_method VARCHAR2,
    p_payment_date TIMESTAMP, p_payment_id OUT NUMBER) IS
    v_status RENTAL.Status_Name%TYPE;
  BEGIN
    SAVEPOINT svr_payment;
    SELECT Status_Name INTO v_status FROM RENTAL WHERE Rental_ID=p_rental_id FOR UPDATE WAIT 10;
    IF v_status NOT IN ('Active','Completed') OR p_amount IS NULL OR p_amount <= 0
       OR p_method NOT IN ('Card','UPI','Cash','Bank Transfer') OR p_payment_date IS NULL THEN
      RAISE_APPLICATION_ERROR(-20119,'Invalid payment details or rental'); END IF;
    p_payment_id := SEQ_SVR_PAYMENT.NEXTVAL;
    INSERT INTO PAYMENT(Payment_ID,Rental_ID,Payment_Date,Amount,Payment_Method,Payment_Status)
      VALUES(p_payment_id,p_rental_id,p_payment_date,p_amount,p_method,'Completed');
  EXCEPTION WHEN OTHERS THEN
    ROLLBACK TO svr_payment; RAISE;
  END;

  PROCEDURE OVERDUE_REPORT(p_as_of TIMESTAMP, p_count OUT NUMBER,
    p_estimated_outstanding OUT NUMBER) IS
    CURSOR c_overdue IS SELECT r.Rental_ID,r.Expected_Return_Date,
        r.Total_Amount-NVL((SELECT SUM(p.Amount) FROM PAYMENT p
          WHERE p.Rental_ID=r.Rental_ID AND p.Payment_Status='Completed'),0) balance
      FROM RENTAL r WHERE r.Status_Name='Active' AND r.Expected_Return_Date < p_as_of
      ORDER BY r.Rental_ID;
    v_row c_overdue%ROWTYPE;
  BEGIN
    IF p_as_of IS NULL THEN RAISE_APPLICATION_ERROR(-20120,'As-of date required'); END IF;
    p_count:=0; p_estimated_outstanding:=0;
    OPEN c_overdue;
    LOOP
      FETCH c_overdue INTO v_row; EXIT WHEN c_overdue%NOTFOUND;
      p_count:=p_count+1; p_estimated_outstanding:=p_estimated_outstanding+v_row.balance;
      DBMS_OUTPUT.PUT_LINE('OVERDUE '||v_row.Rental_ID||' due '||
        TO_CHAR(v_row.Expected_Return_Date,'YYYY-MM-DD HH24:MI:SS')||
        ' estimated balance '||TO_CHAR(v_row.balance));
    END LOOP;
    CLOSE c_overdue;
  EXCEPTION WHEN OTHERS THEN
    IF c_overdue%ISOPEN THEN CLOSE c_overdue; END IF; RAISE;
  END;
END SVR_WORKFLOW;
/

CREATE OR REPLACE TRIGGER TRG_SVR_RENTAL
BEFORE INSERT OR UPDATE OR DELETE ON RENTAL FOR EACH ROW
DECLARE
  v_rate NUMBER; v_type NUMBER; v_status VEHICLE.Availability_Status%TYPE;
  v_paid NUMBER;
BEGIN
  IF INSERTING THEN
    IF :NEW.Status_Name='Cancelled' AND :NEW.Rental_ID BETWEEN 5900 AND 5999
       AND :NEW.Total_Amount=0 AND :NEW.Actual_Return_Date IS NULL
       AND :NEW.Expected_Return_Date>:NEW.Start_Date
       AND :NEW.Start_Date>CAST(SYSTIMESTAMP AS TIMESTAMP) THEN
      NULL; -- disposable future, unpaid academic demonstration only
    ELSIF SVR_WORKFLOW.MODE_NAME='START' AND :NEW.Status_Name='Active' THEN
      SELECT Type_ID,Availability_Status INTO v_type,v_status FROM VEHICLE
        WHERE Vehicle_ID=:NEW.Vehicle_ID;
      SELECT Daily_Rate INTO v_rate FROM VEHICLE_TYPE WHERE Type_ID=v_type;
      IF v_status<>'Available' OR :NEW.Daily_Rate_Snapshot<>v_rate OR
         :NEW.Total_Amount<>SVR_WORKFLOW.CALCULATE_CHARGE(:NEW.Start_Date,:NEW.Expected_Return_Date,v_rate) THEN
        RAISE_APPLICATION_ERROR(-20130,'Rental snapshot or availability invalid'); END IF;
      UPDATE VEHICLE SET Availability_Status='Rented'
        WHERE Vehicle_ID=:NEW.Vehicle_ID AND Availability_Status='Available';
      IF SQL%ROWCOUNT<>1 THEN RAISE_APPLICATION_ERROR(-20131,'Vehicle status transition failed'); END IF;
    ELSE RAISE_APPLICATION_ERROR(-20132,'Use START_RENTAL for active rentals'); END IF;
  ELSIF UPDATING THEN
    IF :OLD.Status_Name='Cancelled' AND :OLD.Rental_ID BETWEEN 5900 AND 5999
       AND :NEW.Status_Name='Cancelled' AND :NEW.Rental_ID=:OLD.Rental_ID
       AND :NEW.Customer_ID=:OLD.Customer_ID AND :NEW.Vehicle_ID=:OLD.Vehicle_ID
       AND :NEW.Employee_ID=:OLD.Employee_ID AND :NEW.Start_Date=:OLD.Start_Date
       AND :NEW.Daily_Rate_Snapshot=:OLD.Daily_Rate_Snapshot
       AND :NEW.Total_Amount=0 AND :NEW.Actual_Return_Date IS NULL
       AND :NEW.Expected_Return_Date>:NEW.Start_Date THEN NULL;
    ELSIF SVR_WORKFLOW.MODE_NAME='RETURN' AND :OLD.Status_Name='Active'
       AND :NEW.Status_Name='Completed' AND :NEW.Rental_ID=:OLD.Rental_ID
       AND :NEW.Customer_ID=:OLD.Customer_ID AND :NEW.Vehicle_ID=:OLD.Vehicle_ID
       AND :NEW.Employee_ID=:OLD.Employee_ID AND :NEW.Start_Date=:OLD.Start_Date
       AND :NEW.Expected_Return_Date=:OLD.Expected_Return_Date
       AND :NEW.Daily_Rate_Snapshot=:OLD.Daily_Rate_Snapshot
       AND :NEW.Actual_Return_Date IS NOT NULL
       AND :NEW.Total_Amount=SVR_WORKFLOW.CALCULATE_CHARGE(:OLD.Start_Date,:NEW.Actual_Return_Date,:OLD.Daily_Rate_Snapshot) THEN
      SELECT NVL(SUM(Amount),0) INTO v_paid FROM PAYMENT
        WHERE Rental_ID=:OLD.Rental_ID AND Payment_Status='Completed';
      IF v_paid>:NEW.Total_Amount THEN RAISE_APPLICATION_ERROR(-20133,'Paid amount exceeds final charge'); END IF;
      UPDATE VEHICLE SET Availability_Status='Available'
        WHERE Vehicle_ID=:OLD.Vehicle_ID AND Availability_Status='Rented';
      IF SQL%ROWCOUNT<>1 THEN RAISE_APPLICATION_ERROR(-20134,'Vehicle is not rented'); END IF;
    ELSE RAISE_APPLICATION_ERROR(-20135,'Rental history is immutable; use RECORD_RETURN'); END IF;
  ELSE
    IF :OLD.Status_Name<>'Cancelled' OR :OLD.Rental_ID NOT BETWEEN 5900 AND 5999 THEN
      RAISE_APPLICATION_ERROR(-20136,'Rental history cannot be deleted'); END IF;
    SELECT COUNT(*) INTO v_paid FROM PAYMENT WHERE Rental_ID=:OLD.Rental_ID;
    IF v_paid<>0 THEN RAISE_APPLICATION_ERROR(-20137,'Paid rental cannot be deleted'); END IF;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_SVR_PAYMENT
FOR INSERT OR UPDATE OR DELETE ON PAYMENT COMPOUND TRIGGER
  v_rental NUMBER; v_count NUMBER:=0;
  BEFORE EACH ROW IS
    v_status RENTAL.Status_Name%TYPE; v_total NUMBER; v_start TIMESTAMP;
  BEGIN
    IF UPDATING OR DELETING THEN
      RAISE_APPLICATION_ERROR(-20140,'Payment history is immutable'); END IF;
    IF :NEW.Payment_Status<>'Completed' OR :NEW.Amount<=0 OR :NEW.Amount IS NULL
       OR :NEW.Payment_Method NOT IN ('Card','UPI','Cash','Bank Transfer') THEN
      RAISE_APPLICATION_ERROR(-20141,'Only valid completed payments accepted'); END IF;
    IF v_count>0 THEN RAISE_APPLICATION_ERROR(-20142,'Insert one payment per statement'); END IF;
    SELECT Status_Name,Total_Amount,Start_Date INTO v_status,v_total,v_start
      FROM RENTAL WHERE Rental_ID=:NEW.Rental_ID FOR UPDATE WAIT 10;
    IF v_status NOT IN ('Active','Completed') OR :NEW.Payment_Date< v_start
       OR :NEW.Payment_Date>CAST(SYSTIMESTAMP AS TIMESTAMP) OR :NEW.Amount>v_total THEN
      RAISE_APPLICATION_ERROR(-20143,'Invalid rental, date or payment amount'); END IF;
    v_rental:=:NEW.Rental_ID; v_count:=v_count+1;
  END BEFORE EACH ROW;
  AFTER STATEMENT IS
    v_total NUMBER; v_paid NUMBER;
  BEGIN
    IF INSERTING AND v_count=1 THEN
      SELECT Total_Amount INTO v_total FROM RENTAL WHERE Rental_ID=v_rental;
      SELECT NVL(SUM(Amount),0) INTO v_paid FROM PAYMENT
        WHERE Rental_ID=v_rental AND Payment_Status='Completed';
      IF v_paid>v_total THEN RAISE_APPLICATION_ERROR(-20144,'Completed payments exceed bill'); END IF;
    END IF;
  END AFTER STATEMENT;
END TRG_SVR_PAYMENT;
/

DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM USER_OBJECTS WHERE OBJECT_NAME IN
    ('SVR_WORKFLOW','TRG_SVR_RENTAL','TRG_SVR_PAYMENT') AND STATUS='INVALID';
  IF n<>0 THEN RAISE_APPLICATION_ERROR(-20150,'Invalid Step 3 objects; inspect USER_ERRORS'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS Step 3 package and triggers compiled VALID');
END;
/
