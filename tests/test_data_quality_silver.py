"""
======================================================================================
Test Module: Data Quality Checks (Silver Layer)
======================================================================================
Script Purpose:
    Runs automated data quality checks against the 'silver' schema tables using
    pytest, connecting via pyodbc:
        - Null checks on required columns
        - Duplicate key checks
        - Referential integrity checks
        - is_unknown_mailer_code flag checks (silver.causal_data)
    Each check is parametrized where possible (nulls, duplicates, referential
    integrity) so a single test function covers every configured table/column
    combination, rather than repeating similar code per table.

Usage Example:
    & "D:\Python 3.14.0\python.exe" -m pytest tests/test_data_quality_silver.py -v
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
    "silver.campaign_desc": {
        "not_null_columns": ["CAMPAIGN", "DESCRIPTION", "START_DAY", "END_DAY"],
        "key_columns": ["CAMPAIGN"],
        "referential_integrity": [],},

    "silver.campaign_table": {
        "not_null_columns": ["HOUSEHOLD_KEY", "CAMPAIGN"],
        "key_columns": ["HOUSEHOLD_KEY", "CAMPAIGN"],
        "referential_integrity": [("CAMPAIGN", "silver.campaign_desc", "CAMPAIGN"),
                                  ("HOUSEHOLD_KEY", "silver.hh_demographic", "HOUSEHOLD_KEY"),],},

    "silver.coupon": {
        "not_null_columns": ["COUPON_UPC", "CAMPAIGN"],
        "key_columns": ["COUPON_UPC", "CAMPAIGN", "PRODUCT_ID"],
        "referential_integrity": [("CAMPAIGN", "silver.campaign_desc", "CAMPAIGN"),],},

    "silver.coupon_redempt": {
        "not_null_columns": ["HOUSEHOLD_KEY", "COUPON_UPC", "CAMPAIGN"],
        "key_columns": ["HOUSEHOLD_KEY", "COUPON_UPC", "CAMPAIGN", "DAY"],
        "referential_integrity": [("CAMPAIGN", "silver.campaign_desc", "CAMPAIGN"),
                                  ("HOUSEHOLD_KEY", "silver.hh_demographic", "HOUSEHOLD_KEY"),
                                  ("COUPON_UPC", "silver.coupon", "COUPON_UPC"),],},

    "silver.hh_demographic": {
        "not_null_columns": ["HOUSEHOLD_KEY"],
        "key_columns": ["HOUSEHOLD_KEY"],
        "referential_integrity": [],},

    "silver.product": {
        "not_null_columns": ["PRODUCT_ID"],
        "key_columns": ["PRODUCT_ID"],
        "referential_integrity": [],},

    "silver.causal_data": {
        "not_null_columns": ["PRODUCT_ID", "STORE_ID", "WEEK_NO"],
        "key_columns": ["PRODUCT_ID", "STORE_ID", "WEEK_NO", "DISPLAY", "MAILER"],
        "referential_integrity": [("PRODUCT_ID", "silver.product", "PRODUCT_ID"),],},

    "silver.transaction_data": {
        "not_null_columns": ["HOUSEHOLD_KEY", "PRODUCT_ID", "BASKET_ID", "DAY"],
        "key_columns": ["HOUSEHOLD_KEY", "BASKET_ID", "PRODUCT_ID", "DAY"],
        "referential_integrity": [("HOUSEHOLD_KEY", "silver.hh_demographic", "HOUSEHOLD_KEY"),
                                  ("PRODUCT_ID", "silver.product", "PRODUCT_ID"),],},
}

# build a list of null checks:
null_check_cases = [
    (table, column)
    for table, cfg in TABLE_CHECKS.items()
    for column in cfg["not_null_columns"]
]                                          #list comprehension used here

# write actual test function
@pytest.mark.parametrize("table, column", null_check_cases)
def test_no_unexpected_nulls(conn, table, column):
    total = _scalar(conn, f"SELECT COUNT(*) FROM {table}")
    nulls = _scalar(conn, f"SELECT COUNT(*) FROM {table} WHERE {column} IS NULL")
    null_rate = nulls / total if total else 0
    assert null_rate == 0, (
        f"{table}.{column}: {nulls} nulls out of {total} rows"
    )

# build the list of duplicate key cases:
key_check_cases = [(table, cfg["key_columns"]) for table, cfg in TABLE_CHECKS.items()]

# write the duplicate key test function:
@pytest.mark.parametrize("table, key_columns", key_check_cases)
def test_no_duplicate_keys(conn, table, key_columns):
    key_list = ", ".join(key_columns)
    query = f"""
        SELECT COUNT(*) FROM (
            SELECT {key_list}
            FROM {table}
            GROUP BY {key_list}
            HAVING COUNT(*) > 1
        ) AS dupes
    """
    duplicate_key_count = _scalar(conn, query)

    assert duplicate_key_count == 0, (
        f"{table}: found {duplicate_key_count} duplicate key combinations on ({key_list})"
    )

# build list of referential integrity cases:
ri_check_cases = [
    (table, fk_column, parent_table, parent_column)
    for table, cfg in TABLE_CHECKS.items()
    for (fk_column, parent_table, parent_column) in cfg["referential_integrity"]
]

# write the referential integrity test function:
@pytest.mark.parametrize("table, fk_column, parent_table, parent_column", ri_check_cases)
def test_referential_integrity(conn, table, fk_column, parent_table, parent_column):
    query = f"""
        SELECT COUNT(*)
        FROM {table} c
        WHERE c.{fk_column} IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM {parent_table} p
              WHERE p.{parent_column} = c.{fk_column}
          )
    """
    orphan_count = _scalar(conn, query)

    assert orphan_count == 0, (
        f"{table}.{fk_column}: {orphan_count} rows have no match in {parent_table}.{parent_column}"
    )

# causal_data: is_unknown_mailer_code flag checks 
def test_causal_data_unknown_mailer_flag_consistency(conn):
    """Every row with mailer='0' must be flagged 1, and only those rows."""
    query = """
        SELECT COUNT(*)
        FROM silver.causal_data
        WHERE (mailer = '0' AND is_unknown_mailer_code = 0)
           OR (mailer <> '0' AND is_unknown_mailer_code = 1)
    """
    mismatched_rows = _scalar(conn, query)

    assert mismatched_rows == 0, (
        f"silver.causal_data: found {mismatched_rows} rows with inconsistent is_unknown_mailer_code flag"
    )

def test_causal_data_unknown_mailer_count(conn):
    """Sanity check against the known investigated count post-deduplication."""
    flagged_rows = _scalar(conn, "SELECT COUNT(*) FROM silver.causal_data WHERE is_unknown_mailer_code = 1")

    assert flagged_rows == 11534087, (
        f"silver.causal_data: expected 11534087 flagged rows, got {flagged_rows}"
    )