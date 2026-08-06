/*
======================================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
======================================================================================
Script Purpose:
	This stored procedure performs the ETL(Extract, Transform, Load) process to
	populate the 'silver' schema tables from the 'bronze' schema.
Actions performed:
	- Drops Non-Clustered Indexes to speed up bulk loading operations.
	- Truncates Silver tables.
	- Inserts transformed and cleaned data from Bronze into Silver tables.
	- Re-creates/Rebuilds Indexes for downstream query performance.

Parameters:
	None.
	This stored procedure does not accept any parameters or return any value.

Usage Example:
	EXEC silver.load_silver;
======================================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS 
BEGIN
	SET NOCOUNT ON;

	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;

	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===========================================================';
		PRINT 'Loading Silver Layer';
		PRINT '===========================================================';

		-- ===================================================================
		-- INDEX MANAGEMENT: PRE-LOAD (DROP NON-CLUSTERED INDEXES)
		-- ===================================================================
		PRINT '>> Dropping Non-Clustered Indexes for Faster Bulk Insertion...';

		IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_silver_transaction_household_key' AND object_id = OBJECT_ID('silver.transaction_data'))
			DROP INDEX IX_silver_transaction_household_key ON silver.transaction_data;

		IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_silver_coupon_redempt_household' AND object_id = OBJECT_ID('silver.coupon_redempt'))
			DROP INDEX IX_silver_coupon_redempt_household ON silver.coupon_redempt;

		IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_silver_hh_demographic_key' AND object_id = OBJECT_ID('silver.hh_demographic'))
			DROP INDEX IX_silver_hh_demographic_key ON silver.hh_demographic;

		PRINT '>> -------------';

		-- ===================================================================
		-- 1. silver.campaign_desc
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.campaign_desc';
		TRUNCATE TABLE silver.campaign_desc;
	
		PRINT '>> Inserting Data into: silver.campaign_desc';
		INSERT INTO silver.campaign_desc WITH (TABLOCK) (
			description,
			campaign,
			start_day,
			end_day
		)
		SELECT 
			TRIM(description) AS description,
			TRY_CAST(campaign AS SMALLINT) AS campaign,
			TRY_CAST(start_day AS SMALLINT) AS start_day,
			TRY_CAST(end_day AS SMALLINT) AS end_day
		FROM bronze.campaign_desc
		WHERE TRY_CAST(campaign AS SMALLINT) IS NOT NULL
		GROUP BY TRIM(description), TRY_CAST(campaign AS SMALLINT), TRY_CAST(start_day AS SMALLINT), TRY_CAST(end_day AS SMALLINT);

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- 2. silver.campaign_table
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.campaign_table';
		TRUNCATE TABLE silver.campaign_table;

		PRINT '>> Inserting Data into: silver.campaign_table';
		INSERT INTO silver.campaign_table WITH (TABLOCK) (
			description,
			household_key,
			campaign
		)
		SELECT 
			TRIM(description) AS description,
			TRY_CAST(household_key AS INT) AS household_key,
			TRY_CAST(campaign AS SMALLINT) AS campaign 
		FROM bronze.campaign_table
		WHERE TRY_CAST(household_key AS INT) IS NOT NULL 
		  AND TRY_CAST(campaign AS SMALLINT) IS NOT NULL
		GROUP BY TRIM(description), TRY_CAST(household_key AS INT), TRY_CAST(campaign AS SMALLINT);

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- 3. silver.causal_data
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.causal_data';
		TRUNCATE TABLE silver.causal_data;

		PRINT '>> Inserting Data into: silver.causal_data';
		
		;WITH CastedCausal AS (
			SELECT
				TRY_CAST(product_id AS INT) AS product_id,
				TRY_CAST(store_id AS INT) AS store_id,
				TRY_CAST(week_no AS SMALLINT) AS week_no,
				CASE WHEN TRIM(display) <> '0' THEN TRIM(display) END AS display,
				CASE WHEN TRIM(mailer) <> '0' THEN TRIM(mailer) END AS mailer
			FROM bronze.causal_data
		)
		INSERT INTO silver.causal_data WITH (TABLOCK) (
			product_id,
			store_id,
			week_no,
			display,
			mailer,
			is_unknown_display_code,
			is_unknown_mailer_code,
			is_ambiguous_promotion
		)
		SELECT
			product_id,
			store_id,
			week_no,
			ISNULL(MAX(display), '0') AS display,
			ISNULL(MAX(mailer), '0') AS mailer,
			CASE WHEN MAX(display) IS NULL THEN 1 ELSE 0 END AS is_unknown_display_code,
			CASE WHEN MAX(mailer) IS NULL THEN 1 ELSE 0 END AS is_unknown_mailer_code,
			CASE WHEN COUNT(DISTINCT display) > 1 OR COUNT(DISTINCT mailer) > 1 THEN 1 ELSE 0 END AS is_ambiguous_promotion
		FROM CastedCausal
		WHERE product_id IS NOT NULL 
		  AND store_id IS NOT NULL 
		  AND week_no IS NOT NULL
		GROUP BY product_id, store_id, week_no;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- 4. silver.coupon
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.coupon';
		TRUNCATE TABLE silver.coupon;

		PRINT '>> Inserting Data into: silver.coupon';
		INSERT INTO silver.coupon WITH (TABLOCK) (
			coupon_upc,
			product_id,
			campaign
		)
		SELECT 
			TRIM(coupon_upc) AS coupon_upc,
			TRY_CAST(product_id AS INT) AS product_id,
			TRY_CAST(campaign AS SMALLINT) AS campaign
		FROM bronze.coupon
		WHERE TRY_CAST(product_id AS INT) IS NOT NULL 
		  AND TRY_CAST(campaign AS SMALLINT) IS NOT NULL
		GROUP BY TRIM(coupon_upc), TRY_CAST(product_id AS INT), TRY_CAST(campaign AS SMALLINT);

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- 5. silver.coupon_redempt
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.coupon_redempt';
		TRUNCATE TABLE silver.coupon_redempt;

		PRINT '>> Inserting Data into: silver.coupon_redempt';
		INSERT INTO silver.coupon_redempt WITH (TABLOCK) (
			household_key,
			day,
			coupon_upc,
			campaign
		)
		SELECT 
			TRY_CAST(household_key AS INT) AS household_key,
			TRY_CAST(day AS SMALLINT) AS day,
			TRIM(coupon_upc) AS coupon_upc,
			TRY_CAST(campaign AS SMALLINT) AS campaign
		FROM bronze.coupon_redempt
		WHERE TRY_CAST(household_key AS INT) IS NOT NULL 
		  AND TRY_CAST(day AS SMALLINT) IS NOT NULL 
		  AND TRY_CAST(campaign AS SMALLINT) IS NOT NULL
		GROUP BY TRY_CAST(household_key AS INT), TRY_CAST(day AS SMALLINT), TRIM(coupon_upc), TRY_CAST(campaign AS SMALLINT);

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- 6. silver.hh_demographic
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.hh_demographic';
		TRUNCATE TABLE silver.hh_demographic;

		PRINT '>> Inserting Data into: silver.hh_demographic';
		INSERT INTO silver.hh_demographic WITH (TABLOCK) (
			age_group,
			marital_status_group,
			income_level,
			homeownership_status,
			household_composition,
			household_size,
			kid_category,
			household_key
		)
		SELECT 
			TRIM(age_group) AS age_group,
			TRIM(marital_status_group) AS marital_status_group,
			TRIM(income_level) AS income_level,
			TRIM(homeownership_status) AS homeownership_status,
			TRIM(household_composition) AS household_composition,
			TRIM(household_size) AS household_size,
			TRIM(kid_category) AS kid_category,
			household_key
		FROM bronze.hh_demographic
		GROUP BY 
			TRIM(age_group), TRIM(marital_status_group), TRIM(income_level), 
			TRIM(homeownership_status), TRIM(household_composition), 
			TRIM(household_size), TRIM(kid_category), household_key;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- 7. silver.product
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.product';
		TRUNCATE TABLE silver.product;

		PRINT '>> Inserting Data into: silver.product';
		INSERT INTO silver.product WITH (TABLOCK) (
			product_id,
			manufacturer,
			department,
			brand,
			commodity_desc,
			sub_commodity_desc,
			is_unknown_product,
			curr_size_of_product
		)
		SELECT 
			TRY_CAST(product_id AS INT) AS product_id,
			TRY_CAST(manufacturer AS INT) AS manufacturer,
			TRIM(department) AS department,
			TRIM(brand) AS brand,
			TRIM(commodity_desc) AS commodity_desc,
			TRIM(sub_commodity_desc) AS sub_commodity_desc,
			CASE WHEN TRIM(commodity_desc) IN ('UNKNOWN', '', ' ') OR TRIM(commodity_desc) IS NULL THEN 1 ELSE 0 END AS is_unknown_product,
			TRIM(curr_size_of_product) AS curr_size_of_product
		FROM bronze.product
		WHERE TRY_CAST(product_id AS INT) IS NOT NULL 
		  AND TRY_CAST(manufacturer AS INT) IS NOT NULL
		GROUP BY 
			TRY_CAST(product_id AS INT), TRY_CAST(manufacturer AS INT), TRIM(department), TRIM(brand), 
			TRIM(commodity_desc), TRIM(sub_commodity_desc), TRIM(curr_size_of_product);

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- 8. silver.transaction_data
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.transaction_data';
		TRUNCATE TABLE silver.transaction_data;

		PRINT '>> Inserting Data into: silver.transaction_data';
		INSERT INTO silver.transaction_data WITH (TABLOCK) (
			household_key,
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
			TRY_CAST(household_key AS INT) AS household_key,
			TRY_CAST(basket_id AS BIGINT) AS basket_id,
			TRY_CAST(day AS SMALLINT) AS day,
			TRY_CAST(product_id AS INT) AS product_id,
			TRY_CAST(quantity AS INT) AS quantity,
			COALESCE(TRY_CAST(sales_value AS DECIMAL(10,2)), 0) AS sales_value,
			TRY_CAST(store_id AS INT) AS store_id,
			COALESCE(TRY_CAST(retail_disc AS DECIMAL(10,2)), 0) AS retail_disc,
			TRY_CAST(trans_time AS SMALLINT) AS trans_time,
			TRY_CAST(week_no AS SMALLINT) AS week_no,
			TRY_CAST(coupon_disc AS DECIMAL(10,2)) AS coupon_disc,
			TRY_CAST(coupon_match_disc AS DECIMAL(10,2)) AS coupon_match_disc
		FROM bronze.transaction_data
		WHERE TRY_CAST(household_key AS INT) IS NOT NULL 
		  AND TRY_CAST(basket_id AS BIGINT) IS NOT NULL 
		  AND TRY_CAST(product_id AS INT) IS NOT NULL 
		  AND TRY_CAST(store_id AS INT) IS NOT NULL;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- 9. Insert Unknown placeholder rows into silver.hh_demographic
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Inserting Unknown placeholder rows into: silver.hh_demographic';

		INSERT INTO silver.hh_demographic WITH (TABLOCK) (
			age_group,
			marital_status_group,
			income_level,
			homeownership_status,
			household_composition,
			household_size,
			kid_category,
			household_key
		)
		SELECT 
			'Unknown',
			'U',
			'Unknown',
			'Unknown',
			'Unknown',
			'Unknown',
			'Unknown',
			t.household_key
		FROM (
			SELECT household_key 
			FROM silver.transaction_data 
			WHERE household_key IS NOT NULL
			GROUP BY household_key
		) t
		WHERE NOT EXISTS (
			SELECT 1 
			FROM silver.hh_demographic h 
			WHERE h.household_key = t.household_key
		);

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- INDEX MANAGEMENT: POST-LOAD (RECREATE NON-CLUSTERED INDEXES)
		-- ===================================================================
		SET @start_time = GETDATE();
		PRINT '>> Rebuilding Non-Clustered Indexes for Downstream Performance...';

		CREATE NONCLUSTERED INDEX IX_silver_hh_demographic_key 
		ON silver.hh_demographic (household_key);

		CREATE NONCLUSTERED INDEX IX_silver_transaction_household_key 
		ON silver.transaction_data (household_key) 
		INCLUDE (product_id, sales_value);

		CREATE NONCLUSTERED INDEX IX_silver_coupon_redempt_household 
		ON silver.coupon_redempt (household_key);

		SET @end_time = GETDATE();
		PRINT '>> Index Creation Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===================================================================
		-- SUMMARY LOGGING
		-- ===================================================================
		SET @batch_end_time = GETDATE();
		PRINT '===========================================================';
		PRINT 'Loading Silver Layer is completed';
		PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '===========================================================';
	END TRY
	BEGIN CATCH
		PRINT '===========================================================';
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		PRINT 'Error Number: '  + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State: '   + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '===========================================================';
	END CATCH
END;