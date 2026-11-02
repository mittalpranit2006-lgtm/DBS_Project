# Step 4 HTTP API

Base: `http://127.0.0.1:8080`. JSON request and response bodies use camelCase keys. All lists are bounded by `limit=1..100` (default 50). Successful single-record responses contain the record; lists contain `items`. Errors have `{ "error": { "code": "...", "message": "..." } }`. Typical statuses: 400 validation, 404 missing, 405 method, 409 duplicate/business/referenced-record conflict, 413 oversized JSON, 415 content type, 503 database unavailable. Internal SQL, passwords and stack traces are never returned.

| Member | Endpoint and method | Database use |
| --- | --- | --- |
| 1 | `GET/POST /api/customers`, `GET/PUT/DELETE /api/customers/{id}` | PreparedStatement CRUD on CUSTOMER. `GET /api/customers?q=...&limit=...` searches first/last name, email and licence. |
| 1 | `GET/POST /api/customers/{id}/phones`, `PUT/DELETE /api/customers/{id}/phones/{phone}` | PreparedStatement on composite CUSTOMER_PHONE key; PUT body has `newPhoneNo`. |
| 2 | `GET/POST /api/vehicle-types`, `GET/PUT/DELETE /api/vehicle-types/{id}` | VEHICLE_TYPE. |
| 2 | `GET/POST /api/branches`, `GET/PUT/DELETE /api/branches/{id}` | BRANCH. |
| 2 | `GET/POST /api/vehicles`, `GET/PUT/DELETE /api/vehicles/{id}` | VEHICLE; installed status trigger guards Rented transitions and moves. |
| 2 | `GET/POST /api/employees`, `GET/PUT/DELETE /api/employees/{id}` | EMPLOYEE. `role` is an attribute, not an authorization policy. |
| 3 | `GET /api/rentals`, `GET /api/rentals/{id}` | RENTAL reads; list filters `customerId`, `vehicleId`, `status`, `limit`. |
| 3 | `POST /api/rentals/start` | CallableStatement `SVR_WORKFLOW.START_RENTAL`; body: `customerId`, `vehicleId`, `employeeId`, `startDate`, `expectedReturnDate`. |
| 3 | `POST /api/rentals/{id}/return` | CallableStatement `SVR_WORKFLOW.RECORD_RETURN`; body: `actualReturnDate`. |
| 1 | `GET /api/payments`, `GET /api/payments/{id}` | PAYMENT reads; list filters `rentalId`, `limit`. |
| 1 | `POST /api/payments` | CallableStatement `SVR_WORKFLOW.RECORD_PAYMENT`; body: `rentalId`, positive `amount`, `paymentMethod` (`Card`, `UPI`, `Cash`, `Bank Transfer`), `paymentDate`. |
| 3 | `GET /api/reports/charge-estimate?start=...&end=...&rate=...` | CallableStatement `SVR_WORKFLOW.CALCULATE_CHARGE`. |
| 1 | `GET /api/reports/outstanding?rentalId=...` | CallableStatement `SVR_WORKFLOW.OUTSTANDING_BALANCE`; only Completed payments count. |
| 3 | `GET /api/reports/overdue?asOf=...&limit=...` | Calls installed `SVR_WORKFLOW.OVERDUE_REPORT` explicit cursor for total count and estimated outstanding, then runs a matching parameterized SELECT for structured `items` in the same read-only snapshot. The package exposes OUT scalars and DBMS_OUTPUT, not a ref cursor. |
| 1 | `GET /api/reports/revenue?basis=cash\|recognized&limit=...` | PreparedStatement branch aggregation. `cash` sums Completed PAYMENT; `recognized` sums Completed RENTAL bills. |
| shared | `GET /api/health`, `GET /api/health/database` | Process health and separate read-only Oracle health. |
| shared | `GET /api/dashboard` | Read-only Oracle counts for customers, vehicles, rentals, payments, available vehicles, active/overdue rentals, and completed cash collected. |

Master create bodies require an explicit positive ID. Oracle primary keys provide collision safety and return 409 on duplicates; no `MAX(id)+1` query is used. PUT is a full replacement of non-key fields. Required fields match `database/schema/02_tables.sql`: CUSTOMER has `firstName`, `lastName`, `email`, `licenseNo`, `address`, `registrationDate`; VEHICLE_TYPE has `typeName`, `dailyRate`, `securityDeposit`; BRANCH has `branchName`, `location`, `phone`; VEHICLE has `registrationNo`, `brand`, `model`, `purchaseYear`, `availabilityStatus`, `typeId`, `branchId`; EMPLOYEE has `name`, `email`, `phone`, `role`, `branchId`. Phones use 10–15 digits. Dates in requests use `YYYY-MM-DD` and timestamps use ISO local date-time to seconds, e.g. `2026-10-24T18:00:00`. Money uses decimal values with at most two fractional digits.

Search `q` is case-insensitive over each master's documented text columns. The SQL identifier set is fixed in `MasterRepository`; only values are bound from requests. IDs in path/query and sort order are validated or fixed. There is no arbitrary SQL endpoint.

Historical rentals and payments have no generic UPDATE/DELETE endpoint. Genuine cancellation and refund operations are unavailable. Owner-level DDL, authentication and application authorization are outside this step. The fixed rollback test header described in `backend-setup.md` is enabled only with `SVR_TEST_MODE=true` on the localhost server.

The Step 5 frontend uses only these same-origin routes. It sends local timestamps to seconds without UTC conversion. A separate rollback-only browser demonstration can use `?step5Rollback=1` with a server explicitly started in test mode; workflow responses then indicate rollback in the UI and leave seed history unchanged. Normal port 8080 remains in non-test mode.
