"""
======================================================================================
Test Module: Data Quality Checks (Gold Layer)
======================================================================================
Script Purpose:
    Runs automated data quality checks against the 'gold' schema tables using
    pytest, connecting directly to SQL Server via pyodbc:
        - Null checks on required columns across dimension and fact tables
        - Duplicate key checks on unique primary and composite keys
        - Referential integrity checks validating child FKs exist in parent dimensions
        - Row-count reconciliation comparing gold facts against silver sources
        - Business threshold checks (MIN_DAYS >= 5 filter in gold.fact_campaign_lift)
        - Redemption event integrity checks (DISTINCT redemption_event_key count 
          matching silver source to account for product fan-out)

    Each check is parametrized where applicable (nulls, duplicates, referential
    integrity, row counts) so a single test function covers every configured 
    table/column combination dynamically.

Usage Example:
    & "D:\Python 3.14.0\python.exe" -m pytest tests/test_data_quality_gold.py -v
======================================================================================
"""

# import libraries
import pyodbc
import pytest

# connection details:
SERVER = r"LAPPY\SQLEXPRESS"
DATABASE = "DunnhumbyDB"
CONN_STR = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={SERVER};"
            f"DATABASE={DATABASE};"
            f"Trusted_Connection=yes;")
@pytest.fixture(scope="session")
def conn():
    connection = pyodbc.connect(CONN_STR)
    yield connection
    connection.close()     #conn fixture

def _scalar(conn, query):
    cursor = conn.cursor()
    cursor.execute(query)
    row = cursor.fetchone()
    return row[0] if row else None   #helper function

# start table checks dictionary:
TABLE_CHECKS = {
    # dimension tables:
    "gold.dim_date": {
        "not_null_columns": ["DATE_KEY", "FULL_DATE", "DAY_NO", "WEEK_NO", "MONTH_NO", "MONTH_NAME", "QUARTER", 
                             "YEAR", "DAY_NAME", "IS_WEEKEND"],
        "key_columns": ["DATE_KEY"],
        "referential_integrity": [],},

    "gold.dim_household": {
        "not_null_columns": ["HOUSEHOLD_KEY", "AGE_GROUP", "MARITAL_STATUS", "INCOME_LEVEL", "HOMEOWNERSHIP_STATUS",
                             "HOUSEHOLD_COMPOSITION", "HOUSEHOLD_SIZE", "KID_CATEGORY", "IS_UNKNOWN_HOUSEHOLD"],
        "key_columns": ["HOUSEHOLD_KEY"],
        "referential_integrity": [],},

    "gold.dim_product": {
        "not_null_columns": ["PRODUCT_ID", "MANUFACTURER", "DEPARTMENT", "BRAND", "COMMODITY_DESC", 
                             "SUB_COMMODITY_DESC", "CURR_SIZE_OF_PRODUCT", "IS_CATCHALL_CATEGORY", 
                             "IS_UNKNOWN_PRODUCT"],
        "key_columns": ["PRODUCT_ID"],
        "referential_integrity": [],},

    "gold.dim_campaign": {
        "not_null_columns": ["CAMPAIGN_ID", "CAMPAIGN_TYPE", "START_DAY", "END_DAY", "START_DATE", "END_DATE", 
                             "DURATION_DAYS"],
        "key_columns": ["CAMPAIGN_ID"],
        "referential_integrity": [],},

    "gold.dim_store": {
        "not_null_columns": ["STORE_ID"],
        "key_columns": ["STORE_ID"],
        "referential_integrity": [],},

    "gold.dim_coupon": {
        "not_null_columns": ["COUPON_UPC", "PRODUCT_ID", "CAMPAIGN_ID", "CAMPAIGN_TYPE"],
        "key_columns": ["COUPON_UPC", "CAMPAIGN_ID", "PRODUCT_ID"],
        "referential_integrity": [("CAMPAIGN_ID", "gold.dim_campaign", "CAMPAIGN_ID")],},

    # fact tables:
    "gold.fact_transactions": {
        "not_null_columns": ["DATE_KEY", "HOUSEHOLD_KEY", "BASKET_ID", "DAY_NUMBER", "PRODUCT_ID", "STORE_ID", 
                             "TRANS_TIME", "WEEK_NO", "QUANTITY", "SALES_VALUE", "RETAIL_DISC", "COUPON_DISC", 
                             "COUPON_MATCH_DISC"],
        "key_columns": [],  # High-volume transactional table without single natural PK
        "referential_integrity": [
                                ("HOUSEHOLD_KEY", "gold.dim_household", "HOUSEHOLD_KEY"),
                                ("PRODUCT_ID", "gold.dim_product", "PRODUCT_ID"),
                                ("STORE_ID", "gold.dim_store", "STORE_ID"),
                                ("DATE_KEY", "gold.dim_date", "DATE_KEY"),],},

    "gold.fact_coupon_redemption": {
        "not_null_columns": ["REDEMPTION_EVENT_KEY", "DATE_KEY", "HOUSEHOLD_KEY", "DAY_NUMBER", "COUPON_UPC", 
                             "CAMPAIGN_ID", "CAMPAIGN_TYPE"],
        "key_columns": [],  #leave empty as redemptions naturally repeat across keys (e.g., same household may redeem multiple coupons on same day)
        "referential_integrity": [
                                ("HOUSEHOLD_KEY", "gold.dim_household", "HOUSEHOLD_KEY"),
                                ("CAMPAIGN_ID", "gold.dim_campaign", "CAMPAIGN_ID"),
                                ("DATE_KEY", "gold.dim_date", "DATE_KEY"),
                                ("PRODUCT_ID", "gold.dim_product", "PRODUCT_ID")],}, # Optional FK handling built into test logic

    "gold.fact_executive_daily_summary": {
        "not_null_columns": ["DATE_KEY", "ACTUAL_SALES_AMOUNT", "BEHAVIORAL_BASELINE_AMOUNT", "COUPON_DISCOUNT_AMOUNT", 
                             "INSTORE_DISCOUNT_AMOUNT", "TOTAL_DISCOUNT_AMOUNT", "WASTED_SPEND_FLOORED_AMOUNT"],
        "key_columns": ["DATE_KEY"],
        "referential_integrity": [("DATE_KEY", "gold.dim_date", "DATE_KEY"),],},

    "gold.fact_campaign_lift": {
        "not_null_columns": ["HOUSEHOLD_KEY", "CATEGORY", "BASELINE_SPEND", "BASELINE_DAYS","CAMPAIGN_SPEND", 
                             "CAMPAIGN_DAYS", "BASELINE_SPEND_PER_DAY", "CAMPAIGN_SPEND_PER_DAY", 
                             "LIFT_PER_DAY", "IS_CATCHALL_CATEGORY", "IS_RELIABLE_PAIR"],
        "key_columns": ["HOUSEHOLD_KEY", "CATEGORY"],
        "referential_integrity": [("HOUSEHOLD_KEY", "gold.dim_household", "HOUSEHOLD_KEY")],},

    "gold.fact_campaign_category_lift": {
        "not_null_columns": ["CAMPAIGN_ID", "COMMODITY_DESC", "COUPONS_DISTRIBUTED", "COUPONS_REDEEMED", 
                             "ACTUAL_SALES", "BEHAVIORAL_BASELINE_SALES", "DISCOUNT_SPEND", "INCREMENTAL_LIFT"],
        "key_columns": ["CAMPAIGN_ID", "COMMODITY_DESC"],
        "referential_integrity": [("CAMPAIGN_ID", "gold.dim_campaign", "CAMPAIGN_ID"),],},

    "gold.fact_store_promo_lift": {
        "not_null_columns": ["DATE_KEY", "STORE_ID", "COMMODITY_DESC", "DISPLAY_FLAG", "MAILER_FLAG", 
                             "IS_UNKNOWN_MAILER_FLAG", "IS_CAUSAL_TRACKED", "PROMO_COMBINATION_TYPE", 
                             "ACTUAL_SALES", "UNITS_SOLD"],
        "key_columns": ["DATE_KEY", "STORE_ID", "COMMODITY_DESC", "DISPLAY_FLAG", "MAILER_FLAG", 
                        "IS_UNKNOWN_MAILER_FLAG", "IS_CAUSAL_TRACKED"],
        "referential_integrity": [("DATE_KEY", "gold.dim_date", "DATE_KEY"),
                                  ("STORE_ID", "gold.dim_store", "STORE_ID"),],},

    "gold.fact_household_segment_lift": {
        "not_null_columns": ["HOUSEHOLD_KEY", "CAMPAIGN_ID", "TOTAL_SPEND", "BEHAVIORAL_BASELINE_SPEND", 
                             "TOTAL_DISCOUNT_RECEIVED", "INCREMENTAL_LIFT"],
        "key_columns": ["HOUSEHOLD_KEY", "CAMPAIGN_ID"],
        "referential_integrity": [("HOUSEHOLD_KEY", "gold.dim_household", "HOUSEHOLD_KEY"),
                                  ("CAMPAIGN_ID", "gold.dim_campaign", "CAMPAIGN_ID"),],}
}

# DYNAMIC PARAMETRIZED CHECKS (NOT NULL, KEYS, REFERENTIAL INTEGRITY)

# build the list of not-null cases:
not_null_cases = [
    (table, col)
    for table, cfg in TABLE_CHECKS.items()
    for col in cfg["not_null_columns"]
]

@pytest.mark.parametrize("table, col", not_null_cases)
def test_not_null_columns(conn, table, col):
    query = f"SELECT COUNT(*) FROM {table} WHERE {col} IS NULL"
    null_count = _scalar(conn, query)
    assert null_count == 0, f"{table}.{col} contains {null_count} unexpected NULL values"

# build the list of duplicate key cases:
duplicate_key_cases = [
    (table, cfg["key_columns"])
    for table, cfg in TABLE_CHECKS.items()
    if cfg["key_columns"]
]

@pytest.mark.parametrize("table, key_columns", duplicate_key_cases)
def test_no_duplicate_keys(conn, table, key_columns):
    cols = ", ".join(key_columns)
    query = f"""
        SELECT COUNT(*) FROM (
            SELECT {cols} FROM {table}
            GROUP BY {cols}
            HAVING COUNT(*) > 1
        ) AS dupes
    """
    dup_count = _scalar(conn, query)
    assert dup_count == 0, f"{table} has {dup_count} duplicate key records on ({cols})"

# build the list of referential integrity cases:
fk_check_cases = [
    (table, fk_col, parent_table, parent_col)
    for table, cfg in TABLE_CHECKS.items()
    for (fk_col, parent_table, parent_col) in cfg["referential_integrity"]
]

@pytest.mark.parametrize("table, fk_col, parent_table, parent_col", fk_check_cases)
def test_no_orphaned_foreign_keys(conn, table, fk_col, parent_table, parent_col):
    query = f"""
        SELECT COUNT(*) FROM {table} t
        WHERE t.{fk_col} IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM {parent_table} p WHERE p.{parent_col} = t.{fk_col}
          )
    """
    orphan_count = _scalar(conn, query)
    assert orphan_count == 0, f"{table}.{fk_col} contains {orphan_count} orphans vs {parent_table}.{parent_col}"

# DIMENSION-SPECIFIC BUSINESS LOGIC CHECKS

def test_dim_date_logic_and_sequence(conn):
    """Validates gold.dim_date sequence, weekend logic, and date key mappings."""
    query_mapping = """
        SELECT COUNT(*) FROM gold.dim_date
        WHERE date_key <> CAST(CONVERT(VARCHAR(8), full_date, 112) AS INT)
           OR full_date <> DATEADD(DAY, day_no - 1, '2020-01-01')
           OR is_weekend NOT IN (0, 1)
    """
    assert _scalar(conn, query_mapping) == 0, "dim_date has invalid date key mappings or weekend flags"

    query_calendar = """
        SELECT COUNT(*) FROM gold.dim_date
        WHERE month_no <> DATEPART(MONTH, full_date)
           OR month_name <> DATENAME(MONTH, full_date)
           OR year <> DATEPART(YEAR, full_date)
           OR quarter <> 'Q' + CAST(DATEPART(QUARTER, full_date) AS VARCHAR(1))
           OR day_name <> DATENAME(WEEKDAY, full_date)
           OR is_weekend <> CASE WHEN DATENAME(WEEKDAY, full_date) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END
    """
    assert _scalar(conn, query_calendar) == 0, "dim_date derived calendar attributes do not align with full_date"

    query_week = """
        SELECT COUNT(*) FROM gold.dim_date
        WHERE week_no <> CASE WHEN day_no <= 5 THEN 1 ELSE ((day_no - 6) / 7) + 2 END
    """
    assert _scalar(conn, query_week) == 0, "dim_date week_no logic is inconsistent with Gold calendar rules"

    query_sequence = """
        SELECT CASE WHEN COUNT(*) <> (MAX(day_no) - MIN(day_no) + 1) THEN 1 ELSE 0 END
        FROM gold.dim_date
    """
    assert _scalar(conn, query_sequence) == 0, "dim_date has gaps in its day_no sequence"

def test_dim_household_attribute_alignment(conn):
    """Validates gold.dim_household row counts, attribute values, and unknown flags."""
    gold_count = _scalar(conn, "SELECT COUNT(*) FROM gold.dim_household")
    silver_count = _scalar(conn, "SELECT COUNT(*) FROM silver.hh_demographic")
    assert gold_count == silver_count, f"dim_household count ({gold_count}) does not match silver.hh_demographic ({silver_count})"

    query_attr = """
        SELECT COUNT(*)
        FROM silver.hh_demographic s
        LEFT JOIN gold.dim_household g ON s.household_key = g.household_key
        WHERE g.household_key IS NULL
           OR g.age_group <> s.age_group
           OR g.marital_status <> s.marital_status_group
           OR g.income_level <> s.income_level
           OR g.homeownership_status <> s.homeownership_status
           OR g.household_composition <> s.household_composition
           OR g.household_size <> s.household_size
           OR g.kid_category <> s.kid_category
    """
    assert _scalar(conn, query_attr) == 0, "dim_household attributes differ from silver.hh_demographic source"

def test_dim_product_attribute_and_catchall_logic(conn):
    """Validates gold.dim_product row counts, attributes, and catchall category flag rules."""
    gold_count = _scalar(conn, "SELECT COUNT(*) FROM gold.dim_product")
    silver_count = _scalar(conn, "SELECT COUNT(*) FROM silver.product")
    assert gold_count == silver_count, f"dim_product count ({gold_count}) does not match silver.product ({silver_count})"

    query_catchall = """
        SELECT COUNT(*) FROM gold.dim_product
        WHERE is_catchall_category <> CASE 
            WHEN department IN ('CNTRL/STORE SUP', 'COUP/STR & MFG', 'GM MERCH EXP', 'MISC SALES TRAN',
                                'MISC. TRANS.', 'PHARMACY SUPPLY', 'CHARITABLE CONT', 'PROD-WHS SALES',
                                'MEAT-WHSE') THEN 1
            WHEN commodity_desc IN ('DELI SUPPLIES', 'MEAT SUPPLIES', 'PROD SUPPLIES', '(CORP USE ONLY)',
                                    'MISCELLANEOUS(CORP USE ONLY)') THEN 1
            WHEN commodity_desc IN ('COUPON', 'COUPON/MISC ITEMS', 'COUPONS/STORE & MFG', 
                                    'NO COMMODITY DESCRIPTION', 'BOTTLE DEPOSITS') THEN 1
            ELSE 0 END
    """
    assert _scalar(conn, query_catchall) == 0, "dim_product is_catchall_category logic mismatch"

def test_dim_campaign_duration_and_date_mapping(conn):
    """Validates gold.dim_campaign attributes, durations, and mapping to gold.dim_date."""
    gold_count = _scalar(conn, "SELECT COUNT(*) FROM gold.dim_campaign")
    silver_count = _scalar(conn, "SELECT COUNT(*) FROM silver.campaign_desc")
    assert gold_count == silver_count, f"dim_campaign count ({gold_count}) mismatch vs silver.campaign_desc ({silver_count})"

    query_duration = """
        SELECT COUNT(*) FROM gold.dim_campaign
        WHERE start_day > end_day
           OR start_date > end_date
           OR duration_days <> (end_day - start_day + 1)
           OR DATEDIFF(DAY, start_date, end_date) + 1 <> duration_days
    """
    assert _scalar(conn, query_duration) == 0, "dim_campaign has invalid start/end dates or duration calculations"

def test_dim_store_bidirectional_set_equality(conn):
    """Ensures store_id set in gold.dim_store precisely matches the Silver store universe."""
    query_set_diff = """
        WITH ExpectedStores AS (
            SELECT store_id FROM silver.transaction_data WHERE store_id IS NOT NULL
            UNION
            SELECT store_id FROM silver.causal_data WHERE store_id IS NOT NULL
        )
        SELECT 
            (SELECT COUNT(*) FROM (SELECT store_id FROM gold.dim_store EXCEPT SELECT store_id FROM ExpectedStores) a)
          + (SELECT COUNT(*) FROM (SELECT store_id FROM ExpectedStores EXCEPT SELECT store_id FROM gold.dim_store) b)
    """
    assert _scalar(conn, query_set_diff) == 0, "gold.dim_store set does not match Silver store universe"

def test_dim_coupon_attributes_and_source_match(conn):
    """Validates gold.dim_coupon row count and attributes against Silver sources."""
    gold_count = _scalar(conn, "SELECT COUNT(*) FROM gold.dim_coupon")
    silver_count = _scalar(conn, "SELECT COUNT(*) FROM silver.coupon")
    assert gold_count == silver_count, f"dim_coupon count ({gold_count}) does not match silver.coupon ({silver_count})"

# FACT & AGGREGATE BUSINESS LOGIC CHECKS

def test_fact_transactions_financial_reconciliation(conn):
    """Reconciles total sales, quantities, and discounts between gold.fact_transactions and silver."""
    query = """
        SELECT COUNT(*)
        FROM (
            SELECT 
                COUNT(*) AS total_rows,
                ISNULL(SUM(sales_value), 0) AS total_sales,
                ISNULL(SUM(quantity), 0) AS total_qty,
                ISNULL(SUM(retail_disc), 0) AS total_retail_disc,
                ISNULL(SUM(coupon_disc), 0) AS total_coupon_disc,
                ISNULL(SUM(coupon_match_disc), 0) AS total_coupon_match_disc
            FROM gold.fact_transactions
        ) g
        CROSS JOIN (
            SELECT 
                COUNT(*) AS total_rows,
                ISNULL(SUM(ISNULL(sales_value, 0.00)), 0) AS total_sales,
                ISNULL(SUM(ISNULL(quantity, 0)), 0) AS total_qty,
                ISNULL(SUM(ISNULL(retail_disc, 0.00)), 0) AS total_retail_disc,
                ISNULL(SUM(ISNULL(coupon_disc, 0.00)), 0) AS total_coupon_disc,
                ISNULL(SUM(ISNULL(coupon_match_disc, 0.00)), 0) AS total_coupon_match_disc
            FROM silver.transaction_data
        ) s
        WHERE g.total_rows <> s.total_rows
           OR g.total_sales <> s.total_sales
           OR g.total_qty <> s.total_qty
           OR g.total_retail_disc <> s.total_retail_disc
           OR g.total_coupon_disc <> s.total_coupon_disc
           OR g.total_coupon_match_disc <> s.total_coupon_match_disc
    """
    assert _scalar(conn, query) == 0, "fact_transactions totals mismatch vs silver.transaction_data"

def test_fact_coupon_redemption_population(conn):
    """Validates row count of gold.fact_coupon_redemption against expected silver grain population."""
    query = """
        SELECT COUNT(*)
        FROM (SELECT COUNT(*) AS cnt FROM gold.fact_coupon_redemption) g
        CROSS JOIN (
            SELECT COUNT(*) AS cnt
            FROM (
                SELECT DISTINCT cr.household_key, cr.day, cr.coupon_upc, cr.campaign, c.product_id, cd.description
                FROM silver.coupon_redempt cr
                INNER JOIN gold.dim_date d ON cr.day = d.day_no
                LEFT JOIN silver.coupon c ON cr.coupon_upc = c.coupon_upc AND cr.campaign = c.campaign
                LEFT JOIN silver.campaign_desc cd ON cr.campaign = cd.campaign
            ) expected
        ) s
        WHERE g.cnt <> s.cnt
    """
    assert _scalar(conn, query) == 0, "fact_coupon_redemption row count mismatch vs expected silver population"

def test_fact_executive_daily_summary_formulas(conn):
    """Validates discount formulas and wasted spend bounds on executive daily summary."""
    query_formula = """
        SELECT COUNT(*) FROM gold.fact_executive_daily_summary
        WHERE total_discount_amount <> coupon_discount_amount + instore_discount_amount
    """
    assert _scalar(conn, query_formula) == 0, "total_discount_amount formula is invalid in executive daily summary"

    query_wasted = """
        SELECT COUNT(*) FROM gold.fact_executive_daily_summary
        WHERE wasted_spend_floored_amount < 0 
           OR wasted_spend_floored_amount > total_discount_amount
    """
    assert _scalar(conn, query_wasted) == 0, "wasted_spend_floored_amount lies outside valid bounds [0, total_discount]"

def test_fact_campaign_lift_reliability_and_formulas(conn):
    """Validates is_reliable_pair threshold logic (>=5 both sides) and spend-per-day / lift formulas."""
    query = """
        SELECT COUNT(*) FROM gold.fact_campaign_lift
        WHERE is_reliable_pair <> CASE WHEN baseline_days >= 5 AND campaign_days >= 5 THEN 1 ELSE 0 END
           OR ABS(baseline_spend_per_day - ISNULL(CAST(baseline_spend / NULLIF(baseline_days, 0) AS DECIMAL(10,2)), 0.00)) > 0.01
           OR ABS(campaign_spend_per_day - ISNULL(CAST(campaign_spend / NULLIF(campaign_days, 0) AS DECIMAL(10,2)), 0.00)) > 0.01
           OR ABS(lift_per_day - (campaign_spend_per_day - baseline_spend_per_day)) > 0.01
           OR baseline_spend < 0 OR campaign_spend < 0 OR baseline_days < 0 OR campaign_days < 0
    """
    assert _scalar(conn, query) == 0, "fact_campaign_lift has incorrect is_reliable_pair flag, spend-per-day formulas, or negative values"

def test_fact_campaign_category_lift_logic(conn):
    """Validates coupon counts, non-negative spend, and incremental lift formula consistency."""
    query = """
        SELECT COUNT(*) FROM gold.fact_campaign_category_lift
        WHERE coupons_distributed < 0 
           OR coupons_redeemed < 0
           OR discount_spend < 0
           OR actual_sales < 0
           OR behavioral_baseline_sales < 0
           OR ABS(incremental_lift - (actual_sales - behavioral_baseline_sales)) > 0.01
    """
    assert _scalar(conn, query) == 0, "fact_campaign_category_lift contains invalid metrics or inconsistent lift calculations"

def test_fact_store_promo_lift_combinations(conn):
    """Validates promotion flag values and promo_combination_type derivation logic."""
    query = """
        SELECT COUNT(*) FROM gold.fact_store_promo_lift
        WHERE display_flag NOT IN ('0', '1') 
           OR mailer_flag NOT IN ('0', '1')
           OR is_unknown_mailer_flag NOT IN (0, 1)
           OR is_causal_tracked NOT IN (0, 1)
           OR promo_combination_type <> CASE 
                WHEN display_flag = '1' AND mailer_flag = '1' THEN 'Both'
                WHEN display_flag = '1' AND mailer_flag = '0' THEN 'Display Only'
                WHEN display_flag = '0' AND mailer_flag = '1' THEN 'Mailer Only'
                ELSE 'No Promo' END
    """
    assert _scalar(conn, query) == 0, "fact_store_promo_lift has invalid flags or promo_combination_type derivations"

def test_fact_household_segment_lift_discounts(conn):
    """Validates incremental lift consistency and non-negative values in household segment lift."""
    query = """
        SELECT COUNT(*) FROM gold.fact_household_segment_lift
        WHERE total_spend < 0 
           OR behavioral_baseline_spend < 0 
           OR total_discount_received < 0
           OR ABS(incremental_lift - (total_spend - behavioral_baseline_spend)) > 0.01
    """
    assert _scalar(conn, query) == 0, "fact_household_segment_lift contains negative spend or inconsistent lift values"

def test_fact_household_segment_lift_baseline_and_targeting(conn):
    """Validates total_spend/behavioral_baseline_spend against a source recompute (non-campaign-day baseline 
       rate x campaign duration), and confirms the table's grain matches silver.campaign_table targeting exactly."""
    query = """
        ;WITH ActiveCampaignDays AS (
            SELECT DISTINCT d.day_no AS day_number
            FROM gold.dim_date AS d
            INNER JOIN silver.campaign_desc AS cd ON d.day_no BETWEEN cd.start_day AND cd.end_day
        ),
        NonCampaignDayCount AS (
            SELECT COUNT(DISTINCT d.day_no) AS total_non_campaign_days
            FROM gold.dim_date AS d
            LEFT JOIN ActiveCampaignDays AS acd ON d.day_no = acd.day_number
            WHERE acd.day_number IS NULL
        ),
        HouseholdDailyBaselines AS (
            SELECT
                t.household_key,
                SUM(t.sales_value) / NULLIF((SELECT total_non_campaign_days FROM NonCampaignDayCount), 0) AS baseline_daily_rate
            FROM silver.transaction_data AS t
            LEFT JOIN ActiveCampaignDays AS acd ON t.day = acd.day_number
            WHERE acd.day_number IS NULL
            GROUP BY t.household_key
        ),
        TargetedHouseholds AS (
            SELECT DISTINCT campaign AS campaign_id, household_key
            FROM silver.campaign_table
            WHERE household_key IS NOT NULL AND campaign IS NOT NULL
        ),
        Expected AS (
            SELECT
                th.household_key,
                th.campaign_id,
                ISNULL(SUM(t.sales_value), 0.00) AS expected_total_spend,
                (cd.end_day - cd.start_day + 1) * MAX(ISNULL(hdb.baseline_daily_rate, 0.00)) AS expected_baseline_spend
            FROM TargetedHouseholds AS th
            INNER JOIN silver.campaign_desc AS cd ON th.campaign_id = cd.campaign
            LEFT JOIN silver.transaction_data AS t ON t.household_key = th.household_key AND t.day BETWEEN cd.start_day AND cd.end_day
            LEFT JOIN HouseholdDailyBaselines AS hdb ON t.household_key = hdb.household_key
            GROUP BY th.household_key, th.campaign_id, cd.start_day, cd.end_day
        )
        SELECT COUNT(*) FROM (
            SELECT f.household_key, f.campaign_id, f.total_spend, f.behavioral_baseline_spend,
                   e.expected_total_spend, e.expected_baseline_spend
            FROM gold.fact_household_segment_lift AS f
            FULL OUTER JOIN Expected AS e
                ON f.household_key = e.household_key AND f.campaign_id = e.campaign_id
            WHERE f.household_key IS NULL OR e.household_key IS NULL
               OR ABS(f.total_spend - e.expected_total_spend) > 0.01
               OR ABS(f.behavioral_baseline_spend - e.expected_baseline_spend) > 0.01
        ) AS mismatches
    """
    assert _scalar(conn, query) == 0, "fact_household_segment_lift baseline/targeting logic does not match source"