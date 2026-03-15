-- ============================================================
-- PROJECT: Australian Retail Analytics Platform
-- FILE:    03_data_quality_checks.sql
-- DESC:    Automated data quality checks with logging
--          Covers: nulls, duplicates, referential integrity,
--          business rule violations, and row count validation
-- ============================================================

USE AusRetailDW;
GO

-- ── Data quality log table ───────────────────────────────────────
DROP TABLE IF EXISTS dw.dq_log;
GO

CREATE TABLE dw.dq_log (
    log_id          INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    check_name      NVARCHAR(200)   NOT NULL,
    table_name      NVARCHAR(100)   NOT NULL,
    check_type      NVARCHAR(50)    NOT NULL,  -- NULL_CHECK | DUPLICATE | REF_INTEGRITY | BUSINESS_RULE | ROW_COUNT
    status          NVARCHAR(10)    NOT NULL,  -- PASS | FAIL | WARN
    records_checked INT,
    records_failed  INT,
    details         NVARCHAR(500),
    run_datetime    DATETIME2       NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ── Stored procedure: run all checks ────────────────────────────
CREATE OR ALTER PROCEDURE dw.usp_run_dq_checks
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @failed INT, @total INT, @msg NVARCHAR(500);

    PRINT '====== DATA QUALITY CHECK RUN: ' + CONVERT(NVARCHAR,SYSDATETIME(),120) + ' ======';

    -- ── 1. NULL check: fact_sales critical columns ───────────────
    SELECT @failed = COUNT(*) FROM dw.fact_sales
    WHERE sale_id IS NULL OR date_key IS NULL OR product_key IS NULL
       OR store_key IS NULL OR revenue_aud IS NULL OR quantity IS NULL;
    SELECT @total = COUNT(*) FROM dw.fact_sales;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('NULL check on critical columns', 'dw.fact_sales', 'NULL_CHECK',
           CASE WHEN @failed = 0 THEN 'PASS' ELSE 'FAIL' END,
           @total, @failed,
           'Checked: sale_id, date_key, product_key, store_key, revenue_aud, quantity');

    PRINT 'CHECK 1 — NULL critical columns (fact_sales): ' + CASE WHEN @failed=0 THEN 'PASS' ELSE 'FAIL ('+CAST(@failed AS NVARCHAR)+' rows)' END;

    -- ── 2. Duplicate sale_id ─────────────────────────────────────
    SELECT @failed = COUNT(*) FROM (
        SELECT sale_id, COUNT(*) AS cnt
        FROM dw.fact_sales
        GROUP BY sale_id
        HAVING COUNT(*) > 1
    ) x;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('Duplicate sale_id check', 'dw.fact_sales', 'DUPLICATE',
           CASE WHEN @failed = 0 THEN 'PASS' ELSE 'FAIL' END,
           @total, @failed, 'Each sale_id must be unique');

    PRINT 'CHECK 2 — Duplicate sale_id: ' + CASE WHEN @failed=0 THEN 'PASS' ELSE 'FAIL ('+CAST(@failed AS NVARCHAR)+' dupes)' END;

    -- ── 3. Referential integrity: date_key ───────────────────────
    SELECT @failed = COUNT(*) FROM dw.fact_sales f
    LEFT JOIN dw.dim_date d ON d.date_key = f.date_key
    WHERE d.date_key IS NULL;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('Orphan date_key check', 'dw.fact_sales', 'REF_INTEGRITY',
           CASE WHEN @failed = 0 THEN 'PASS' ELSE 'FAIL' END,
           @total, @failed, 'fact_sales.date_key must exist in dim_date');

    PRINT 'CHECK 3 — Orphan date_key: ' + CASE WHEN @failed=0 THEN 'PASS' ELSE 'FAIL' END;

    -- ── 4. Referential integrity: product_key ───────────────────
    SELECT @failed = COUNT(*) FROM dw.fact_sales f
    LEFT JOIN dw.dim_product p ON p.product_key = f.product_key
    WHERE p.product_key IS NULL;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('Orphan product_key check', 'dw.fact_sales', 'REF_INTEGRITY',
           CASE WHEN @failed = 0 THEN 'PASS' ELSE 'FAIL' END,
           @total, @failed, 'fact_sales.product_key must exist in dim_product');

    PRINT 'CHECK 4 — Orphan product_key: ' + CASE WHEN @failed=0 THEN 'PASS' ELSE 'FAIL' END;

    -- ── 5. Business rule: negative revenue ──────────────────────
    SELECT @failed = COUNT(*) FROM dw.fact_sales WHERE revenue_aud < 0;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('Negative revenue check', 'dw.fact_sales', 'BUSINESS_RULE',
           CASE WHEN @failed = 0 THEN 'PASS' ELSE 'FAIL' END,
           @total, @failed, 'Revenue must be >= 0 (returns handled separately)');

    PRINT 'CHECK 5 — Negative revenue: ' + CASE WHEN @failed=0 THEN 'PASS' ELSE 'FAIL' END;

    -- ── 6. Business rule: quantity must be positive ──────────────
    SELECT @failed = COUNT(*) FROM dw.fact_sales WHERE quantity <= 0;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('Zero/negative quantity check', 'dw.fact_sales', 'BUSINESS_RULE',
           CASE WHEN @failed = 0 THEN 'PASS' ELSE 'FAIL' END,
           @total, @failed, 'Quantity must be > 0');

    PRINT 'CHECK 6 — Zero/negative quantity: ' + CASE WHEN @failed=0 THEN 'PASS' ELSE 'FAIL' END;

    -- ── 7. Business rule: discount must be 0-100% ────────────────
    SELECT @failed = COUNT(*) FROM dw.fact_sales WHERE discount_pct < 0 OR discount_pct > 100;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('Discount % range check', 'dw.fact_sales', 'BUSINESS_RULE',
           CASE WHEN @failed = 0 THEN 'PASS' ELSE 'FAIL' END,
           @total, @failed, 'Discount % must be between 0 and 100');

    PRINT 'CHECK 7 — Discount % range: ' + CASE WHEN @failed=0 THEN 'PASS' ELSE 'FAIL' END;

    -- ── 8. Business rule: unit cost < unit price ─────────────────
    SELECT @failed = COUNT(*) FROM dw.dim_product WHERE unit_cost_aud >= unit_price_aud;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('Cost < Price check', 'dw.dim_product', 'BUSINESS_RULE',
           CASE WHEN @failed = 0 THEN 'PASS' ELSE 'WARN' END,
           (SELECT COUNT(*) FROM dw.dim_product), @failed,
           'Unit cost should be less than unit price for positive margin');

    PRINT 'CHECK 8 — Cost < Price: ' + CASE WHEN @failed=0 THEN 'PASS' ELSE 'WARN ('+CAST(@failed AS NVARCHAR)+' products)' END;

    -- ── 9. Row count: dim_date coverage check ───────────────────
    DECLARE @min_date DATE, @max_date DATE, @expected_days INT, @actual_days INT;
    SELECT @min_date = MIN(full_date), @max_date = MAX(full_date) FROM dw.dim_date;
    SET @expected_days = DATEDIFF(DAY, @min_date, @max_date) + 1;
    SELECT @actual_days = COUNT(*) FROM dw.dim_date;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('Date dimension completeness', 'dw.dim_date', 'ROW_COUNT',
           CASE WHEN @actual_days = @expected_days THEN 'PASS' ELSE 'FAIL' END,
           @expected_days, @expected_days - @actual_days,
           'Expected ' + CAST(@expected_days AS NVARCHAR) + ' days, found ' + CAST(@actual_days AS NVARCHAR));

    PRINT 'CHECK 9 — dim_date completeness: ' + CASE WHEN @actual_days=@expected_days THEN 'PASS' ELSE 'FAIL' END;

    -- ── 10. Supplier reliability score range ─────────────────────
    SELECT @failed = COUNT(*) FROM dw.dim_supplier
    WHERE reliability_score < 0 OR reliability_score > 1;

    INSERT INTO dw.dq_log(check_name, table_name, check_type, status, records_checked, records_failed, details)
    VALUES('Supplier reliability score range', 'dw.dim_supplier', 'BUSINESS_RULE',
           CASE WHEN @failed = 0 THEN 'PASS' ELSE 'FAIL' END,
           (SELECT COUNT(*) FROM dw.dim_supplier), @failed,
           'Reliability score must be between 0.0 and 1.0');

    PRINT 'CHECK 10 — Supplier reliability score: ' + CASE WHEN @failed=0 THEN 'PASS' ELSE 'FAIL' END;

    -- ── Summary ──────────────────────────────────────────────────
    DECLARE @pass_count INT, @fail_count INT, @warn_count INT;
    SELECT
        @pass_count = SUM(CASE WHEN status='PASS' THEN 1 ELSE 0 END),
        @fail_count = SUM(CASE WHEN status='FAIL' THEN 1 ELSE 0 END),
        @warn_count = SUM(CASE WHEN status='WARN' THEN 1 ELSE 0 END)
    FROM dw.dq_log
    WHERE run_datetime >= DATEADD(SECOND,-10,SYSDATETIME());

    PRINT '====================================';
    PRINT 'DQ SUMMARY: PASS=' + CAST(@pass_count AS NVARCHAR) +
          ' | FAIL=' + CAST(@fail_count AS NVARCHAR) +
          ' | WARN=' + CAST(@warn_count AS NVARCHAR);
    PRINT '====================================';
END;
GO

-- ── View: latest DQ check results (for Power BI) ────────────────
CREATE OR ALTER VIEW report.vw_dq_latest_results AS
SELECT
    check_name,
    table_name,
    check_type,
    status,
    records_checked,
    records_failed,
    CAST(CASE WHEN records_checked > 0
        THEN ROUND(CAST(records_failed AS FLOAT)/records_checked*100,2)
        ELSE 0 END AS DECIMAL(5,2))  AS failure_pct,
    details,
    run_datetime
FROM dw.dq_log
WHERE run_datetime = (
    SELECT MAX(run_datetime) FROM dw.dq_log
);
GO

PRINT 'Data quality objects created successfully.';
GO
