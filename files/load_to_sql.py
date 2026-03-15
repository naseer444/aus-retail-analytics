"""
============================================================
PROJECT: Australian Retail Analytics Platform
FILE:    load_to_sql.py
DESC:    Python script to bulk-load CSV files into SQL Server
         staging tables using pyodbc (simulates ADF copy activity)
USAGE:   python load_to_sql.py
============================================================
"""

import pyodbc
import csv
import os
import sys
from datetime import datetime

# ── Connection config — update these for your environment ────────
SERVER   = 'localhost'          # or 'your-server.database.windows.net' for Azure SQL
DATABASE = 'AusRetailDW'
# Option A: Windows Auth (local SQL Server)
CONN_STR = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;'
# Option B: SQL Auth (Azure SQL — uncomment and fill in)
# USERNAME = 'your_username'
# PASSWORD = 'your_password'
# CONN_STR = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};UID={USERNAME};PWD={PASSWORD};'

DATA_DIR = os.path.join(os.path.dirname(__file__), '..', 'data')

# Table → CSV file → column mapping
LOAD_CONFIG = [
    {
        'table': 'staging.dim_date',
        'file':  'dim_date.csv',
        'cols':  ['date_id','date','day','month','month_name','quarter','year',
                  'financial_year','week_of_year','day_of_week','is_weekend',
                  'is_public_holiday','is_eofy_month','season'],
    },
    {
        'table': 'staging.dim_supplier',
        'file':  'dim_supplier.csv',
        'cols':  ['supplier_id','supplier_name','country','category','lead_time_days',
                  'reliability_score','contract_start','payment_terms_days','is_preferred'],
    },
    {
        'table': 'staging.dim_product',
        'file':  'dim_product.csv',
        'cols':  ['product_id','product_name','category','subcategory','brand',
                  'supplier_id','unit_cost_aud','unit_price_aud','weight_kg',
                  'country_of_origin','is_active'],
    },
    {
        'table': 'staging.dim_store',
        'file':  'dim_store.csv',
        'cols':  ['store_id','store_name','city','state','postcode','store_type',
                  'open_date','floor_area_sqm','is_active'],
    },
    {
        'table': 'staging.fact_sales',
        'file':  'fact_sales.csv',
        'cols':  ['sale_id','date_id','product_id','store_id','channel','quantity',
                  'unit_price_aud','discount_pct','net_unit_price','revenue_aud',
                  'cost_aud','gross_profit_aud','gst_aud','payment_method'],
    },
]

BATCH_SIZE = 1000  # rows per commit


def get_connection():
    try:
        conn = pyodbc.connect(CONN_STR, timeout=30)
        conn.autocommit = False
        return conn
    except pyodbc.Error as e:
        print(f'[ERROR] Could not connect to SQL Server: {e}')
        sys.exit(1)


def truncate_staging(cursor, table: str):
    cursor.execute(f'TRUNCATE TABLE {table};')
    print(f'  → Truncated {table}')


def load_csv_to_staging(cursor, table: str, file: str, cols: list) -> int:
    filepath = os.path.join(DATA_DIR, file)
    if not os.path.exists(filepath):
        print(f'  [WARN] File not found: {filepath}')
        return 0

    placeholders = ', '.join(['?' for _ in cols])
    col_list     = ', '.join(cols)
    sql = f'INSERT INTO {table} ({col_list}) VALUES ({placeholders})'

    total = 0
    batch = []
    with open(filepath, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            batch.append([row.get(c, None) for c in cols])
            if len(batch) >= BATCH_SIZE:
                cursor.executemany(sql, batch)
                total += len(batch)
                batch = []
        if batch:
            cursor.executemany(sql, batch)
            total += len(batch)

    return total


def run_pipeline(cursor):
    """Execute the staging → dw transform stored procedure."""
    cursor.execute('EXEC dw.usp_run_full_pipeline;')
    # Print any server messages
    while cursor.nextset():
        pass
    print('  → Transform pipeline completed')


def run_dq_checks(cursor):
    """Execute data quality checks."""
    cursor.execute('EXEC dw.usp_run_dq_checks;')
    while cursor.nextset():
        pass
    print('  → DQ checks completed')


def print_row_counts(cursor):
    tables = [
        'dw.dim_date', 'dw.dim_product', 'dw.dim_store',
        'dw.dim_supplier', 'dw.fact_sales'
    ]
    print('\n  Row counts in DW:')
    for t in tables:
        cursor.execute(f'SELECT COUNT(*) FROM {t}')
        cnt = cursor.fetchone()[0]
        print(f'    {t:<30} {cnt:>10,}')


def main():
    start = datetime.now()
    print('='*60)
    print('  Australian Retail Analytics — Data Load Pipeline')
    print(f'  Started: {start.strftime("%Y-%m-%d %H:%M:%S")}')
    print('='*60)

    conn   = get_connection()
    cursor = conn.cursor()

    try:
        # ── Step 1: Load all CSVs into staging ───────────────────
        print('\n[STEP 1] Loading CSVs → Staging tables')
        for cfg in LOAD_CONFIG:
            truncate_staging(cursor, cfg['table'])
            rows = load_csv_to_staging(cursor, cfg['table'], cfg['file'], cfg['cols'])
            conn.commit()
            print(f'  → {cfg["file"]} loaded: {rows:,} rows into {cfg["table"]}')

        # ── Step 2: Transform staging → DW ───────────────────────
        print('\n[STEP 2] Running transform pipeline (staging → dw)')
        run_pipeline(cursor)
        conn.commit()

        # ── Step 3: Data quality checks ───────────────────────────
        print('\n[STEP 3] Running data quality checks')
        run_dq_checks(cursor)
        conn.commit()

        # ── Step 4: Summary ───────────────────────────────────────
        print('\n[STEP 4] Final row counts')
        print_row_counts(cursor)

        elapsed = (datetime.now() - start).total_seconds()
        print(f'\n✅ Pipeline completed successfully in {elapsed:.1f}s')

    except Exception as e:
        conn.rollback()
        print(f'\n[ERROR] Pipeline failed: {e}')
        raise
    finally:
        cursor.close()
        conn.close()


if __name__ == '__main__':
    main()
