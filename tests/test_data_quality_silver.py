"""
======================================================================================
Test Module: Data Quality Checks (Silver Layer)
======================================================================================
Script Purpose:
    Runs automated data quality checks against the 'silver' schema tables using
    pytest, connecting via pyodbc:
        - NULL checks on required columns
        - Blank and whitespace checks
        - Duplicate key and grain checks
        - Referential integrity checks
        - Data validity checks
        - Unknown-value flag consistency checks
          (product, display, and mailer)
    Each check is parametrized where possible (NULLs, duplicates, referential
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
        "not_null_columns": ["COUPON_UPC", "PRODUCT_ID", "CAMPAIGN"],
        "key_columns": ["COUPON_UPC", "CAMPAIGN", "PRODUCT_ID"],
        "referential_integrity": [("CAMPAIGN", "silver.campaign_desc", "CAMPAIGN"),
                                  ("PRODUCT_ID", "silver.product", "PRODUCT_ID"),],},

    "silver.coupon_redempt": {
        "not_null_columns": ["HOUSEHOLD_KEY", "COUPON_UPC", "CAMPAIGN", "DAY"],
        "key_columns": ["HOUSEHOLD_KEY", "COUPON_UPC", "CAMPAIGN", "DAY"],
        "referential_integrity": [("CAMPAIGN", "silver.campaign_desc", "CAMPAIGN"),
                                  ("HOUSEHOLD_KEY", "silver.hh_demographic", "HOUSEHOLD_KEY"),
                                  ("COUPON_UPC", "silver.coupon", "COUPON_UPC"),],},

    "silver.hh_demographic": {
        "not_null_columns": ["HOUSEHOLD_KEY", "AGE_GROUP", "MARITAL_STATUS_GROUP", "INCOME_LEVEL", "HOMEOWNERSHIP_STATUS", "HOUSEHOLD_COMPOSITION", "HOUSEHOLD_SIZE", "KID_CATEGORY"],
        "key_columns": ["HOUSEHOLD_KEY"],
        "referential_integrity": [],},

    "silver.product": {
        "not_null_columns": ["PRODUCT_ID", "MANUFACTURER"],
        "key_columns": ["PRODUCT_ID"],
        "referential_integrity": [],},

    "silver.causal_data": {
        "not_null_columns": ["PRODUCT_ID", "STORE_ID", "WEEK_NO", "DISPLAY", "MAILER"],
        "key_columns": ["PRODUCT_ID", "STORE_ID", "WEEK_NO", "DISPLAY", "MAILER"],
        "referential_integrity": [("PRODUCT_ID", "silver.product", "PRODUCT_ID"),],},

    "silver.transaction_data": {
        "not_null_columns": ["HOUSEHOLD_KEY", "PRODUCT_ID", "BASKET_ID", "DAY", "STORE_ID"],
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

# campaign_desc: description must not be blank
def test_campaign_desc_description_not_blank(conn):
    """DESCRIPTION must not be NULL, blank, or whitespace-only."""
    query = """
        SELECT COUNT(*)
        FROM silver.campaign_desc
        WHERE NULLIF(TRIM(description), '') IS NULL
    """
    blank_count = _scalar(conn, query)

    assert blank_count == 0, (
        f"silver.campaign_desc: found {blank_count} blank or whitespace-only descriptions"
    )

# campaign_desc: campaign window must be logically valid
def test_campaign_desc_date_window_valid(conn):
    """START_DAY must not be greater than END_DAY."""
    query = """
        SELECT COUNT(*)
        FROM silver.campaign_desc
        WHERE start_day > end_day
    """
    invalid_window_count = _scalar(conn, query)

    assert invalid_window_count == 0, (
        f"silver.campaign_desc: found {invalid_window_count} rows "
        f"where START_DAY is greater than END_DAY"
    )

# campaign_table: description must not be blank
def test_campaign_table_description_not_blank(conn):
    """DESCRIPTION must not be NULL, blank, or whitespace-only."""
    query = """
        SELECT COUNT(*)
        FROM silver.campaign_table
        WHERE NULLIF(TRIM(description), '') IS NULL
    """
    blank_count = _scalar(conn, query)

    assert blank_count == 0, (
        f"silver.campaign_table: found {blank_count} "
        f"blank or whitespace-only descriptions"
    )

# coupon: coupon_upc must not be blank
def test_coupon_upc_not_blank(conn):
    """COUPON_UPC must not be NULL, blank, or whitespace-only."""
    query = """
        SELECT COUNT(*)
        FROM silver.coupon
        WHERE NULLIF(TRIM(coupon_upc), '') IS NULL
    """
    blank_count = _scalar(conn, query)

    assert blank_count == 0, (
        f"silver.coupon: found {blank_count} blank or whitespace-only coupon_upc values"
    )

# coupon_redempt: coupon_upc must not be blank
def test_coupon_redempt_upc_not_blank(conn):
    """COUPON_UPC must not be NULL, blank, or whitespace-only."""
    query = """
        SELECT COUNT(*)
        FROM silver.coupon_redempt
        WHERE NULLIF(TRIM(coupon_upc), '') IS NULL
    """
    blank_count = _scalar(conn, query)

    assert blank_count == 0, (
        f"silver.coupon_redempt: found {blank_count} "
        f"blank or whitespace-only coupon_upc values"
    )

# coupon_redempt: coupon_upc + campaign must exist in coupon
def test_coupon_redempt_coupon_campaign_referential_integrity(conn):
    """COUPON_UPC + CAMPAIGN combinations must exist in silver.coupon."""
    query = """
        SELECT COUNT(*)
        FROM silver.coupon_redempt AS c
        LEFT JOIN (
            SELECT DISTINCT coupon_upc, campaign
            FROM silver.coupon
        ) AS p
            ON c.coupon_upc = p.coupon_upc
           AND c.campaign = p.campaign
        WHERE c.coupon_upc IS NOT NULL
          AND c.campaign IS NOT NULL
          AND p.coupon_upc IS NULL
    """
    orphan_count = _scalar(conn, query)

    assert orphan_count == 0, (
        f"silver.coupon_redempt: found {orphan_count} rows where "
        f"COUPON_UPC + CAMPAIGN has no match in silver.coupon"
    )

# product: unknown product flag must contain only 0 or 1
def test_product_unknown_flag_valid(conn):
    """is_unknown_product must contain only 0 or 1 and must not be NULL."""
    query = """
        SELECT COUNT(*)
        FROM silver.product
        WHERE is_unknown_product NOT IN (0, 1)
           OR is_unknown_product IS NULL
    """
    invalid_count = _scalar(conn, query)

    assert invalid_count == 0, (
        f"silver.product: found {invalid_count} rows with invalid "
        f"is_unknown_product flag values"
    )

# product: unknown product flag must match commodity description
def test_product_unknown_flag_consistency(conn):
    """is_unknown_product must correctly reflect commodity_desc."""
    query = """
        SELECT COUNT(*)
        FROM silver.product
        WHERE (
                (
                    (NULLIF(TRIM(commodity_desc), '') IS NULL
                     OR UPPER(TRIM(commodity_desc)) = 'UNKNOWN')
                    AND is_unknown_product <> 1
                )
                OR
                (
                    NULLIF(TRIM(commodity_desc), '') IS NOT NULL
                    AND UPPER(TRIM(commodity_desc)) <> 'UNKNOWN'
                    AND is_unknown_product <> 0
                )
              )
    """
    mismatch_count = _scalar(conn, query)

    assert mismatch_count == 0, (
        f"silver.product: found {mismatch_count} rows where "
        f"is_unknown_product is inconsistent with commodity_desc"
    )

# causal_data: display unknown flag must match display value
def test_causal_data_unknown_display_flag_consistency(conn):
    """is_unknown_display_code must correctly reflect display='UNKNOWN'."""
    query = """
        SELECT COUNT(*)
        FROM silver.causal_data
        WHERE (
                (UPPER(TRIM(display)) = 'UNKNOWN'
                 AND is_unknown_display_code <> 1)
                OR
                (UPPER(TRIM(display)) <> 'UNKNOWN'
                 AND is_unknown_display_code <> 0)
                OR
                is_unknown_display_code IS NULL
              )
    """
    mismatch_count = _scalar(conn, query)

    assert mismatch_count == 0, (
        f"silver.causal_data: found {mismatch_count} rows with "
        f"inconsistent is_unknown_display_code flag"
    )

# causal_data: mailer unknown flag must match mailer value
def test_causal_data_unknown_mailer_flag_consistency(conn):
    """is_unknown_mailer_code must correctly reflect mailer='UNKNOWN'."""
    query = """
        SELECT COUNT(*)
        FROM silver.causal_data
        WHERE (
                (UPPER(TRIM(mailer)) = 'UNKNOWN'
                 AND is_unknown_mailer_code <> 1)
                OR
                (UPPER(TRIM(mailer)) <> 'UNKNOWN'
                 AND is_unknown_mailer_code <> 0)
                OR
                is_unknown_mailer_code IS NULL
              )
    """
    mismatch_count = _scalar(conn, query)

    assert mismatch_count == 0, (
        f"silver.causal_data: found {mismatch_count} rows with "
        f"inconsistent is_unknown_mailer_code flag"
    )

# causal_data: display and mailer must not be blank
def test_causal_data_display_mailer_not_blank(conn):
    """DISPLAY and MAILER must not be NULL, blank, or whitespace-only."""
    query = """
        SELECT COUNT(*)
        FROM silver.causal_data
        WHERE NULLIF(TRIM(display), '') IS NULL
           OR NULLIF(TRIM(mailer), '') IS NULL
    """
    blank_count = _scalar(conn, query)

    assert blank_count == 0, (
        f"silver.causal_data: found {blank_count} rows with "
        f"blank or whitespace-only DISPLAY/MAILER values"
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

