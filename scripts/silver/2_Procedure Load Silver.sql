/*
======================================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
======================================================================================
Script Purpose:
  	This stored procedure performs the ETL(Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
  Actions performed:
  	- Truncates Silver tables.
  	- Inserts transformed and cleaned data from Bronze into Silver table.

Parameters:
	  None.
    This stored procedure does not accept any parameters or return any value.

Usage Example:
	EXEC silver.load_silver;
======================================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS 
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===========================================================';
		PRINT 'Loading Silver Layer';
		PRINT '===========================================================';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.campaign_desc';
		TRUNCATE TABLE silver.campaign_desc;
	
		PRINT '>> Inserting Data into: silver.campaign_desc';
		INSERT INTO silver.campaign_desc (
			description,
			campaign,
			start_day,
			end_day
		)
		SELECT DISTINCT 
			TRIM(description) AS description,
			TRY_CAST(campaign AS SMALLINT) AS campaign,
			TRY_CAST(start_day AS SMALLINT) AS start_day,
			TRY_CAST(end_day AS SMALLINT) AS end_day
		FROM bronze.campaign_desc
		WHERE TRY_CAST(campaign AS SMALLINT) IS NOT NULL;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.campaign_table';
		TRUNCATE TABLE silver.campaign_table;

		PRINT '>> Inserting Data into: silver.campaign_table';
		INSERT INTO silver.campaign_table (
			description,
			household_key,
			campaign
		)
		SELECT DISTINCT
			TRIM(description) AS description,
			TRY_CAST(household_key AS INT) AS household_key,
			TRY_CAST(campaign AS SMALLINT) AS campaign 
		FROM bronze.campaign_table
		WHERE TRY_CAST(household_key AS INT) IS NOT NULL AND
			  TRY_CAST(campaign AS SMALLINT) IS NOT NULL;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.causal_data';
		TRUNCATE TABLE silver.causal_data;

		PRINT '>> Inserting Data into: silver.causal_data';
		INSERT INTO silver.causal_data (
			product_id,
			store_id,
			week_no,
			display,
			mailer,
			is_unknown_mailer_code
		)
		SELECT DISTINCT
			TRY_CAST(product_id AS INT) AS product_id,
			TRY_CAST(store_id AS INT) AS store_id,
			TRY_CAST(week_no AS SMALLINT) AS week_no,
			TRIM(display) AS display,
			TRIM(mailer) AS mailer,
			CASE 
				WHEN TRIM(mailer) = '0' THEN 1 
				ELSE 0 
			END AS is_unknown_mailer_code
		FROM bronze.causal_data
		WHERE TRY_CAST(product_id AS INT) IS NOT NULL AND
			  TRY_CAST(store_id AS INT) IS NOT NULL AND
			  TRY_CAST(week_no AS SMALLINT) IS NOT NULL;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.coupon';
		TRUNCATE TABLE silver.coupon;

		PRINT '>> Inserting Data into: silver.coupon';
		INSERT INTO silver.coupon (
			coupon_upc,
			product_id,
			campaign
		)
		SELECT DISTINCT
			TRIM(coupon_upc) AS coupon_upc,
			TRY_CAST(product_id AS INT) AS product_id,
			TRY_CAST(campaign AS SMALLINT) AS campaign
		FROM bronze.coupon
		WHERE TRY_CAST(product_id AS INT) IS NOT NULL AND 
			  TRY_CAST(campaign AS SMALLINT) IS NOT NULL;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.coupon_redempt';
		TRUNCATE TABLE silver.coupon_redempt;

		PRINT '>> Inserting Data into: silver.coupon_redempt';
		INSERT INTO silver.coupon_redempt (
			household_key,
			day,
			coupon_upc,
			campaign
		)
		SELECT DISTINCT
			TRY_CAST(household_key AS INT) AS household_key,
			TRY_CAST(day AS SMALLINT) AS day,
			TRIM(coupon_upc) AS coupon_upc,
			TRY_CAST(campaign AS SMALLINT) AS campaign
		FROM bronze.coupon_redempt
		WHERE TRY_CAST(household_key AS INT) IS NOT NULL AND
			  TRY_CAST(day AS SMALLINT) IS NOT NULL AND
			  TRY_CAST(campaign AS SMALLINT) IS NOT NULL;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.hh_demographic';
		TRUNCATE TABLE silver.hh_demographic;

		PRINT '>> Inserting Data into: silver.hh_demographic';
		INSERT INTO silver.hh_demographic (
			age_group,
			marital_status_group,
			income_level,
			homeownership_status,
			household_composition,
			household_size,
			kid_category,
			household_key
		)
		SELECT DISTINCT
			TRIM(age_group) AS age_group,
			TRIM(marital_status_group) AS marital_status_group,
			TRIM(income_level) AS income_level,
			TRIM(homeownership_status) AS homeownership_status,
			TRIM(household_composition) AS household_composition,
			TRIM(household_size) AS household_size,
			TRIM(kid_category) AS kid_category,
			household_key
		FROM bronze.hh_demographic;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.product';
		TRUNCATE TABLE silver.product;

		PRINT '>> Inserting Data into: silver.product';
		INSERT INTO silver.product (
			product_id,
			manufacturer,
			department,
			brand,
			commodity_desc,
			sub_commodity_desc,
			is_unknown_product,
			curr_size_of_product
		)
		SELECT DISTINCT
			TRY_CAST(product_id AS INT) AS product_id,
			TRY_CAST(manufacturer AS INT) AS manufacturer,
			TRIM(department) AS department,
			TRIM(brand) AS brand,
			TRIM(commodity_desc) AS commodity_desc,
			TRIM(sub_commodity_desc) AS sub_commodity_desc,
			CASE WHEN commodity_desc IN ('UNKNOWN', '', ' ') THEN 1 
				 ELSE 0 
			END AS is_unknown_product,
			TRIM(curr_size_of_product) AS curr_size_of_product
		FROM bronze.product
		WHERE TRY_CAST(product_id AS INT) IS NOT NULL AND
			  TRY_CAST(manufacturer AS INT) IS NOT NULL;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.transaction_data';
		TRUNCATE TABLE silver.transaction_data;

		PRINT '>> Inserting Data into: silver.transaction_data';
		INSERT INTO silver.transaction_data (
			household_key ,
			basket_id,
			day,
			product_id,
			quantity,
			sales_value,
			store_id,
			retail_disc,
			trans_time,
			week_no,
			coupon_disc,
			coupon_match_disc
		)
		SELECT 
			TRY_CAST(household_key AS INT),
			TRY_CAST(basket_id AS BIGINT),
			TRY_CAST(day AS SMALLINT),
			TRY_CAST(product_id AS INT),
			TRY_CAST(quantity AS INT),
			TRY_CAST(sales_value AS DECIMAL(10,2)),
			TRY_CAST(store_id AS INT),
			TRY_CAST(retail_disc AS DECIMAL(10,2)),
			TRY_CAST(trans_time AS SMALLINT),
			TRY_CAST(week_no AS SMALLINT),
			TRY_CAST(coupon_disc AS DECIMAL(10,2)),
			TRY_CAST(coupon_match_disc AS DECIMAL(10,2))
		FROM bronze.transaction_data
		WHERE TRY_CAST(household_key AS INT) IS NOT NULL AND 
			  TRY_CAST(basket_id AS BIGINT) IS NOT NULL AND 
			  TRY_CAST(product_id AS INT) IS NOT NULL AND 
			  TRY_CAST(store_id AS INT) IS NOT NULL;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Inserting Unknown placeholder rows into: silver.hh_demographic';
		INSERT INTO silver.hh_demographic (
			age_group,
			marital_status_group,
			income_level,
			homeownership_status,
			household_composition,
			household_size,
			kid_category,
			household_key
		)
		SELECT DISTINCT
			'Unknown',
			'U',
			'Unknown',
			'Unknown',
			'Unknown',
			'Unknown',
			'Unknown',
			t.household_key
		FROM silver.transaction_data t
		WHERE NOT EXISTS (
			SELECT 1 FROM silver.hh_demographic h
			WHERE h.household_key = t.household_key);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @batch_end_time = GETDATE();
		PRINT '===========================================================';
		PRINT 'Loading Silver Layer is completed';
		PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '===========================================================';
	END TRY
	BEGIN CATCH
		PRINT '===========================================================';
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '===========================================================';
	END CATCH
END
