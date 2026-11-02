# Step 2B SQL*Plus runbook

## Execution status — completed 24 October 2026

The user-provided preflight screenshot showed `SYSTEM` in `XEPDB1`, with `SVR_APP` absent. A first runner attempt from a disconnected `/nolog` session exposed a SQL*Plus issue: `SP2-0640` did not trigger `WHENEVER SQLERROR`, and unconditional messages misleadingly said the account was created. A separate read-only SYSDBA inspection of XEPDB1 confirmed **SVR_APP still absent and no project objects**. The runner was repaired to start with a fresh SYSTEM login, and success messages now come only from connected PL/SQL post-checks. A deliberately nonexistent-account probe confirmed failed login exits before later commands.

The corrected one-time runner was then executed from SQL*Plus with private password entry:

```sql
@database/step2b_execute.sql
```

It established a fresh SYSTEM connection, repeated preflight, created SVR_APP, connected freshly as SVR_APP, created eight tables and one active-rental unique index, inserted 81 fictional rows, ran verification and all 15 labeled SELECTs, then committed. It reconnected as SVR_APP for expected negative tests, rollback and final verification. The two password-free project logs are `evidence/step2b-project.log` and `evidence/step2b-negative-rollback.log`; neither contains `SP2-`, `ORA-`, `PLS-`, or credential terms. **Do not rerun the one-time runner, setup, schema or seed.**

Final row counts are CUSTOMER 10, CUSTOMER_PHONE 11, VEHICLE_TYPE 10, BRANCH 10, VEHICLE 10, EMPLOYEE 10, RENTAL 10 and PAYMENT 10. Constraint summary is 8 enabled/validated PK, 8 FK, 8 UNIQUE and 54 CHECK (including NOT NULL) constraints; the active-rental unique index is VALID. Orphan, charge, registration-date, availability and payment assertions all passed. `evidence/step2b-seed-consistency-audit.log` separately shows every rental's payment rule PASS, zero rate-snapshot mismatches and zero availability mismatches. `evidence/step2b-admin-postcheck.log` confirms XEPDB1 READ WRITE, SVR_APP OPEN with 20 MB USERS quota, only CREATE SESSION and CREATE TABLE privileges, no roles or object grants, and exactly eight owned tables.

The sequence below is retained as a recovery and review reference. It describes what was run; repeating the one-time creation steps against this populated account is not part of Step 2B.

## Reviewed state and connection

The 24 October 2026 listener check found `DESKTOP-FFIRV71:1521`, with service `xepdb1` READY. The user's subsequent SQL*Plus screenshot confirmed `SYSTEM` in `XEPDB1` and a passing read-only administrator preflight; `SVR_APP` was absent. That screenshot is saved at `evidence/step2b-admin-preflight.png`. The administrator scripts require `SYSTEM` in `XEPDB1`; every project script independently requires `SVR_APP` in `XEPDB1`. Never run project DDL in `SYSTEM`, `SYS`, or `CDB$ROOT`.

The installed SQL*Plus 21.3 client failed a quoted absolute `@` path containing `DBS Project`, and its `@@` include did not resolve from the calling script's directory in a local probe. Start SQL*Plus from the project directory and use the project-relative `@database/...` paths below. The reviewed scripts have no nested includes. `WHENEVER SQLERROR` and `WHENEVER OSERROR` stop database/OS errors, but SQL*Plus `SP2` command errors do not reliably trigger them. Confirm each `@` script actually starts and finishes; stop on any `SP2`, `ORA`, or `PLS` error.

## 1. Administrator preflight

In a new private PowerShell window, run these commands. They contain no password:

```powershell
Set-Location 'C:\Users\mitta\Desktop\DBS Project\SmartVehicleRental'
$env:ORACLE_HOME = 'C:\oracle_sql_lite\dbhomeXE'
$env:TNS_ADMIN = 'C:\oracle_sql_lite\homes\OraDB21Home1\network\admin'
& 'C:\oracle_sql_lite\dbhomeXE\bin\sqlplus.exe' /nolog
```

At the `SQL>` prompt, type these lines. `CONNECT` prompts privately for the SYSTEM password. Do not type a password on the command line, spool the administrator session, or share a password in chat.

```sql
CONNECT SYSTEM@"DESKTOP-FFIRV71:1521/xepdb1"
SHOW USER
SELECT SYS_CONTEXT('USERENV','CON_NAME') AS container_name FROM dual;
@database/schema/00_admin_preflight.sql
```

The read-only preflight requires `SYSTEM`, `XEPDB1`, online `USERS` and `TEMP`, and an absent `SVR_APP`. It stops if any condition fails. If `SVR_APP` exists, preserve it: open another fresh SYSTEM session with the same PowerShell setup and `CONNECT`, then run `@database/schema/00_admin_inspect.sql`. Inspect its account status, quota, privileges, roles, grants, and objects before deciding whether the existing account is usable. Do not run setup, reset a password, drop objects, or overwrite the account.

If the preflight passes with `SVR_APP` absent, run the setup in the **same fresh SYSTEM session**:

```sql
@database/schema/01_admin_setup.sql
```

The setup repeats the guard, prompts for a new password with `ACCEPT ... HIDE`, creates only `SVR_APP` in `XEPDB1` with default `USERS`, temporary `TEMP`, a 20 MB `USERS` quota, and grants only `CREATE SESSION` and `CREATE TABLE` for this step. It does not grant a DBA role, `RESOURCE`, unlimited tablespace, or cross-schema privileges. This substitution pattern does not support a double quote or ampersand in the new password. Use a strong password without those two characters, keep the terminal private, and close the session after setup. No admin spooling is permitted.

## 2. Project schema and uncommitted seed

Open a **new** PowerShell/SQL*Plus session with the same three PowerShell setup lines. Connect as the project user; SQL*Plus prompts privately for its password:

```sql
CONNECT SVR_APP@"DESKTOP-FFIRV71:1521/xepdb1"
SPOOL evidence/step2b-project.log
SHOW USER
SELECT SYS_CONTEXT('USERENV','CON_NAME') AS container_name,
       SYS_CONTEXT('USERENV','SERVICE_NAME') AS service_name FROM dual;
@database/schema/02_tables.sql
@database/seed/01_seed.sql
@database/verification/01_verify.sql
@database/queries/01_select_demos.sql
```

The schema refuses any existing user tables; the seed refuses a nonempty eight-table schema. Run each once. DDL commits implicitly, so on partial schema failure, stop and inspect actual objects before preparing a specific repair. The seed leaves DML **uncommitted**. Verification checks exact table names, at least ten rows each, enabled/validated PK/FK/UNIQUE/CHECK constraints, the active-vehicle index, all FK orphans, charges, availability, payment consistency, registration dates, and representative statuses. The query script runs fifteen SELECT demonstrations. If all checks pass and no SQL*Plus command error appeared, commit in the same session, then close its spool:

```sql
COMMIT;
SPOOL OFF
EXIT
```

If any seed or verification error occurs, the fail-fast SQL error handler rolls back seed DML and exits. Do not blindly rerun the schema or seed. Inspect actual objects and rows, repair only the problem, and keep unrelated `SYSTEM` objects intact. If a SELECT demonstration or SQL*Plus command error occurs, explicitly `ROLLBACK;` before leaving the project session.

## 3. Fresh-session rollback demonstration and final verification

After the seed is committed, open a **fresh** project-user session. Do not use a session with unrelated uncommitted work. Run:

```sql
CONNECT SVR_APP@"DESKTOP-FFIRV71:1521/xepdb1"
SPOOL evidence/step2b-negative-rollback.log
SHOW USER
SELECT SYS_CONTEXT('USERENV','CON_NAME') AS container_name FROM dual;
@database/verification/02_negative_rollback.sql
@database/verification/01_verify.sql
SPOOL OFF
EXIT
```

The negative script must report expected FK, duplicate composite PK, and status CHECK rejections, and one-row disposable INSERT/UPDATE/DELETE, then prove the disposable row is absent after rollback. The final verification proves all eight table counts and consistency checks still pass. Stop on any unexpected error or missing PASS line.

Save only password-free output under `evidence/`. The listener status is already saved as `evidence/step2b-listener-status.txt`. Do not place `CONNECT .../<password>` in SQL history, files, shell arguments, or logs.

The missing Cycle VI coverage and the Review 1 nine-relation diagram amendment remain documented in `lab-cycle-map.md` and `design-changes.md`. They do not block this database step. Step 3 transactional safeguards, return workflows, and payment checks are still future work.
