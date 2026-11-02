# Step 2A implementation amendment to Review 1

The supplied Review 1 remains the historical submitted document. Its nine-relation ER and relational diagrams **must be annotated or redrawn** before they are presented as the implementation design. This amendment follows the user's explicit eight-table decision to meet the 6–8 table guideline in G2 p. 1; it is not a claim that Review 1 originally contained eight relations.

| Review 1, pp. 3 and 6–7 | Step 2A implementation | Reason and effect |
| --- | --- | --- |
| `RENTAL_STATUS(Status_ID PK, Status_Name, Description)` | No `RENTAL_STATUS` table | Remove one lookup relation to reach eight tables. The separate status description is not stored. |
| `RENTAL.Status_ID` FK → `RENTAL_STATUS.Status_ID` | `RENTAL.Status_Name VARCHAR2(12)` with CHECK in `('Active','Completed','Cancelled')` | Three states are enforced directly in RENTAL; no status FK remains. |
| Nine relations | Eight: CUSTOMER, CUSTOMER_PHONE, VEHICLE_TYPE, BRANCH, VEHICLE, EMPLOYEE, RENTAL, PAYMENT | Meets G2 table count while retaining the multivalued-phone relation. |
| `RENTAL` has no rate snapshot | Add `RENTAL.Daily_Rate_Snapshot NUMBER(10,2) NOT NULL` | Technical historical-rate column. Capture the vehicle type's daily rate when the rental begins; changing current tariffs does not recalculate an older rental. |
| `Rental_Duration`, `Late_Days` shown as derived | Still derived, never stored | Calculate from timestamps when needed. |
| `CUSTOMER_PHONE(Customer_ID,Phone_No)` composite PK | Same composite PK and customer FK | No change. |

All other Review 1 attributes, keys and relationships are retained. The new status check, rate snapshot and technical datatypes/constraints are implementation choices. The [implementation ER source](er-implementation.mmd) depicts the eight-table amendment; Review 1 p. 5 remains a historical drawing reference.

## Charge policy chosen for this implementation

For a non-cancelled rental, `Billable_Days = GREATEST(1, CEIL((end - Start_Date) in 24-hour days))`. The `end` is `Expected_Return_Date` while Active (estimate) and `Actual_Return_Date` when Completed (final). The final charge is billable days times `Daily_Rate_Snapshot`; late time is therefore charged at the ordinary daily rate, with no additional penalty. `Late_Days` is `GREATEST(0, CEIL(actual/now - expected))`, using actual return for Completed and current time for Active. A Cancelled rental has zero charge and zero billable days. No tax is added. `VEHICLE_TYPE.Security_Deposit` is reference information only, not a PAYMENT or revenue item. The implementation keeps `Total_Amount` as the active estimate or completed final total. These are user-specified project policies, **not quotations from the PDFs**.

DDL can constrain allowed values, dates, amounts, FKs and one Active rental per vehicle. It cannot by itself capture the rate at the right moment, recalculate final charges, synchronize vehicle availability, validate payment totals against rentals, or prevent all temporal overlaps. Those transactional safeguards belong to Step 3 procedures/triggers and a single-vehicle row-locking strategy.
