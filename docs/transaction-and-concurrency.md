# Step 3 transaction and concurrency results

Actual Oracle 21c XE target: `SVR_APP` in `XEPDB1` at `DESKTOP-FFIRV71:1521/xepdb1`. Passwords were entered only at visible SQL*Plus prompts and never stored in these logs. The administrator grant was limited to CREATE PROCEDURE, CREATE TRIGGER and CREATE SEQUENCE; existing CREATE SESSION/TABLE remained.

## Transaction rules

`START_RENTAL`, `RECORD_RETURN` and `RECORD_PAYMENT` set an entry savepoint. On error they roll back to that savepoint and re-raise; they do not commit. Caller COMMIT/ROLLBACK controls the transaction. Vehicle operations lock VEHICLE before RENTAL; payment locks RENTAL before inserting PAYMENT. The Active-vehicle unique index remains a second backstop. Sequences can advance even on rollback.

The functional test in `evidence/step3-functional.log` passed start, return, one-day and 24-hour boundary charging, rate snapshot retention after a type-rate edit, partial payment and outstanding balance, and the overdue explicit cursor. It distinguished expected failures: invalid dates, wrong-branch employee, historical interval overlap, unavailable/duplicate/maintenance vehicle, overpayment (including direct INSERT), unsupported Pending payment, repeat return, direct Active rental INSERT, direct vehicle Rented UPDATE, direct PAYMENT UPDATE/DELETE, genuine RENTAL DELETE, and an early return whose final bill fell below collected payments. A failed start preserved a caller UPDATE made before the call. The script rolled back all disposable work and verified seed restoration.

## Two real sessions

Session A SID 873 and B SID 13 ran simultaneously as SVR_APP. In `evidence/step3-concurrency-a.log` and `evidence/step3-concurrency-b.log`:

| Contention | B began waiting | A release | B proceeded | Result |
| --- | --- | --- | --- | --- |
| VEHICLE 3004 | 17:43:00.171 | ROLLBACK 17:43:04.377 | 17:43:04.377 | B then started disposable rental 7003 and rolled it back; A's 7002 had been uncommitted and was rolled back. |
| RENTAL 5001 payment parent | 17:43:05.322 | COMMIT 17:43:09.359 | 17:43:09.358–.361 | B inserted disposable payment 8003 after the lock release and rolled it back. A committed only a `SELECT FOR UPDATE` lock, no data change. |

This shows actual blocking and release order for the two paths. The test does not claim that the table owner is unable to disable triggers or change code. No autonomous transaction is used.

## Final state and limits

`evidence/step3-final-audit.log` is a fresh read-only SYSDBA check in XEPDB1. Counts remain CUSTOMER 10, CUSTOMER_PHONE 11, VEHICLE_TYPE 10, BRANCH 10, VEHICLE 10, EMPLOYEE 10, RENTAL 10, PAYMENT 10. There are zero invalid objects, zero USER_ERRORS, zero availability mismatches, zero overpaid rentals, and zero disposable rentals/payments. All 8 PK, 8 FK, 8 UNIQUE and 54 CHECK constraints remain enabled and validated.

New payment rows must be Completed; Pending/Refunded and refund/reversal workflows are not implemented. Completed cash receipts are not the same as recognized rental revenue. Cancellation of genuine rentals is not exposed. The narrow future Cancelled ID 5900–5999 path exists for rolled-back academic DML. Direct owner DDL or trigger disabling is outside these safeguards. No JDBC/backend code was added.
