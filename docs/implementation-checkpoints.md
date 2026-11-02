# Implementation checkpoints

## Step 1 — completed earlier

- [x] Inspect project folder, three source PDFs, Java 21, SQL*Plus client and browser access.
- [x] Create the Java/static welcome-page scaffold. Direct `javac` compile and browser page load were observed; Maven was unavailable.

## Step 2A — prepared, never executed against Oracle

- [x] Re-read G1, G2 and R1; record the user-authorized eight-table amendment and historical Review 1 difference.
- [x] Map visible laboratory exercise sets and record missing explicit Cycle VI material.
- [x] Define Oracle datatypes, keys, foreign keys, nullability, checks, defaults, uniqueness, deletion rules and the rate snapshot.
- [x] Prepare guarded admin preflight/setup, guarded eight-table DDL, ten-plus-row-per-table seed, fifteen SELECTs and verification/negative-check scripts.
- [x] Assign three-member modules and prepare Step 2B runbook.
- [ ] Execute admin preflight, setup, schema, seed or verification: explicitly deferred to Step 2B.
- [ ] Run an Oracle parse/compile or observe query output: no accessible project-user connection was used in Step 2A.

## Step 2B — completed and verified in Oracle

- [x] Re-read the runbook, every prepared SQL*Plus script, schema/design notes, and applicable project instructions. No `AGENTS.md` was present at the project or relevant parent/child levels.
- [x] Verify the actual listener endpoint `DESKTOP-FFIRV71:1521` and ready `xepdb1` service; save password-free listener output under `evidence/`.
- [x] Test SQL*Plus paths without a database login. Correct the runbook to start in the project directory and use project-relative paths; remove nested includes that failed the probe.
- [x] Correct seed order so DML remains uncommitted until verification and all fifteen SELECTs pass. Correct customer 1008's registration date to precede the sample rental and add a verification assertion. Strengthen constraint reporting and rollback demonstration checks.
- [x] Prepare a guarded one-command Step 2B runner for the observed SYSTEM session; a harmless SQL*Plus probe confirmed project-relative nested `@database/...` calls work from the project directory.
- [x] Investigate a failed disconnected runner attempt. A screenshot showed `SP2-0640` and misleading unconditional output; a read-only SYSDBA query in XEPDB1 confirmed SVR_APP and its objects absent. Repair the runner to connect SYSTEM first and replace success prompts with database post-check output. Evidence saved under `evidence/`.
- [x] Observe the user's authenticated SYSTEM connection to XEPDB1 and passing `00_admin_preflight.sql` output. The screenshot in `evidence/step2b-admin-preflight.png` shows USERS/TEMP online, at least 20 MB USERS headroom, and SVR_APP absent.
- [x] Run corrected `step2b_execute.sql` with private local password entry: guarded SYSTEM setup created SVR_APP, and read-only postcheck found OPEN account, 20 MB USERS quota, CREATE SESSION and CREATE TABLE only, no roles/object grants.
- [x] Connect freshly as SVR_APP, create eight tables and one active-rental unique index, insert 81 fictional rows, run `01_verify.sql` and all fifteen SELECTs, then commit. Password-free output is in `evidence/step2b-project.log`.
- [x] Reconnect as SVR_APP for expected FK/PK/CHECK failures, disposable DML and rollback; repeat full verification and final row counts. Password-free output is in `evidence/step2b-negative-rollback.log`.
- [x] Independently audit completed/active/cancelled payment rules, rate snapshots and vehicle availability; all ten rentals pass and both mismatch counts are zero. See `evidence/step2b-seed-consistency-audit.log`.

Final counts: CUSTOMER 10; CUSTOMER_PHONE 11; VEHICLE_TYPE 10; BRANCH 10; VEHICLE 10; EMPLOYEE 10; RENTAL 10; PAYMENT 10. All 8 PK, 8 FK, 8 UNIQUE and 54 CHECK constraints are enabled and validated; all orphan checks passed. No unexpected SQL*Plus/Oracle errors appear in the two project execution logs.

At Step 2B closure, no Step 3 transactional safeguards had yet been claimed. Missing Cycle VI material and the Review 1 diagram amendment remain open in `lab-cycle-map.md` and `design-changes.md`.

## Step 3 and later

- [x] Preflight live XEPDB1/SVR_APP without changing Step 2B data; grant only CREATE PROCEDURE, CREATE TRIGGER and CREATE SEQUENCE. See `evidence/step3-live-preflight.log` and `evidence/step3-final-audit.log`.
- [x] Document Step 3 interfaces before installation; install two sequences, `SVR_WORKFLOW` (three procedures, two functions, explicit cursor), and three VALID triggers. `USER_ERRORS` is empty.
- [x] Run rollback functional tests for charges, rental/return, rate snapshot, maintenance, payment cap, direct DML, preservation of caller work, and overdue cursor. See `evidence/step3-functional.log`.
- [x] Run two actual SVR_APP sessions (SIDs 873 and 13) showing vehicle lock release after rollback and payment-parent lock release after commit. See `evidence/step3-concurrency-a.log` and `evidence/step3-concurrency-b.log`.
- [x] Run separate member INSERT/UPDATE/DELETE and five-SELECT demonstrations with rollback; see `evidence/step3-members.log`.
- [x] Fresh final read-only audit confirms seed counts unchanged, valid objects/constraints, zero availability mismatches, zero overpaid rentals and zero disposable records. See `evidence/step3-final-audit.log`.
- [ ] Finish full I–VI cycle-equivalent catalogue after Cycle VI is supplied.
- [x] Step 4: retain Java HttpServer, add same-origin JSON APIs using direct JDBC PreparedStatement/CallableStatement and per-request transactions; no ORM or full frontend.
- [x] Set up project-local Maven Wrapper 3.3.4/Maven 3.9.11 and Oracle ojdbc11 21.23.0.0 for Java 21; final build passes (`evidence/step4-build.log`).
- [x] Run real HTTP/Oracle integration for application/database health, master and phone CRUD/search, rental start/return, payment, charge/outstanding/overdue/revenue reports, negative responses and rollback (`evidence/step4-http-integration.log`).
- [x] Move request transaction ownership into `service/TransactionService`, rebuild and rerun the complete HTTP suite; final read-only audit remains clean (`evidence/step4-post-refactor-audit.log`).
- [x] Re-run Step 2B SQL*Plus consistency assertions after cleanup as SVR_APP; all eight original counts and constraints pass, with no test rows (`evidence/step4-sqlplus-verify.log`). An initial disconnected attempt is retained separately and is not counted as passing.
- [x] Step 5: build the interactive HTML/CSS/JavaScript frontend on the documented APIs with five screens, safe DOM rendering, form validation, bounded search/list views, API-backed selectors and package-backed workflow forms. Final Maven build: `evidence/step5-build.log`.
- [x] Browser-test dashboard, customer/phone CRUD, all four fleet master forms, referenced-record rejection, rental estimate/validation, rollback-only start/return/payment, overpayment rejection, reports and 390px layout. Screenshots and exact results: `docs/frontend-test-results.md` and `evidence/step5-*.jpg`.
- [x] Clean all disposable Step 5 master records and verify live SVR_APP/XEPDB1 seed counts, no API-visible orphans, availability mismatch or overpaid rental: `evidence/step5-final-consistency.json`.
- [ ] Complete the offline browser visual state and automated double-submit stress check in Step 6. The test browser tab became unresponsive after its 8081 server stopped; fetch now times out after eight seconds.
- [ ] Build/report with team names and faculty-reviewed amended ER diagram.

## Step 6A — acceptance testing and necessary fixes

- [x] Re-read requirements/source mapping, backend and frontend test results, member scripts, database consistency evidence and startup instructions. Build with the documented Maven Wrapper; final build succeeds in `evidence/step6a-build.log`.
- [x] Confirm live normal application and read-only Oracle health: `http://127.0.0.1:8080/`, `SVR_APP` in `XEPDB1` (`evidence/step6a-health-database.json`). Harden `run-local.ps1` preflight, per-port diagnostics and failed-Java-exit reporting; occupied-port test in `evidence/step6a-launcher-port-check.txt`.
- [x] Complete outstanding Step 5 offline/mobile, eight-second timeout and repeated-submission checks through controlled proxy, with recovery in the same tab. Add uncertain-write guidance with no automatic retry; proxy log and screenshots in `evidence/step6a-*`.
- [x] Rehearse all three member browser paths, required/duplicate/date/overpayment/reference validation, reports, desktop/narrow layout and keyboard search; remove only disposable master records. Replace blocking native confirm with accessible dialog and eliminate incidental favicon request. See `docs/acceptance-test-results.md`.
- [x] Inventory all five screens' console warnings/errors and proxy network failures, distinguishing deliberate faults and 409 rejections from unexpected requests; see `evidence/step6a-browser-console.json` and `evidence/step6a-proxy-requests.ndjson`.
- [x] Audit SVR_APP/XEPDB1 eight-table counts, constraints, orphans, charges, availability, overpayments, invalid objects/errors and disposable records; all pass in `evidence/step6a-final-oracle-audit-partial.log` before the seed-comparison query defect. Preserve that ORA-00918 evidence, correct the generator, then run all eight two-way 81-row comparisons in a separate read-only SYS/XEPDB1 session with CURRENT_SCHEMA=SVR_APP; every mismatch count is zero in final `evidence/step6a-seed-diff-sys.log`. After customer 1989's browser update/delete, final counts, cleanup, objects and constraints pass in `evidence/step6a-post-cleanup-sys.log`.
- [x] Create Step 6A requirement matrix, test results, limitations and update member guide/README. Step 6B final report and viva materials have not been generated.

## Step 6A follow-up — committed normal-browser workflow

- [x] Reuse healthy port 8080 server with `testMode:false`; database health reports `SVR_APP`/`XEPDB1`. Preflight confirms unused isolated IDs, seed type 1 rate and matching branch employee. See `evidence/step6a-committed-health.json` and `step6a-committed-preflight.log`.
- [x] Create fictional customer 1981 and vehicle 3981 through the normal browser; start and refresh committed rental 7016. Fresh Oracle and HTTP reads show Active, ₹1,200 snapshot, ₹2,400 estimate and vehicle Rented.
- [x] Commit return at 04:36; refresh confirms Completed, ₹1,200 final charge, unchanged snapshot and vehicle Available. Commit ₹500 UPI payment 8018; refresh shows ₹700 balance. Browser rejects ₹701 overpayment and leaves one payment/₹700 balance. See `docs/acceptance-test-results.md` and `evidence/step6a-commit-*.jpg`.
- [x] Final read-only Oracle audit: original 81 seed rows unchanged in both directions, 11/11/10/10/11/10/11/11 total rows, 78 enabled/validated constraints, zero orphans, invalid objects, compilation errors, availability/charge mismatches or overpaid rentals. See `evidence/step6a-committed-final-audit.log`.
- [x] Retain only the four clearly marked test records CUSTOMER 1981, VEHICLE 3981, RENTAL 7016 and PAYMENT 8018; history triggers prevent safe deletion of genuine rental/payment records. No trigger or constraint bypass used. Cycle VI and Review 1 diagram amendment remain open; Step 6B report/viva materials not generated.
# Step 6B draft handoff (25 October 2026)

Prepared `submission-step6b/` with editable Markdown/DOCX report, PDF rendition, amended eight-table ER and relational diagrams (editable SVG plus PNG/PDF), three separate member guides, group demo run sheet, requirements/submission checklist, limitations and file index. The report uses committed Step 6A browser and fresh Oracle evidence; no app or database changes were made. The PDF and diagram images were visually inspected. The DOCX still requires a final Word layout inspection because LibreOffice is unavailable and Word COM export was denied in this runtime. Cycle VI, faculty acceptance of the Review 1 diagram amendment, member/institution details and G1 handwritten obligations remain outstanding. See `../submission-step6b/FILE-INDEX.md`.

