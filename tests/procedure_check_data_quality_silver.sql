/*
======================================================================================
Stored Procedure: Check Data Quality (Silver Layer)
======================================================================================
Script Purpose:
	Runs data quality checks against the 'silver' schema tables:
		- NULL checks on required columns
		- Duplicate key checks
		- Referential integrity checks
		- Data validity and flag consistency checks
		- Grain and join-safety checks
	Prints a PASS/FAIL for each DQ check, plus informational notes and a final summary.

Usage Example:
	EXEC silver.check_data_quality;
======================================================================================
*/

CREATE OR ALTER PROCEDURE silver.check_data_quality AS 
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	DECLARE @fail_count INT = 0;
	DECLARE @check_count INT = 0;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===============================================================';
		PRINT 'Running Silver Layer Data Quality Checks';
		PRINT '===============================================================';

		-- ===============================================================
		-- Checking Table: silver.campaign_desc
		-- ===============================================================
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.campaign_desc';

		-- Check 1: Required columns must not contain NULL
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.campaign_desc
				  WHERE campaign IS NULL OR
						description IS NULL OR
						start_day IS NULL OR 
						end_day IS NULL
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULLs found in required columns';
		END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

		-- Check 2: Description must not be blank
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.campaign_desc
				   WHERE NULLIF(TRIM(description), '') IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: blank or whitespace-only descriptions found';
		END
		ELSE
			PRINT 'PASS: no blank descriptions';
		
		-- Check 3: Campaign must be unique
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.campaign_desc
				  GROUP BY campaign HAVING COUNT(*) > 1
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate keys on (campaign)';
		END
		ELSE
			PRINT 'PASS: no duplicate keys on (campaign)';

		-- Check 4: Campaign window must be logically valid
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.campaign_desc
				   WHERE start_day > end_day
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: start_day is greater than end_day';
		END
		ELSE
			PRINT 'PASS: campaign date windows are valid';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===============================================================
		-- Checking Table: silver.campaign_table
		-- ===============================================================
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.campaign_table';
		
		-- Check 1: Required columns must not contain NULL
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.campaign_table
				  WHERE household_key IS NULL OR
						campaign IS NULL 
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULLs found in required columns';
		END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

		-- Check 2: Description must not be blank
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.campaign_table
				   WHERE NULLIF(TRIM(description), '') IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: blank or whitespace-only descriptions found';
		END
		ELSE
			PRINT 'PASS: no blank descriptions';

		-- Check 3: Household-campaign combination must be unique
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.campaign_table
				  GROUP BY household_key, campaign HAVING COUNT(*) > 1
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate keys on (household_key, campaign)';
		END
		ELSE
			PRINT 'PASS: no duplicate keys on (household_key, campaign)';

		-- Check 4: Campaign must exist in silver.campaign_desc
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.campaign_table AS c
				  LEFT JOIN silver.campaign_desc AS p ON c.campaign = p.campaign
				  WHERE c.campaign IS NOT NULL AND p.campaign IS NULL
				 )
		BEGIN 
		SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: campaign values missing from silver.campaign_desc';
		END
		ELSE
			PRINT 'PASS: campaign — referential integrity OK';

		-- Check 5: Household_key must exist in silver.hh_demographic
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.campaign_table AS c
				  LEFT JOIN silver.hh_demographic AS p ON c.household_key = p.household_key
				  WHERE c.household_key IS NOT NULL AND p.household_key IS NULL
				 )
		BEGIN 
		SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: household_key values missing from silver.hh_demographic';
		END
		ELSE
			PRINT 'PASS: household_key — referential integrity OK';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===============================================================
		-- Checking Table: silver.coupon
		-- ===============================================================
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.coupon';

		-- Check 1: Required columns must not contain NULL
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon
				  WHERE coupon_upc IS NULL OR
						product_id IS NULL OR
						campaign IS NULL 
				 )
		BEGIN 
		SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULLs found in required columns';
		END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

		-- Check 2: Coupon UPC must not be blank
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.coupon
				   WHERE NULLIF(TRIM(coupon_upc), '') IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: blank or whitespace-only coupon_upc values found';
		END
		ELSE
			PRINT 'PASS: no blank coupon_upc values';

		-- Check 3: Coupon key must be unique
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon
				  GROUP BY coupon_upc, campaign, product_id HAVING COUNT(*) > 1
				 )
		BEGIN 
		SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate keys on (coupon_upc, campaign, product_id)';
		END
		ELSE
			PRINT 'PASS: no duplicate keys on (coupon_upc, campaign, product_id)';

		-- Check 4: Product must exist in silver.product
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.coupon AS c
				   LEFT JOIN silver.product AS p ON c.product_id = p.product_id
				   WHERE c.product_id IS NOT NULL AND p.product_id IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: product_id values missing from silver.product';
		END
		ELSE
			PRINT 'PASS: product_id — referential integrity OK';

		-- Check 5: Campaign must exist in silver.campaign_desc
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon AS c
				  LEFT JOIN silver.campaign_desc AS p ON c.campaign = p.campaign
				  WHERE c.campaign IS NOT NULL AND p.campaign IS NULL
				 )
		BEGIN 
		SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: campaign values missing from silver.campaign_desc';
		END
		ELSE
			PRINT 'PASS: campaign — referential integrity OK';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===============================================================
		-- Checking Table: silver.coupon_redempt
		-- ===============================================================
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.coupon_redempt';

		-- Check 1: Required columns must not contain NULL
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon_redempt
				  WHERE household_key IS NULL OR day IS NULL OR coupon_upc IS NULL OR campaign IS NULL 
				 )
		BEGIN 
		SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULLs found in required columns';
		END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

		-- Check 2: Coupon UPC must not be blank
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.coupon_redempt
				   WHERE NULLIF(TRIM(coupon_upc), '') IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: blank or whitespace-only coupon_upc values found';
		END
		ELSE
			PRINT 'PASS: no blank coupon_upc values';

		-- Check 3: Redemption key must be unique
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon_redempt
				  GROUP BY household_key, coupon_upc, campaign, day HAVING COUNT(*) > 1
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate keys on (household_key, coupon_upc, campaign, day)';
		END
		ELSE
			PRINT 'PASS: no duplicate keys on (household_key, coupon_upc, campaign, day)';

		-- Check 4: Campaign must exist in silver.campaign_desc
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon_redempt AS c
				  LEFT JOIN silver.campaign_desc AS p ON c.campaign = p.campaign
				  WHERE c.campaign IS NOT NULL AND p.campaign IS NULL
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: campaign values missing from silver.campaign_desc';
		END
		ELSE
			PRINT 'PASS: campaign — referential integrity OK';

		-- Check 5: Household must exist in silver.hh_demographic
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon_redempt AS c
				  LEFT JOIN silver.hh_demographic AS p ON c.household_key = p.household_key
				  WHERE c.household_key IS NOT NULL AND p.household_key IS NULL
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: household_key values missing from silver.hh_demographic';
		END
		ELSE
			PRINT 'PASS: household_key — referential integrity OK';

		-- Check 6: Coupon UPC + campaign must exist in silver.coupon
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon_redempt AS c
				  LEFT JOIN (SELECT DISTINCT coupon_upc, campaign FROM silver.coupon) AS p 
				  ON c.coupon_upc = p.coupon_upc AND c.campaign = p.campaign
				  WHERE c.coupon_upc IS NOT NULL AND c.campaign IS NOT NULL AND p.coupon_upc IS NULL
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: coupon_upc + campaign combinations missing from silver.coupon';
		END
		ELSE
			PRINT 'PASS: coupon_upc + campaign — referential integrity OK';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===============================================================
		-- Checking Table: silver.hh_demographic
		-- ===============================================================
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.hh_demographic';

		-- Check 1: Required demographic attributes must not be NULL
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.hh_demographic
				  WHERE household_key IS NULL OR 
						age_group IS NULL OR 
						marital_status_group IS NULL OR 
						income_level IS NULL OR 
						homeownership_status IS NULL OR 
						household_composition IS NULL OR 
						household_size IS NULL OR 
						kid_category IS NULL
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULLs found in demographic attributes';
		END
		ELSE
			PRINT 'PASS: no NULLs in demographic attributes';

		-- Check 2: Household key must be unique
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.hh_demographic
				  GROUP BY household_key HAVING COUNT(*) > 1
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate keys on (household_key)';
		END
		ELSE
			PRINT 'PASS: no duplicate keys on (household_key)';

		-- Check 3: All transaction households must exist in hh_demographic
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.transaction_data AS t
				   LEFT JOIN silver.hh_demographic AS h ON t.household_key = h.household_key
				   WHERE t.household_key IS NOT NULL AND h.household_key IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: transaction household_key values missing from silver.hh_demographic';
		END
		ELSE
			PRINT 'PASS: transaction household_key — referential integrity OK';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
		-- ===============================================================
		-- Checking Table: silver.product
		-- ===============================================================
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.product';

		-- Check 1: Required columns must not contain NULL
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.product
				  WHERE product_id IS NULL OR manufacturer IS NULL
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULLs found in required columns';
		END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

		-- Check 2: Product ID must be unique
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.product
				  GROUP BY product_id HAVING COUNT(*) > 1
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate keys on (product_id)';
		END
		ELSE
			PRINT 'PASS: no duplicate keys on (product_id)';

		-- Check 3: is_unknown_product must contain only 0 or 1
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.product
				   WHERE is_unknown_product NOT IN (0, 1) OR is_unknown_product IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: invalid values found in is_unknown_product';
		END
		ELSE
			PRINT 'PASS: is_unknown_product contains only valid flag values';

		-- Check 4: is_unknown_product flag must match commodity_desc
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.product
				   WHERE((NULLIF(TRIM(commodity_desc), '') IS NULL OR 
						  UPPER(TRIM(commodity_desc)) = 'UNKNOWN') AND 
						  is_unknown_product <> 1)
						 OR
						 (NULLIF(TRIM(commodity_desc), '') IS NOT NULL AND 
						  UPPER(TRIM(commodity_desc)) <> 'UNKNOWN' AND 
						  is_unknown_product <> 0))
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: is_unknown_product flag inconsistent with commodity_desc';
		END
		ELSE
			PRINT 'PASS: is_unknown_product — flag consistency OK';

		-- Check 5: Product IDs used in transaction_data must exist in product
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.transaction_data AS t
				   LEFT JOIN silver.product AS p ON t.product_id = p.product_id
				   WHERE t.product_id IS NOT NULL AND p.product_id IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: product_id values missing from silver.product for transaction_data';
		END
		ELSE
			PRINT 'PASS: transaction_data product_id — referential integrity OK';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ===============================================================
		-- Checking Table: silver.causal_data
		-- ===============================================================
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.causal_data';

		-- Check 1: Required columns must not contain NULL
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.causal_data
				  WHERE product_id IS NULL OR
						week_no IS NULL OR
						store_id IS NULL 
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULLs found in required columns';
		END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

		-- Check 2: Display and mailer must not be NULL or blank
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.causal_data
				   WHERE NULLIF(TRIM(display), '') IS NULL OR NULLIF(TRIM(mailer), '') IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULL or blank display/mailer values found';
		END
		ELSE
			PRINT 'PASS: no NULL or blank display/mailer values';

		-- Check 3: Causal record must be unique
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.causal_data
				  GROUP BY product_id, store_id, week_no, display, mailer HAVING COUNT(*) > 1
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate keys on (product_id, store_id, week_no, display, mailer)';
		END
		ELSE
			PRINT 'PASS: no duplicate keys on (product_id, store_id, week_no, display, mailer)';

		-- Check 4: Product must exist in silver.product
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.causal_data AS c
				  LEFT JOIN silver.product AS p ON c.product_id = p.product_id
				  WHERE c.product_id IS NOT NULL AND p.product_id IS NULL
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: product_id values missing from silver.product';
		END
		ELSE
			PRINT 'PASS: product_id — referential integrity OK';

		-- Check 5: Display unknown flag must match display value
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.causal_data
				   WHERE ((UPPER(TRIM(display))) = 'UNKNOWN' AND is_unknown_display_code <> 1)	OR
						 ((UPPER(TRIM(display))) <> 'UNKNOWN' AND is_unknown_display_code <> 0) OR
						 is_unknown_display_code IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: is_unknown_display_code flag inconsistent with display value';
		END
		ELSE
			PRINT 'PASS: is_unknown_display_code — flag consistency OK';
		
		-- Check 6: Mailer unknown flag must match mailer value
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM silver.causal_data
				   WHERE ((UPPER(TRIM(mailer))) = 'UNKNOWN' AND is_unknown_mailer_code <> 1) OR
						 ((UPPER(TRIM(mailer))) <> 'UNKNOWN' AND is_unknown_mailer_code <> 0) OR
						 is_unknown_mailer_code IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: is_unknown_mailer_code flag inconsistent with mailer value';
		END
		ELSE
			PRINT 'PASS: is_unknown_mailer_code — flag consistency OK';
		
		-- Informational Check: Grain and join-safety checks
		IF EXISTS (SELECT 1
				   FROM silver.causal_data
				   GROUP BY product_id, store_id, week_no
				   HAVING COUNT(*) > 1
				  )
		BEGIN
			PRINT 'NOTE: silver.causal_data — (product_id, store_id, week_no) is NOT unique. Multiple display/mailer combinations may exist for the same product/store/week. Use the full key or aggregate before joining.';
		END
		ELSE
			PRINT 'PASS: silver.causal_data — (product_id, store_id, week_no) is unique and join-safe';

		-- ===============================================================
		-- Checking Table: silver.transaction_data
		-- ===============================================================
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.transaction_data';

		-- Check 1: Required columns must not contain NULL
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.transaction_data
				  WHERE household_key IS NULL OR product_id	IS NULL OR basket_id IS NULL OR day IS NULL OR store_id IS NULL)
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULLs found in required columns';
		END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

		-- Check 2: Transaction grain must be unique
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.transaction_data
				  GROUP BY household_key, basket_id, product_id, day HAVING COUNT(*) > 1
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate keys on (household_key, basket_id, product_id, day)';
		END
		ELSE
			PRINT 'PASS: no duplicate keys on (household_key, basket_id, product_id, day)';

		-- Check 3: Household must exist in silver.hh_demographic
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.transaction_data AS c
				  LEFT JOIN silver.hh_demographic AS p ON c.household_key = p.household_key
				  WHERE c.household_key IS NOT NULL AND p.household_key IS NULL
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: household_key values missing from silver.hh_demographic';
		END
		ELSE
			PRINT 'PASS: household_key — referential integrity OK';

		-- Check 4: Product must exist in silver.product
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.transaction_data AS c
				  LEFT JOIN silver.product AS p ON c.product_id = p.product_id
				  WHERE c.product_id IS NOT NULL AND p.product_id IS NULL
				 )
		BEGIN 
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: product_id values missing from silver.product';
		END
		ELSE
			PRINT 'PASS: product_id — referential integrity OK';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
		SET @batch_end_time = GETDATE();
		PRINT '===============================================================';
		PRINT 'Silver Layer Data Quality Checks Completed';
		PRINT '>> Total DQ Checks: ' + CAST(@check_count AS NVARCHAR);
		PRINT '>> Failed DQ Checks: ' + CAST(@fail_count AS NVARCHAR);
		PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		IF @fail_count = 0
			PRINT '>> Overall Result: PASS';
		ELSE
			PRINT '>> Overall Result: FAIL';
		PRINT '===============================================================';
	END TRY
	BEGIN CATCH
		PRINT '===============================================================';
		PRINT 'ERROR OCCURRED DURING RUNNING SILVER LAYER DATA QUALITY CHECKS';
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '===============================================================';
	END CATCH
END
