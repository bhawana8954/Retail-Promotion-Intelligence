## Directory Structure

```text
├── dataset/          # Source dataset files and samples
|   |
|   ├── samples/
|   │ ├── causal_data_sample.csv
|   │ └── transaction_data_sample.csv
|   ├── campaign_desc.csv
|   ├── campaign_table.csv
|   ├── coupon_redempt.csv
|   ├── coupon.csv
|   ├── hh_demographic.csv
|   ├── product.csv
|   └── Readme.md     # Dataset source and full-file download instructions
|
|
├── docs/             # Architecture, business logic, terminology, and dataset documentation
|   |
|   ├── business_logic_and_terminology.md                  # Business definitions, formulas, and terminology
|   ├── data_architecture.png                              # Overall Bronze → Silver → Gold architecture
|   ├── data_integration.png                               # End-to-end data integration and processing flow
|   ├── data_model.png                                     # Gold-layer star schema and table relationships
|   ├── Directory_Structure.md                             # Detailed repository structure and file descriptions
|   └── dunnhumby - The Complete Journey User Guide.pdf    # Original dataset user guide
|
|
├── powerbi/          # Power BI dashboard and report documentation
|   |
|   ├── Readme.md                                       # Dashboard pages, navigation, features, and key findings
|   └── retail_promotion_intelligence_dashboard.pdf     # Exported Power BI dashboard
|
|
├── python/           # Python-based analytical prototyping
|   |
|   └── baseline_and_lift_prototyping.ipynb      # Baseline and incremental lift analysis prototype
|
|
├── scripts/          # SQL Server database creation and ETL scripts
|   |
|   ├── bronze/       # Bronze layer: raw data tables and loading procedure
|   |   |
|   |   ├── 1_DDL_bronze.sql                # Bronze table definitions
|   |   ├── 2_procedure_load_bronze.sql     # Bronze data loading procedure
|   |   └── Readme.md                       # Bronze tables and execution instructions
|   |
|   ├── silver/       # Silver layer: cleaned, standardized, and transformed data
|   |   |
|   |   ├── 1_DDL_silver.sql                # Silver table definitions
|   |   ├── 2_procedure_load_silver.sql     # Bronze → Silver transformation and loading procedure
|   |   ├── 3_index_silver.sql              # Silver-layer indexes for query performance
|   |   └── Readme.md                       # Silver tables, transformations, and execution guide

|   ├── gold/         # Gold layer: analytical star schema, ETL, and indexes
|   |   |
|   |   ├── 1_DDL_gold.sql                  # Gold dimension and fact table definitions
|   |   ├── 2_procedure_load_gold.sql       # Silver → Gold transformation and loading procedure
|   |   ├── 3_index_gold.sql                # Gold-layer indexes for query performance
|   |   └── Readme.md                       # Gold tables, transformations, and execution guide
|   |
|   └── 0_DDL_initial_database.sql          # Database and schema initialization
|
|
├── tests/           # SQL and Python data quality validation for Silver and Gold layers
|   |
|   ├── procedure_check_data_quality_silver.sql            # Silver-layer SQL data quality checks
|   ├── procedure_check_data_quality_dimension_gold.sql    # Gold dimension data quality checks
|   ├── procedure_check_data_quality_fact_gold.sql         # Gold fact data quality checks
|   ├── test_data_quality_gold.py                          # Gold-layer Python/pytest validation tests
|   └── test_data_quality_silver.py                        # Silver-layer Python/pytest validation tests
|
|
└── README.md       # Project overview, insights, setup, and documentation guide