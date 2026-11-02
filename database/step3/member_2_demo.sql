SET ECHO ON VERIFY OFF
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE BEGIN IF USER<>'SVR_APP' OR SYS_CONTEXT('USERENV','CON_NAME')<>'XEPDB1' THEN RAISE_APPLICATION_ERROR(-20300,'Wrong account/container'); END IF; END;
/
SAVEPOINT member_demo;
INSERT INTO VEHICLE_TYPE VALUES(99,'Disposable Demo Type',999,0);
UPDATE VEHICLE_TYPE SET Daily_Rate=1000 WHERE Type_ID=99;
DELETE FROM VEHICLE_TYPE WHERE Type_ID=99;
PROMPT Member 2 - Fleet, types, branches and employees
-- M2.1 simple selection
PROMPT M2.1 - vehicle types and rates
SELECT Type_ID,Type_Name,Daily_Rate,Security_Deposit FROM VEHICLE_TYPE ORDER BY Type_ID;
-- M2.2 complex join
PROMPT M2.2 - vehicle, type and branch
SELECT v.Vehicle_ID,v.Registration_No,t.Type_Name,b.Branch_Name,b.Location,
       v.Availability_Status
  FROM VEHICLE v JOIN VEHICLE_TYPE t ON t.Type_ID=v.Type_ID
       JOIN BRANCH b ON b.Branch_ID=v.Branch_ID ORDER BY v.Vehicle_ID;
-- M2.3 nested query: branches with an available vehicle
PROMPT M2.3 - branches with available vehicles
SELECT b.Branch_ID,b.Branch_Name FROM BRANCH b
 WHERE EXISTS (SELECT 1 FROM VEHICLE v WHERE v.Branch_ID=b.Branch_ID
                 AND v.Availability_Status='Available') ORDER BY b.Branch_ID;
-- M2.4 aggregation and outer join
PROMPT M2.4 - fleet size by branch
SELECT b.Branch_ID,b.Branch_Name,COUNT(v.Vehicle_ID) AS Fleet_Size
  FROM BRANCH b LEFT JOIN VEHICLE v ON v.Branch_ID=b.Branch_ID
 GROUP BY b.Branch_ID,b.Branch_Name ORDER BY b.Branch_ID;
-- M2.5 SQL functions
PROMPT M2.5 - employee duties and phone lengths
SELECT e.Employee_ID,UPPER(e.Name) AS Employee_Name,e."ROLE",b.Branch_Name,
       LENGTH(e.Phone) AS Phone_Digits
  FROM EMPLOYEE e JOIN BRANCH b ON b.Branch_ID=e.Branch_ID
 ORDER BY e.Employee_ID;


ROLLBACK TO member_demo;
PROMPT PASS member 2 DML rolled back and five SELECTs completed

