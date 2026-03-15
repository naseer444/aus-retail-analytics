USE AusRetailDW;
EXEC dw.usp_run_full_pipeline;

USE AusRetailDW;
SELECT 'fact_sales'    AS tbl, COUNT(*) AS rows FROM dw.fact_sales
UNION ALL SELECT 'dim_product',  COUNT(*) FROM dw.dim_product
UNION ALL SELECT 'dim_store',    COUNT(*) FROM dw.dim_store
UNION ALL SELECT 'dim_date',     COUNT(*) FROM dw.dim_date
UNION ALL SELECT 'dim_supplier', COUNT(*) FROM dw.dim_supplier;