-- ============================================================
-- PROJECT: Australian Retail Analytics Platform
-- FILE:    01_create_schema.sql
-- DESC:    Creates the star schema for the retail data warehouse
-- AUTHOR:  Naseer ud din

-- ============================================================

USE master;
GO

-- Create database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'AusRetailDW')
BEGIN
    CREATE DATABASE AusRetailDW
    COLLATE SQL_Latin1_General_CP1_CI_AS;
    PRINT 'Database AusRetailDW created.';
END
GO

USE AusRetailDW;
GO

-- ── Create schemas ───────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'report')
    EXEC('CREATE SCHEMA report');
GO

PRINT 'Schemas created: staging, dw, report';
GO

-- ============================================================
-- STAGING TABLES  (raw ingested data — Bronze layer equivalent)
-- ============================================================

DROP TABLE IF EXISTS staging.fact_sales;
DROP TABLE IF EXISTS staging.dim_product;
DROP TABLE IF EXISTS staging.dim_store;
DROP TABLE IF EXISTS staging.dim_supplier;
DROP TABLE IF EXISTS staging.dim_date;
GO

CREATE TABLE staging.dim_product (
    product_id          NVARCHAR(20),
    product_name        NVARCHAR(200),
    category            NVARCHAR(100),
    subcategory         NVARCHAR(100),
    brand               NVARCHAR(100),
    supplier_id         NVARCHAR(20),
    unit_cost_aud       NVARCHAR(20),   -- loaded as string, cast during transform
    unit_price_aud      NVARCHAR(20),
    weight_kg           NVARCHAR(20),
    country_of_origin   NVARCHAR(100),
    is_active           NVARCHAR(5),
    load_datetime       DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE staging.dim_store (
    store_id            NVARCHAR(20),
    store_name          NVARCHAR(200),
    city                NVARCHAR(100),
    state               NVARCHAR(10),
    postcode            NVARCHAR(10),
    store_type          NVARCHAR(50),
    open_date           NVARCHAR(20),
    floor_area_sqm      NVARCHAR(20),
    is_active           NVARCHAR(5),
    load_datetime       DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE staging.dim_supplier (
    supplier_id         NVARCHAR(20),
    supplier_name       NVARCHAR(200),
    country             NVARCHAR(100),
    category            NVARCHAR(100),
    lead_time_days      NVARCHAR(10),
    reliability_score   NVARCHAR(10),
    contract_start      NVARCHAR(20),
    payment_terms_days  NVARCHAR(10),
    is_preferred        NVARCHAR(5),
    load_datetime       DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE staging.dim_date (
    date_id             NVARCHAR(10),
    date                NVARCHAR(20),
    day                 NVARCHAR(5),
    month               NVARCHAR(5),
    month_name          NVARCHAR(20),
    quarter             NVARCHAR(5),
    year                NVARCHAR(10),
    financial_year      NVARCHAR(20),
    week_of_year        NVARCHAR(5),
    day_of_week         NVARCHAR(20),
    is_weekend          NVARCHAR(5),
    is_public_holiday   NVARCHAR(5),
    is_eofy_month       NVARCHAR(5),
    season              NVARCHAR(20),
    load_datetime       DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE staging.fact_sales (
    sale_id             NVARCHAR(20),
    date_id             NVARCHAR(10),
    product_id          NVARCHAR(20),
    store_id            NVARCHAR(20),
    channel             NVARCHAR(50),
    quantity            NVARCHAR(10),
    unit_price_aud      NVARCHAR(20),
    discount_pct        NVARCHAR(10),
    net_unit_price      NVARCHAR(20),
    revenue_aud         NVARCHAR(20),
    cost_aud            NVARCHAR(20),
    gross_profit_aud    NVARCHAR(20),
    gst_aud             NVARCHAR(20),
    payment_method      NVARCHAR(50),
    load_datetime       DATETIME2 DEFAULT SYSDATETIME()
);
GO

PRINT 'Staging tables created successfully.';
GO

-- ============================================================
-- DATA WAREHOUSE TABLES  (Silver / Gold layer equivalent)
-- ============================================================

DROP TABLE IF EXISTS dw.fact_sales;
DROP TABLE IF EXISTS dw.dim_product;
DROP TABLE IF EXISTS dw.dim_store;
DROP TABLE IF EXISTS dw.dim_supplier;
DROP TABLE IF EXISTS dw.dim_date;
GO

-- ── Dimension: Date ──────────────────────────────────────────────
CREATE TABLE dw.dim_date (
    date_key            INT             NOT NULL PRIMARY KEY,  -- YYYYMMDD
    full_date           DATE            NOT NULL,
    day                 TINYINT         NOT NULL,
    month               TINYINT         NOT NULL,
    month_name          NVARCHAR(20)    NOT NULL,
    quarter             NCHAR(2)        NOT NULL,
    year                SMALLINT        NOT NULL,
    financial_year      NVARCHAR(10)    NOT NULL,   -- e.g. FY2023/24
    week_of_year        TINYINT         NOT NULL,
    day_of_week         NVARCHAR(10)    NOT NULL,
    is_weekend          BIT             NOT NULL DEFAULT 0,
    is_public_holiday   BIT             NOT NULL DEFAULT 0,
    is_eofy_month       BIT             NOT NULL DEFAULT 0,
    season              NVARCHAR(10)    NOT NULL
);

-- ── Dimension: Product ───────────────────────────────────────────
CREATE TABLE dw.dim_product (
    product_key         INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    product_id          NVARCHAR(20)    NOT NULL UNIQUE,
    product_name        NVARCHAR(200)   NOT NULL,
    category            NVARCHAR(100)   NOT NULL,
    subcategory         NVARCHAR(100)   NOT NULL,
    brand               NVARCHAR(100),
    supplier_id         NVARCHAR(20),
    unit_cost_aud       DECIMAL(10,2)   NOT NULL,
    unit_price_aud      DECIMAL(10,2)   NOT NULL,
    margin_pct          AS (CAST(ROUND((unit_price_aud - unit_cost_aud) / NULLIF(unit_price_aud,0) * 100, 2) AS DECIMAL(5,2))),
    weight_kg           DECIMAL(5,2),
    country_of_origin   NVARCHAR(100),
    is_active           BIT             NOT NULL DEFAULT 1,
    dw_insert_datetime  DATETIME2       NOT NULL DEFAULT SYSDATETIME()
);

-- ── Dimension: Store ─────────────────────────────────────────────
CREATE TABLE dw.dim_store (
    store_key           INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    store_id            NVARCHAR(20)    NOT NULL UNIQUE,
    store_name          NVARCHAR(200)   NOT NULL,
    city                NVARCHAR(100)   NOT NULL,
    state               NCHAR(3)        NOT NULL,
    postcode            NVARCHAR(10),
    store_type          NVARCHAR(50),
    open_date           DATE,
    floor_area_sqm      INT,
    is_active           BIT             NOT NULL DEFAULT 1,
    dw_insert_datetime  DATETIME2       NOT NULL DEFAULT SYSDATETIME()
);

-- ── Dimension: Supplier ──────────────────────────────────────────
CREATE TABLE dw.dim_supplier (
    supplier_key        INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    supplier_id         NVARCHAR(20)    NOT NULL UNIQUE,
    supplier_name       NVARCHAR(200)   NOT NULL,
    country             NVARCHAR(100),
    category            NVARCHAR(100),
    lead_time_days      INT,
    reliability_score   DECIMAL(4,2),
    contract_start      DATE,
    payment_terms_days  INT,
    is_preferred        BIT             NOT NULL DEFAULT 0,
    dw_insert_datetime  DATETIME2       NOT NULL DEFAULT SYSDATETIME()
);

-- ── Fact: Sales ──────────────────────────────────────────────────
CREATE TABLE dw.fact_sales (
    sale_key            BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    sale_id             NVARCHAR(20)    NOT NULL UNIQUE,
    date_key            INT             NOT NULL,
    product_key         INT             NOT NULL,
    store_key           INT             NOT NULL,
    channel             NVARCHAR(50)    NOT NULL,
    quantity            INT             NOT NULL,
    unit_price_aud      DECIMAL(10,2)   NOT NULL,
    discount_pct        DECIMAL(5,2)    NOT NULL DEFAULT 0,
    net_unit_price      DECIMAL(10,2)   NOT NULL,
    revenue_aud         DECIMAL(12,2)   NOT NULL,
    cost_aud            DECIMAL(12,2)   NOT NULL,
    gross_profit_aud    DECIMAL(12,2)   NOT NULL,
    gst_aud             DECIMAL(10,2)   NOT NULL,
    payment_method      NVARCHAR(50),
    dw_insert_datetime  DATETIME2       NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT fk_sales_date     FOREIGN KEY (date_key)    REFERENCES dw.dim_date(date_key),
    CONSTRAINT fk_sales_product  FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    CONSTRAINT fk_sales_store    FOREIGN KEY (store_key)   REFERENCES dw.dim_store(store_key)
);

-- ── Indexes for query performance ────────────────────────────────
CREATE NONCLUSTERED INDEX ix_fact_sales_date    ON dw.fact_sales(date_key);
CREATE NONCLUSTERED INDEX ix_fact_sales_product ON dw.fact_sales(product_key);
CREATE NONCLUSTERED INDEX ix_fact_sales_store   ON dw.fact_sales(store_key);
CREATE NONCLUSTERED INDEX ix_fact_sales_channel ON dw.fact_sales(channel);
GO

PRINT 'Data warehouse tables created successfully.';
GO
