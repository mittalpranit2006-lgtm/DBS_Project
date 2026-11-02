SET ECHO ON VERIFY OFF
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE BEGIN IF USER<>'SVR_APP' OR SYS_CONTEXT('USERENV','CON_NAME')<>'XEPDB1' THEN RAISE_APPLICATION_ERROR(-20300,'Wrong account/container'); END IF; END;
/
SAVEPOINT member_demo;
INSERT INTO RENTAL VALUES(5998,1009,3009,2009,'Cancelled',TIMESTAMP '2026-12-01 09:00:00',TIMESTAMP '2026-12-02 09:00:00',NULL,0,3800);
UPDATE RENTAL SET Expected_Return_Date=TIMESTAMP '2026-12-03 09:00:00' WHERE Rental_ID=5998;
DELETE FROM RENTAL WHERE Rental_ID=5998;
PROMPT Member 3 - Rentals, returns, statuses and charges
-- M3.1 simple selection
PROMPT M3.1 - rental list
SELECT Rental_ID,Status_Name,Start_Date,Expected_Return_Date,Total_Amount
  FROM RENTAL ORDER BY Rental_ID;
-- M3.2 complex customer/vehicle/rate join
PROMPT M3.2 - rental customer and vehicle details
SELECT r.Rental_ID,c.First_Name || ' ' || c.Last_Name AS Customer_Name,
       v.Registration_No,t.Type_Name,r.Status_Name,r.Daily_Rate_Snapshot
  FROM RENTAL r JOIN CUSTOMER c ON c.Customer_ID=r.Customer_ID
       JOIN VEHICLE v ON v.Vehicle_ID=r.Vehicle_ID
       JOIN VEHICLE_TYPE t ON t.Type_ID=v.Type_ID ORDER BY r.Rental_ID;
-- M3.3 nested query: vehicles with completed rental history
PROMPT M3.3 - vehicles with completed rentals
SELECT v.Vehicle_ID,v.Registration_No FROM VEHICLE v
 WHERE EXISTS (SELECT 1 FROM RENTAL r WHERE r.Vehicle_ID=v.Vehicle_ID
                 AND r.Status_Name='Completed') ORDER BY v.Vehicle_ID;
-- M3.4 derived duration and late days; neither is stored
PROMPT M3.4 - derived billable and late days
SELECT Rental_ID,Status_Name,
       CASE WHEN Status_Name='Cancelled' THEN 0 ELSE
         GREATEST(1,CEIL(CAST(COALESCE(Actual_Return_Date,Expected_Return_Date) AS DATE)
                         -CAST(Start_Date AS DATE))) END AS Billable_Days,
       CASE WHEN Status_Name='Completed' THEN
         GREATEST(0,CEIL(CAST(Actual_Return_Date AS DATE)-CAST(Expected_Return_Date AS DATE)))
         WHEN Status_Name='Active' THEN
         GREATEST(0,CEIL(CAST(SYSTIMESTAMP AS DATE)-CAST(Expected_Return_Date AS DATE)))
         ELSE 0 END AS Late_Days,
       Total_Amount FROM RENTAL ORDER BY Rental_ID;
-- M3.5 SQL functions and aggregation
PROMPT M3.5 - rental counts and average charge by status
SELECT Status_Name,COUNT(*) AS Rental_Count,
       ROUND(AVG(Total_Amount),2) AS Average_Charge
  FROM RENTAL GROUP BY Status_Name ORDER BY Status_Name;

ROLLBACK TO member_demo;
PROMPT PASS member 3 DML rolled back and five SELECTs completed

