# 🦘 Australian Retail Analytics Platform

> **End-to-end data pipeline and reporting solution built to demonstrate skills aligned with the Blundstone Data Developer role.**  
> Stack: Python · SQL Server · Azure Data Factory · Azure Data Lake · Power BI · DAX

---

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  SOURCE LAYER                                                   │
│  CSV Files (simulating ERP/POS exports)                         │
│  dim_product · dim_store · dim_supplier · dim_date · fact_sales │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼  Azure Data Factory (copy pipelines)
┌─────────────────────────────────────────────────────────────────┐
│  BRONZE LAYER — Azure Data Lake Gen2                            │
│  Raw ingested files, no transformation                          │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼  ADF Data Flow / Stored Procedures
┌─────────────────────────────────────────────────────────────────┐
│  SILVER LAYER — SQL Server (staging schema)                     │
│  Type-cast, validated, deduplicated                             │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼  MERGE stored procedures (usp_load_*)
┌─────────────────────────────────────────────────────────────────┐
│  GOLD LAYER — SQL Server (dw + report schemas)                  │
│  Star schema · Analytics views · DQ log                         │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼  Power BI DirectQuery / Import
┌─────────────────────────────────────────────────────────────────┐
│  REPORTING LAYER — Power BI                                     │
│  Sales Performance · Supply Chain · DQ Monitor                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📂 Project Structure

```
aus-retail-analytics/
│
├── data/                          # Generated source CSV files
│   ├── dim_product.csv            # 176 products across 5 categories
│   ├── dim_store.csv              # 32 stores across all AU states
│   ├── dim_supplier.csv           # 10 suppliers (AU, APAC, EU)
│   ├── dim_date.csv               # 1,461 days (Jan 2021 – Dec 2024)
│   └── fact_sales.csv             # ~50,000 transactions
│
├── sql/
│   ├── 01_create_schema.sql       # DB, schemas, staging & DW tables
│   ├── 02_transform_load.sql      # MERGE stored procedures
│   ├── 03_data_quality_checks.sql # 10 automated DQ checks + log table
│   └── 04_analytics_views.sql     # 6 report-layer views for Power BI
│
├── scripts/
│   └── load_to_sql.py             # Python pipeline runner
│
├── adf/                           # Azure Data Factory assets (Phase 2)
│   └── pipelines/                 # ARM-exportable pipeline JSONs
│
├── powerbi/
│   └── AusRetail.pbix             # Power BI report (Phase 3)
│
└── docs/
    ├── data_dictionary.md         # Column definitions & business rules
    └── architecture_diagram.png   # System architecture
```

---

## 🗄️ Data Model

**Star Schema** in the `dw` schema:

| Table | Type | Rows | Description |
|---|---|---|---|
| `dw.dim_date` | Dimension | 1,461 | Calendar + AU fiscal year + seasons |
| `dw.dim_product` | Dimension | 176 | Products across 5 ABS retail categories |
| `dw.dim_store` | Dimension | 32 | Stores across all 8 AU states/territories |
| `dw.dim_supplier` | Dimension | 10 | Suppliers with lead times & reliability scores |
| `dw.fact_sales` | Fact | ~50,700 | Transactions 2021–2024 with revenue, cost, GST |

**Australian Context:**
- Product categories align with **ABS Retail Trade classifications** (Clothing & Footwear, Food, Hardware, Electronics, Sporting Goods)
- Seasonal patterns reflect real AU retail: Christmas surge (Dec), EOFY (June), Boxing Day (26 Dec), Back-to-School (Jan/Feb)
- States: NSW, VIC, QLD, SA, WA, TAS, ACT, NT
- GST (10%) calculated on all transactions

---

## ⚙️ How to Run

### Prerequisites
- SQL Server 2019+ (or Azure SQL Database)
- Python 3.9+ with `pyodbc` installed
- ODBC Driver 17 for SQL Server

### Step 1 — Create the database schema
```sql
-- Run in SSMS or Azure Data Studio, in order:
-- 01_create_schema.sql
-- 02_transform_load.sql
-- 03_data_quality_checks.sql
-- 04_analytics_views.sql
```

### Step 2 — Install Python dependencies
```bash
pip install pyodbc
```

### Step 3 — Configure connection string
Edit `scripts/load_to_sql.py` and update:
```python
SERVER   = 'your-server-name'
DATABASE = 'AusRetailDW'
# Use Windows Auth (local) or SQL Auth (Azure SQL)
```

### Step 4 — Run the pipeline
```bash
python scripts/load_to_sql.py
```

### Step 5 — Verify in SSMS
```sql
-- Check row counts
SELECT 'fact_sales' AS tbl, COUNT(*) AS rows FROM dw.fact_sales
UNION ALL SELECT 'dim_product', COUNT(*) FROM dw.dim_product
UNION ALL SELECT 'dim_store',   COUNT(*) FROM dw.dim_store;

-- Check DQ results
SELECT * FROM report.vw_dq_latest_results;
```

---

## 📊 Power BI Dashboard (Phase 3)

Three report pages connect to the `report.*` views:

| Page | View | KPIs |
|---|---|---|
| **Sales Performance** | `vw_sales_monthly`, `vw_sales_yoy` | Revenue, Gross Margin, YoY Growth, Avg Basket Size |
| **Supply Chain** | `vw_supplier_analysis`, `vw_product_performance` | Lead Times, Supplier Risk, Product Rankings |
| **Data Quality Monitor** | `vw_dq_latest_results` | Pass/Fail rate, Failed record counts by check |

**Key DAX measures (documented in pbix):**
- `Rolling 30-Day Revenue`
- `EOFY Period Revenue vs Prior Year`
- `Supplier Risk Score (weighted)`
- `Revenue per Square Metre`

---

## 🔍 Data Quality Framework

10 automated checks run after every pipeline execution:

| # | Check | Type | Table |
|---|---|---|---|
| 1 | NULL on critical columns | NULL_CHECK | fact_sales |
| 2 | Duplicate sale_id | DUPLICATE | fact_sales |
| 3 | Orphan date_key | REF_INTEGRITY | fact_sales |
| 4 | Orphan product_key | REF_INTEGRITY | fact_sales |
| 5 | Negative revenue | BUSINESS_RULE | fact_sales |
| 6 | Zero/negative quantity | BUSINESS_RULE | fact_sales |
| 7 | Discount % out of range | BUSINESS_RULE | fact_sales |
| 8 | Cost ≥ Price | BUSINESS_RULE | dim_product |
| 9 | Date dimension completeness | ROW_COUNT | dim_date |
| 10 | Supplier reliability score range | BUSINESS_RULE | dim_supplier |

All results are logged to `dw.dq_log` and surfaced via `report.vw_dq_latest_results`.

---

## 🗺️ Roadmap

- [x] **Phase 1** — Data generation, SQL star schema, transform SPs, DQ checks ← *you are here*
- [ ] **Phase 2** — Azure Data Factory pipeline (ARM template export)
- [ ] **Phase 3** — Power BI dashboard (Sales · Supply Chain · DQ Monitor)
- [ ] **Phase 4** — Documentation: data dictionary, lineage diagram

---

## 🧠 Skills Demonstrated

| Skill | Where |
|---|---|
| SQL Server schema design | `01_create_schema.sql` |
| ETL with MERGE patterns | `02_transform_load.sql` |
| Data quality governance | `03_data_quality_checks.sql` |
| Analytics views / reporting layer | `04_analytics_views.sql` |
| Python data pipeline | `load_to_sql.py` |
| Star schema / dimensional modelling | `dw.*` tables |
| Australian retail domain knowledge | Data model, ABS categories, GST |

---

*Built as a portfolio project to demonstrate data engineering skills for the Blundstone Data Developer role (JOB-404683).*
