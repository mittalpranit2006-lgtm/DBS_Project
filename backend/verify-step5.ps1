$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:8080/api'
function Read-Api([string]$path) { Invoke-RestMethod -Uri ($base + $path) -Method Get }
$health = Read-Api '/health/database'
if ($health.account -ne 'SVR_APP' -or $health.pdb -ne 'XEPDB1') { throw 'Wrong database account or PDB.' }
$names = @('customers','vehicle-types','branches','vehicles','employees','rentals','payments')
$rows = @{}
foreach ($name in $names) { $rows[$name] = @((Read-Api ('/' + $name + '?limit=100')).items) }
$phones = @()
foreach ($customer in $rows.customers) { $phones += @((Read-Api ('/customers/' + $customer.customerId + '/phones')).items) }
$counts = [ordered]@{
  CUSTOMER = $rows.customers.Count; CUSTOMER_PHONE = $phones.Count
  VEHICLE_TYPE = $rows['vehicle-types'].Count; BRANCH = $rows.branches.Count
  VEHICLE = $rows.vehicles.Count; EMPLOYEE = $rows.employees.Count
  RENTAL = $rows.rentals.Count; PAYMENT = $rows.payments.Count
}
$expected = @{ CUSTOMER=10; CUSTOMER_PHONE=11; VEHICLE_TYPE=10; BRANCH=10; VEHICLE=10; EMPLOYEE=10; RENTAL=10; PAYMENT=10 }
$issues = @()
foreach ($key in $expected.Keys) { if ($counts[$key] -ne $expected[$key]) { $issues += "$key count is $($counts[$key]), expected $($expected[$key])" } }
$customerIds = @($rows.customers | ForEach-Object { $_.customerId })
$typeIds = @($rows['vehicle-types'] | ForEach-Object { $_.typeId })
$branchIds = @($rows.branches | ForEach-Object { $_.branchId })
$vehicleIds = @($rows.vehicles | ForEach-Object { $_.vehicleId })
$employeeIds = @($rows.employees | ForEach-Object { $_.employeeId })
$rentalIds = @($rows.rentals | ForEach-Object { $_.rentalId })
foreach ($phone in $phones) { if ($phone.customerId -notin $customerIds) { $issues += "Orphan phone $($phone.phoneNo)" } }
foreach ($vehicle in $rows.vehicles) {
  if ($vehicle.typeId -notin $typeIds -or $vehicle.branchId -notin $branchIds) { $issues += "Orphan vehicle $($vehicle.vehicleId)" }
  $activeCount = @($rows.rentals | Where-Object { $_.vehicleId -eq $vehicle.vehicleId -and $_.statusName -eq 'Active' }).Count
  if (($vehicle.availabilityStatus -eq 'Rented' -and $activeCount -ne 1) -or ($vehicle.availabilityStatus -ne 'Rented' -and $activeCount -ne 0)) { $issues += "Availability mismatch $($vehicle.vehicleId)" }
}
foreach ($employee in $rows.employees) { if ($employee.branchId -notin $branchIds) { $issues += "Orphan employee $($employee.employeeId)" } }
foreach ($rental in $rows.rentals) {
  if ($rental.customerId -notin $customerIds -or $rental.vehicleId -notin $vehicleIds -or $rental.employeeId -notin $employeeIds) { $issues += "Orphan rental $($rental.rentalId)" }
  if ([datetime]$rental.expectedReturnDate -le [datetime]$rental.startDate) { $issues += "Invalid rental dates $($rental.rentalId)" }
  if ($null -ne $rental.actualReturnDate -and [datetime]$rental.actualReturnDate -lt [datetime]$rental.startDate) { $issues += "Invalid actual return $($rental.rentalId)" }
}
foreach ($payment in $rows.payments) { if ($payment.rentalId -notin $rentalIds) { $issues += "Orphan payment $($payment.paymentId)" } }
foreach ($rental in $rows.rentals) {
  $paid = ($rows.payments | Where-Object { $_.rentalId -eq $rental.rentalId -and $_.paymentStatus -eq 'Completed' } | Measure-Object -Property amount -Sum).Sum
  if ([decimal]$paid -gt [decimal]$rental.totalAmount) { $issues += "Overpaid rental $($rental.rentalId)" }
}
foreach ($pair in @(@('customers',1995),@('employees',2995),@('vehicles',3995),@('vehicle-types',99),@('branches',99))) {
  try { $null = Read-Api ('/' + $pair[0] + '/' + $pair[1]); $issues += "Disposable record remains: $($pair[0])/$($pair[1])" }
  catch { if ([int]$_.Exception.Response.StatusCode -ne 404) { throw } }
}
$result = [ordered]@{
  checkedAt = (Get-Date).ToString('s'); account=$health.account; pdb=$health.pdb
  counts=$counts; orphanCount=0; availabilityMismatchCount=0; overpaidRentalCount=0
  disposableRecordsFound=0; issues=$issues; passed=($issues.Count -eq 0)
}
$result | ConvertTo-Json -Depth 6
if ($issues.Count) { exit 1 }
