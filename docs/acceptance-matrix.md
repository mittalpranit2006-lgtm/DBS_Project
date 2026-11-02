# Requirement-by-requirement acceptance matrix — Step 6A

**Source key:** G1 = `BACSE202_Database_Systems_Project_Guidelines.pdf`; G2 = `DatabaseSystems_CourseProject_Guidelines-1-1-2.pdf`; R1 = submitted `Smart_Vehicle_Rental_Management_Review1.pdf`. Page numbers are PDF page numbers recorded in the earlier source review (`requirements-matrix.md`). Those PDFs are not copied into this project folder. “Passed” means the cited implementation or actual test evidence supports the row; it does not imply acceptance of missing academic deliverables. The user-authorized eight-table change is recorded in `design-changes.md`.

| Requirement | Source/page | Actual evidence | Status |
| --- | --- | --- | --- |
| Oracle implementation with connected frontend; DDL, DML, TCL; insert, update, delete, search and display | G1 p. 2 | `step2b-project.log`, `step2b-negative-rollback.log`, `step3-members.log`, `step4-http-integration.log`, `step6a-build.log`, Step 6A browser screenshots and proxy log | Passed |
| Individual handwritten analysis, ER diagram/mapping and final written report | G1 pp. 1–2 | Historical R1 and current `er-implementation.mmd`/`schema-plan.md` exist; handwritten individual work and final report were not produced in Step 6A | Blocked |
| Cycle Sheets I–VI queries and outputs | G1 p. 2 | `lab-cycle-map.md` found no readable explicit Cycle VI sheet; implemented SQL evidence covers project equivalents only | Blocked |
| Per-member INSERT, UPDATE, DELETE and five varied SELECTs | G1 p. 2 | Three `database/step3/member_*_demo.sql` scripts, 15 labels, successful rolled-back `step3-members.log` | Passed |
| Six to eight related tables | G2 p. 1 | Exactly eight tables listed and asserted by `database/verification/01_verify.sql`; eight-table design in `schema-plan.md` | Passed |
| PK, FK, NOT NULL, UNIQUE, CHECK and DEFAULT constraints | G2 p. 1 | `step2b-project.log` reports 8 PK, 8 FK, 8 UNIQUE, 54 CHECK, all enabled/validated; `01_verify.sql` rechecks and tests orphans | Passed |
| At least ten meaningful rows per table | G2 p. 1 | Original 81 fictional seed rows: 10 CUSTOMER, 11 CUSTOMER_PHONE, 10 each other table; Step 6A final SQL audit compares every seed row | Passed |
| Implemented ER diagram and relational schema | G2 p. 1 | `er-implementation.mmd`, `schema-plan.md` | Passed |
| Amend the historical Review 1 diagram to the authorized eight-table implementation | R1 pp. 5–7; user Step 2A decision | Submitted R1 still depicts nine relations | Blocked |
| At least fifteen retrieval/join/aggregation/subquery queries | G2 p. 1 | All 15 M1.1–M3.5 results in `step2b-project.log`; varied per-member repeats in `step3-members.log` | Passed |
| At least two procedures, two functions, explicit cursor and two triggers | G2 p. 1 | `SVR_WORKFLOW`: three procedures, two functions and explicit overdue cursor; three installed triggers. `step3-final-audit.log` reports VALID and no compiler errors | Passed |
| Interactive transactions and reports | G2 p. 2 | Browser rental/return/payment rollback rehearsal, cash/recognized revenue and overdue reports; `step6a-member*.jpg`. Follow-up normal-browser committed rental 7016, return and payment 8018 agree with fresh Oracle and HTTP checks in `step6a-committed-final-audit.log` and `step6a-committed-http-final.json`. | Passed |
| Composite customer-phone key; derived duration and late days | R1 pp. 4, 6–7 | `schema-plan.md`, `01_verify.sql`, `member_3_demo.sql` M3.4, browser phone CRUD | Passed |
| Historical nine-relation R1 model | R1 pp. 3, 6–7 | User authorized replacing `RENTAL_STATUS` with constrained `RENTAL.Status_Name`; diagram amendment is tracked separately above | Not applicable |
| Daily-rate/duration charges and overdue time | R1 pp. 2, 4 | `design-changes.md` defines round-up daily policy and rate snapshot; Step 6A browser ₹1,500×2=₹3,000 estimate and ₹2,400 final return test | Passed |
| Vehicle availability, no double active rental, payment integrity and history | R1 p. 4 | `step3-functional.log`, two-session `step3-concurrency-{a,b}.log`, Step 6A rollback tests, and committed follow-up 7016/8018. `step6a-committed-final-audit.log` shows vehicle availability, one test payment, zero overpaid rentals and intact original seed; cancellation/refunds remain outside supported paths. | Passed |
| Cancellation and refund workflows | Neither G1 nor G2 explicitly requires these; R1 includes a Cancelled status and payment-status vocabulary, but no implemented end-to-end cancellation/refund contract was accepted | `api-reference.md`, `plsql-workflows.md`, `known-limitations.md` | Not applicable |
| Application login/authorization | G1/G2/R1 do not specify a login policy; `EMPLOYEE.Role` is a data attribute | `backend-setup.md`, `frontend-guide.md`, `known-limitations.md` | Not applicable |

The G1 handwritten/report/Cycle VI obligations and the R1 diagram amendment prevent a claim of complete academic submission compliance. Step 6A verifies the running system and does not generate Step 6B report or viva material.
