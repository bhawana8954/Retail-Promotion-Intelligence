/*
======================================================================================
Stored Procedure: Check Data Quality (Gold Layer)
======================================================================================
Script Purpose:
	Runs data quality checks against the 'gold' schema views:
		- Row count checks (Gold view vs. Silver source)
		- Duplicate key checks
		- Referential integrity checks (orphaned FKs after joins to dimensions)
		- Range/sequence checks
	Prints a PASS/FAIL for each check, plus a final summary.

Usage Example:
	EXEC gold.check_data_quality:
======================================================================================
*/

CREATE OR ALTER PROCEDURE gold.check_data_quality AS 
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	DECLARE @fail_count INT = 0;
	DECLARE @check_count INT = 0;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===============================================================';
		PRINT 'Running Gold Layer Data Quality Checks';
		PRINT '===============================================================';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.dim_campaign';
		-- dim_campaign uses an INNER JOIN to dim_date on start_day/end_day, so a campaign whose days fall outside dim_date's 
		-- range silently disappears instead of erroring
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(*) FROM gold.dim_campaign) <> (SELECT COUNT(*) FROM silver.campaign_desc)
			BEGIN
				SET @fail_count = @fail_count + 1;
					PRINT 'FAIL: row count mismatch vs silver.campaign_desc (campaigns dropped by join)';
				END
		ELSE
			PRINT 'PASS: row count matches silver.campaign_desc';

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.dim_campaign
				  GROUP BY campaign_id HAVING COUNT(*) > 1
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: duplicate keys on (campaign_id)';
				  END
		ELSE
			PRINT 'PASS: no duplicate keys on (campaign_id)';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.dim_coupon';
		-- dim_coupon LEFT JOINs to dim_campaign- a coupon whose campaign isn't found gets a NULL campaign_type instead of erroring
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.dim_coupon
				  WHERE campaign_type IS NULL 
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: campaign_id values missing from gold.dim_campaign';
				  END
		ELSE
			PRINT 'PASS: campaign_id — referential integrity OK';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.dim_household';
		-- straight pass-through of silver.hh_demographic - row count must match exactly
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(*) FROM gold.dim_household) <> (SELECT COUNT(*) FROM silver.hh_demographic)
			BEGIN 
				SET @fail_count = @fail_count + 1;
					PRINT 'FAIL: row count mismatch vs silver.hh_demographic';
			END
		ELSE
			PRINT 'PASS: row count matches silver.hh_demographic';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.dim_product';
		-- straight pass-through of silver.product - row count must match exactly
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(*) FROM gold.dim_product) <> (SELECT COUNT(*) FROM silver.product)
			BEGIN 
				SET @fail_count = @fail_count + 1;
					PRINT 'FAIL: row count mismatch vs silver.product';
			END
		ELSE
			PRINT 'PASS: row count matches silver.product';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.dim_store';
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.dim_store
				  WHERE store_id IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: NULLs found in store_id';
				  END
		ELSE
			PRINT 'PASS: no NULLs in store_id';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.dim_date';
		-- dim_date's day_number range must cover every day value actually referenced by transaction_data.day and campaign_desc.end_day
		SET @check_count = @check_count + 1;
		IF (SELECT MAX(day_number) FROM gold.dim_date) < 
		   (SELECT MAX(mx) FROM (
				SELECT MAX(day) AS mx FROM silver.transaction_data
				UNION ALL
				SELECT MAX(end_day) FROM silver.campaign_desc
			) AS combined)
				BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: dim_date max day_number does not cover max day referenced in source tables';
				END
		ELSE
			PRINT 'PASS: dim_date covers max day referenced in source tables';

		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.calendar_seed
				  HAVING COUNT(*) <> (MAX(day_number) - MIN(day_number) + 1)
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: gaps or duplicates in calendar_seed day_number sequence';
				  END
		ELSE
			PRINT 'PASS: calendar_seed day_number sequence has no gaps or duplicates';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_transactions';
		-- row count must match silver.transaction_data exactly (view is a straight pass-through with LEFT JOINs to dims, so 
		-- nothing should be dropped)
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(*) FROM gold.fact_transactions) <> (SELECT COUNT(*) FROM silver.transaction_data)
			BEGIN 
				SET @fail_count = @fail_count + 1;
					PRINT 'FAIL: row count mismatch vs silver.transaction_data';
			END
		ELSE
			PRINT 'PASS: row count matches silver.transaction_data';

		-- total sales_value must match silver.transaction_data exactly
		SET @check_count = @check_count + 1;
		IF (SELECT SUM(sales_value) FROM gold.fact_transactions) <> (SELECT SUM(sales_value) FROM silver.transaction_data)
			BEGIN 
				SET @fail_count = @fail_count + 1;
					PRINT 'FAIL: total sales_value mismatch vs silver.transaction_data';
			END
		ELSE
			PRINT 'PASS: total sales_value matches silver.transaction_data';

		-- every household_key in the fact must exist in dim_household should always pass
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_transactions AS f
				  LEFT JOIN gold.dim_household AS d
					ON f.household_key = d.household_key
				  WHERE f.household_key IS NOT NULL AND
						d.household_key IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: household_key values missing from gold.dim_household';
				  END
		ELSE
			PRINT 'PASS: household_key — referential integrity OK';

		-- every product_id in the fact must exist in dim_product
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_transactions AS f
				  LEFT JOIN gold.dim_product AS d
					ON f.product_id = d.product_id
				  WHERE f.product_id IS NOT NULL AND
						d.product_id IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: product_id values missing from gold.dim_product';
				  END
		ELSE
			PRINT 'PASS: product_id — referential integrity OK';

		-- every store_id in the fact must exist in dim_store
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_transactions AS f
				  LEFT JOIN gold.dim_store AS d
					ON f.store_id = d.store_id
				  WHERE f.store_id IS NOT NULL AND
						d.store_id IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: store_id values missing from gold.dim_store';
				  END
		ELSE
			PRINT 'PASS: store_id — referential integrity OK';

		-- every day_number in the fact must exist in dim_date
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_transactions AS f
				  LEFT JOIN gold.dim_date AS d
					ON f.day_number = d.day_number
				  WHERE f.day_number IS NOT NULL AND
						d.day_number IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: day_number values missing from gold.dim_date';
				  END
		ELSE
			PRINT 'PASS: day_number — referential integrity OK';

		-- key columns should never be NULL (household_key, product_id, store_id, day_number)
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_transactions
				  WHERE household_key IS NULL OR
						product_id IS NULL OR
						store_id IS NULL OR
						day_number IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: NULLs found in key columns (household_key/product_id/store_id/day_number)';
				  END
		ELSE
			PRINT 'PASS: no NULLs in key columns';

		-- sales_value and quantity should never be negative
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_transactions
				  WHERE sales_value < 0 OR
						quantity < 0
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: negative sales_value or quantity found';
				  END
		ELSE
			PRINT 'PASS: no negative sales_value or quantity';

		-- sales_value and quantity should never be NULL
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_transactions
				  WHERE sales_value IS NULL OR
						quantity IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: NULLs found in sales_value or quantity';
				  END
		ELSE
			PRINT 'PASS: no NULLs in sales_value or quantity';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_campaign_lift';
		-- Check 18: the view's own WHERE clause filters to baseline_days >= 5 AND campaign_days >= 5 - this verifies that filter is 
		-- actually holding rather than trusting the view definition
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_campaign_lift
				  WHERE baseline_days < 5 OR
						campaign_days < 5
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: rows found below the MIN_DAYS >= 5 reliability threshold';
				  END
		ELSE
			PRINT 'PASS: all rows meet the MIN_DAYS >= 5 reliability threshold';

		-- spend values should never be negative
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_campaign_lift
				  WHERE baseline_spend < 0 OR
						campaign_spend < 0
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: negative baseline_spend or campaign_spend found';
				  END
		ELSE
			PRINT 'PASS: no negative baseline_spend or campaign_spend';

		-- Check 20: spend and per-day values should never be NULL for rows that survived the MIN_DAYS filter
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_campaign_lift
				  WHERE baseline_spend IS NULL OR
						campaign_spend IS NULL OR
						baseline_spend_per_day IS NULL OR
						campaign_spend_per_day IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: NULLs found in spend or per-day columns';
				  END
		ELSE
			PRINT 'PASS: no NULLs in spend or per-day columns';

		-- each household_key + category pair should appear at most once
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_campaign_lift
				  GROUP BY household_key, category HAVING COUNT(*) > 1
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: duplicate keys on (household_key, category)';
				  END
		ELSE
			PRINT 'PASS: no duplicate keys on (household_key, category)';

		-- sanity bound - row count can never exceed the number of distinct household_key/category pairs that exist in the underlying 
		-- transaction data (catches a join or grouping bug that fabricates extra rows)
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(*) FROM gold.fact_campaign_lift) > 
		   (SELECT COUNT(*) FROM (
				SELECT DISTINCT t.household_key, p.commodity_desc
				FROM silver.transaction_data AS t
				JOIN silver.product AS p ON p.product_id = t.product_id
			) AS pairs)
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: row count exceeds distinct household_key/category pairs in source data';
				  END
		ELSE
			PRINT 'PASS: row count within expected household_key/category bound';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_coupon_redemption';
		-- dim_coupon's grain (coupon_upc + campaign) can map to multiple products, so joining coupon_redempt to it fans out - a distinct 
		-- count of redemption_event_key (which excludes product_id) should still equal the original silver.coupon_redempt row count, 
		-- proving the fan-out doesn't break redemption-event accounting even though row count itself grows
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(DISTINCT redemption_event_key) FROM gold.fact_coupon_redemption) <> (SELECT COUNT(*) FROM silver.coupon_redempt)
			BEGIN 
				SET @fail_count = @fail_count + 1;
					PRINT 'FAIL: distinct redemption_event_key count does not match silver.coupon_redempt';
			END
		ELSE
			PRINT 'PASS: distinct redemption_event_key count matches silver.coupon_redempt';

		-- every coupon_upc + campaign pair in coupon_redempt must resolve against dim_coupon 
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_coupon_redemption
				  WHERE product_id IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: coupon_upc/campaign values missing from gold.dim_coupon';
				  END
		ELSE
			PRINT 'PASS: coupon_upc/campaign — referential integrity OK';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_store_promotion';
		-- row count must match silver.causal_data exactly (this view aggregates dim_date to week level via a LEFT JOIN, so a mismatch here
		-- would mean the week lookup is fanning rows out or dropping them)
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(*) FROM gold.fact_store_promotion) <> (SELECT COUNT(*) FROM silver.causal_data)
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: row count mismatch vs silver.causal_data';
				  END
		ELSE
			PRINT 'PASS: row count matches silver.causal_data';

		-- every week_no must resolve to a week_start_date/week_end_date (LEFT JOIN to week_lookup means an unmatched week_no surfaces as nulls)
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_store_promotion
				  WHERE week_start_date IS NULL OR
						week_end_date IS NULL
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: week_no values missing from gold.dim_date week lookup';
				  END
		ELSE
			PRINT 'PASS: week_no — referential integrity OK';

		-- (product_id, store_id, week_no) should be unique - causal_data's documented grain is one row per product-store-week
		SET @check_count = @check_count + 1;
		IF EXISTS(SELECT 1 
				  FROM gold.fact_store_promotion
				  GROUP BY product_id, store_id, week_no HAVING COUNT(*) > 1
				 )
				  BEGIN 
					SET @fail_count = @fail_count + 1;
						PRINT 'FAIL: duplicate keys on (product_id, store_id, week_no)';
				  END
		ELSE
			PRINT 'PASS: no duplicate keys on (product_id, store_id, week_no)';
		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @batch_end_time = GETDATE();
		PRINT '===============================================================';
		PRINT 'Data Quality Check Summary';
		PRINT '===============================================================';
		PRINT '>> Total Checks Run: ' + CAST(@check_count AS NVARCHAR);
		PRINT '>> Total Checks Failed: ' + CAST(@fail_count AS NVARCHAR);
		PRINT '>> Total Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		IF @fail_count = 0
			PRINT '>> ALL CHECKS PASSED';
		ELSE
			PRINT '>> ' + CAST(@fail_count AS NVARCHAR) + ' CHECK(S) FAILED - REVIEW ABOVE';

	END TRY
	BEGIN CATCH
		PRINT '===============================================================';
		PRINT 'ERROR OCCURRED DURING DATA QUALITY CHECKS';
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		PRINT '===============================================================';
	END CATCH
END;
GO
