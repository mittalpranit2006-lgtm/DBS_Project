-- Fifteen read-only demonstration queries: five per team member.
SET ECHO OFF
SET VERIFY OFF
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE
BEGIN
  IF USER <> 'SVR_APP' OR SYS_CONTEXT('USERENV', 'CON_NAME') <> 'XEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20010, 'Expected SVR_APP in XEPDB1; no queries run');
  END IF;
END;
/
PROMPT Member 1 - Customers, phones, payments and revenue
-- M1.1 simple selection
PROMPT M1.1 - customer list
SELECT Customer_ID, First_Name, Last_Name, Email FROM CUSTOMER ORDER BY Customer_ID;
-- M1.2 one-to-many join
PROMPT M1.2 - customer phones
SELECT c.Customer_ID, c.First_Name, c.Last_Name, cp.Phone_No
  FROM CUSTOMER c JOIN CUSTOMER_PHONE cp ON cp.Customer_ID=c.Customer_ID
 ORDER BY c.Customer_ID, cp.Phone_No;
-- M1.3 complex multi-table join and aggregation; collected rent, not accrued revenue
PROMPT M1.3 - collected rent by branch
SELECT b.Branch_Name, b.Location, SUM(p.Amount) AS Collected_Rent
  FROM PAYMENT p JOIN RENTAL r ON r.Rental_ID=p.Rental_ID
       JOIN VEHICLE v ON v.Vehicle_ID=r.Vehicle_ID
       JOIN BRANCH b ON b.Branch_ID=v.Branch_ID
 WHERE p.Payment_Status='Completed' AND r.Status_Name<>'Cancelled'
 GROUP BY b.Branch_Name,b.Location ORDER BY Collected_Rent DESC;
-- M1.4 correlated nested query
PROMPT M1.4 - customers with completed payments
SELECT c.Customer_ID,c.First_Name,c.Last_Name FROM CUSTOMER c
 WHERE EXISTS (SELECT 1 FROM RENTAL r JOIN PAYMENT p ON p.Rental_ID=r.Rental_ID
                WHERE r.Customer_ID=c.Customer_ID AND p.Payment_Status='Completed')
 ORDER BY c.Customer_ID;
-- M1.5 SQL functions and aggregation
PROMPT M1.5 - collection by month
SELECT TO_CHAR(p.Payment_Date,'YYYY-MM') AS Collection_Month,
       COUNT(*) AS Payment_Count, ROUND(SUM(p.Amount),2) AS Cash_Collected
  FROM PAYMENT p WHERE p.Payment_Status='Completed'
 GROUP BY TO_CHAR(p.Payment_Date,'YYYY-MM') ORDER BY Collection_Month;

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
