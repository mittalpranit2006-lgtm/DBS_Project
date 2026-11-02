# Eight-table implementation schema (Step 2A)

This implementation amendment to Review 1 pp. 3, 6–7 was executed and verified in Oracle XEPDB1 during Step 2B. Exact definitions are in `database/schema/02_tables.sql`; actual results are in `evidence/step2b-project.log` and `evidence/step2b-negative-rollback.log`. The submitted nine-relation Review 1 remains historical. See `design-changes.md` and `er-implementation.mmd` for the amendment.

## Columns, keys and nullability

`NN` = NOT NULL; `PK` = primary key; `UQ` = unique; `FK` = foreign key. Oracle unquoted identifiers are stored uppercase. `EMPLOYEE."ROLE"` is quoted uppercase because ROLE is a SQL keyword. `NUMBER(p,s)` monetary values use two decimal places; `TIMESTAMP(0)` stores second precision. Each FK has Oracle's default restrictive deletion behavior (no `ON DELETE CASCADE` or `SET NULL`).

| Table | Columns and types | Keys and references |
| --- | --- | --- |
| CUSTOMER | Customer_ID NUMBER(6) NN; First_Name VARCHAR2(60 CHAR) NN; Last_Name VARCHAR2(60 CHAR) NN; Email VARCHAR2(254 CHAR) NN; License_No VARCHAR2(24 CHAR) NN; Address VARCHAR2(240 CHAR) NN; Registration_Date DATE NN DEFAULT SYSDATE | PK Customer_ID; UQ Email, License_No |
| CUSTOMER_PHONE | Customer_ID NUMBER(6) NN; Phone_No VARCHAR2(15 CHAR) NN | Composite PK (Customer_ID, Phone_No); FK Customer_ID → CUSTOMER; phone digits 10–15 |
| VEHICLE_TYPE | Type_ID NUMBER(4) NN; Type_Name VARCHAR2(60 CHAR) NN; Daily_Rate NUMBER(10,2) NN; Security_Deposit NUMBER(10,2) NN DEFAULT 0 | PK Type_ID; UQ Type_Name; Daily_Rate > 0, Security_Deposit ≥ 0 |
| BRANCH | Branch_ID NUMBER(4) NN; Branch_Name VARCHAR2(80 CHAR) NN; Location VARCHAR2(160 CHAR) NN; Phone VARCHAR2(15 CHAR) NN | PK Branch_ID; UQ (Branch_Name, Location), Phone; phone digits 10–15 |
| VEHICLE | Vehicle_ID NUMBER(6) NN; Registration_No VARCHAR2(24 CHAR) NN; Brand VARCHAR2(60 CHAR) NN; Model VARCHAR2(60 CHAR) NN; Purchase_Year NUMBER(4) NN; Availability_Status VARCHAR2(16 CHAR) NN DEFAULT `Available`; Type_ID NUMBER(4) NN; Branch_ID NUMBER(4) NN | PK Vehicle_ID; UQ Registration_No; FKs Type_ID → VEHICLE_TYPE, Branch_ID → BRANCH; year 1990–2100; availability `Available`, `Rented`, `Maintenance` |
| EMPLOYEE | Employee_ID NUMBER(6) NN; Name VARCHAR2(120 CHAR) NN; Email VARCHAR2(254 CHAR) NN; Phone VARCHAR2(15 CHAR) NN; "ROLE" VARCHAR2(40 CHAR) NN; Branch_ID NUMBER(4) NN | PK Employee_ID; UQ Email, Phone; FK Branch_ID → BRANCH; phone digits 10–15 |
| RENTAL | Rental_ID NUMBER(8) NN; Customer_ID NUMBER(6) NN; Vehicle_ID NUMBER(6) NN; Employee_ID NUMBER(6) NN; Status_Name VARCHAR2(12 CHAR) NN DEFAULT `Active`; Start_Date TIMESTAMP(0) NN; Expected_Return_Date TIMESTAMP(0) NN; Actual_Return_Date TIMESTAMP(0) nullable; Total_Amount NUMBER(12,2) NN DEFAULT 0; Daily_Rate_Snapshot NUMBER(10,2) NN | PK Rental_ID; FKs Customer_ID → CUSTOMER, Vehicle_ID → VEHICLE, Employee_ID → EMPLOYEE; status `Active`/`Completed`/`Cancelled`; expected > start; actual ≥ start if present; Completed requires actual, other statuses require NULL actual; nonnegative total, Cancelled total zero, positive snapshot rate |
| PAYMENT | Payment_ID NUMBER(8) NN; Rental_ID NUMBER(8) NN; Payment_Date TIMESTAMP(0) NN DEFAULT SYSTIMESTAMP; Amount NUMBER(12,2) NN; Payment_Method VARCHAR2(20 CHAR) NN; Payment_Status VARCHAR2(12 CHAR) NN DEFAULT `Completed` | PK Payment_ID; FK Rental_ID → RENTAL; Amount > 0; method `Card`/`UPI`/`Cash`/`Bank Transfer`; status `Pending`/`Completed`/`Refunded` |

The `UQ_RENTAL_ACTIVE_VEH` unique function-based index allows at most one `Active` RENTAL per Vehicle_ID. This is one DDL-level concurrency backstop, not a complete rental workflow. It does not enforce non-overlap of historical intervals, availability transitions, rate capture, or payment totals.

Email and licence uniqueness are exact stored-value checks. `Phone_No` is unique only within one customer's composite key, so a shared number can appear for two customers. Application input normalization and stronger format validation may be added later without changing the eight-table model.

## Relationship and deletion rules

CUSTOMER → CUSTOMER_PHONE and RENTAL; VEHICLE_TYPE → VEHICLE; BRANCH → VEHICLE and EMPLOYEE; VEHICLE → RENTAL; EMPLOYEE → RENTAL; RENTAL → PAYMENT are all 1:N. Child FKs are mandatory. There is no status table or status FK. Every FK restricts parent deletion while children exist; no automatic cascade is used. Thus referenced customers, vehicles and employees cannot be deleted by ordinary parent DELETE, and a rental with payments cannot be deleted. A rental without payments is *not* protected by an FK against direct DELETE, so Step 3 must restrict deletion of genuine rental history through application logic or a deliberate trigger. Demonstration DELETEs target only disposable, unreferenced records and are rolled back.

## Derived and transactional rules

`Rental_Duration` and `Late_Days` remain derived, not stored. `Customer_Name` is represented by First_Name and Last_Name. `Daily_Rate_Snapshot` is the sole added technical data column, frozen at rental start; `Total_Amount` records the current estimate for Active, the final charge for Completed, or zero for Cancelled. Billing policy details are in `design-changes.md`.

Step 3 implemented guarded start/return procedures with `SELECT ... FOR UPDATE` vehicle locks, status checks, rate capture, charge calculation, historical overlap rejection and availability updates in one caller-controlled transaction. Payment validation/aggregate limits and immutable history are enforced by the compound payment trigger, with a vehicle transition trigger and rental trigger. Genuine cancellation and refund workflows remain unimplemented. See `plsql-workflows.md` and `transaction-and-concurrency.md`. No login/authentication tables are planned; EMPLOYEE.Role records duties, not application permissions.
