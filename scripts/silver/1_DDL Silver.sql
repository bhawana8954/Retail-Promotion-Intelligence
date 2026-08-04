/*
==========================================================================
DDL Script: Create Silver Tables
==========================================================================
Script Purpose:
	This script creates tables in the 'silver' schema, dropping existing
	tables if they already exist.
	Run this script to redefine the DDL structure of 'silver' Tables.
==========================================================================
*/

IF OBJECT_ID ('silver.campaign_desc', 'U') IS NOT NULL
	DROP TABLE silver.campaign_desc;
GO

CREATE TABLE silver.campaign_desc (
	description      NVARCHAR(20),
	campaign         SMALLINT,
	start_day        SMALLINT,
	end_day          SMALLINT,
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID ('silver.campaign_table', 'U') IS NOT NULL
	DROP TABLE silver.campaign_table;
GO

CREATE TABLE silver.campaign_table (
	description      NVARCHAR(20),
	household_key    INT,
	campaign         SMALLINT,
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID ('silver.causal_data', 'U') IS NOT NULL
	DROP TABLE silver.causal_data;
GO

CREATE TABLE silver.causal_data (
    product_id              INT,
    store_id                INT,
    week_no                 SMALLINT,
    display                 CHAR(1),
    mailer                  CHAR(1),
    is_unknown_mailer_code  BIT NOT NULL DEFAULT 0,
    is_unknown_display_code BIT NOT NULL DEFAULT 0,
    is_ambiguous_promotion  BIT NOT NULL DEFAULT 0,
    dwh_create_date        DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID ('silver.coupon', 'U') IS NOT NULL
	DROP TABLE silver.coupon;
GO

CREATE TABLE silver.coupon (
    coupon_upc       VARCHAR(20),
    product_id       INT,
    campaign         SMALLINT,
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID ('silver.coupon_redempt', 'U') IS NOT NULL
	DROP TABLE silver.coupon_redempt;
GO

CREATE TABLE silver.coupon_redempt (
    household_key    INT,
    day              SMALLINT,
    coupon_upc       VARCHAR(20),
    campaign         SMALLINT,
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID ('silver.hh_demographic', 'U') IS NOT NULL
	DROP TABLE silver.hh_demographic;
GO

CREATE TABLE silver.hh_demographic (
    age_group             VARCHAR(20),
    marital_status_group  CHAR(1),
    income_level          VARCHAR(20),
    homeownership_status  VARCHAR(30),
    household_composition VARCHAR(20),
    household_size        VARCHAR(10),
    kid_category          VARCHAR(20),
    household_key         INT,
    dwh_create_date       DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID ('silver.product', 'U') IS NOT NULL
	DROP TABLE silver.product;
GO

CREATE TABLE silver.product (
    product_id              INT,
    manufacturer            INT,
    department              VARCHAR(50),
    brand                   VARCHAR(20),
    commodity_desc          NVARCHAR(100),
    sub_commodity_desc      NVARCHAR(100),
    is_unknown_product      BIT,
    curr_size_of_product    NVARCHAR(50),
    dwh_create_date         DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID ('silver.transaction_data', 'U') IS NOT NULL
	DROP TABLE silver.transaction_data;
GO

CREATE TABLE silver.transaction_data (
    household_key       INT,
    basket_id           BIGINT,
    day                 SMALLINT,
    product_id          INT,
    quantity            INT,
    sales_value         DECIMAL(10,2),
    store_id            INT,
    retail_disc         DECIMAL(10,2),
    trans_time          SMALLINT,
    week_no             SMALLINT,
    coupon_disc         DECIMAL(10,2),
    coupon_match_disc   DECIMAL(10,2),
    dwh_create_date     DATETIME2 DEFAULT GETDATE()
);
GO
