/*
======================================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
======================================================================================
Script Purpose:
	This stored procedure loads data into the 'bronze' schema from external CSV files,
	It performs the following actions:
	- Truncates the bronze tables before loading the data.
	- Uses the 'BULK INSERT' command to load data from csv file into bronze tables.

Parameters:
	@base_path NVARCHAR(500) - Base path directory containing CSV files.
Usage Example:
	EXEC bronze.load_bronze @base_path = 'C:\Users\bhawa\OneDrive\Desktop\Dunnhumby- The Complete Journey Project\Retail-Promotion-Intelligence\dataset\';
======================================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze 
	@base_path NVARCHAR(500) = 'C:\Users\bhawa\OneDrive\Desktop\Dunnhumby- The Complete Journey Project\Retail-Promotion-Intelligence\dataset\'
AS BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	DECLARE @sql NVARCHAR(MAX);

	-- Ensure path ends with a trailing backslash
	IF RIGHT(@base_path, 1) <> '\'
		SET @base_path = @base_path + '\';

	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===========================================================';
		PRINT 'Loading Bronze Layer';
		PRINT '===========================================================';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.campaign_desc';
		TRUNCATE TABLE bronze.campaign_desc;
			PRINT '>> Inserting Data into: bronze.campaign_desc';
			SET @sql = N'BULK INSERT bronze.campaign_desc
			FROM '''+@base_path + 'campaign_desc.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0A'',
				TABLOCK
			);';
			EXEC sp_executesql @sql;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.campaign_table';
		TRUNCATE TABLE bronze.campaign_table;
			PRINT '>> Inserting Data into: bronze.campaign_table';
			SET @sql = N'BULK INSERT bronze.campaign_table
			FROM '''+@base_path + 'campaign_table.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0A'',
				TABLOCK
			);';
			EXEC sp_executesql @sql;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.causal_data';
		TRUNCATE TABLE bronze.causal_data;
			PRINT '>> Inserting Data into: bronze.causal_data';
			SET @sql = N'BULK INSERT bronze.causal_data
			FROM '''+@base_path + 'causal_data.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0A'',
				TABLOCK
			);';
			EXEC sp_executesql @sql;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.coupon';
		TRUNCATE TABLE bronze.coupon;
			PRINT '>> Inserting Data into: bronze.coupon';
			SET @sql = N'BULK INSERT bronze.coupon
			FROM '''+@base_path + 'coupon.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0A'',
				TABLOCK
			);';
			EXEC sp_executesql @sql;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.coupon_redempt';
		TRUNCATE TABLE bronze.coupon_redempt;
			PRINT '>> Inserting Data into: bronze.coupon_redempt';
			SET @sql = N'BULK INSERT bronze.coupon_redempt
			FROM '''+@base_path + 'coupon_redempt.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0A'',
				TABLOCK
			);';
			EXEC sp_executesql @sql;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.hh_demographic';
		TRUNCATE TABLE bronze.hh_demographic;
			PRINT '>> Inserting Data into: bronze.hh_demographic';
			SET @sql = N'BULK INSERT bronze.hh_demographic
			FROM '''+@base_path + 'hh_demographic.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0A'',
				TABLOCK
			);';
			EXEC sp_executesql @sql;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.product';
		TRUNCATE TABLE bronze.product;
			PRINT '>> Inserting Data into: bronze.product';
			SET @sql = N'BULK INSERT bronze.product
			FROM '''+@base_path + 'product.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0A'',
				TABLOCK
			);';
			EXEC sp_executesql @sql;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.transaction_data';
		TRUNCATE TABLE bronze.transaction_data;
			PRINT '>> Inserting Data into: bronze.transaction_data';
			SET @sql = N'BULK INSERT bronze.transaction_data
			FROM '''+@base_path + 'transaction_data.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0A'',
				TABLOCK
			);';
			EXEC sp_executesql @sql;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @batch_end_time = GETDATE();
		PRINT '===========================================================';
		PRINT 'Loading Bronze Layer is completed';
		PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '===========================================================';
	END TRY
	BEGIN CATCH
		PRINT '===========================================================';
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '===========================================================';
	END CATCH
END
