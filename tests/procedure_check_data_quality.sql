/*
======================================================================================
Stored Procedure: Check Data Quality (Silver Layer)
======================================================================================
Script Purpose:
	Runs data quality checks against the 'silver' schema tables:
		- Null checks on required columns
		- Duplicate key checks
		- Referential integrity checks
		- Uniqueness check for join-safe keys
	Prints a PASS/FAIL for each check, plus a final summary.

Usage Example:
	EXEC silver.check_data_quality:
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

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.campaign_desc';
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
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.campaign_table';
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

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.campaign_table AS c
				  LEFT JOIN silver.campaign_desc AS p
					ON c.campaign = p.campaign
				  WHERE c.campaign IS NOT NULL AND
						p.campaign IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: campaign values missing from silver.campaign_desc';
				  END
		ELSE
			PRINT 'PASS: campaign — referential integrity OK';

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.campaign_table AS c
				  LEFT JOIN silver.hh_demographic AS p
					ON c.household_key = p.household_key
				  WHERE c.household_key IS NOT NULL AND
						p.household_key IS NULL
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

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.coupon';
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon
				  WHERE coupon_upc IS NULL OR
						campaign IS NULL 
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: NULLs found in required columns';
				  END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

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

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon AS c
				  LEFT JOIN silver.campaign_desc AS p
					ON c.campaign = p.campaign
				  WHERE c.campaign IS NOT NULL AND
						p.campaign IS NULL
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

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.coupon_redempt';
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon_redempt
				  WHERE household_key IS NULL OR
						coupon_upc IS NULL OR
						campaign IS NULL 
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: NULLs found in required columns';
				  END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

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

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon_redempt AS c
				  LEFT JOIN silver.campaign_desc AS p
					ON c.campaign = p.campaign
				  WHERE c.campaign IS NOT NULL AND
						p.campaign IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: campaign values missing from silver.campaign_desc';
				  END
		ELSE
			PRINT 'PASS: campaign — referential integrity OK';

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon_redempt AS c
				  LEFT JOIN silver.hh_demographic AS p
					ON c.household_key = p.household_key
				  WHERE c.household_key IS NOT NULL AND
						p.household_key IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: household_key values missing from silver.hh_demographic';
				  END
		ELSE
			PRINT 'PASS: household_key — referential integrity OK';

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.coupon_redempt AS c
				  LEFT JOIN silver.coupon AS p
					ON c.coupon_upc = p.coupon_upc
				  WHERE c.coupon_upc IS NOT NULL AND
						p.coupon_upc IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: coupon_upc values missing from silver.coupon';
				  END
		ELSE
			PRINT 'PASS: coupon_upc — referential integrity OK';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.hh_demographic';
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.hh_demographic
				  WHERE household_key IS NULL 
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: NULLs found in required columns';
				  END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

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
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.product';
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.product
				  WHERE product_id IS NULL 
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: NULLs found in required columns';
				  END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

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
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.casual_data';
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

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.causal_data AS c
				  LEFT JOIN silver.product AS p
					ON c.product_id = p.product_id
				  WHERE c.product_id IS NOT NULL AND
						p.product_id IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: product_id values missing from silver.product';
				  END
		ELSE
			PRINT 'PASS: product_id — referential integrity OK';

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1
				  FROM silver.causal_data
				  WHERE (mailer = '0' AND is_unknown_mailer_code = 0)
					 OR (mailer <> '0' AND is_unknown_mailer_code = 1)
				 )
				  BEGIN
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: is_unknown_mailer_code flag inconsistent with mailer value';
				  END
		ELSE
			PRINT 'PASS: is_unknown_mailer_code — flag consistency OK';
		
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(*) FROM silver.causal_data WHERE is_unknown_mailer_code = 1) <> 11534183
				  BEGIN
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: is_unknown_mailer_code total count does not match expected 11534183';
				  END
		ELSE
			PRINT 'PASS: is_unknown_mailer_code — total count matches expected 11534183';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.causal_data
				  GROUP BY product_id, store_id, week_no HAVING COUNT(*) > 1
				 )
			PRINT 'NOTE: silver.causal_data — (product_id, store_id, week_no) is NOT unique; a product can have multiple display/mailer rows per store/week. Always join using the full key including display and mailer, or aggregate first.';
		ELSE
			PRINT 'PASS: silver.causal_data — (product_id, store_id, week_no) is join-safe as-is';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: silver.transaction_data';
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.transaction_data
				  WHERE household_key IS NULL OR
						product_id	IS NULL OR
						basket_id IS NULL OR
						day IS NULL 
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: NULLs found in required columns';
				  END
		ELSE
			PRINT 'PASS: no NULLs in required columns';

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

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.transaction_data AS c
				  LEFT JOIN silver.hh_demographic AS p
					ON c.household_key = p.household_key
				  WHERE c.household_key IS NOT NULL AND
						p.household_key IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: household_key values missing from silver.hh_demographic';
				  END
		ELSE
			PRINT 'PASS: household_key — referential integrity OK';

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM silver.transaction_data AS c
				  LEFT JOIN silver.product AS p
					ON c.product_id = p.product_id
				  WHERE c.product_id IS NOT NULL AND
						p.product_id IS NULL
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
		PRINT 'Running Silver Layer Data Quality Checks is completed';
		PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '===============================================================';
	END TRY
	BEGIN CATCH
		PRINT '===============================================================';
		PRINT 'ERROR OCCURED DURING RUNNING SILVER LAYER DATA QUALITY CHECKS';
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '===============================================================';
	END CATCH
END
