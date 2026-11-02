# Member 3 — rentals, returns, statuses and charges

**Presenter:** [Name / registration number]. The retained RENTAL 7016 is for read-only explanation. Repeating a committed start/return requires a new isolated customer and vehicle, and genuine history remains afterward. Use the rollback-only demonstration environment when repeatability without new history is required.

1. Show charge estimate, then explain `GET /api/reports/charge-estimate` → `SVR_WORKFLOW.CALCULATE_CHARGE` → VEHICLE_TYPE current rate. A future start captures Daily_Rate_Snapshot in RENTAL; the committed example captured ₹1,200/day.
2. Inspect RENTAL 7016: Active start was 25 Oct 2026 04:32, expected 27 Oct 04:32, ₹2,400 estimate and vehicle Rented. `POST /api/rentals/start` → `START_RENTAL` locks VEHICLE, checks availability/overlap, inserts RENTAL and updates VEHICLE. Reopened detail and Oracle checks confirmed persistence.
3. Inspect return at 25 Oct 04:36: Completed, actual return set, final ₹1,200, VEHICLE 3981 Available. `POST /api/rentals/{id}/return` → `RECORD_RETURN`, RENTAL and VEHICLE. The charge policy rounds to at least one day.
4. Show overdue report `GET /api/reports/overdue` → explicit `SVR_WORKFLOW.OVERDUE_REPORT` cursor and matching SELECT over RENTAL/PAYMENT. Explain derived late days.
5. Show `database/step3/member_3_demo.sql`: future unpaid Cancelled RENTAL 5998 disposable INSERT, UPDATE, DELETE, rolled back; M3.1 simple list, M3.2 joins, M3.3 nested EXISTS, M3.4 derived-day functions, M3.5 status aggregation. It does not demonstrate a supported genuine cancellation workflow. Actual output: `evidence/step3-members.log`.

**Viva prompts:** How is double rental prevented? Vehicle row lock, status/interval checks and one-Active-per-vehicle unique index. Who commits? JDBC caller, after package success. Why is the early return ₹1,200? Minimum one billable day. Can normal history be deleted? No; rental/payment history triggers guard it.

