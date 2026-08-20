# Silver Layer Documentation
This directory contains the SQL scripts required to clean, transform, and standardize data from the Bronze Layer into the Silver Layer for the Retail Promotion Intelligence project (based on the Dunnhumby - The Complete Journey dataset).

## Overview:
The Silver Layer acts as the cleansed, validated, and enterprise-ready data repository within the Medallion Architecture (Bronze ➔ Silver ➔ Gold).

- **Data Cleansing Strategy**: Data is extracted from raw staging tables (bronze), trimmed, strongly typed, deduplicated, and validated before being populated into silver tables.

- **Deduplication & Granularity Alignment**: Grouping logic (GROUP BY) removes duplicate records from source tables and aligns causal marketing events down to unique composite primary keys.

- **Missing Value Handling & Imputation**: Applies financial fallbacks (COALESCE to 0.00) and populates surrogate 'Unknown' placeholder records in demographics to enforce referential integrity across transactions.

- **Data Quality Flagging**: Creates dedicated indicator flags (`is_unknown_product`, `is_unknown_display_code`, `is_unknown_mailer_code`, `is_ambiguous_promotion`) to preserve edge cases without dropping valid transactions.

- **Bulk Load Performance**: Employs adaptive index management (dropping non-clustered indexes pre-load and rebuilding post-load) alongside WITH (TABLOCK) hints to maximize ETL insertion speeds.

- **Execution Logging**: Measures step-by-step load durations per table and logs execution details via SQL console output with `TRY...CATCH` exception handling.

## Directory Structure:

bronze/
```
├── 1_DDL Silver.sql                # DDL script to define cleansed silver tables, primary keys, and schema
├── 2_Procedure Load Silver.sql     # Stored procedure (silver.load_silver) for ETL transformation and load
└── Readme.md                       # Documentation for the silver folder
```

## Transformed Tables:
The schema defines 8 core tables cleansed and structured for analytics:

| **Table Name** | **Description** | **Columns** |
|---|----------|---|
| `silver.campaign_desc` | Cleansed metadata defining promotional campaign start and end dates. | `campaign`, `description`, `start_day`, `end_day` |
| `silver.campaign_table` | Cleansed mapping between target household accounts and specific campaigns. | `description`, `household_key`, `campaign` |
| `silver.causal_data` | Weekly product display/mailer placement per store with promotional quality flags. | `product_id`, `store_id`, `week_no`, `display`, `mailer`, `is_unknown_display_code`, `is_unknown_mailer_code`, `is_ambiguous_promotion` |
| `silver.coupon` | Cleansed coupon UPC barcode mappings to products and campaigns. | `coupon_upc`, `product_id`, `campaign` |
| `silver.coupon_redempt` | Deduplicated historical coupon redemption logs by households. | `household_key`, `day`, `coupon_upc`, `campaign` |
| `silver.hh_demographic` | Standardized household demographics with imputed unknown surrogate records. | `age_group`, `marital_status_group`, `income_level`, `homeownership_status`, `household_composition`, `household_size`, `kid_category`, `household_key` |
| `silver.product` | Standardized merchandise catalog with product quality flags. | `product_id`, `manufacturer`, `department`, `brand`, `commodity_desc`, `sub_commodity_desc`, `curr_size_of_product`, `is_unknown_product` |
| `silver.transaction_data` | Cleaned Point-Of-Sale transaction logs with non-null financial values.	| `household_key`, `basket_id`, `day`, `product_id`, `quantity`, `sales_value`, `store_id`, `retail_disc`, `trans_time`, `week_no`, `coupon_disc`, `coupon_match_disc` |

## Major Transformations Made:
Key data processing highlights applied during the Bronze ➔ Silver transition:

- **Type Casting & Sanitization**: Converted all raw text data into strict numeric (INT, BIGINT, SMALLINT, DECIMAL(10,2)) and boolean (BIT) types using TRY_CAST. Stripped leading and trailing whitespace using TRIM().

- **Primary Key Enforcement**: Consolidated raw duplicates across all tables using composite GROUP BY logic to guarantee primary key uniqueness.

- **Orphan Household Imputation**: Automatically inserted placeholder demographic records ('Unknown', 'U') for any transaction household_key absent from the raw demographic dataset.

- **Financial Metric Coalescing**: Handled missing discount and sales values by mapping NULL entries to 0.00.

- **Causal Feature Flags**: Resolved multi-coded promotional rows by assigning consolidated MAX() display/mailer values and flagging unknown or ambiguous promotion states.

## Execution Guide:
Raw CSV files downloaded and stored in a accessible local or network directory.

**Step 1: Create Tables (DDL)**
Ensure Bronze tables are populated before running the Silver transformations.<br>
**SQL**<br>
EXEC 1_DDL_Silver.sql;

**Step 2: Execute Data Load**
Execute the stored procedure to run the full ETL transformation from Bronze to Silver:<br>
**SQL**<br>
EXEC silver.load_silver;

**Step 3: Create Indexes**
Run the indexing script post-load to accelerate BI query performance across primary and foreign keys:<br>
**SQL**<br>
EXEC 3_Index_Gold.sql;