# Coordinated group demonstration

**Before the session:** Verify Java 21, Oracle XEPDB1 and a single localhost server on port 8080. Run the Maven build and `backend/run-local.ps1` only if the server is not already healthy. Enter SVR_APP credentials privately at the prompt. Check `/api/health` and `/api/health/database`; confirm normal `testMode:false`. Do not place credentials in slides, files or terminal arguments. Keep `evidence/step6a-committed-final-audit.log` and `evidence/step3-members.log` available.

| Order | Owner | Live action | API → SQL/PLSQL → table → visible proof |
| --- | --- | --- | --- |
| 1 | All | Open dashboard and database indicator | `/api/health/database` → JDBC probe → SVR_APP/XEPDB1 indicator |
| 2 | Member 1 | Customer/phone search, then isolated CRUD | `/api/customers`, `/phones` → MasterRepository prepared DML → CUSTOMER/CUSTOMER_PHONE → refreshed detail |
| 3 | Member 2 | Type/branch/vehicle/employee search and isolated CRUD | corresponding master endpoints → prepared DML → four fleet/organization tables → refreshed lists |
| 4 | Member 2 | Referenced branch delete rejection | `DELETE /api/branches/{id}` → FK constraint → BRANCH child references → visible 409 |
| 5 | Member 3 | Estimate and inspect committed 7016 | `/api/reports/charge-estimate`, `/api/rentals/7016` → CALCULATE_CHARGE/SELECT → RENTAL/VEHICLE_TYPE → ₹1,200 snapshot, Completed |
| 6 | Member 3 | Explain start/return with captured evidence or new isolated rollback case | start/return endpoints → START_RENTAL/RECORD_RETURN → RENTAL/VEHICLE → status/availability |
| 7 | Member 1 | Inspect payment 8018 and outstanding | `/api/payments`, outstanding → RECORD_PAYMENT/OUTSTANDING_BALANCE → PAYMENT/RENTAL → ₹500, ₹700 |
| 8 | Members 1/3 | Revenue and overdue reports | report endpoints → aggregate SQL / OVERDUE_REPORT cursor → report rows |
| 9 | Each | Present five SELECTs and DML script output | member_1/2/3_demo.sql → Oracle, rollback → `step3-members.log` |

Use new fictional IDs for any live writes. A committed payment/rental is protected history and should not be repeated against 7016. The normal committed start/return/payment evidence is already captured in `evidence/step6a-commit-*.jpg`, HTTP JSON and fresh Oracle audit. For a clean repeatable workflow, use the separately documented rollback-only server with its visible rollback label; never describe that rehearsal as committed. Refresh after uncertain network outcomes before attempting another write.

**Handoff timing:** Member 1 introduces data and payments; Member 2 shows fleet dependencies; Member 3 explains rental workflow and charges; Member 1 closes with revenue. Allocate time for questions on the eight-table amendment, snapshot billing, concurrency, trigger limits and academic open items.

