# Remaining decisions after Step 2B

## Resolved for the proposed implementation

- **Table count:** user authorized exactly eight tables by replacing R1's RENTAL_STATUS relation and RENTAL.Status_ID FK with a constrained RENTAL.Status_Name. `CUSTOMER_PHONE` and its composite PK stay. Faculty acceptance of the amended diagram remains to be confirmed for submission.
- **Team size and topics:** three members; ownership is in `module-ownership.md`. Individual names remain to be entered.
- **Billing policy:** one-day minimum, 24-hour ceiling, current estimate from expected return, completed charge from actual return, overdue time at normal daily rate, no separate penalty or tax. Security deposit is reference data only. `Daily_Rate_Snapshot` preserves historical rate.
- **Authentication:** no login/authentication tables in this phase. EMPLOYEE.Role is a duty description only.
- **Seed count:** at least ten plausible fictional rows prepared per each of the eight tables, including ten distinct vehicle types and branches. This meets the literal G2 minimum; instructor acceptance of ten lookup rows can still be checked.
- **Actual Oracle setup:** read-only preflight passed under SYSTEM/XEPDB1; guarded setup created SVR_APP. Final Oracle checks show the account OPEN, XEPDB1 READ WRITE, eight tables, and the planned 20 MB USERS quota with CREATE SESSION and CREATE TABLE only. Password-free execution evidence is under `evidence/`.

## Still open or gated

| Item | Why it matters | Next input/action |
| --- | --- | --- |
| Cycle VI | G1 p. 2 requires I–VI output, but no readable explicit Cycle VI sheet was found. `VL2026270102656_AST05.pdf` is encrypted; Assessment 7 is MongoDB. | Supply a readable Cycle VI sheet or instructor-approved equivalent before claiming complete cycle coverage. |
| Faculty review of ER amendment | R1 pp. 6–7 contain nine relations; implementation has eight. | Annotate/redraw the handwritten ER and relational schema from `er-implementation.mmd` and explain the exact change. |
| Course identity/deadlines | G1 says BACSE202 and G2 says BCSE302L; G1 dates omit year. | Confirm which brief and deadlines govern submission. |
| Step 3 transaction policy details | DDL cannot enforce all cross-table or temporal rules. | Finalize atomic start/return/cancel behavior, late-day display at time of report, payment reversal/refund handling and whether future reservations may overlap. |
| Revenue recognition | Current queries report captured rent payments, including active-rental prepayments, as **cash collected**; security deposits are absent. Accounting recognition timing was not specified. | Decide whether a separate completed-rental revenue report is required; do not call cash receipts accrued revenue. |
| Team names | Ownership is numbered, not personalized. | Fill in three names/registration numbers in later report; no schema dependency. |
| Maven/JDBC | Maven not on PATH in Step 1; Java scaffold remains static. | Install/configure Maven only in a later authorized step, then add Oracle JDBC and backend APIs. |

No setup, schema, seed, query, negative-check or verification SQL was executed during Step 2A. Oracle DDL commits implicitly, so a partially failed schema cannot be made safe with ROLLBACK; inspect the actual state and plan a manual repair rather than rerunning or dropping objects automatically.
