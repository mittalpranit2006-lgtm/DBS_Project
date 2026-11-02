# Member 1 — customers, phones, payments and revenue

**Presenter:** [Name / registration number]. Use the running normal app at http://127.0.0.1:8080/ for read-only inspection. For a repeatable write demonstration, use new fictional IDs and the rollback-only server described in `docs/frontend-guide.md`, or plan to retain any committed payment as protected history. Never reuse CUSTOMER 1981 or PAYMENT 8018 for writes.

1. On Customers, search for the fictional customer and show customer detail and its phone list. For CRUD, create and edit a new disposable customer/phone, then remove the phone before the customer. API: `/api/customers` and `/api/customers/{id}/phones`; SQL: `MasterRepository` parameterized CUSTOMER and CUSTOMER_PHONE DML. Visible result: list/detail changes or validation message.
2. On Rentals/Reports, inspect completed RENTAL 7016 and PAYMENT 8018. Explain ₹1,200 final bill, ₹500 completed UPI payment and ₹700 balance. API: `/api/payments`, `/api/reports/outstanding`; PL/SQL: `SVR_WORKFLOW.RECORD_PAYMENT` and `OUTSTANDING_BALANCE`; tables PAYMENT, RENTAL. Do not submit another payment for this history.
3. Show cash and recognized revenue as separate reports. API: `/api/reports/revenue?basis=cash|recognized`; prepared aggregate joins over PAYMENT, RENTAL, VEHICLE and BRANCH.
4. Show `database/step3/member_1_demo.sql`: disposable INSERT, UPDATE, DELETE on CUSTOMER 1991, rolled back; five SELECTs M1.1 simple list, M1.2 phone join, M1.3 aggregate, M1.4 correlated EXISTS, M1.5 date/round functions. Actual output: `evidence/step3-members.log`.

**Viva prompts:** Why composite phone PK? It allows several numbers per customer while preventing a duplicate number for that customer. Why separate cash and recognized revenue? Payment dates and completed rental charges measure different events. What blocks overpayment? Guarded package call plus payment trigger; ₹701 above the remaining ₹700 was rejected in the committed test.

