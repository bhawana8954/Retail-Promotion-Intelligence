"""
======================================================================================
Test Module: Data Quality Checks (Gold Layer)
======================================================================================
Script Purpose:
    Runs automated data quality checks against the 'gold' schema tables using
    pytest, connecting via pyodbc:
        - Sequence and range coverage checks
        - Row count parity checks (Gold vs. Silver)
        - Duplicate primary key checks
        - Referential integrity (orphaned FKs)
        - Aggregation, sanity, and business rule validation

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
    connection.close()   # establishes a single database connection shared across all test functions.

def _scalar(conn, query):
    cursor = conn.cursor()
    cursor.execute(query)
    row = cursor.fetchone()
    return row[0] if row else None  # helper function: Executes a query and returns a single scalar result (e.g., count, sum).

# start table checks dictionary:
TABLE_CHECKS = {
    # dimension tables:
    "gold.dim_date": {
        "not_null_columns": ["DATE_KEY","FULL_DATE","DAY_NO","WEEK_NO","MONTH_NO","MONTH_NAME","QUARTER","YEAR","DAY_NAME"],
        "key_columns": ["DAY_NO"],
        "referential_integrity": [],},

    "gold.dim_campaign": {
            "not_null_columns": ["CAMPAIGN_ID", "CAMPAIGN_NAME", "START_DATE", "END_DATE"],
            "key_columns": ["CAMPAIGN_ID"],
            "referential_integrity": [],},

    "gold.dim_coupon": {
        "not_null_columns": ["COUPON_UPC", "CAMPAIGN_ID", "PRODUCT_ID"],
        "key_columns": ["COUPON_UPC", "CAMPAIGN_ID", "PRODUCT_ID"],
        "referential_integrity": [("CAMPAIGN_ID", "gold.dim_campaign", "CAMPAIGN_ID")
                                  ("PRODUCT_ID", "gold.dim_product", "PRODUCT_ID")],},

    "gold.dim_household": {
        "not_null_columns": ["HOUSEHOLD_KEY", "INCOME_DESC", "HOMEOWNER_DESC", "HOUSEHOLD_SIZE_DESC"],
        "key_columns": ["STORE_ID"],
        "referential_integrity": [],},

    "gold.dim_product": {
            "not_null_columns": ["PRODUCT_ID"],
            "key_columns": ["PRODUCT_ID"],
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
