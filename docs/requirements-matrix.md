# Requirements matrix — Step 2A

**G1** = `BACSE202_Database_Systems_Project_Guidelines.pdf`; **G2** = `DatabaseSystems_CourseProject_Guidelines-1-1-2.pdf`; **R1** = the submitted `Smart_Vehicle_Rental_Management_Review1.pdf`. Page numbers are PDF pages. “Project choice” means the user's Step 2A instruction or a documented implementation decision, not a faculty requirement.

| Requirement or fact | Source | Step 2A response |
| --- | --- | --- |
| Handwritten individual analysis, ER diagram and mapping; group Oracle implementation | G1 pp. 1–2 | Preserve R1 as historical submission; provide amended eight-table ER source for the implementation. Report work remains later. |
| Oracle schema, integrity constraints, population, DDL/DML/TCL, frontend connectivity and Insert/Update/Delete/Search/Display | G1 p. 2 | SQL*Plus Step 2B and Step 3 evidence, Step 4 JDBC, and Step 5 browser CRUD/search/display are implemented. See `frontend-test-results.md`; full final acceptance is Step 6. |
| Cycle Sheets I–VI queries and outputs | G1 p. 2 | See `lab-cycle-map.md`; Step 2B produced schema, seed, 15 SELECT and rollback output, but full I–VI coverage is not claimed and VI material is still missing. |
| Per-person one INSERT, UPDATE, DELETE and five SELECT queries of varied forms | G1 p. 2 | All three separate disposable DML and five-SELECT scripts ran in Step 3; see `database/step3/member_*_demo.sql` and `evidence/step3-members.log`. |
| 6–8 related tables, suitable PK/FK and NOT NULL/UNIQUE/CHECK/DEFAULT | G2 p. 1 | User-authorized eight-table amendment removes RENTAL_STATUS and stores constrained RENTAL.Status_Name. See `design-changes.md`. |
| At least ten meaningful records per table | G2 p. 1 | Oracle Step 2B final verification shows 10 customers, 11 phones, 10 types, 10 branches, 10 vehicles, 10 employees, 10 rentals and 10 payments. See `evidence/step2b-negative-rollback.log`. |
| ER diagram and relational schema | G2 p. 1; R1 pp. 5–7 | `er-implementation.mmd` and `schema-plan.md`; R1 diagram requires amendment. |
| At least 15 retrieval/join/aggregation/subquery queries | G2 p. 1 | All 15 labeled SELECT demonstrations ran in Step 2B; results are in `evidence/step2b-project.log`. |
| At least two procedures, two functions, one cursor and two triggers | G2 p. 1 | `SVR_WORKFLOW` contains three procedures, two functions and an explicit overdue cursor; three valid triggers guard rental, payment and vehicle status paths. See `docs/plsql-workflows.md` and `evidence/step3-final-audit.log`. |
| Interactive transactions and report sections | G2 p. 2 | Step 5 UI shows package-backed rental, return, payment, overdue and branch revenue. Browser evidence is in `frontend-test-results.md`; final written report remains Step 6. |
| Composite CUSTOMER_PHONE key and derived rental duration/late days | R1 pp. 4, 6–7 | Retained. |
| Historical nine-relation schema with RENTAL_STATUS FK | R1 pp. 3, 6–7 | Changed only as explicitly authorized: eight tables, constrained Status_Name. R1 remains historical. |
| Charge based on daily rate and duration; late returns may add charge | R1 pp. 2, 4 | Project choice: minimum one day, round up partial 24 hours, normal daily rate for overdue time, no separate penalty or tax. Snapshot rate is an added technical column. |
| Vehicle availability, no double active rental, payment-to-rental integrity, history | R1 p. 4 | Step 3 procedures and triggers enforce guarded transitions, historical interval checks, immutable payment history and completed-payment cap; actual rollback and two-session lock evidence is in `docs/transaction-and-concurrency.md`. Owner-level DDL and cancellation/refunds remain outside the implemented workflow. |
| No login policy specified; EMPLOYEE.Role is a data attribute | R1 pp. 3, 6; user Step 2A | No login/authentication tables now; no access-control claim. |

G1 pp. 1–2 and G2 pp. 1–2 have different course labels and some different requirements. The user explicitly selected the eight-table interpretation for this implementation; the submitted Review 1 document itself has not been rewritten. G1's dates omit a year; final deadlines still require confirmation.
