/*
======================================================================================
Stored Procedure: Check Data Quality (Gold Layer - Dimension Tables)
======================================================================================
Script Purpose:
	Runs data quality checks against the 'gold' schema dimension tables:
		- Row count checks (Gold table vs. Silver source)
		- Duplicate key checks
		- Referential integrity checks (orphaned FKs)
		- Range/sequence checks
		- Behavioral & aggregate sanity checks across all 6 gold dimension entities
	Prints a PASS/FAIL for each check, plus a final summary.

Usage Example:
	EXEC gold.dimension_check_data_quality;
======================================================================================
*/

CREATE OR ALTER PROCEDURE gold.dimension_check_data_quality AS 
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	DECLARE @fail_count INT = 0;
	DECLARE @check_count INT = 0;
	DECLARE @max_source_day INT;
	
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===============================================================';
		PRINT 'Running Gold Layer Data Quality Checks for Dimension tables.';
		PRINT '===============================================================';

		-- ---------------------------------------------------------------
		-- Checking Table 1: gold.dim_date
		-- ---------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Checking Table: gold.dim_date';

        -- Check 1: Mandatory NULL Checks, Key Mappings & Weekend Flag
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_date
                   WHERE date_key IS NULL OR full_date IS NULL OR day_no IS NULL OR week_no IS NULL OR month_no IS NULL OR month_name IS NULL
                         OR quarter IS NULL OR year IS NULL OR day_name IS NULL OR is_weekend IS NULL OR date_key <> CAST(CONVERT(VARCHAR(8), full_date, 112) AS INT)
                         OR full_date <> DATEADD(DAY, day_no - 1, '2020-01-01') OR is_weekend NOT IN (0, 1)
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: NULLs, key mapping mismatch, or invalid weekend values found';
        END
        ELSE
            PRINT 'PASS: Mandatory fields, key mappings, and weekend values OK';


        -- Check 2: Derived Calendar Attributes Consistency (Anchored strictly to full_date)
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_date
                   WHERE month_no <> DATEPART(MONTH, full_date) OR month_name <> DATENAME(MONTH, full_date) OR year <> DATEPART(YEAR, full_date)
                         OR quarter <> 'Q' + CAST(DATEPART(QUARTER, full_date) AS VARCHAR(1)) OR day_name <> DATENAME(WEEKDAY, full_date) 
                         OR is_weekend <> CASE WHEN DATENAME(WEEKDAY, full_date) IN ('Saturday', 'Sunday') THEN 1
                                               ELSE 0
                                          END
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: Derived calendar attributes are inconsistent with full_date';
        END
        ELSE
            PRINT 'PASS: Derived calendar attributes are consistent';

        -- Check 3: Week Number Consistency
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_date
                   WHERE week_no <> CASE WHEN day_no <= 5 THEN 1 ELSE ((day_no - 6) / 7) + 2 END
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: week_no is inconsistent with the Gold calendar logic';
        END
        ELSE
            PRINT 'PASS: week_no is consistent with the Gold calendar logic';

        -- Check 4: Sequence Continuity & Date Key Uniqueness
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_date
                   HAVING COUNT(*) <> (MAX(day_no) - MIN(day_no) + 1) OR COUNT(DISTINCT date_key) <> COUNT(*)
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: Gaps in day_no sequence or duplicate date_key values found';
        END
        ELSE
            PRINT 'PASS: day_no sequence is contiguous and date_key values are unique';

        -- Check 5: Source Coverage and Expected Day Range
        SELECT @max_source_day = ISNULL(NULLIF(MAX(max_d), 0), 719)
        FROM (SELECT MAX(day) AS max_d FROM silver.transaction_data
              UNION ALL
              SELECT MAX(end_day) AS max_d FROM silver.campaign_desc) AS combined_sources;

        SET @check_count = @check_count + 1;

        IF NOT EXISTS (SELECT 1 FROM gold.dim_date)
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: gold.dim_date is empty';
        END

        ELSE IF (SELECT MIN(day_no) FROM gold.dim_date) <> 1
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: dim_date day_no does not start at 1';
        END

        ELSE IF (SELECT MAX(day_no) FROM gold.dim_date) < @max_source_day
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: dim_date does not cover the maximum source day';
        END

        ELSE
            PRINT 'PASS: dim_date source day coverage OK';

        SET @end_time = GETDATE();
        PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ---------------------------------------------------------------
		-- Checking Table 2: gold.dim_household
		-- ---------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Checking Table: gold.dim_household';

        -- Check 1: Exact Row Count Match vs silver.hh_demographic
        SET @check_count = @check_count + 1;
        IF (SELECT COUNT(*) FROM gold.dim_household) <> 
           (SELECT COUNT(*) FROM silver.hh_demographic)
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: row count mismatch vs silver.hh_demographic';
        END
        ELSE
            PRINT 'PASS: row count matches silver.hh_demographic exactly';

        -- Check 2: Household Key Uniqueness
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_household
                   GROUP BY household_key HAVING COUNT(*) > 1
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: duplicate keys on (household_key)';
        END
        ELSE
            PRINT 'PASS: primary key uniqueness OK';

        -- Check 3: Mandatory Columns Non-Nullability
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_household
                   WHERE household_key IS NULL OR age_group IS NULL OR marital_status IS NULL
                         OR income_level IS NULL OR homeownership_status IS NULL OR household_composition IS NULL
                         OR household_size IS NULL OR kid_category IS NULL OR is_unknown_household IS NULL
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: NULL values found in mandatory dim_household columns';
        END
        ELSE
            PRINT 'PASS: mandatory fields non-null OK';

        -- Check 4: Gold Household Attributes Must Match Silver
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM silver.hh_demographic AS s
                   LEFT JOIN gold.dim_household AS g ON s.household_key = g.household_key
                   WHERE g.household_key IS NULL OR g.age_group <> s.age_group
                         OR g.marital_status <> s.marital_status_group OR g.income_level <> s.income_level
                         OR g.homeownership_status <> s.homeownership_status OR g.household_composition <> s.household_composition
                         OR g.household_size <> s.household_size OR g.kid_category <> s.kid_category
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: Gold household attributes do not match silver.hh_demographic';
        END
        ELSE
            PRINT 'PASS: Gold household attributes match silver.hh_demographic';

        -- Check 5: is_unknown_household Flag Must Match Gold Business Logic
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_household
                   WHERE is_unknown_household NOT IN (0, 1) 
                         OR is_unknown_household <> CASE WHEN age_group = 'Unknown'
                                                          AND marital_status = 'U'
                                                          AND income_level = 'Unknown'
                                                          AND homeownership_status = 'Unknown'
                                                          AND household_composition = 'Unknown'
                                                          AND household_size = 'Unknown'
                                                          AND kid_category = 'Unknown'
                                                         THEN 1
                                                         ELSE 0
                                                     END
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: is_unknown_household flag is invalid or incorrectly derived';
        END
        ELSE
            PRINT 'PASS: is_unknown_household flag is correctly derived';

        SET @end_time = GETDATE();
        PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ---------------------------------------------------------------
		-- Checking Table 3: gold.dim_product
		-- ---------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Checking Table: gold.dim_product';

        -- Check 1: Exact Row Count Match vs silver.product
        SET @check_count = @check_count + 1;
        IF (SELECT COUNT(*) FROM gold.dim_product) <> 
           (SELECT COUNT(*) FROM silver.product)
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: row count mismatch vs silver.product';
        END
        ELSE
            PRINT 'PASS: row count matches silver.product exactly';

        -- Check 2: Product ID Uniqueness
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_product
                   GROUP BY product_id HAVING COUNT(*) > 1
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: duplicate keys on (product_id)';
        END
        ELSE
            PRINT 'PASS: primary key uniqueness OK';

        -- Check 3: Mandatory Column Non-Nullability
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_product
                   WHERE product_id IS NULL OR manufacturer IS NULL OR department IS NULL OR brand IS NULL
                         OR commodity_desc IS NULL OR sub_commodity_desc IS NULL OR curr_size_of_product IS NULL
                         OR is_catchall_category IS NULL OR is_unknown_product IS NULL
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: NULL values found in mandatory product columns';
        END
        ELSE
            PRINT 'PASS: mandatory product columns non-null OK';

        -- Check 4: Gold Product Attributes and is_unknown_product Must Match Silver
        SET @check_count = @check_count + 1;
        IF EXISTS ( SELECT 1
                    FROM silver.product AS s
                    LEFT JOIN gold.dim_product AS g ON s.product_id = g.product_id
                    WHERE g.product_id IS NULL OR g.manufacturer <> s.manufacturer OR g.department <> s.department
                          OR g.brand <> s.brand OR g.commodity_desc <> s.commodity_desc OR g.sub_commodity_desc <> s.sub_commodity_desc
                          OR g.curr_size_of_product <> s.curr_size_of_product OR g.is_unknown_product <> s.is_unknown_product
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: Gold product attributes or is_unknown_product do not match silver.product';
        END
        ELSE
            PRINT 'PASS: Gold product attributes and is_unknown_product match silver.product';

        -- Check 5: is_catchall_category Flag & Business Logic Validation
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_product
                   WHERE is_catchall_category <>
	                    -- Non-merchandise & operational departments
	                    CASE WHEN department IN ('CNTRL/STORE SUP', 'COUP/STR & MFG', 'GM MERCH EXP', 'MISC SALES TRAN',
								                 'MISC. TRANS.', 'PHARMACY SUPPLY', 'CHARITABLE CONT', 'PROD-WHS SALES',
								                 'MEAT-WHSE') THEN 1
	                    -- Store supplies & internal corporate use commodities
			                 WHEN commodity_desc IN ('DELI SUPPLIES', 'MEAT SUPPLIES', 'PROD SUPPLIES', '(CORP USE ONLY)',
									                 'MISCELLANEOUS(CORP USE ONLY)') THEN 1
	                    -- System coupons, deposits & ledger adjustments
			                 WHEN commodity_desc IN ('COUPON', 'COUPON/MISC ITEMS', 'COUPONS/STORE & MFG', 
									                 'NO COMMODITY DESCRIPTION', 'BOTTLE DEPOSITS') THEN 1
			                 ELSE 0
	                    END
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: invalid values or business logic mismatch in is_catchall_category';
        END
        ELSE
            PRINT 'PASS: is_catchall_category values and business logic OK';

        SET @end_time = GETDATE();
        PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ---------------------------------------------------------------
		-- Checking Table 4: gold.dim_campaign
		-- ---------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Checking Table: gold.dim_campaign';

        -- Check 1: Exact Row Count Match vs silver.campaign_desc
        SET @check_count = @check_count + 1;
        IF (SELECT COUNT(*) FROM gold.dim_campaign) <> 
           (SELECT COUNT(*) FROM silver.campaign_desc)
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: row count mismatch vs silver.campaign_desc';
        END
        ELSE
            PRINT 'PASS: row count matches silver.campaign_desc';

        -- Check 2: Campaign ID Uniqueness
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_campaign
                   GROUP BY campaign_id HAVING COUNT(*) > 1
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: duplicate keys on (campaign_id)';
        END
        ELSE
            PRINT 'PASS: primary key uniqueness OK';

        -- Check 3: Mandatory Columns Non-Nullability
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_campaign
                   WHERE campaign_id IS NULL OR campaign_type IS NULL OR start_day IS NULL
                         OR end_day IS NULL OR start_date IS NULL OR end_date IS NULL
                         OR duration_days IS NULL
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: NULL values found in required campaign columns';
        END
        ELSE
            PRINT 'PASS: all campaign columns non-null OK';

        -- Check 4: Gold Campaign Attributes Must Match Silver
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM silver.campaign_desc AS s
                   LEFT JOIN gold.dim_campaign AS g ON s.campaign = g.campaign_id
                   WHERE g.campaign_id IS NULL OR g.campaign_type <> s.description OR 
                         g.start_day <> s.start_day OR g.end_day <> s.end_day
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: Gold campaign attributes do not match silver.campaign_desc';
        END
        ELSE
            PRINT 'PASS: Gold campaign attributes match silver.campaign_desc';

        -- Check 5: Campaign Date and Duration Logic
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_campaign
                   WHERE start_day > end_day OR start_date > end_date OR duration_days <> (end_day - start_day + 1)
                         OR DATEDIFF(DAY, start_date, end_date) + 1 <> duration_days
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: invalid campaign date range or duration_days calculation';
        END
        ELSE
            PRINT 'PASS: campaign date ranges and duration_days calculations valid';

        -- Check 6: Campaign Dates Must Match gold.dim_date
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM gold.dim_campaign AS c
                   LEFT JOIN gold.dim_date AS d_start ON c.start_day = d_start.day_no
                   LEFT JOIN gold.dim_date AS d_end ON c.end_day = d_end.day_no
                   WHERE d_start.day_no IS NULL OR d_end.day_no IS NULL OR c.start_date <> d_start.full_date
                         OR c.end_date <> d_end.full_date
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: campaign start_date or end_date does not match gold.dim_date';
        END
        ELSE
            PRINT 'PASS: campaign dates correctly map to gold.dim_date';

        SET @end_time = GETDATE();
        PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ---------------------------------------------------------------
		-- Checking Table 5: gold.dim_store
		-- ---------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Checking Table: gold.dim_store';

        -- Extract Silver Store Universe ONCE into a temp table
        IF OBJECT_ID('tempdb..#ExpectedStores') IS NOT NULL 
        DROP TABLE #ExpectedStores;

        CREATE TABLE #ExpectedStores (
            store_id INT PRIMARY KEY -- Adjust datatype if store_id is VARCHAR
        );

        INSERT INTO #ExpectedStores (store_id)
            SELECT store_id FROM silver.transaction_data WHERE store_id IS NOT NULL
            UNION 
            SELECT store_id FROM silver.causal_data WHERE store_id IS NOT NULL;

        -- Check 1: Store ID Uniqueness & Non-Nullability
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1 
                   FROM gold.dim_store 
                   WHERE store_id IS NULL 
                   GROUP BY store_id HAVING COUNT(*) > 1 OR store_id IS NULL
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: Found NULLs or duplicate keys on gold.dim_store(store_id)';
        END
        ELSE
            PRINT 'PASS: store_id primary key uniqueness and non-nullability OK';

        -- Check 2: Bidirectional Set Equality 
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT store_id FROM gold.dim_store
                   EXCEPT
                   SELECT store_id FROM #ExpectedStores
                  )
        OR EXISTS (SELECT store_id FROM #ExpectedStores
                   EXCEPT
                   SELECT store_id FROM gold.dim_store
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: Gold store IDs do not match the Silver store universe';
        END
        ELSE
            PRINT 'PASS: Gold store IDs exactly match the Silver store universe';

        -- Cleanup
        DROP TABLE #ExpectedStores;

        SET @end_time = GETDATE();
        PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ---------------------------------------------------------------
		-- Checking Table 6: gold.dim_coupon
		-- ---------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Checking Table: gold.dim_coupon';

        -- Check 1: Exact Row Count Match vs silver.coupon
        SET @check_count = @check_count + 1;
        IF (SELECT COUNT(*) FROM gold.dim_coupon) <> 
           (SELECT COUNT(*) FROM silver.coupon)
        BEGIN 
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: row count mismatch vs silver.coupon';
        END
        ELSE 
            PRINT 'PASS: row count matches silver.coupon exactly';

        -- Check 2: Composite Primary Key Uniqueness on (coupon_upc, product_id, campaign_id)
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1 
                   FROM gold.dim_coupon 
                   GROUP BY coupon_upc, product_id, campaign_id HAVING COUNT(*) > 1
                  )
        BEGIN 
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: duplicate keys on composite primary key (coupon_upc, product_id, campaign_id)';
        END
        ELSE 
            PRINT 'PASS: composite primary key uniqueness OK';

        -- Check 3: Non-Nullability on Key and Attribute Columns
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1 
                   FROM gold.dim_coupon 
                   WHERE coupon_upc IS NULL OR product_id IS NULL 
                         OR campaign_id IS NULL OR campaign_type IS NULL
                  )
        BEGIN 
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: NULL values found in mandatory coupon columns';
        END
        ELSE 
            PRINT 'PASS: mandatory coupon columns non-null OK';

        -- Check 4: Referential Integrity with gold.dim_campaign
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1 
                   FROM gold.dim_coupon AS c 
                   LEFT JOIN gold.dim_campaign AS dc ON c.campaign_id = dc.campaign_id 
                   WHERE dc.campaign_id IS NULL
                  )
        BEGIN 
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: campaign_id values found that do not exist in gold.dim_campaign';
        END
        ELSE 
            PRINT 'PASS: referential integrity with gold.dim_campaign OK';

        -- Check 5: Coupon Attributes Must Match Silver Sources
        SET @check_count = @check_count + 1;
        IF EXISTS (SELECT 1
                   FROM silver.coupon AS s
                   LEFT JOIN silver.campaign_desc AS cd ON s.campaign = cd.campaign
                   LEFT JOIN gold.dim_coupon AS g ON s.coupon_upc = g.coupon_upc 
                                                 AND s.product_id = g.product_id
                                                 AND s.campaign = g.campaign_id
                   WHERE g.coupon_upc IS NULL OR g.campaign_type <> cd.description
                  )
        BEGIN
            SET @fail_count = @fail_count + 1;
            PRINT 'FAIL: Gold coupon attributes do not match silver.coupon/silver.campaign_desc';
        END
        ELSE
            PRINT 'PASS: Gold coupon attributes match Silver sources';

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