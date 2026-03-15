-- ============================================================
-- PROJECT: Australian Retail Analytics Platform
-- FILE:    02_transform_load.sql
-- DESC:    Stored procedure to transform & load staging → dw
--          Simulates the Silver layer transformation logic
-- ============================================================

USE AusRetailDW;
GO

-- ── Load dimensions first, then fact ────────────────────────────

CREATE OR ALTER PROCEDURE dw.usp_load_dim_date
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dw.dim_date AS target
    USING (
        SELECT
            CAST(date_id AS INT)                    AS date_key,
            CAST(date AS DATE)                      AS full_date,
            CAST(day AS TINYINT)                    AS day,
            CAST(month AS TINYINT)                  AS month,
            month_name,
            quarter,
            CAST(year AS SMALLINT)                  AS year,
            financial_year,
            CAST(week_of_year AS TINYINT)           AS week_of_year,
            day_of_week,
            CAST(CASE is_weekend        WHEN 'Y' THEN 1 ELSE 0 END AS BIT) AS is_weekend,
            CAST(CASE is_public_holiday WHEN 'Y' THEN 1 ELSE 0 END AS BIT) AS is_public_holiday,
            CAST(CASE is_eofy_month     WHEN 'Y' THEN 1 ELSE 0 END AS BIT) AS is_eofy_month,
            season
        FROM staging.dim_date
        WHERE TRY_CAST(date_id AS INT) IS NOT NULL
    ) AS source ON target.date_key = source.date_key
    WHEN NOT MATCHED THEN
        INSERT (date_key, full_date, day, month, month_name, quarter, year,
                financial_year, week_of_year, day_of_week, is_weekend,
                is_public_holiday, is_eofy_month, season)
        VALUES (source.date_key, source.full_date, source.day, source.month, source.month_name,
                source.quarter, source.year, source.financial_year, source.week_of_year,
                source.day_of_week, source.is_weekend, source.is_public_holiday,
                source.is_eofy_month, source.season);

    PRINT 'dim_date loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows affected.';
END;
GO

-- ─────────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dw.usp_load_dim_supplier
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dw.dim_supplier AS target
    USING (
        SELECT
            supplier_id,
            supplier_name,
            country,
            category,
            TRY_CAST(lead_time_days AS INT)         AS lead_time_days,
            TRY_CAST(reliability_score AS DECIMAL(4,2)) AS reliability_score,
            TRY_CAST(contract_start AS DATE)        AS contract_start,
            TRY_CAST(payment_terms_days AS INT)     AS payment_terms_days,
            CAST(CASE is_preferred WHEN 'Y' THEN 1 ELSE 0 END AS BIT) AS is_preferred
        FROM staging.dim_supplier
        WHERE supplier_id IS NOT NULL
    ) AS source ON target.supplier_id = source.supplier_id
    WHEN MATCHED THEN
        UPDATE SET
            supplier_name      = source.supplier_name,
            reliability_score  = source.reliability_score,
            is_preferred       = source.is_preferred
    WHEN NOT MATCHED THEN
        INSERT (supplier_id, supplier_name, country, category, lead_time_days,
                reliability_score, contract_start, payment_terms_days, is_preferred)
        VALUES (source.supplier_id, source.supplier_name, source.country, source.category,
                source.lead_time_days, source.reliability_score, source.contract_start,
                source.payment_terms_days, source.is_preferred);

    PRINT 'dim_supplier loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows affected.';
END;
GO

-- ─────────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dw.usp_load_dim_product
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dw.dim_product AS target
    USING (
        SELECT
            product_id,
            product_name,
            category,
            subcategory,
            brand,
            supplier_id,
            TRY_CAST(unit_cost_aud  AS DECIMAL(10,2)) AS unit_cost_aud,
            TRY_CAST(unit_price_aud AS DECIMAL(10,2)) AS unit_price_aud,
            TRY_CAST(weight_kg      AS DECIMAL(5,2))  AS weight_kg,
            country_of_origin,
            CAST(CASE is_active WHEN 'Y' THEN 1 ELSE 0 END AS BIT) AS is_active
        FROM staging.dim_product
        WHERE product_id IS NOT NULL
          AND TRY_CAST(unit_cost_aud  AS DECIMAL(10,2)) IS NOT NULL
          AND TRY_CAST(unit_price_aud AS DECIMAL(10,2)) IS NOT NULL
    ) AS source ON target.product_id = source.product_id
    WHEN MATCHED THEN
        UPDATE SET
            product_name     = source.product_name,
            unit_cost_aud    = source.unit_cost_aud,
            unit_price_aud   = source.unit_price_aud,
            is_active        = source.is_active
    WHEN NOT MATCHED THEN
        INSERT (product_id, product_name, category, subcategory, brand, supplier_id,
                unit_cost_aud, unit_price_aud, weight_kg, country_of_origin, is_active)
        VALUES (source.product_id, source.product_name, source.category, source.subcategory,
                source.brand, source.supplier_id, source.unit_cost_aud, source.unit_price_aud,
                source.weight_kg, source.country_of_origin, source.is_active);

    PRINT 'dim_product loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows affected.';
END;
GO

-- ─────────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dw.usp_load_dim_store
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dw.dim_store AS target
    USING (
        SELECT
            store_id,
            store_name,
            city,
            state,
            postcode,
            store_type,
            TRY_CAST(open_date AS DATE)      AS open_date,
            TRY_CAST(floor_area_sqm AS INT)  AS floor_area_sqm,
            CAST(CASE is_active WHEN 'Y' THEN 1 ELSE 0 END AS BIT) AS is_active
        FROM staging.dim_store
        WHERE store_id IS NOT NULL
    ) AS source ON target.store_id = source.store_id
    WHEN MATCHED THEN
        UPDATE SET
            store_name     = source.store_name,
            is_active      = source.is_active,
            floor_area_sqm = source.floor_area_sqm
    WHEN NOT MATCHED THEN
        INSERT (store_id, store_name, city, state, postcode, store_type,
                open_date, floor_area_sqm, is_active)
        VALUES (source.store_id, source.store_name, source.city, source.state, source.postcode,
                source.store_type, source.open_date, source.floor_area_sqm, source.is_active);

    PRINT 'dim_store loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows affected.';
END;
GO

-- ─────────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dw.usp_load_fact_sales
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dw.fact_sales (
        sale_id, date_key, product_key, store_key, channel,
        quantity, unit_price_aud, discount_pct, net_unit_price,
        revenue_aud, cost_aud, gross_profit_aud, gst_aud, payment_method
    )
    SELECT
        s.sale_id,
        CAST(s.date_id AS INT),
        p.product_key,
        st.store_key,
        s.channel,
        CAST(s.quantity AS INT),
        TRY_CAST(s.unit_price_aud  AS DECIMAL(10,2)),
        TRY_CAST(s.discount_pct    AS DECIMAL(5,2)),
        TRY_CAST(s.net_unit_price  AS DECIMAL(10,2)),
        TRY_CAST(s.revenue_aud     AS DECIMAL(12,2)),
        TRY_CAST(s.cost_aud        AS DECIMAL(12,2)),
        TRY_CAST(s.gross_profit_aud AS DECIMAL(12,2)),
        TRY_CAST(s.gst_aud         AS DECIMAL(10,2)),
        s.payment_method
    FROM staging.fact_sales s
    JOIN dw.dim_product p  ON p.product_id = s.product_id
    JOIN dw.dim_store   st ON st.store_id  = s.store_id
    JOIN dw.dim_date    d  ON d.date_key   = CAST(s.date_id AS INT)
    WHERE s.sale_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dw.fact_sales f WHERE f.sale_id = s.sale_id
      );

    PRINT 'fact_sales loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows inserted.';
END;
GO

-- ── Master pipeline procedure ────────────────────────────────────
CREATE OR ALTER PROCEDURE dw.usp_run_full_pipeline
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start DATETIME2 = SYSDATETIME();
    PRINT '=== Pipeline started: ' + CONVERT(NVARCHAR,@start,120) + ' ===';

    EXEC dw.usp_load_dim_date;
    EXEC dw.usp_load_dim_supplier;
    EXEC dw.usp_load_dim_product;
    EXEC dw.usp_load_dim_store;
    EXEC dw.usp_load_fact_sales;

    PRINT '=== Pipeline completed in ' +
          CAST(DATEDIFF(MILLISECOND,@start,SYSDATETIME()) AS NVARCHAR) + 'ms ===';
END;
GO

PRINT 'All stored procedures created successfully.';
GO
