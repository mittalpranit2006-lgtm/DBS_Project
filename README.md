# Smart Vehicle Rental Management System

**Submission materials:** [completed report in the supplied format](submission-step6b/Smart_Vehicle_Rental_Project_Report.docx), [amended diagrams, member guides and checklist](submission-step6b/FILE-INDEX.md). Cycle VI, Review 1 amendment approval and individual handwritten obligations remain open.

The Java 21 backend serves a plain HTML, CSS and JavaScript frontend. Its five screens use the eight-table Oracle schema and installed PL/SQL through same-origin JSON APIs. Step 6A acceptance testing is documented in [acceptance test results](docs/acceptance-test-results.md) and the [requirement matrix](docs/acceptance-matrix.md). No login or application authorization is implemented.

## Source of truth and status

- Review 1 remains the historical nine-relation submission. The user authorized an eight-table implementation by replacing `RENTAL_STATUS` and `RENTAL.Status_ID` with constrained `RENTAL.Status_Name`, while retaining the composite `CUSTOMER_PHONE` key. See [design changes](docs/design-changes.md) and [schema plan](docs/schema-plan.md).
- The BACSE202 and BCSE302L PDFs have different scope and minimums. The chosen eight-table implementation meets the latter's 6–8 table count; the submitted Review 1 diagram needs amendment for implementation. See [open decisions](docs/open-decisions.md).
- Java 21.0.11 and SQL*Plus 21.3 are installed. Maven was not on `PATH`, so `backend/mvnw.cmd` uses project-local Maven 3.9.11. Oracle XEPDB1 is READ WRITE through `DESKTOP-FFIRV71:1521/xepdb1`. See [backend setup](docs/backend-setup.md).
- The guarded scripts created exactly eight SVR_APP tables and committed 81 fictional rows after verification and 15 SELECT demonstrations. Constraint, orphan, sample payment/availability, and negative/rollback checks passed. Password-free logs are under `evidence/`; the [Step 2B runbook](docs/step2b-runbook.md) records execution and recovery details.
- Step 3 installed `SVR_WORKFLOW`, two sequences and three triggers. Step 4 HTTP/JDBC integration passed. Step 5 browser tests exercised the frontend and a separate rollback-only workflow server; its disposable master records were removed. Final seed counts and consistency passed; see [frontend test results](docs/frontend-test-results.md).
- Step 6A exercised all five screens, controlled offline/timeout/lost-response behavior, rapid submission, three member browser rehearsals and a direct SQL*Plus audit. Its initial disposable master records were removed. A follow-up then verified **committed** normal-browser rental start, return and payment; the protected fictional history remains as CUSTOMER 1981, VEHICLE 3981, RENTAL 7016 and PAYMENT 8018. All 81 original seed rows still match exactly; final counts are 11/11/10/10/11/10/11/11 in schema order. See [acceptance results](docs/acceptance-test-results.md) and [known limitations](docs/known-limitations.md). The historical nine-relation diagram and Cycle VI coverage remain unresolved.

## Layout

| Path | Purpose |
| --- | --- |
| `docs/` | Requirements, schema baseline, decisions and checkpoints |
| `database/schema/` | Guarded administrator and eight-table Oracle DDL scripts |
| `database/seed/` | Guarded fictional sample data, ten-plus rows per table |
| `database/queries/` | Fifteen read-only demonstration SELECTs |
| `database/step3/` | Installed procedures, functions, cursor, triggers and demonstrations |
| `database/verification/` | Read-only assertions and separate rollback demonstration |
| `backend/` | Java 21 HTTP API, Maven Wrapper, local start script and static frontend |
| `evidence/` | Local outputs, excluded from Git by default |

## Build and run locally

From `backend/` in PowerShell:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.11'
.\mvnw.cmd -B package dependency:copy-dependencies '-DoutputDirectory=target/dependency'
.\run-local.ps1
```

The local script reads the ignored `local-config.ps1`, checks the Java build and selected port, then asks for the SVR_APP password with hidden input. Do not place a password in source, static files, URLs or command arguments. Open [http://127.0.0.1:8080/](http://127.0.0.1:8080/) in a local browser; the database indicator should show `SVR_APP · XEPDB1`. Check `/api/health` separately from `/api/health/database`. See the [frontend guide](docs/frontend-guide.md), [API reference](docs/api-reference.md), [backend setup](docs/backend-setup.md) and [member demo guide](docs/member-demo-guide.md). The normal local config does not enable rollback test mode. Do not run the command again while the server already owns port 8080.
