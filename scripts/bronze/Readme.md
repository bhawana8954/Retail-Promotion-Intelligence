# Bronze Layer Documentation
This directory contains the SQL scripts required to set up and populate the Bronze Layer of the data warehouse architecture for the Retail Promotion Intelligence project (based on the dunnhumby - The Complete Journey dataset).

## Overview:
The Bronze Layer acts as the raw landing zone for incoming data.

- **Data Strategy**: Ingestion follows a Full Load (Truncate & Load) pattern.

- **Schema Integrity**: Data is ingested "as-is" from external CSV sources with minimal data type transformations to ensure high load performance and raw data retention.

- **Dynamic Paths**: The ingestion stored procedure accepts a base folder path as a parameter, avoiding hardcoded file paths across different local or server environments.

- **Execution Logging**: Execution duration per table and total batch execution metrics are logged directly to the SQL console with error handling via TRY...CATCH.

## Directory Structure:

bronze/
```
├── 1_DDL_bronze.sql                # DDL script to create/redefine bronze tables
├── 2_procedure_load_bronze.sql     # Stored procedure to bulk load raw data from CSVs
└── Readme.md                       # Documentation for the bronze folder
```

## Ingested Tables:
The schema defines 8 core tables capturing retail promotions, demographics, products, and transactional events:

| **Table Name** | **Description** | **Columns** |
|---|----------|---|
| `bronze.campaign_desc` | Metadata defining promotional campaign start and end dates. | `description`, `campaign`, `start_day`, `end_day` |
| `bronze.campaign_table` | Mapping between household accounts and specific campaigns. | `description`, `household_key`, `campaign` |
| `bronze.causal_data` | Display and mailer promotion placement per store/week. | `product_id`, `store_id`, `week_no`, `display`, `mailer` |
| `bronze.coupon` | Links coupon UPC identifiers to product IDs and campaigns | `coupon_upc`, `product_id`, `campaign` |
| `bronze.coupon_redempt` | Historical redemption events of coupons by households. | `household_key`, `day`, `coupon_upc`, `campaign` |
| `bronze.hh_demographic` | Household demographics (income, size, age, ownership). | `age_group`, `marital_status_group`, `income_level`, `homeownership_status`, `household_composition`, `household_size`, `kid_category`, `household_key` |
| `bronze.product` | Product hierarchy, manufacturer, department, and branding. | `product_id`, `manufacturer`, `department`, `brand`, `commodity_desc`, `sub_commodity_desc`, `curr_size_of_product` |
| `bronze.transaction_data` | Transaction logs (sales, discounts, quantity, store).	| `household_key`, `basket_id`, `day`, `product_id`, `quantity`, `sales_value`, `store_id`, `retail_disc`, `trans_time`, `week_no`, `coupon_disc`, `coupon_match_disc` |

## Execution Guide
Raw CSV files downloaded and stored in a accessible local or network directory.

**Step 1: Create Tables (DDL)**
Run ddl_bronze.sql to drop (if existing) and recreate all Bronze tables:<br>
**SQL**<br>
EXEC 1_DDL_bronze.sql;

**Step 2: Create/Deploy the Bronze Load Procedure**
Execute the SQL script containing the bronze.load_bronze stored procedure. This creates or updates the procedure in the database.<br>
**SQL**<br>
EXEC 2_procedure_load_bronze.sql;

**Step 3: Execute Data Load**
Execute the stored procedure by passing your local directory path using @base_path:<br>
**SQL**<br>
EXEC bronze.load_bronze 
    @base_path = 'C:\Users\bhawa\OneDrive\Desktop\Dunnhumby- The Complete Journey Project\Retail-Promotion-Intelligence\dataset\'; --(e.g.)