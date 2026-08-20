/*
==========================================================================
DDL Script: Create Gold Layer
==========================================================================
Script Purpose:
	This script creates tables in the 'gold' schema, dropping existing
	tables if they already exist.
	Run this script to redefine the DDL structure of 'gold' Tables.
==========================================================================
*/

IF OBJECT_ID ('gold.dim_date', 'U') IS NOT NULL
	DROP TABLE gold.dim_date;
GO

CREATE TABLE gold.dim_date (
    date_key        INT             PRIMARY KEY,               
    full_date       DATE            NOT NULL,                
    day_no          INT             NOT NULL,              
    week_no         SMALLINT        NOT NULL,              
    month_no        TINYINT         NOT NULL,              
    month_name      VARCHAR(20)     NOT NULL,        
    quarter         VARCHAR(2)      NOT NULL,            
    year            INT             NOT NULL,                      
    day_name        VARCHAR(20)     NOT NULL,          
    is_weekend      BIT             NOT NULL                 
);
GO

IF OBJECT_ID ('gold.dim_household', 'U') IS NOT NULL
	DROP TABLE gold.dim_household;
GO

CREATE TABLE gold.dim_household (
    household_key           INT             PRIMARY KEY,
    age_group               VARCHAR(20)     NOT NULL,
    marital_status          VARCHAR(20)     NOT NULL,
    income_level            VARCHAR(30)     NOT NULL,
    homeownership_status    VARCHAR(30)     NOT NULL,
    household_composition   VARCHAR(30)     NOT NULL,
    household_size          VARCHAR(20)     NOT NULL,
    kid_category            VARCHAR(20)     NOT NULL,
    is_unknown_household    BIT             NOT NULL
);
GO

IF OBJECT_ID ('gold.dim_product', 'U') IS NOT NULL
	DROP TABLE gold.dim_product;
GO

CREATE TABLE gold.dim_product (
    product_id              INT             PRIMARY KEY,
    manufacturer            INT             NOT NULL,
    department              VARCHAR(50)     NOT NULL,
    brand                   VARCHAR(30)     NOT NULL,
    commodity_desc          VARCHAR(50)     NOT NULL,
    sub_commodity_desc      VARCHAR(50)     NOT NULL,
    curr_size_of_product    VARCHAR(30)     NOT NULL,
    is_catchall_category    BIT             NOT NULL,        
    is_unknown_product      BIT             NOT NULL           
);
GO

IF OBJECT_ID ('gold.dim_campaign', 'U') IS NOT NULL
	DROP TABLE gold.dim_campaign;
GO

CREATE TABLE gold.dim_campaign (
    campaign_id     SMALLINT        PRIMARY KEY,
    campaign_type   VARCHAR(20)     NOT NULL,
    start_day       INT             NOT NULL,
    end_day         INT             NOT NULL,
    start_date      DATE            NOT NULL,
    end_date        DATE            NOT NULL,
    duration_days   INT             NOT NULL
);
GO

IF OBJECT_ID ('gold.dim_store', 'U') IS NOT NULL
	DROP TABLE gold.dim_store;
GO

CREATE TABLE gold.dim_store (
    store_id    INT     PRIMARY KEY
);
GO

IF OBJECT_ID ('gold.dim_coupon', 'U') IS NOT NULL
	DROP TABLE gold.dim_coupon;
GO

CREATE TABLE gold.dim_coupon (
    coupon_upc      VARCHAR(20)     NOT NULL,
    product_id      INT             NOT NULL,
    campaign_id     SMALLINT        NOT NULL,
    campaign_type   VARCHAR(20)     NOT NULL,
    PRIMARY KEY (coupon_upc, product_id, campaign_id)
);
GO

IF OBJECT_ID ('gold.fact_transactions', 'U') IS NOT NULL
	DROP TABLE gold.fact_transactions;
GO

CREATE TABLE gold.fact_transactions (
    transaction_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    date_key            INT             NOT NULL,                  
    household_key       INT             NOT NULL,             
    basket_id           BIGINT          NOT NULL,              
    day_number          INT             NOT NULL,           
    product_id          INT             NOT NULL,                
    store_id            INT             NOT NULL,                  
    trans_time          INT             NOT NULL,           
    week_no             SMALLINT        NOT NULL,              
    quantity            INT             NOT NULL,                  
    sales_value         DECIMAL(10,2)   NOT NULL,     
    retail_disc         DECIMAL(10,2)   NOT NULL,     
    coupon_disc         DECIMAL(10,2)   NOT NULL,     
    coupon_match_disc   DECIMAL(10,2)   NOT NULL
);
GO

IF OBJECT_ID ('gold.fact_coupon_redemption', 'U') IS NOT NULL
	DROP TABLE gold.fact_coupon_redemption;
GO

CREATE TABLE gold.fact_coupon_redemption (
    redemption_key BIGINT IDENTITY(1,1) PRIMARY KEY,
    redemption_event_key    VARCHAR(60)     NOT NULL,   -- household+day+coupon+campaign; NOT unique — repeats when one coupon maps to several products
    date_key                INT             NOT NULL,                  
    household_key           INT             NOT NULL,             
    day_number              INT             NOT NULL,           
    coupon_upc              VARCHAR(20)     NOT NULL,        
    campaign_id             SMALLINT        NOT NULL,          
    product_id              INT             NOT NULL,                    
    campaign_type           VARCHAR(20)     NOT NULL      
);
GO

IF OBJECT_ID ('gold.fact_executive_daily_summary', 'U') IS NOT NULL
	DROP TABLE gold.fact_executive_daily_summary;
GO

CREATE TABLE gold.fact_executive_daily_summary (
    date_key                        INT             PRIMARY KEY,                       
    actual_sales_amount             DECIMAL(18,2)   NOT NULL,      
    behavioral_baseline_amount      DECIMAL(18,2)   NOT NULL, 
    coupon_discount_amount          DECIMAL(18,2)   NOT NULL,  
    instore_discount_amount         DECIMAL(18,2)   NOT NULL, 
    total_discount_amount           DECIMAL(18,2)   NOT NULL,   
    wasted_spend_floored_amount     DECIMAL(18,2)   NOT NULL 
);

IF OBJECT_ID ('gold.fact_campaign_lift', 'U') IS NOT NULL
	DROP TABLE gold.fact_campaign_lift;
GO

CREATE TABLE gold.fact_campaign_lift (
    lift_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    household_key               INT             NOT NULL,                     
    category                    VARCHAR(50)     NOT NULL,                  
    baseline_spend              DECIMAL(18,2)   NOT NULL,          
    baseline_days               INT             NOT NULL,                     
    campaign_spend              DECIMAL(18,2)   NOT NULL,          
    campaign_days               INT             NOT NULL,                     
    baseline_spend_per_day      DECIMAL(10,2)   NOT NULL,  
    campaign_spend_per_day      DECIMAL(10,2)   NOT NULL,  
    lift_per_day                DECIMAL(10,2)   NOT NULL,            
    is_catchall_category        BIT             NOT NULL,              
    is_reliable_pair            BIT             NOT NULL                   
);

IF OBJECT_ID ('gold.fact_campaign_category_lift', 'U') IS NOT NULL
	DROP TABLE gold.fact_campaign_category_lift;
GO

CREATE TABLE gold.fact_campaign_category_lift (
    campaign_id                   SMALLINT          NOT NULL,
    commodity_desc                VARCHAR(50)       NOT NULL,
    coupons_distributed           INT               NOT NULL,
    coupons_redeemed              INT               NOT NULL, 
    actual_sales                  DECIMAL(12,2)     NOT NULL,
    behavioral_baseline_sales     DECIMAL(12,2)     NOT NULL,
    discount_spend                DECIMAL(12,2)     NOT NULL,
    incremental_lift              DECIMAL(12,2)     NOT NULL,
    PRIMARY KEY(campaign_id, commodity_desc)
);

IF OBJECT_ID ('gold.fact_store_promo_lift', 'U') IS NOT NULL
	DROP TABLE gold.fact_store_promo_lift;
GO

CREATE TABLE gold.fact_store_promo_lift (
    store_promo_lift_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    date_key                    INT             NOT NULL,                         
    store_id                    INT             NOT NULL,                          
    commodity_desc              VARCHAR(50)     NOT NULL,            
    display_flag                CHAR(1)         NOT NULL,                  
    mailer_flag                 CHAR(1)         NOT NULL,                   
    is_unknown_mailer_flag      BIT             NOT NULL,
    is_causal_tracked           BIT             NOT NULL,
    promo_combination_type      VARCHAR(20)     NOT NULL,    
    actual_sales                DECIMAL(18,2)   NOT NULL,            
    units_sold                  INT             NOT NULL                         
);

IF OBJECT_ID ('gold.fact_household_segment_lift', 'U') IS NOT NULL
	DROP TABLE gold.fact_household_segment_lift;
GO

CREATE TABLE gold.fact_household_segment_lift (
    household_segment_lift_id   BIGINT IDENTITY(1,1) PRIMARY KEY,
    household_key               INT             NOT NULL,                     
    campaign_id                 SMALLINT        NOT NULL,                  
    total_spend                 DECIMAL(18,2)   NOT NULL,             
    behavioral_baseline_spend   DECIMAL(18,2)   NOT NULL,
    total_discount_received     DECIMAL(18,2)   NOT NULL, 
    incremental_lift            DECIMAL(18,2)   NOT NULL         
);