# Environment check — 24 October 2026 (Step 2B access review)

## Step 2B actual access check

- A read-only `lsnrctl status LISTENER` succeeded with `ORACLE_HOME=C:\oracle_sql_lite\dbhomeXE` and `TNS_ADMIN=C:\oracle_sql_lite\homes\OraDB21Home1\network\admin`. Its password-free output is in `evidence/step2b-listener-status.txt`. The listener reports TCP `DESKTOP-FFIRV71:1521` and service `xepdb1` with instance `xe` in `READY` status. The listener status does **not** prove an authenticated PDB connection or its READ WRITE state.
- The active Oracle network configuration is in `C:\oracle_sql_lite\homes\OraDB21Home1\network\admin`; `listener.ora` and `tnsnames.ora` identify `DESKTOP-FFIRV71:1521`. An initial sandboxed listener check failed at the socket boundary. The same read-only check succeeded with local-network access.
- A SQL*Plus 21.3 `/nolog` probe showed that a quoted absolute `@` path under `DBS Project` was split at the space; a nested `@@` include did not find its script-relative file. A project-relative `@database/...` path worked when SQL*Plus started with the project as current directory. The Step 2B runbook and scripts were corrected accordingly.
- An interactive `/nolog` session rejected `CONNECT SYSTEM@//DESKTOP-FFIRV71:1521/xepdb1` with `SP2-0306`. Oracle's quoted password-omitted form, `CONNECT SYSTEM@"DESKTOP-FFIRV71:1521/xepdb1"`, reached the hidden `Enter password:` prompt. The runbook now uses that form for both accounts. No password was entered by the tool.
- The user supplied a screenshot of an actual private-terminal SQL*Plus session. It shows `Connected.`, `SHOW USER` = `SYSTEM`, `SYS_CONTEXT('USERENV','CON_NAME')` = `XEPDB1`, and `@database/schema/00_admin_preflight.sql` reporting PASS: `USERS` and `TEMP` online, `USERS` headroom at least 20 MB, and `SVR_APP` absent. The screenshot is copied to `evidence/step2b-admin-preflight.png`; it displays no password. The first unquoted connection attempt failed with `SP2-0306` and `SP2-0640`, then the corrected quoted connection and preflight succeeded. This is actual administrator preflight evidence, not project-user execution evidence.
- The noninteractive execution tool had no SYSTEM or SVR_APP password. The user entered passwords privately in local SQL*Plus for the reviewed runner; no password appears in project SQL source or the saved text logs.
- A later screenshot showed two runner attempts from disconnected `/nolog` sessions. SQL*Plus emitted `SP2-0640: Not connected`, then an unconditional script message misleadingly said `SVR_APP created`; the following project login failed with `ORA-01017`. This is a runner defect, not evidence of successful setup. The screenshot is saved as `evidence/step2b-failed-runner-attempt.png`.
- A fresh read-only local OS-authenticated SYSDBA inspection switched to `XEPDB1` and queried `DBA_USERS` and `DBA_OBJECTS` for SVR_APP. Both returned **no rows**, proving no project account or objects were created by the failed attempt. Output is in `evidence/step2b-post-failure-account-inspection.txt`. No DDL was run in this SYS session.
- The runner was repaired to start with a fresh quoted SYSTEM `CONNECT` before preflight. Unconditional success messages in setup/schema/seed/negative scripts were replaced by connected PL/SQL post-checks. A deliberately nonexistent-account probe returned ORA-01017 with a nonzero exit and did not continue to later commands. The corrected runner was then executed successfully with private password entry.

## Step 2B completed Oracle results

- The password-free project log `evidence/step2b-project.log` shows `SVR_APP` connected to `XEPDB1` via service `xepdb1`, eight tables and the active-rental unique index created, 81 fictional rows inserted, all verification assertions passing, all 15 labeled SELECT demonstrations returning results, and `Commit complete` after those checks. It contains no `SP2-`, `ORA-`, or `PLS-` error lines and no credential terms.
- Final table counts, repeated after the fresh-connection negative/rollback test: CUSTOMER 10, CUSTOMER_PHONE 11, VEHICLE_TYPE 10, BRANCH 10, VEHICLE 10, EMPLOYEE 10, RENTAL 10, PAYMENT 10. `USER_TABLES` matched exactly those eight names. Constraint summary: 8 enabled/validated PK, 8 FK, 8 UNIQUE and 54 CHECK constraints (including Oracle's generated NOT NULL checks). The unique active-rental index was VALID. Orphan checks for all eight FK relationships returned zero; charge, registration-date, availability and payment assertions passed.
- `evidence/step2b-negative-rollback.log` shows a fresh `SVR_APP` connection, expected FK, composite-PK and status-CHECK rejections, disposable INSERT/UPDATE/DELETE each affecting one row, rollback leaving zero disposable rows, and a full final verification with unchanged counts. It contains no unexpected `SP2-`, `ORA-`, or `PLS-` error lines.
- `evidence/step2b-admin-postcheck.log` is a separate read-only OS-authenticated SYSDBA inspection in `XEPDB1`: PDB READ WRITE; SVR_APP OPEN, default USERS and temporary TEMP, USERS quota 20,971,520 bytes, only CREATE SESSION and CREATE TABLE system privileges, no roles or object grants, and exactly the eight expected SVR_APP tables. SYS was used only for this read-only inspection, never for project DDL.
- `evidence/step2b-seed-consistency-audit.log` independently shows all 10 rentals passing payment rules: seven Completed fully paid, two Active with partial payments within their charges, one Cancelled with no payment. Rate snapshot mismatches and vehicle availability mismatches are both zero.

**Step 2A user-provided environment:** Oracle Database 21c Express Edition; the user's SQL*Plus session is SYSTEM in CDB$ROOT; XEPDB1 exists and is READ WRITE. These statements were supplied by the user after the Step 1 checks below. A fresh Computer Use inventory still showed SQL Plus installed but not running with no visible window, and local process inspection returned no SQL*Plus process. This task did not independently connect to Oracle or execute SQL; the guarded Step 2B preflight will verify the target PDB, tablespaces and proposed account before any change.

## Location and access

- Project parent: `C:\Users\mitta\Desktop\DBS Project`. It was empty before Step 1. New project: `C:\Users\mitta\Desktop\DBS Project\SmartVehicleRental`. No previous project files were overwritten.
- Checked `AGENTS.md` at the drive, `Users`, user profile, Desktop and project-parent levels; none was present. The new project did not contain one.
- Local execution and Computer Use reported Windows paths and Windows apps on this desktop. This is access to the local laptop workspace, not a claim about a separate remote Oracle runtime.
- Browser Use exposed an in-app browser. It opened and visually verified the local welcome page at `http://127.0.0.1:8080/`.

## Installed tools and checks performed

| Check | Actual result |
| --- | --- |
| OS | PowerShell 7.6.5; `Windows_NT`, AMD64; OS build `10.0.26300.0` reported by .NET. |
| JDK | `C:\Program Files\Java\jdk-21.0.11\bin\java.exe -version` reported Java 21.0.11 LTS; matching `javac` reported 21.0.11. The Oracle `javapath` shims found on `PATH` did not respond promptly, so the direct JDK binaries were used. |
| Maven | `mvn` not found on `PATH`; no Maven build was run. The scaffold has `backend/pom.xml` targeting release 21. |
| SQL*Plus client | Installed at `C:\oracle_sql_lite\dbhomeXE\bin\sqlplus.exe`. It reported 21.3.0.0.0 when `ORACLE_HOME=C:\oracle_sql_lite\dbhomeXE` was set for that command. Without it, `sqlplus -v` failed with SP2-0667/SP2-0750 (message file/ORACLE_HOME). |
| Existing SQL*Plus session | Computer Use listed SQL Plus as installed but not running, and listed no SQL*Plus window. Local process inspection also found no `sqlplus` process. The user's existing logged-in session was therefore not accessible from these tools. No login was attempted. |
| Oracle connectivity | No username, server version, service/container or user-table result was obtained. A client version alone does not establish a database connection. No local `tnslsnr` or `oracle` process was returned by process inspection; this does not rule out a database elsewhere. The Oracle client `network/admin` directory contained `sqlnet.ora.rooh` but no visible `tnsnames.ora`. Service-control inspection was denied, and no listener connection was established. |
| Java compile | Direct `javac --release 21` completed successfully and copied the static resources into `backend/target/classes`. This is not a Maven build. |
| Java run | Initial sandboxed run failed with `Permission denied: connect` while Java created its loopback selector. Running the same compiled server with local-port access succeeded and printed the welcome URL. |
| Browser | In-app browser loaded the page and showed all four proposed modules and the explicit “Database connectivity has not been configured” message. This verifies static serving only. |

## Read-only SQL*Plus checks for the user

Run these **inside the already logged-in SQL*Plus prompt** and share the non-sensitive output. No password or connection string is needed in chat. These commands do not modify the database:

```sql
SHOW USER
SELECT banner FROM v$version WHERE banner LIKE 'Oracle Database%';
SELECT SYS_CONTEXT('USERENV','DB_NAME') AS db_name,
       SYS_CONTEXT('USERENV','SERVICE_NAME') AS service_name,
       SYS_CONTEXT('USERENV','CON_NAME') AS container_name
FROM dual;
SELECT table_name FROM user_tables ORDER BY table_name;
```

If the `v$version` query is denied, report its error; do not change permissions. If the current SQL*Plus session is actually on another desktop or machine, run the checks there. Do not log out of it.

## Source documents inspected

- `C:\Users\mitta\Desktop\VIT Academics\VIT 3rd Sem Documents\DBS\project\BACSE202_Database_Systems_Project_Guidelines.pdf` — all 2 pages.
- `C:\Users\mitta\Desktop\VIT Academics\VIT 3rd Sem Documents\DBS\project\DatabaseSystems_CourseProject_Guidelines-1-1-2.pdf` — all 2 pages.
- `C:\Users\mitta\Desktop\Smart_Vehicle_Rental_Management_Review1.pdf` — all 7 pages, including visual inspection of the diagram/reference layout on p. 5.
# Step 3 live follow-up (24 October 2026)

The project connected as `SVR_APP` to `XEPDB1` through `DESKTOP-FFIRV71:1521/xepdb1` for the package, trigger, test and member scripts. A passwordless local SYSDBA connection was used only for the XEPDB1 preflight, the three minimal CREATE grants, and read-only final audits. The final audit in `evidence/step3-final-audit.log` shows the eight seed table counts unchanged, valid Step 3 objects and no disposable rows. Passwords were entered privately at SQL*Plus prompts and are absent from scripts and evidence logs.

