# Three-member module ownership and demonstration plan

The team has three members; names remain to be filled in. Ownership below follows the user's Step 2A assignment. It allocates academic demonstration work, not database privileges or application roles. G1 p. 2 expects each person to demonstrate at least one INSERT, UPDATE and DELETE plus five varied SELECT queries.

| Member | Ownership | Five prepared SELECTs in `database/queries/01_select_demos.sql` | Disposable DML demonstration |
| --- | --- | --- | --- |
| 1 | Customers, customer phones, payments, revenue reports | M1.1 customer list (simple); M1.2 customer-phone join; M1.3 branch collected-rent multi-join/aggregation; M1.4 correlated `EXISTS` paid customers; M1.5 `TO_CHAR`/`ROUND` monthly cash receipts | INSERT temporary unreferenced CUSTOMER 1991, UPDATE its address, DELETE it, then ROLLBACK. Payment demonstrations should use separate disposable records only after transactional billing is implemented. |
| 2 | Vehicles, vehicle types, branches, employees | M2.1 type list (simple); M2.2 vehicle/type/branch join; M2.3 nested `EXISTS` available branches; M2.4 outer join fleet counts; M2.5 `UPPER`/`LENGTH` employee listing | INSERT unused VEHICLE_TYPE 99, UPDATE its rate, DELETE it, then ROLLBACK. Never change a rate used by a historical rental except to verify snapshot preservation. |
| 3 | Rentals, returns, statuses, charge calculations | M3.1 rental list (simple); M3.2 customer/vehicle/type join; M3.3 nested `EXISTS` rental history; M3.4 `CEIL`/`GREATEST` derived days; M3.5 status aggregation/`AVG` | After Step 3 procedures exist, INSERT a disposable future Cancelled RENTAL 5998 with no payment, UPDATE its expected date, DELETE it, then ROLLBACK. Show actual start/return on retained records through the procedures, without deleting genuine transaction history. |

All three separate DML/five-SELECT scripts ran in Step 3 as SVR_APP and rolled back; see `database/step3/member_1_demo.sql`, `member_2_demo.sql`, `member_3_demo.sql` and `evidence/step3-members.log`. The disposable IDs were unused. The earlier `database/verification/02_negative_rollback.sql` is Step 2B evidence only and not seed data.

`EMPLOYEE."ROLE"` stores duties such as Rental Agent or Branch Manager. No login or access control is implemented in this phase, so this column must not be described as an application permission mechanism.
