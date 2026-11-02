# Step 3 member demonstration guide

Use SQL*Plus in `C:\Users\mitta\Desktop\DBS Project\SmartVehicleRental`, connect privately as `SVR_APP@"DESKTOP-FFIRV71:1521/xepdb1"`, and run `@database/step3_members.sql`. The runner asks for the password and spools `evidence/step3-members.log`; no password belongs in source, command arguments or the log. It was executed successfully on 24 October 2026.

| Member | Own script | Disposable DML | Five SELECTs |
| --- | --- | --- | --- |
| 1 customers/phones/payments/revenue | `database/step3/member_1_demo.sql` | INSERT, UPDATE, DELETE unreferenced CUSTOMER 1991 | M1.1–M1.5 simple customer list, phone join, branch collected-cash aggregation, correlated EXISTS, monthly date/round functions |
| 2 vehicles/types/branches/employees | `database/step3/member_2_demo.sql` | INSERT, UPDATE, DELETE unused VEHICLE_TYPE 99 | M2.1–M2.5 simple type list, vehicle/type/branch join, nested EXISTS, outer join count, UPPER/LENGTH functions |
| 3 rentals/returns/charges | `database/step3/member_3_demo.sql` | INSERT, UPDATE, DELETE future unpaid Cancelled RENTAL 5998 | M3.1–M3.5 simple rental list, customer/vehicle/type join, nested EXISTS, derived day functions, status aggregation |

Each script checks SVR_APP/XEPDB1, uses a savepoint, performs its DML, executes its five SELECTs and rolls back. The Member 3 DML exemption is restricted to future Cancelled rentals in ID 5900–5999 with no payment. Genuine rental starts and returns should be shown through `SVR_WORKFLOW.START_RENTAL` and `SVR_WORKFLOW.RECORD_RETURN`, as in `database/step3/02_functional_test.sql`; never DELETE real rental history. The existing 15 SELECT labels/results remain in `evidence/step2b-project.log` too.

## Step 4 HTTP demonstration

Build and start the localhost backend as in `backend-setup.md`. Member 1 can show CUSTOMER create/search/update/delete, composite CUSTOMER_PHONE operations, PAYMENT listing, outstanding balance and branch cash report. Member 2 can show VEHICLE_TYPE, BRANCH, VEHICLE and EMPLOYEE CRUD/search, then the referenced BRANCH delete returning 409. Member 3 can show RENTAL listing/detail, `POST /api/rentals/start`, `POST /api/rentals/{id}/return`, charge estimate and overdue report. The workflow endpoints call the installed package, not direct rental/payment DML; see the exact JSON fields in `api-reference.md`.

For repeatable demonstrations without changing the seed, temporarily set `SVR_TEST_MODE=true` in ignored `backend/local-config.ps1` and send `X-SVR-Rollback: true` on workflow POST requests. The response confirms the rollback header. Remove that local test setting for normal use. `backend/integration-test.py` provides a complete observed run and deletes only its five isolated master records; its output is `evidence/step4-http-integration.log`.

## Step 5 screen-to-database demonstration

The browser opens `http://127.0.0.1:8080/`. Each member can point to the visible result after the API confirms it. For workflow demos that must leave seed history intact, use the separate rollback-only browser server described in `frontend-guide.md`; its UI explicitly says the test transaction was rolled back.

| Owner and screen action | HTTP endpoint | SQL or PL/SQL | Tables | Visible result |
| --- | --- | --- | --- | --- |
| Member 1: add/search/edit/delete customer | `POST/GET/PUT/DELETE /api/customers` | Parameterized `INSERT/SELECT/UPDATE/DELETE` in `MasterRepository` | CUSTOMER | Search row, details, update or reference rejection |
| Member 1: add/edit/remove phone | `POST /api/customers/{id}/phones`; `PUT/DELETE .../{phone}` | Parameterized DML using both CUSTOMER_ID and PHONE_NO | CUSTOMER_PHONE | Phone list updates |
| Member 1: payment and balance | `POST /api/payments`; `GET /api/payments`, `/api/reports/outstanding` | `SVR_WORKFLOW.RECORD_PAYMENT`, `OUTSTANDING_BALANCE`; payment SELECT | PAYMENT, RENTAL | Payment row and remaining balance, or cap rejection |
| Member 1: revenue | `GET /api/reports/revenue?basis=cash` and `basis=recognized` | Prepared branch joins and aggregations | PAYMENT, RENTAL, VEHICLE, BRANCH | Separate cash and recognized tables |
| Member 2: type/branch/vehicle/employee CRUD and search | `GET/POST/PUT/DELETE /api/vehicle-types`, `/branches`, `/vehicles`, `/employees` | Fixed-table parameterized CRUD in `MasterRepository`; vehicle trigger checks status | VEHICLE_TYPE, BRANCH, VEHICLE, EMPLOYEE | Lists, details, updated rows and blocked referenced delete |
| Member 3: rental search/detail | `GET /api/rentals`, `/api/rentals/{id}` | Parameterized RENTAL SELECT | RENTAL | Filtered status/history and detail |
| Member 3: estimate/start/return | `GET /api/reports/charge-estimate`; `POST /api/rentals/start`; `POST /api/rentals/{id}/return` | `SVR_WORKFLOW.CALCULATE_CHARGE`, `START_RENTAL`, `RECORD_RETURN` | RENTAL, VEHICLE, CUSTOMER, EMPLOYEE, VEHICLE_TYPE | Estimated then final charge, rental status and availability |
| Member 3: overdue | `GET /api/reports/overdue` | `SVR_WORKFLOW.OVERDUE_REPORT` and matching parameterized SELECT | RENTAL, PAYMENT | Count, estimated outstanding and overdue rows |

The five varied SELECTs and each member's disposable INSERT/UPDATE/DELETE remain separately demonstrated by the Step 3 SQL*Plus scripts above. The UI does not expose unrestricted historical rental/payment editing or cancellation/refunds.

## Step 6A browser rehearsal actually observed

The actions in the table above were repeated in the real browser against `SVR_APP`/`XEPDB1` on 24–25 October 2026. Member 1 used disposable customers 1986/1987 and a phone, and customer 1989 for a visible address update, then showed rollback-only payment, outstanding balance and both revenue bases. Member 2 used disposable type 98, branch 98, vehicle 3986 and employee 2986; the referenced branch DELETE returned 409, then the records were removed in dependency order. Member 3 showed a ₹3,000 two-day estimate, rejected reverse dates, rollback-only start/return, refreshed availability/status and overdue reporting. The rollback-only UI explicitly labelled its operations as rolled back; no permanent rental/payment history was added. The complete browser outcomes and screenshots are in `acceptance-test-results.md`, `evidence/step6a-member*.jpg` and `evidence/step6a-customer-update.jpg`.

For viva mapping, follow each row of the screen-to-database table in order: perform the screen action, point to the API route, name the `MasterRepository` SQL or `SVR_WORKFLOW` member, identify the affected tables, and show the refreshed row/report or rejected error. Use the Step 3 member scripts for each person's separate INSERT/UPDATE/DELETE and five varied SELECT obligations; do not imply the rollback-only browser operations committed.

## Committed Step 6A follow-up evidence

The normal app on port 8080 later committed a separate fictional workflow: CUSTOMER 1981 and VEHICLE 3981, RENTAL 7016 (started Active and returned Completed), and PAYMENT 8018 (₹500 UPI). The rental's ₹1,200 rate snapshot and final charge, Available vehicle status and ₹700 remaining balance were independently verified in Oracle. A ₹701 overpayment was rejected. These records remain protected history; use them for **read-only** viva inspection, and use a fresh isolated test case for any repeatable write demonstration. The screenshots, HTTP responses and fresh SQL*Plus audit are listed in `acceptance-test-results.md`. The historical rollback-only member rehearsal above remains distinct from this committed example.
