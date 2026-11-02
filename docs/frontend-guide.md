# Step 5 frontend guide

The Java 21 server serves the frontend and JSON API from `http://127.0.0.1:8080/`. From `backend/`, set `JAVA_HOME` to `C:\Program Files\Java\jdk-21.0.11`, run `.\mvnw.cmd -B package dependency:copy-dependencies '-DoutputDirectory=target/dependency'`, then `.\run-local.ps1`. The launcher asks for the SVR_APP password privately. The normal local config points to XEPDB1 and has test mode off. Check the database indicator, `/api/health`, and `/api/health/database` if a screen cannot load.

## Screens

| Screen | Actions |
| --- | --- |
| Dashboard | Live Oracle counts, available vehicles, active/overdue rentals and completed cash collected. |
| Customers & phones | Search and bounded list, detail, customer create/edit/delete; add, change and remove phone values through the composite key route. |
| Fleet & organization | Subsections for vehicles, vehicle types, branches and employees with search, detail and CRUD. Vehicle type and branch selectors load from the API. Rented status/move restrictions and referenced-record deletion are enforced by Oracle and surfaced as errors. |
| Rentals & returns | Filter by customer, vehicle and status; show detail/balance, available-vehicle selection, package-backed charge estimate, rental start and return. Historical rows have no edit/delete controls. |
| Payments & reports | Filter/detail payment history, package-backed payment entry, outstanding balance, branch cash receipts, recognized completed-rental charges and overdue rows. |

Lists request at most 100 records. The API has a `limit` parameter but no offset cursor; the UI describes this rather than implying full pagination. IDs for master creates are explicit and must be unused. Forms retain values when the backend rejects a write. Buttons disable during submission, and a success notice appears only after an HTTP success. Destructive master/phone actions ask for confirmation. Input text is rendered through DOM `textContent`, not HTML insertion.

Dates are entered as local date/time and sent as ISO local timestamps with seconds. The UI does not convert through UTC. INR formatting is display only; charges, final bills, outstanding balance, overpayment checks and revenue come from Oracle/API calculations. Cash revenue means completed payment receipts; recognized revenue means completed rental bills. An Active rental's `totalAmount` is an estimate.

There is no login or application authorization. `EMPLOYEE.Role` is descriptive. Cancellation, refund and historical rental/payment edits are unavailable. The Review 1 nine-relation diagram still needs the authorized eight-table amendment, and full Cycle VI coverage still needs the missing material. These do not block Step 5 browsing.

## Rollback-only workflow demonstration

For repeatable browser testing without retaining transaction history, start a **separate** local server from `backend/` with `.\run-local.ps1 -Port 8081 -RollbackTestMode` and enter SVR_APP password at its hidden prompt. Open `http://127.0.0.1:8081/?step5Rollback=1`. The frontend checks `/api/health` for test mode before sending `X-SVR-Rollback: true` on rental-start, return and payment POST requests. It labels confirmed rollback responses explicitly and never presents them as committed writes. Ordinary port 8080 remains non-test. Stop the 8081 process after testing. The test script leaves sequence gaps; this is expected.
