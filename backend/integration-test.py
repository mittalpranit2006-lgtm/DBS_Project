"""Local HTTP/Oracle integration check. Uses no database credential; cleans its master rows."""
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta

BASE = "http://127.0.0.1:8080"
created = []
failures = []


def request(method, path, payload=None, rollback=False, expected=None):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"} if body is not None else {}
    if rollback:
        headers["X-SVR-Rollback"] = "true"
    req = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            status, raw, hdrs = response.status, response.read(), response.headers
    except urllib.error.HTTPError as error:
        status, raw, hdrs = error.code, error.read(), error.headers
    try:
        result = json.loads(raw) if raw else {}
    except json.JSONDecodeError:
        result = {"raw": raw.decode("utf-8", errors="replace")[:160]}
    print(f"{method} {path} -> {status} {json.dumps(result, default=str)[:700]}")
    if expected is not None and status != expected:
        raise AssertionError(f"Expected HTTP {expected}, received {status}: {result}")
    if rollback and status < 400 and hdrs.get("X-SVR-Rolled-Back") != "true":
        raise AssertionError("Rollback test header was not honored")
    return result


def cleanup():
    for path in reversed(created):
        try:
            request("DELETE", path, expected=200)
        except Exception as error:
            failures.append(f"CLEANUP FAILED {path}: {error}")


def main():
    health = request("GET", "/api/health", expected=200)
    if health.get("testMode") is not True:
        raise RuntimeError("Refusing workflow tests: SVR_TEST_MODE is not enabled")
    db = request("GET", "/api/health/database", expected=200)
    assert db["account"] == "SVR_APP" and db["pdb"] == "XEPDB1"
    with urllib.request.urlopen(BASE + "/", timeout=10) as response:
        assert response.status == 200 and b"Smart Vehicle Rental" in response.read()
    print("GET / -> 200 static page")

    for path in ["/api/customers/1901", "/api/vehicle-types/91", "/api/branches/91",
                 "/api/vehicles/3901", "/api/employees/2901"]:
        request("GET", path, expected=404)

    request("POST", "/api/customers", {
        "customerId":1901,"firstName":"Step","lastName":"Four",
        "email":"step4.1901@example.test","licenseNo":"DL-STEP4-1901",
        "address":"Temporary Test Address","registrationDate":"2026-10-01"}, expected=201)
    created.append("/api/customers/1901")
    request("GET", "/api/customers/1901", expected=200)
    request("GET", "/api/customers?q=step4.1901&limit=5", expected=200)
    request("PUT", "/api/customers/1901", {
        "firstName":"Step","lastName":"Four","email":"step4.1901@example.test",
        "licenseNo":"DL-STEP4-1901","address":"Updated Test Address",
        "registrationDate":"2026-10-01"}, expected=200)
    request("POST", "/api/customers", {
        "customerId":1901,"firstName":"Step","lastName":"Four",
        "email":"step4.duplicate@example.test","licenseNo":"DL-STEP4-DUP",
        "address":"Duplicate","registrationDate":"2026-10-01"}, expected=409)
    request("POST", "/api/customers", {"customerId":1902}, expected=400)
    request("POST", "/api/customers", "not-json", expected=400)
    request("PATCH", "/api/customers/1901", expected=405)

    request("POST", "/api/customers/1901/phones", {"phoneNo":"9991234567"}, expected=201)
    request("GET", "/api/customers/1901/phones", expected=200)
    request("PUT", "/api/customers/1901/phones/9991234567", {"newPhoneNo":"9991234568"}, expected=200)
    request("DELETE", "/api/customers/1901/phones/9991234568", expected=200)

    request("POST", "/api/vehicle-types", {
        "typeId":91,"typeName":"Step4 Test Type","dailyRate":1800,"securityDeposit":1000},expected=201)
    created.append("/api/vehicle-types/91")
    request("PUT", "/api/vehicle-types/91", {
        "typeName":"Step4 Test Type","dailyRate":1900,"securityDeposit":1000},expected=200)
    request("GET", "/api/vehicle-types?q=Step4&limit=5", expected=200)

    request("POST", "/api/branches", {
        "branchId":91,"branchName":"Step4 Branch","location":"Test City","phone":"9991234500"},expected=201)
    created.append("/api/branches/91")
    request("PUT", "/api/branches/91", {
        "branchName":"Step4 Branch","location":"Updated Test City","phone":"9991234500"},expected=200)
    request("GET", "/api/branches?q=Step4&limit=5", expected=200)

    request("POST", "/api/employees", {
        "employeeId":2901,"name":"Step Four Agent","email":"step4.agent@example.test",
        "phone":"9991234501","role":"Rental Agent","branchId":91},expected=201)
    created.append("/api/employees/2901")
    request("PUT", "/api/employees/2901", {
        "name":"Step Four Agent","email":"step4.agent@example.test",
        "phone":"9991234501","role":"Branch Manager","branchId":91},expected=200)
    request("GET", "/api/employees?q=Step%20Four&limit=5", expected=200)

    request("POST", "/api/vehicles", {
        "vehicleId":3901,"registrationNo":"SVR-STEP4-3901","brand":"Test",
        "model":"Model A","purchaseYear":2025,"availabilityStatus":"Available",
        "typeId":91,"branchId":91},expected=201)
    created.append("/api/vehicles/3901")
    request("PUT", "/api/vehicles/3901", {
        "registrationNo":"SVR-STEP4-3901","brand":"Test","model":"Model B",
        "purchaseYear":2025,"availabilityStatus":"Available","typeId":91,"branchId":91},expected=200)
    request("GET", "/api/vehicles?q=SVR-STEP4-3901&limit=5", expected=200)
    request("DELETE", "/api/branches/91", expected=409)

    now = datetime.now().replace(microsecond=0)
    start = (now-timedelta(hours=1)).isoformat()
    expected = (now+timedelta(hours=23)).isoformat()
    paid = (now-timedelta(minutes=1)).isoformat()
    request("POST", "/api/rentals/start", {
        "customerId":1901,"vehicleId":3901,"employeeId":2901,
        "startDate":start,"expectedReturnDate":expected},rollback=True,expected=201)
    assert request("GET", "/api/vehicles/3901", expected=200)["availabilityStatus"] == "Available"
    request("POST", "/api/rentals/start", {
        "customerId":1001,"vehicleId":3001,"employeeId":2001,
        "startDate":start,"expectedReturnDate":expected},rollback=True,expected=409)
    request("POST", "/api/rentals/start", {
        "customerId":1901,"vehicleId":3901,"employeeId":2901,
        "startDate":start,"expectedReturnDate":start},rollback=True,expected=400)
    request("POST", "/api/rentals/5001/return", {"actualReturnDate":now.isoformat()},
            rollback=True,expected=200)
    assert request("GET", "/api/rentals/5001", expected=200)["statusName"] == "Active"
    request("GET", "/api/rentals?customerId=1001&limit=5", expected=200)
    request("POST", "/api/payments", {
        "rentalId":5001,"amount":100,"paymentMethod":"UPI","paymentDate":paid},
        rollback=True,expected=201)
    request("POST", "/api/payments", {
        "rentalId":5001,"amount":1300,"paymentMethod":"UPI","paymentDate":paid},
        rollback=True,expected=409)
    request("GET", "/api/payments/6001", expected=200)
    request("GET", "/api/payments?rentalId=5001&limit=5", expected=200)
    balance=request("GET", "/api/reports/outstanding?rentalId=5001", expected=200)
    assert float(balance["outstandingBalance"]) == 1200
    args=urllib.parse.urlencode({"start":start,"end":expected,"rate":"1900"})
    charge=request("GET", "/api/reports/charge-estimate?"+args,expected=200)
    assert float(charge["charge"]) == 1900
    request("GET", "/api/reports/overdue?limit=10",expected=200)
    request("GET", "/api/reports/revenue?basis=cash&limit=10",expected=200)
    request("GET", "/api/reports/revenue?basis=recognized&limit=10",expected=200)


try:
    main()
except Exception as error:
    failures.append(str(error))
finally:
    cleanup()
    if failures:
        for failure in failures: print("FAIL", failure)
        sys.exit(1)
    print("PASS all HTTP/JDBC checks and master cleanup")
