USE AusRetailDW;


-- Inject bad data to simulate real DQ failures
-- 1. Negative revenue rows
INSERT INTO dw.fact_sales 
(sale_id, date_key, product_key, store_key, channel, quantity, 
unit_price_aud, discount_pct, net_unit_price, revenue_aud, 
cost_aud, gross_profit_aud, gst_aud, payment_method)
SELECT TOP 50
    'BAD' + CAST(ROW_NUMBER() OVER (ORDER BY sale_key) AS NVARCHAR),
    date_key, product_key, store_key, channel, quantity,
    unit_price_aud, discount_pct, net_unit_price,
    -1 * revenue_aud,
    cost_aud, gross_profit_aud, gst_aud, payment_method
FROM dw.fact_sales
WHERE sale_key <= 50;

-- 2. Zero quantity rows
INSERT INTO dw.fact_sales
(sale_id, date_key, product_key, store_key, channel, quantity,
unit_price_aud, discount_pct, net_unit_price, revenue_aud,
cost_aud, gross_profit_aud, gst_aud, payment_method)
SELECT TOP 30
    'ZQT' + CAST(ROW_NUMBER() OVER (ORDER BY sale_key) AS NVARCHAR),
    date_key, product_key, store_key, channel,
    0,
    unit_price_aud, discount_pct, net_unit_price, revenue_aud,
    cost_aud, gross_profit_aud, gst_aud, payment_method
FROM dw.fact_sales
WHERE sale_key <= 30;

-- 3. Invalid discount rows
INSERT INTO dw.fact_sales
(sale_id, date_key, product_key, store_key, channel, quantity,
unit_price_aud, discount_pct, net_unit_price, revenue_aud,
cost_aud, gross_profit_aud, gst_aud, payment_method)
SELECT TOP 20
    'DSC' + CAST(ROW_NUMBER() OVER (ORDER BY sale_key) AS NVARCHAR),
    date_key, product_key, store_key, channel, quantity,
    unit_price_aud,
    150,
    net_unit_price, revenue_aud,
    cost_aud, gross_profit_aud, gst_aud, payment_method
FROM dw.fact_sales
WHERE sale_key <= 20;

-- Run DQ checks
EXEC dw.usp_run_dq_checks;

-- Verify
SELECT check_name, status, records_failed, failure_pct
FROM report.vw_dq_latest_results
ORDER BY status DESC;