"""Generate read-only SQL comparing every original seed row to Oracle rows."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
seed = (root / 'database/seed/01_seed.sql').read_text()
rows: dict[str, list[str]] = {}
for table, values in re.findall(r'^INSERT INTO (\w+) VALUES \((.*)\);$', seed, re.M):
    rows.setdefault(table, []).append(values)

keys = {
    'CUSTOMER': ('CUSTOMER_ID', '1001', '1010'),
    'CUSTOMER_PHONE': ('CUSTOMER_ID', '1001', '1010'),
    'VEHICLE_TYPE': ('TYPE_ID', '1', '10'),
    'BRANCH': ('BRANCH_ID', '1', '10'),
    'VEHICLE': ('VEHICLE_ID', '3001', '3010'),
    'EMPLOYEE': ('EMPLOYEE_ID', '2001', '2010'),
    'RENTAL': ('RENTAL_ID', '5001', '5010'),
    'PAYMENT': ('PAYMENT_ID', '6001', '6010'),
}
column_counts = {'CUSTOMER': 7, 'CUSTOMER_PHONE': 2, 'VEHICLE_TYPE': 4,
                 'BRANCH': 4, 'VEHICLE': 8, 'EMPLOYEE': 6,
                 'RENTAL': 10, 'PAYMENT': 6}
assert set(rows) == set(keys), rows.keys()
assert sum(map(len, rows.values())) == 81
out = ['-- Generated from the unchanged original seed INSERT literals; read-only.',
       'SET ECHO OFF FEEDBACK ON', 'COLUMN TABLE_NAME FORMAT A20']
for table, (key, low, high) in keys.items():
    expected = '\nUNION ALL\n'.join('SELECT ' + values + ' FROM dual' for values in rows[table])
    actual = f'SELECT * FROM {table} WHERE {key} BETWEEN {low} AND {high}'
    aliases = ', '.join(f'c{i}' for i in range(1, column_counts[table] + 1))
    out.append(f"PROMPT SEED DIFF {table} (both counts must be zero)")
    out.append('WITH expected(' + aliases + ') AS (\n' + expected + '\n)\n'
               + "SELECT 'missing_or_changed' AS direction, COUNT(*) AS mismatches FROM (\n"
               + '  SELECT * FROM expected MINUS ' + actual + '\n)\n'
               + "UNION ALL\nSELECT 'unexpected_or_changed', COUNT(*) FROM (\n"
               + '  ' + actual + ' MINUS SELECT * FROM expected\n);')
(root / 'database/verification/step6a_seed_diff.sql').write_text('\n'.join(out) + '\n')
print('Generated 8 original-seed comparisons, 81 expected rows.')
