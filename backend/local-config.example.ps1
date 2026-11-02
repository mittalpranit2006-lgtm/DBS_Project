# Copy to local-config.ps1 and adjust non-secret connection settings.
$env:SVR_DB_URL = 'jdbc:oracle:thin:@//YOUR_HOST:1521/xepdb1'
$env:SVR_DB_USER = 'SVR_APP'
$env:SVR_HTTP_PORT = '8080'
