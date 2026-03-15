-- ============================================================
-- PROJECT: Australian Retail Analytics Platform
-- FILE:    04_analytics_views.sql
-- DESC:    Report-layer views consumed by Power BI dashboards
--          Covers: Sales Performance, Supply Chain, Seasonality
-- ============================================================

USE AusRetailDW;
GO

-- ── 1. Sales summary by month, state, category ──────────────────
CREATE OR ALTER VIEW report.vw_sales_monthly AS
SELECT
    d.year,
    d.month,
    d.month_name,
    d.financial_year,
    d.quarter,
    d.season,
    st.state,
    st.city,
    st.store_type,
    p.category,
    p.subcategory,
    p.brand,
    f.channel,
    f.payment_method,
    COUNT(DISTINCT f.sale_id)               AS transaction_count,
    SUM(f.quantity)                         AS units_sold,
    SUM(f.revenue_aud)                      AS total_revenue_aud,
    SUM(f.cost_aud)                         AS total_cost_aud,
    SUM(f.gross_profit_aud)                 AS total_gross_profit_aud,
    SUM(f.gst_aud)                          AS total_gst_aud,
    ROUND(AVG(f.discount_pct),2)            AS avg_discount_pct,
    ROUND(AVG(f.net_unit_price),2)          AS avg_selling_price,
    ROUND(SUM(f.gross_profit_aud)/NULLIF(SUM(f.revenue_aud),0)*100,2) AS gross_margin_pct
FROM dw.fact_sales f
JOIN dw.dim_date    d  ON d.date_key    = f.date_key
JOIN dw.dim_product p  ON p.product_key = f.product_key
JOIN dw.dim_store   st ON st.store_key  = f.store_key
GROUP BY
    d.year, d.month, d.month_name, d.financial_year, d.quarter, d.season,
    st.state, st.city, st.store_type,
    p.category, p.subcategory, p.brand,
    f.channel, f.payment_method;
GO

-- ── 2. Year-on-year comparison ───────────────────────────────────
CREATE OR ALTER VIEW report.vw_sales_yoy AS
WITH monthly AS (
    SELECT
        d.year,
        d.month,
        d.month_name,
        p.category,
        st.state,
        SUM(f.revenue_aud)       AS revenue_aud,
        SUM(f.gross_profit_aud)  AS gross_profit_aud,
        COUNT(DISTINCT f.sale_id) AS transactions
    FROM dw.fact_sales f
    JOIN dw.dim_date    d  ON d.date_key    = f.date_key
    JOIN dw.dim_product p  ON p.product_key = f.product_key
    JOIN dw.dim_store   st ON st.store_key  = f.store_key
    GROUP BY d.year, d.month, d.month_name, p.category, st.state
)
SELECT
    curr.year,
    curr.month,
    curr.month_name,
    curr.category,
    curr.state,
    curr.revenue_aud                        AS current_revenue,
    prev.revenue_aud                        AS prior_year_revenue,
    curr.revenue_aud - prev.revenue_aud     AS revenue_variance,
    ROUND((curr.revenue_aud - prev.revenue_aud) / NULLIF(prev.revenue_aud,0) * 100, 2) AS revenue_growth_pct,
    curr.gross_profit_aud                   AS current_gp,
    curr.transactions                       AS current_transactions
FROM monthly curr
LEFT JOIN monthly prev
    ON prev.year     = curr.year - 1
    AND prev.month   = curr.month
    AND prev.category = curr.category
    AND prev.state   = curr.state;
GO

-- ── 3. Product performance (top/bottom performers) ──────────────
CREATE OR ALTER VIEW report.vw_product_performance AS
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,
    p.unit_cost_aud,
    p.unit_price_aud,
    p.margin_pct                            AS catalogue_margin_pct,
    p.country_of_origin,
    s.supplier_name,
    s.country                               AS supplier_country,
    s.lead_time_days,
    s.reliability_score,
    COUNT(DISTINCT f.sale_id)               AS total_transactions,
    SUM(f.quantity)                         AS total_units_sold,
    SUM(f.revenue_aud)                      AS total_revenue_aud,
    SUM(f.gross_profit_aud)                 AS total_gross_profit_aud,
    ROUND(SUM(f.gross_profit_aud)/NULLIF(SUM(f.revenue_aud),0)*100,2) AS actual_margin_pct,
    ROUND(AVG(f.discount_pct),2)            AS avg_discount_pct,
    MIN(f.net_unit_price)                   AS min_selling_price,
    MAX(f.net_unit_price)                   AS max_selling_price,
    DENSE_RANK() OVER (ORDER BY SUM(f.revenue_aud) DESC) AS revenue_rank
FROM dw.dim_product p
LEFT JOIN dw.fact_sales f ON f.product_key = p.product_key
LEFT JOIN dw.dim_supplier s ON s.supplier_id = p.supplier_id
GROUP BY
    p.product_id, p.product_name, p.category, p.subcategory, p.brand,
    p.unit_cost_aud, p.unit_price_aud, p.margin_pct, p.country_of_origin,
    s.supplier_name, s.country, s.lead_time_days, s.reliability_score;
GO

-- ── 4. Store performance dashboard ──────────────────────────────
CREATE OR ALTER VIEW report.vw_store_performance AS
SELECT
    st.store_id,
    st.store_name,
    st.city,
    st.state,
    st.store_type,
    st.floor_area_sqm,
    st.open_date,
    d.financial_year,
    COUNT(DISTINCT f.sale_id)                   AS total_transactions,
    SUM(f.quantity)                             AS total_units_sold,
    SUM(f.revenue_aud)                          AS total_revenue_aud,
    SUM(f.gross_profit_aud)                     AS total_gross_profit_aud,
    ROUND(SUM(f.revenue_aud)/NULLIF(st.floor_area_sqm,0),2) AS revenue_per_sqm,
    ROUND(AVG(f.revenue_aud),2)                 AS avg_transaction_value,
    ROUND(SUM(f.gross_profit_aud)/NULLIF(SUM(f.revenue_aud),0)*100,2) AS gross_margin_pct
FROM dw.dim_store st
LEFT JOIN dw.fact_sales f ON f.store_key = st.store_key
LEFT JOIN dw.dim_date   d ON d.date_key  = f.date_key
GROUP BY
    st.store_id, st.store_name, st.city, st.state,
    st.store_type, st.floor_area_sqm, st.open_date,
    d.financial_year;
GO

-- ── 5. Seasonality & peak trading analysis ───────────────────────
CREATE OR ALTER VIEW report.vw_seasonality AS
SELECT
    d.year,
    d.month,
    d.month_name,
    d.season,
    d.is_public_holiday,
    d.is_weekend,
    d.is_eofy_month,
    p.category,
    f.channel,
    COUNT(DISTINCT f.sale_id)               AS transactions,
    SUM(f.revenue_aud)                      AS revenue_aud,
    ROUND(AVG(f.revenue_aud),2)             AS avg_basket_size,
    SUM(f.quantity)                         AS units_sold,
    -- Rolling 3-month average using window function
    ROUND(AVG(SUM(f.revenue_aud)) OVER (
        PARTITION BY p.category, f.channel
        ORDER BY d.year, d.month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3m_avg_revenue
FROM dw.fact_sales f
JOIN dw.dim_date    d ON d.date_key    = f.date_key
JOIN dw.dim_product p ON p.product_key = f.product_key
GROUP BY
    d.year, d.month, d.month_name, d.season,
    d.is_public_holiday, d.is_weekend, d.is_eofy_month,
    p.category, f.channel;
GO

-- ── 6. Supplier risk & supply chain view ────────────────────────
CREATE OR ALTER VIEW report.vw_supplier_analysis AS
SELECT
    s.supplier_id,
    s.supplier_name,
    s.country,
    s.category,
    s.lead_time_days,
    s.reliability_score,
    s.payment_terms_days,
    s.is_preferred,
    COUNT(DISTINCT p.product_id)                AS product_count,
    SUM(f.quantity)                             AS total_units_ordered,
    SUM(f.cost_aud)                             AS total_cost_aud,
    ROUND(SUM(f.gross_profit_aud)/NULLIF(SUM(f.revenue_aud),0)*100,2) AS avg_margin_pct,
    CASE
        WHEN s.reliability_score >= 0.95 THEN 'Low Risk'
        WHEN s.reliability_score >= 0.85 THEN 'Medium Risk'
        ELSE 'High Risk'
    END                                         AS risk_category,
    CASE
        WHEN s.lead_time_days <= 14  THEN 'Fast (<= 14 days)'
        WHEN s.lead_time_days <= 30  THEN 'Standard (15-30 days)'
        ELSE 'Long Lead (> 30 days)'
    END                                         AS lead_time_band
FROM dw.dim_supplier s
LEFT JOIN dw.dim_product p ON p.supplier_id = s.supplier_id
LEFT JOIN dw.fact_sales  f ON f.product_key = p.product_key
GROUP BY
    s.supplier_id, s.supplier_name, s.country, s.category,
    s.lead_time_days, s.reliability_score, s.payment_terms_days, s.is_preferred;
GO

PRINT 'All report views created successfully.';
GO
