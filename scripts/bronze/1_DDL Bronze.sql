/*
==========================================================================
DDL Script: Create Bronze Tables
==========================================================================
Script Purpose:
	This script creates tables in the 'bronze' schema, dropping existing
	tables if they already exist.
	Run this script to redefine the DDL structure of 'bronze' Tables.
==========================================================================
*/

IF OBJECT_ID ('bronze.campaign_desc', 'U') IS NOT NULL
	DROP TABLE bronze.campaign_desc;
GO

CREATE TABLE bronze.campaign_desc (
	description  NVARCHAR(100),
	campaign     NVARCHAR(50),
	start_day       NVARCHAR(50),
	end_day         NVARCHAR(50)
);
GO

IF OBJECT_ID ('bronze.campaign_table', 'U') IS NOT NULL
	DROP TABLE bronze.campaign_table;
GO

CREATE TABLE bronze.campaign_table (
	description     NVARCHAR(100),
	household_key   NVARCHAR(50),
	campaign        NVARCHAR(50)
);
GO

IF OBJECT_ID ('bronze.causal_data', 'U') IS NOT NULL
	DROP TABLE bronze.causal_data;
GO

CREATE TABLE bronze.causal_data (
    product_id      NVARCHAR(50),
    store_id        NVARCHAR(50),
    week_no         NVARCHAR(50),
    display         NVARCHAR(50),
    mailer          NVARCHAR(50)
);
GO

IF OBJECT_ID ('bronze.coupon', 'U') IS NOT NULL
	DROP TABLE bronze.coupon;
GO

CREATE TABLE bronze.coupon (
    coupon_upc      NVARCHAR(50),
    product_id      NVARCHAR(50),
    campaign        NVARCHAR(50)
);
GO

IF OBJECT_ID ('bronze.coupon_redempt', 'U') IS NOT NULL
	DROP TABLE bronze.coupon_redempt;
GO

CREATE TABLE bronze.coupon_redempt (
    household_key   NVARCHAR(50),
    day             NVARCHAR(50),
    coupon_upc      NVARCHAR(50),
    campaign        NVARCHAR(50)
);
GO

IF OBJECT_ID ('bronze.hh_demographic', 'U') IS NOT NULL
	DROP TABLE bronze.hh_demographic;
GO

CREATE TABLE bronze.hh_demographic (
    age_group             VARCHAR(20),
    marital_status_group  CHAR(1),
    income_level          VARCHAR(20),
    homeownership_status  VARCHAR(30),
    household_composition VARCHAR(20),
    household_size        VARCHAR(10),
    kid_category          VARCHAR(20),
    household_key         INT
);
GO

IF OBJECT_ID ('bronze.product', 'U') IS NOT NULL
	DROP TABLE bronze.product;
GO

CREATE TABLE bronze.product (
    product_id              NVARCHAR(50),
    manufacturer            NVARCHAR(100),
    department              NVARCHAR(100),
    brand                   NVARCHAR(100),
    commodity_desc          NVARCHAR(200),
    sub_commodity_desc      NVARCHAR(200),
    curr_size_of_product    NVARCHAR(100)
);
GO

IF OBJECT_ID ('bronze.transaction_data', 'U') IS NOT NULL
	DROP TABLE bronze.transaction_data;
GO

CREATE TABLE bronze.transaction_data (
    household_key       NVARCHAR(50),
    basket_id           NVARCHAR(50),
    day                 NVARCHAR(50),
    product_id          NVARCHAR(50),
    quantity            NVARCHAR(50),
    sales_value         NVARCHAR(50),
    store_id            NVARCHAR(50),
    retail_disc         NVARCHAR(50),
    trans_time          NVARCHAR(50),
    week_no             NVARCHAR(50),
    coupon_disc         NVARCHAR(50),
    coupon_match_disc   NVARCHAR(50)
);
GO
