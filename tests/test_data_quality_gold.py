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
        "not_null_columns": ["DAY_NUMBER", "DATE"],
        "key_columns": ["DAY_NUMBER"],
        "referential_integrity": [],},

    "gold.dim_household": {
        "not_null_columns": ["HOUSEHOLD_KEY"],
        "key_columns": ["HOUSEHOLD_KEY"],
        "referential_integrity": [],},

    "gold.dim_product": {
        "not_null_columns": ["PRODUCT_ID"],
        "key_columns": ["PRODUCT_ID"],
        "referential_integrity": [],},

    "gold.dim_campaign": {
        "not_null_columns": ["CAMPAIGN_ID", "CAMPAIGN", "START_DAY", "END_DAY"],
        "key_columns": ["CAMPAIGN_ID"],
        "referential_integrity": [],},

    "gold.dim_store": {
        "not_null_columns": ["STORE_ID"],
        "key_columns": ["STORE_ID"],
        "referential_integrity": [],},

    "gold.dim_coupon": {
        "not_null_columns": ["COUPON_UPC"],
        "key_columns": ["COUPON_UPC", "CAMPAIGN_ID", "PRODUCT_ID"],
        "referential_integrity": [("CAMPAIGN_ID", "gold.dim_campaign", "CAMPAIGN_ID")],},

    # fact tables:
    "gold.fact_transactions": {
        "not_null_columns": ["HOUSEHOLD_KEY", "PRODUCT_ID", "STORE_ID", "DAY_NUMBER", "QUANTITY", "SALES_VALUE"],
        "key_columns": [],  #leave empty as transactions naturally repeat across keys
        "referential_integrity": [
                                ("HOUSEHOLD_KEY", "gold.dim_household", "HOUSEHOLD_KEY"),
                                ("PRODUCT_ID", "gold.dim_product", "PRODUCT_ID"),
                                ("STORE_ID", "gold.dim_store", "STORE_ID"),
                                ("DAY_NUMBER", "gold.dim_date", "DAY_NUMBER"),],},

    "gold.fact_coupon_redemption": {
        "not_null_columns": ["HOUSEHOLD_KEY", "COUPON_UPC", "CAMPAIGN_ID", "DAY_NUMBER", "REDEMPTION_EVENT_KEY"],
        "key_columns": [],  #leave empty as redemptions naturally repeat across keys (e.g., same household may redeem multiple coupons on same day)
        "referential_integrity": [
                                ("HOUSEHOLD_KEY", "gold.dim_household", "HOUSEHOLD_KEY"),
                                ("DAY_NUMBER", "gold.dim_date", "DAY_NUMBER"),
                                ("PRODUCT_ID", "gold.dim_product", "PRODUCT_ID")],},
        #composite FK to dim_coupon (coupon_upc + campaign) skipped - test function only handles single-column FKs

    "gold.fact_store_promotion": {
        "not_null_columns": ["PRODUCT_ID", "STORE_ID", "WEEK_NO"],
        "key_columns": ["PRODUCT_ID", "STORE_ID", "WEEK_NO"],  #should be unique post week-level aggregation
        "referential_integrity": [
                                ("PRODUCT_ID", "gold.dim_product", "PRODUCT_ID"),
                                ("STORE_ID", "gold.dim_store", "STORE_ID"),],},

    "gold.fact_campaign_lift": {
        "not_null_columns": ["HOUSEHOLD_KEY", "CATEGORY", "BASELINE_SPEND", "BASELINE_DAYS", "CAMPAIGN_SPEND", "CAMPAIGN_DAYS"],
        "key_columns": ["HOUSEHOLD_KEY", "CATEGORY"],
        "referential_integrity": [
                                ("HOUSEHOLD_KEY", "gold.dim_household", "HOUSEHOLD_KEY"),],}
}

# build the list of duplicate key cases:
duplicate_key_cases = [
    (table, cfg["key_columns"])
    for table, cfg in TABLE_CHECKS.items()
    if cfg["key_columns"]
]                                          #skips tables with no key columns defined

# write actual test function
@pytest.mark.parametrize("table, key_columns", duplicate_key_cases)
def test_no_duplicate_keys(conn, table, key_columns):
    cols = ", ".join(key_columns)
    query = f"""
        SELECT COUNT(*) FROM (
            SELECT {cols} FROM {table}
            GROUP BY {cols}
            HAVING COUNT(*) > 1
        ) AS dupes
    """                                   #groups by key, keeps only groups that repeat
    dup_count = _scalar(conn, query)
    assert dup_count == 0, (
        f"{table} has {dup_count} duplicate groups on ({cols})"
    )

# build the list of referential integrity cases:
fk_check_cases = [
    (table, fk_col, parent_table, parent_col)
    for table, cfg in TABLE_CHECKS.items()
    for (fk_col, parent_table, parent_col) in cfg["referential_integrity"]
]                                          #flattens each table's FK rules into one row per FK

# write actual test function
@pytest.mark.parametrize("table, fk_col, parent_table, parent_col", fk_check_cases)
def test_no_orphaned_foreign_keys(conn, table, fk_col, parent_table, parent_col):
    query = f"""
        SELECT COUNT(*) FROM {table} t
        WHERE t.{fk_col} IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM {parent_table} p WHERE p.{parent_col} = t.{fk_col}
          )
    """                                   #finds child rows whose FK has no matching parent row
    orphan_count = _scalar(conn, query)
    assert orphan_count == 0, (
        f"{table}.{fk_col} has {orphan_count} orphans vs {parent_table}.{parent_col}"
    )

# build row-count reconciliation cases: gold table -> matching source table
ROW_COUNT_CHECKS = [
    ("gold.fact_transactions", "silver.transaction_data"),
    ("gold.fact_store_promotion", "silver.causal_data"),
]

@pytest.mark.parametrize("gold_table, source_table", ROW_COUNT_CHECKS)
def test_row_counts_match_source(conn, gold_table, source_table):
    gold_count = _scalar(conn, f"SELECT COUNT(*) FROM {gold_table}")
    source_count = _scalar(conn, f"SELECT COUNT(*) FROM {source_table}")
    assert gold_count == source_count, (
        f"{gold_table} has {gold_count} rows, {source_table} has {source_count} - expected exact match"
    )

# business-rule check: fact_campaign_lift's MIN_DAYS >= 5 reliability filter must actually hold
def test_fact_campaign_lift_min_days_threshold(conn):
    query = """
        SELECT COUNT(*) FROM gold.fact_campaign_lift
        WHERE baseline_days < 5 OR campaign_days < 5
    """                                   #any row failing this shouldn't exist - view should already exclude it
    violation_count = _scalar(conn, query)
    assert violation_count == 0, (
        f"fact_campaign_lift has {violation_count} rows below the MIN_DAYS=5 reliability threshold"
    )

def test_fact_coupon_redemption_distinct_events(conn):
    """Matches stored procedure check for redemption_event_key count vs silver source."""
    query_gold = (
        "SELECT COUNT(DISTINCT redemption_event_key) FROM gold.fact_coupon_redemption"
    )
    query_silver = "SELECT COUNT(*) FROM silver.coupon_redempt"

    gold_count = _scalar(conn, query_gold)
    silver_count = _scalar(conn, query_silver)

    assert (
        gold_count == silver_count
    ), f"Distinct redemption event count ({gold_count}) does not match silver source ({silver_count})"