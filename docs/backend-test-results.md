# Step 4 observed results — 24 October 2026

## Build and startup

The local Maven Wrapper ran Maven 3.9.11 with Java 21.0.11. The final `package` build succeeded (`evidence/step4-build.log`). The localhost server returned HTTP 200 for application health and separate Oracle health. Database health reported `SVR_APP` in `XEPDB1`; no password appears in the response or logs.

A separate temporary process without database configuration returned application health 200 and database health 503 with a safe JSON error (`evidence/step4-health-separation.log`). It was stopped after the check.

## HTTP/JDBC integration

`backend/integration-test.py` ran against the real Oracle-backed server. Its full password-free request/response log is `evidence/step4-http-integration.log`, ending `PASS all HTTP/JDBC checks and master cleanup`.

After moving per-request connection and commit/rollback handling into `TransactionService`, the full HTTP suite was rerun and passed. `evidence/step4-post-refactor-audit.log` independently confirms the unchanged eight table counts, zero leftover test masters/rentals/payments, zero invalid objects and zero overpaid rentals.

- Master operations: CUSTOMER, VEHICLE_TYPE, BRANCH, EMPLOYEE and VEHICLE create, detail, search, update and dependency-order delete all returned the expected statuses. CUSTOMER_PHONE add, display, composite-key update and remove passed.
- The duplicate CUSTOMER returned 409; missing fields and malformed JSON returned 400; unsupported PATCH returned 405; referenced BRANCH deletion returned 409. The script later deleted all five records it had created.
- `START_RENTAL` returned 201 with a rate snapshot of 1900 for the isolated vehicle, then rolled back via the test-only header. The vehicle remained Available. Unavailable vehicle returned 409 and invalid dates 400.
- `RECORD_RETURN` returned 200 with the final charge through CallableStatement and rolled back; seed rental 5001 remained Active. `RECORD_PAYMENT` returned 201 and rolled back; a second amount that would overpay returned 409. Outstanding balance remained 1200.
- The charge function returned 1900 for one day; the installed overdue cursor reported one active overdue rental and estimated outstanding 1500, with one matching structured item. Cash and recognized revenue reports both returned branch aggregates. Static `/` also returned 200.

The first HTTP attempt reached master CRUD but returned 500 on rental-start JSON serialization of an Oracle timestamp. `JdbcRows` was corrected to convert Oracle DATE/TIMESTAMP columns explicitly; the complete rerun passed. A first SQL*Plus verification attempt was disconnected and saved as `evidence/step4-sqlplus-failed-connect.log`; the fresh authenticated retry passed. Neither failed attempt changed retained seed data.

## Post-test Oracle consistency

`evidence/step4-sqlplus-verify.log` is the actual rerun of the existing `database/verification/01_verify.sql` as SVR_APP in XEPDB1. It passed eight-table membership, at least ten rows per table, enabled/validated constraints, orphan checks, registration/rate/availability/payment rules and seed examples. Final counts are CUSTOMER 10, CUSTOMER_PHONE 11 and 10 each in the other six tables. Package, package body, two sequences and three triggers remain VALID. Every Step 4 master test ID, rental ID >=7000 and payment ID >=8000 returned zero rows; overpaid rentals returned zero.

The application ran with temporary `SVR_TEST_MODE=true` in the ignored local config. That line was removed and the temporary test server was stopped after verification. There is no login/authorization, cancellation, refund or full frontend in Step 4. Step 5 can use these JSON endpoints with test mode off.
