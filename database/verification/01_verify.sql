-- Read-only assertions after schema and seed. A failed assertion exits SQL*Plus.
SET ECHO OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE
BEGIN
  IF USER <> 'SVR_APP' OR SYS_CONTEXT('USERENV', 'CON_NAME') <> 'XEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20010, 'Expected SVR_APP in XEPDB1; no verification run');
  END IF;
END;
/
SELECT USER AS project_username,
       SYS_CONTEXT('USERENV','CON_NAME') AS container_name,
       SYS_CONTEXT('USERENV','SERVICE_NAME') AS service_name
  FROM dual;

COLUMN table_name FORMAT A20
SELECT 'CUSTOMER' table_name,COUNT(*) row_count FROM CUSTOMER
UNION ALL SELECT 'CUSTOMER_PHONE',COUNT(*) FROM CUSTOMER_PHONE
UNION ALL SELECT 'VEHICLE_TYPE',COUNT(*) FROM VEHICLE_TYPE
UNION ALL SELECT 'BRANCH',COUNT(*) FROM BRANCH
UNION ALL SELECT 'VEHICLE',COUNT(*) FROM VEHICLE
UNION ALL SELECT 'EMPLOYEE',COUNT(*) FROM EMPLOYEE
UNION ALL SELECT 'RENTAL',COUNT(*) FROM RENTAL
UNION ALL SELECT 'PAYMENT',COUNT(*) FROM PAYMENT;

DECLARE
  v_count NUMBER;
  PROCEDURE require_zero(p_count NUMBER, p_label VARCHAR2) IS
  BEGIN
    IF p_count <> 0 THEN RAISE_APPLICATION_ERROR(-20100, p_label || ': ' || p_count); END IF;
    DBMS_OUTPUT.PUT_LINE('PASS ' || p_label);
  END;
  PROCEDURE require_ten(p_count NUMBER, p_label VARCHAR2) IS
  BEGIN
    IF p_count < 10 THEN RAISE_APPLICATION_ERROR(-20101, p_label || ' has only ' || p_count || ' rows'); END IF;
    DBMS_OUTPUT.PUT_LINE('PASS ' || p_label || ' rows=' || p_count);
  END;
BEGIN
  SELECT COUNT(*) INTO v_count FROM USER_TABLES;
  IF v_count <> 8 THEN RAISE_APPLICATION_ERROR(-20102, 'Expected exactly eight user tables'); END IF;
  SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME IN
    ('CUSTOMER','CUSTOMER_PHONE','VEHICLE_TYPE','BRANCH','VEHICLE','EMPLOYEE','RENTAL','PAYMENT');
  IF v_count <> 8 THEN RAISE_APPLICATION_ERROR(-20103, 'Eight expected table names not all present'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS exact eight-table set');

  SELECT COUNT(*) INTO v_count FROM CUSTOMER; require_ten(v_count,'CUSTOMER');
  SELECT COUNT(*) INTO v_count FROM CUSTOMER_PHONE; require_ten(v_count,'CUSTOMER_PHONE');
  SELECT COUNT(*) INTO v_count FROM VEHICLE_TYPE; require_ten(v_count,'VEHICLE_TYPE');
  SELECT COUNT(*) INTO v_count FROM BRANCH; require_ten(v_count,'BRANCH');
  SELECT COUNT(*) INTO v_count FROM VEHICLE; require_ten(v_count,'VEHICLE');
  SELECT COUNT(*) INTO v_count FROM EMPLOYEE; require_ten(v_count,'EMPLOYEE');
  SELECT COUNT(*) INTO v_count FROM RENTAL; require_ten(v_count,'RENTAL');
  SELECT COUNT(*) INTO v_count FROM PAYMENT; require_ten(v_count,'PAYMENT');

  SELECT COUNT(*) INTO v_count FROM USER_CONSTRAINTS
   WHERE TABLE_NAME IN ('CUSTOMER','CUSTOMER_PHONE','VEHICLE_TYPE','BRANCH',
                        'VEHICLE','EMPLOYEE','RENTAL','PAYMENT')
     AND (STATUS <> 'ENABLED' OR VALIDATED <> 'VALIDATED');
  require_zero(v_count,'disabled or unvalidated constraints');
  SELECT COUNT(*) INTO v_count FROM USER_CONSTRAINTS
   WHERE CONSTRAINT_TYPE = 'P' AND TABLE_NAME IN
    ('CUSTOMER','CUSTOMER_PHONE','VEHICLE_TYPE','BRANCH','VEHICLE','EMPLOYEE','RENTAL','PAYMENT');
  IF v_count <> 8 THEN RAISE_APPLICATION_ERROR(-20104, 'Expected eight primary keys'); END IF;
  SELECT COUNT(*) INTO v_count FROM USER_CONSTRAINTS
   WHERE CONSTRAINT_TYPE = 'R' AND TABLE_NAME IN
    ('CUSTOMER','CUSTOMER_PHONE','VEHICLE_TYPE','BRANCH','VEHICLE','EMPLOYEE','RENTAL','PAYMENT');
  IF v_count <> 8 THEN RAISE_APPLICATION_ERROR(-20105, 'Expected eight foreign keys'); END IF;
  SELECT COUNT(*) INTO v_count FROM USER_CONSTRAINTS
   WHERE CONSTRAINT_TYPE = 'U' AND TABLE_NAME IN
    ('CUSTOMER','CUSTOMER_PHONE','VEHICLE_TYPE','BRANCH','VEHICLE','EMPLOYEE','RENTAL','PAYMENT');
  IF v_count <> 8 THEN RAISE_APPLICATION_ERROR(-20111, 'Expected eight unique constraints'); END IF;
  SELECT COUNT(*) INTO v_count FROM USER_CONSTRAINTS
   WHERE CONSTRAINT_TYPE = 'C' AND TABLE_NAME IN
    ('CUSTOMER','CUSTOMER_PHONE','VEHICLE_TYPE','BRANCH','VEHICLE','EMPLOYEE','RENTAL','PAYMENT');
  IF v_count < 15 THEN RAISE_APPLICATION_ERROR(-20112, 'Expected at least fifteen check constraints'); END IF;
  SELECT COUNT(*) INTO v_count FROM USER_CONS_COLUMNS
   WHERE CONSTRAINT_NAME = 'PK_CUSTOMER_PHONE' AND COLUMN_NAME IN ('CUSTOMER_ID','PHONE_NO');
  IF v_count <> 2 THEN RAISE_APPLICATION_ERROR(-20106, 'Composite CUSTOMER_PHONE key incomplete'); END IF;
  SELECT COUNT(*) INTO v_count FROM USER_INDEXES
   WHERE INDEX_NAME = 'UQ_RENTAL_ACTIVE_VEH' AND STATUS = 'VALID' AND UNIQUENESS = 'UNIQUE';
  IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20107, 'Active-vehicle unique index absent/invalid'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS primary, foreign, unique and check constraints; active-vehicle index');

  SELECT COUNT(*) INTO v_count FROM CUSTOMER_PHONE cp WHERE NOT EXISTS
    (SELECT 1 FROM CUSTOMER c WHERE c.Customer_ID = cp.Customer_ID);
  require_zero(v_count,'orphan customer phones');
  SELECT COUNT(*) INTO v_count FROM VEHICLE v WHERE NOT EXISTS
    (SELECT 1 FROM VEHICLE_TYPE t WHERE t.Type_ID = v.Type_ID) OR NOT EXISTS
    (SELECT 1 FROM BRANCH b WHERE b.Branch_ID = v.Branch_ID);
  require_zero(v_count,'orphan vehicle references');
  SELECT COUNT(*) INTO v_count FROM EMPLOYEE e WHERE NOT EXISTS
    (SELECT 1 FROM BRANCH b WHERE b.Branch_ID = e.Branch_ID);
  require_zero(v_count,'orphan employees');
  SELECT COUNT(*) INTO v_count FROM RENTAL r WHERE NOT EXISTS
    (SELECT 1 FROM CUSTOMER c WHERE c.Customer_ID = r.Customer_ID) OR NOT EXISTS
    (SELECT 1 FROM VEHICLE v WHERE v.Vehicle_ID = r.Vehicle_ID) OR NOT EXISTS
    (SELECT 1 FROM EMPLOYEE e WHERE e.Employee_ID = r.Employee_ID);
  require_zero(v_count,'orphan rental references');
  SELECT COUNT(*) INTO v_count FROM PAYMENT p WHERE NOT EXISTS
    (SELECT 1 FROM RENTAL r WHERE r.Rental_ID = p.Rental_ID);
  require_zero(v_count,'orphan payments');

  SELECT COUNT(*) INTO v_count FROM RENTAL r JOIN CUSTOMER c ON c.Customer_ID=r.Customer_ID
    WHERE CAST(r.Start_Date AS DATE) < c.Registration_Date;
  require_zero(v_count,'rentals before customer registration');

  SELECT COUNT(*) INTO v_count FROM RENTAL r WHERE
    (Status_Name = 'Active' AND Total_Amount <>
      GREATEST(1,CEIL(CAST(Expected_Return_Date AS DATE)-CAST(Start_Date AS DATE))) * Daily_Rate_Snapshot)
    OR (Status_Name = 'Completed' AND Total_Amount <>
      GREATEST(1,CEIL(CAST(Actual_Return_Date AS DATE)-CAST(Start_Date AS DATE))) * Daily_Rate_Snapshot)
    OR (Status_Name = 'Cancelled' AND Total_Amount <> 0);
  require_zero(v_count,'seed charge mismatches');
  SELECT COUNT(*) INTO v_count FROM VEHICLE v WHERE
    (v.Availability_Status = 'Rented' AND NOT EXISTS
       (SELECT 1 FROM RENTAL r WHERE r.Vehicle_ID=v.Vehicle_ID AND r.Status_Name='Active'))
    OR (v.Availability_Status <> 'Rented' AND EXISTS
       (SELECT 1 FROM RENTAL r WHERE r.Vehicle_ID=v.Vehicle_ID AND r.Status_Name='Active'));
  require_zero(v_count,'seed availability mismatches');
  SELECT COUNT(*) INTO v_count FROM RENTAL r WHERE
    (SELECT NVL(SUM(p.Amount),0) FROM PAYMENT p
       WHERE p.Rental_ID=r.Rental_ID AND p.Payment_Status='Completed') > r.Total_Amount;
  require_zero(v_count,'completed payments exceed charges');
  SELECT COUNT(*) INTO v_count FROM PAYMENT p JOIN RENTAL r ON r.Rental_ID=p.Rental_ID
    WHERE r.Status_Name='Cancelled' OR p.Payment_Date < r.Start_Date;
  require_zero(v_count,'cancelled/pre-start payment conflicts');

  SELECT COUNT(*) INTO v_count FROM RENTAL WHERE Status_Name='Active'
    AND Expected_Return_Date < CAST(SYSTIMESTAMP AS TIMESTAMP);
  IF v_count < 1 THEN RAISE_APPLICATION_ERROR(-20108,'Expected an overdue Active example'); END IF;
  SELECT COUNT(*) INTO v_count FROM RENTAL WHERE Status_Name='Completed'
    AND Actual_Return_Date > Expected_Return_Date;
  IF v_count < 1 THEN RAISE_APPLICATION_ERROR(-20109,'Expected a late Completed example'); END IF;
  SELECT COUNT(*) INTO v_count FROM RENTAL WHERE Status_Name='Cancelled';
  IF v_count < 1 THEN RAISE_APPLICATION_ERROR(-20110,'Expected a Cancelled example'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS Active overdue, Completed late and Cancelled examples');
END;
/

SELECT constraint_type, status, validated, COUNT(*) AS constraint_count
  FROM user_constraints
 WHERE table_name IN ('CUSTOMER','CUSTOMER_PHONE','VEHICLE_TYPE','BRANCH',
                      'VEHICLE','EMPLOYEE','RENTAL','PAYMENT')
 GROUP BY constraint_type, status, validated
 ORDER BY constraint_type, status, validated;

SELECT constraint_name, table_name, constraint_type, status, validated
  FROM user_constraints
 WHERE table_name IN ('CUSTOMER','CUSTOMER_PHONE','VEHICLE_TYPE','BRANCH',
                      'VEHICLE','EMPLOYEE','RENTAL','PAYMENT')
 ORDER BY table_name, constraint_name;
