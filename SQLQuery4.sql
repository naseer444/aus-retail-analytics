USE AusRetailDW;

-- Clear staging first
TRUNCATE TABLE staging.dim_date;
TRUNCATE TABLE staging.dim_supplier;
TRUNCATE TABLE staging.dim_product;
TRUNCATE TABLE staging.dim_store;
TRUNCATE TABLE staging.fact_sales;

-- Load dim_date (adjust path)
BULK INSERT staging.dim_date
FROM 'E:\Retail Portfolio Project\files\dim_date.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', 
      TABLOCK, LASTFIELD = 14);

-- Load dim_supplier
BULK INSERT staging.dim_supplier
FROM 'E:\Retail Portfolio Project\files\dim_supplier.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', 
      TABLOCK, LASTFIELD = 9);

-- Load dim_product
BULK INSERT staging.dim_product
FROM 'E:\Retail Portfolio Project\files\dim_product.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', 
      TABLOCK, LASTFIELD = 11);

-- Load dim_store
BULK INSERT staging.dim_store
FROM 'E:\Retail Portfolio Project\files\dim_store.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', 
      TABLOCK, LASTFIELD = 9);

-- Load fact_sales
BULK INSERT staging.fact_sales
FROM 'E:\Retail Portfolio Project\files\fact_sales.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', 
      TABLOCK, LASTFIELD = 14);

-- Verify staging row counts
SELECT 'staging.dim_date'     AS tbl, COUNT(*) AS rows FROM staging.dim_date
UNION ALL SELECT 'staging.dim_supplier', COUNT(*) FROM staging.dim_supplier
UNION ALL SELECT 'staging.dim_product',  COUNT(*) FROM staging.dim_product
UNION ALL SELECT 'staging.dim_store',    COUNT(*) FROM staging.dim_store
UNION ALL SELECT 'staging.fact_sales',   COUNT(*) FROM staging.fact_sales;