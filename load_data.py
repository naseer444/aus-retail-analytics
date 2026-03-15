import pyodbc
import csv
import os

# ── Update this path to your data folder ──
DATA_DIR = r'E:\Retail Portfolio Project\files'

CONN_STR = (
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=localhost\\SQLEXPRESS;'
    'DATABASE=AusRetailDW;'
    'Trusted_Connection=yes;'
    'TrustServerCertificate=yes;'
)

TABLES = [
    'dim_date',
    'dim_supplier', 
    'dim_product',
    'dim_store',
    'fact_sales',
]

def load_csv(cursor, table, filepath):
    with open(filepath, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        cols = reader.fieldnames
        placeholders = ','.join(['?' for _ in cols])
        col_list = ','.join(cols)
        sql = f'INSERT INTO staging.{table} ({col_list}) VALUES ({placeholders})'
        rows = [tuple(row[c] for c in cols) for row in reader]
    cursor.executemany(sql, rows)
    return len(rows)

conn   = pyodbc.connect(CONN_STR)
cursor = conn.cursor()

for table in TABLES:
    filepath = os.path.join(DATA_DIR, f'{table}.csv')
    cursor.execute(f'TRUNCATE TABLE staging.{table}')
    count = load_csv(cursor, table, filepath)
    conn.commit()
    print(f'{table}: {count:,} rows loaded')

print('\nAll done! Now run: EXEC dw.usp_run_full_pipeline in SSMS')
cursor.close()
conn.close()
