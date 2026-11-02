# Step 4 backend setup

The Step 1 `com.sun.net.httpserver.HttpServer` remains the server. It binds only to `127.0.0.1`, serves the existing static files and `/api/*` from one origin, and uses one short-lived JDBC connection per request. HTTP routing/validation, transaction service, database configuration and JDBC repositories are in `backend/src/main/java/com/smartvehiclerental/{http,service,config,repository}`. API ownership follows the three member modules in `api-reference.md`. No ORM, login system or frontend workflow was added.

## Build

Java 21.0.11 is installed at `C:\Program Files\Java\jdk-21.0.11`. Maven was absent from PATH. The project-local Apache Maven Wrapper 3.3.4 was downloaded from Maven Central and its SHA1 verified; it downloads Maven 3.9.11 into the user's Maven cache. From `backend/` in PowerShell:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.11'
.\mvnw.cmd -B package dependency:copy-dependencies '-DoutputDirectory=target/dependency'
```

`pom.xml` uses `com.oracle.database.jdbc:ojdbc11:21.23.0.0` and Jackson 2.17.3. Oracle [lists ojdbc11 21.23 as certified with JDK 21 and Oracle Database 21c](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html). The [Apache Maven Wrapper](https://maven.apache.org/tools/mavenwrapper.html) keeps Maven local to this project. The observed build completed successfully in `evidence/step4-build.log`.

## Local configuration and start

Copy `backend/local-config.example.ps1` to `backend/local-config.ps1` and set the non-secret JDBC URL, SVR_APP username and HTTP port. The current machine's ignored local config points to `jdbc:oracle:thin:@//DESKTOP-FFIRV71:1521/xepdb1`. The config file is outside static resources and is Git ignored. Keep `SVR_DB_PASSWORD` out of files, command arguments and logs.

From `backend/` run:

```powershell
.\run-local.ps1
```

The script asks for the SVR_APP password with hidden input, passes it as a process environment variable, starts Java, and clears it from the launcher environment when Java stops. Alternatively set `SVR_DB_URL`, `SVR_DB_USER=SVR_APP`, `SVR_DB_PASSWORD` and optional `SVR_HTTP_PORT` in a private local environment before running Java. Never put the password in a URL or CLI argument. Open `http://127.0.0.1:8080/`. `/api/health` checks the application without opening Oracle; `/api/health/database` performs a read-only live SVR_APP/XEPDB1 query.

`SVR_TEST_MODE=true` was temporarily enabled in the ignored local config for the integration run and has been removed. In this mode, writes with `X-SVR-Rollback: true` execute through JDBC and the installed PL/SQL, then roll back before the response; the response includes `X-SVR-Rolled-Back: true`. Enable it only for disposable tests. The server binds to localhost and this mode is disabled by default.

Connections have a five-second login/connect timeout, a ten-second Oracle read timeout, and ten- or fifteen-second statement timeouts. Each write disables auto-commit and commits only after all repository work succeeds; failures roll back the whole request. The PL/SQL procedures retain their own savepoints and caller-owned transaction policy.
