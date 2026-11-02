# Member 2 — fleet, vehicle types, branches and employees

**Presenter:** [Name / registration number]. Use http://127.0.0.1:8080/ for read-only inspection, and new fictional unreferenced IDs for a repeatable CRUD demonstration.

1. Show type, branch, vehicle and employee list/search/detail; create and edit isolated records. API: `/api/vehicle-types`, `/api/branches`, `/api/vehicles`, `/api/employees`. SQL: parameterized `MasterRepository` CRUD; affected tables VEHICLE_TYPE, BRANCH, VEHICLE, EMPLOYEE. Explain Type_ID and Branch_ID FKs on VEHICLE and Branch_ID FK on EMPLOYEE.
2. Attempt to delete a referenced disposable branch; show the visible 409 reference rejection. Delete test VEHICLE and EMPLOYEE first, then BRANCH and VEHICLE_TYPE. Do not delete seed or retained historical VEHICLE 3981.
3. Search VEHICLE 3981 read-only and show Available after RENTAL 7016 was returned. The vehicle transition trigger guards direct inconsistent status edits; `RECORD_RETURN` updated availability transactionally.
4. Show `database/step3/member_2_demo.sql`: disposable INSERT, UPDATE, DELETE on unused VEHICLE_TYPE 99, rolled back; M2.1 simple list, M2.2 vehicle/type/branch join, M2.3 nested EXISTS, M2.4 outer join/count, M2.5 string functions. Actual output: `evidence/step3-members.log`.

**Viva prompts:** Why separate VEHICLE_TYPE? A common tariff/deposit applies to many vehicles. Why snapshot a rental rate? A later type-rate change must not change historical charges. Why does a referenced branch delete fail? Mandatory FKs use restrictive parent deletion, with no cascade.

