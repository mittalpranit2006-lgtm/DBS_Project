SET ECHO ON VERIFY OFF
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE BEGIN IF USER<>'SVR_APP' OR SYS_CONTEXT('USERENV','CON_NAME')<>'XEPDB1' THEN RAISE_APPLICATION_ERROR(-20300,'Wrong account/container'); END IF; END;
/
SAVEPOINT member_demo;
INSERT INTO CUSTOMER VALUES(1991,'Demo','One','demo1991@example.test','DL-DEMO-1991','Demo address',SYSDATE);
UPDATE CUSTOMER SET Address='Updated demo address' WHERE Customer_ID=1991;
DELETE FROM CUSTOMER WHERE Customer_ID=1991;
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


ROLLBACK TO member_demo;
PROMPT PASS member 1 DML rolled back and five SELECTs completed

