# Retail Promotion & Customer Loyalty Intelligence Platform

> **Are promotions driving real incremental sales, or are they simply subsidizing purchases customers would have made anyway?**

An end-to-end data analytics platform built on the Dunnhumby *"The Complete Journey"* retail dataset. It uses a Medallion (Bronze → Silver → Gold) architecture in SQL Server, with data quality testing in SQL as well as Python and a four-page Power BI dashboard, to separate genuine promotional lift from purchases that would have happened regardless.

---

## 🏗️ Architecture

![Data Architecture](./docs/data_architecture.png)

| Layer | Purpose |
|---|---|
| **Bronze** | Raw data loaded as-is from source CSVs, no transformation |
| **Silver** | Cleaned, standardized, deduplicated data with data quality checks and explicit unknown-record handling |
| **Gold** | Star-schema dimensional model with behavioral baselines, incremental lift, and wasted spend calculated |

See [`docs/data_model.png`](./docs/data_model.png) for the Gold-layer star schema and [`docs/data_integration.png`](./docs/data_integration.png) for the end-to-end data flow.

---

## 🛠️ Tech Stack

- **Database:** Microsoft SQL Server (T-SQL, stored procedures, indexing)
- **Data Quality & Prototyping:** SQL Server, Python (pandas, pytest)
- **Visualization:** Power BI Desktop / DAX
- **Version Control:** Git

---

## 📁 Repository Structure

```text
├── dataset/          # Source CSVs + sample files (see dataset/Readme.md for full-file download)
├── docs/             # Business logic reference, architecture diagrams, dataset user guide
├── powerbi/          # Dashboard PDF + report documentation
├── python/           # Baseline/lift prototyping notebook
├── scripts/
│   ├── bronze/       # Raw layer DDL + load procedure
│   ├── silver/       # Cleaned layer DDL + load procedure + indexing
│   ├── gold/         # Star-schema DDL + load procedure + indexing
│   └── 0_initial database.sql
├── tests/            # SQL + Python data quality checks (Silver & Gold)
└── README.md
```

---

## 📊 Key Insights

Full detail, visuals, and interpretation notes: [`powerbi/Readme.md`](./powerbi/Readme.md) · [Dashboard PDF](./powerbi/Retail_Promotion_Intelligence_Dashboard.pdf)

| Page | Headline Finding |
|---|---|
| **Executive Overview** | ~$1.45M in discount spend generated only ~$230.66K in incremental sales (~6× spend-to-lift, roughly $0.16 incremental sales per $1 spent). 18.97% of spend was wasted. |
| **Campaign & Coupon Performance** | Total incremental lift across campaigns is ~-$24.86M; most campaigns run 85–93% below baseline. Coupon redemption rate: 39.80%. |
| **In-Store Promotion Effectiveness** | Mailer promotions generate positive lift (~$1.15K/day); display promotions generate negative lift (~-$167.71/day). |
| **Household Segments & Loyalty** | Across 1,584 targeted households, average incremental lift is $690.28/household. Middle-age segments outperform the average by 59–78%. |

**Overall takeaway:** promotional strategy should move from broad, uniform discounting toward campaign-, mechanism-, and customer-segment-level evaluation. See [`docs/business_logic_and_terminology.md`](./docs/business_logic_and_terminology.md) for the definitions and formulas behind these numbers.

---

## 🚀 Getting Started — Full Execution Order

### Prerequisites

- Microsoft SQL Server + SSMS or Azure Data Studio
- Python 3.x with `pandas` and `pytest` installed
- Power BI Desktop
- Git

### 1. Clone the repository & get the full dataset

```bash
git clone <repo-url>
```

`transaction_data.csv` and `causal_data.csv` exceed GitHub's file-size limits and aren't committed — 500-row samples are included instead. Follow [`dataset/Readme.md`](./dataset/Readme.md) to download the full official files and place them in the expected path.

### 2. Initialize the database

Run:
```
scripts/0_initial database.sql
```
Creates the database and the `bronze`, `silver`, and `gold` schemas.

### 3. Build the Bronze layer

1. Run `scripts/bronze/1_DDL Bronze.sql`
2. Run `scripts/bronze/2_Procedure Load Bronze.sql`, then execute the load procedure it creates

See [`scripts/bronze/Readme.md`](./scripts/bronze/Readme.md) for table descriptions and the exact execution command.

### 4. Build the Silver layer

1. Run `scripts/silver/1_DDL Silver.sql`
2. Run `scripts/silver/2_Procedure Load Silver.sql`, then execute the load procedure it creates
3. Run `scripts/silver/3_Index Silver.sql`
4. Run data quality checks: `tests/procedure_check_data_quality_silver.sql` and `pytest tests/test_data_quality_silver.py`

See [`scripts/silver/Readme.md`](./scripts/silver/Readme.md) for table descriptions and the exact execution command.

### 5. Build the Gold layer

1. Run `scripts/gold/1_DDL Gold.sql`
2. Run `scripts/gold/2_Procedure Load Gold.sql`, then execute `EXEC gold.load_gold;`
3. Run `scripts/gold/3_Index Gold.sql`
4. Run data quality checks: `tests/procedure_dimension_check_data_quality_gold.sql`, `tests/procedure_fact_check_data_quality_gold.sql`, and `pytest tests/test_data_quality_gold.py`

See [`scripts/gold/Readme.md`](./scripts/gold/Readme.md) for table descriptions and the full execution guide.

### 6. Explore the Power BI dashboard

Open the `.pbix` in Power BI Desktop, connect to the `gold` schema, and refresh. See [`powerbi/Readme.md`](./powerbi/Readme.md) for navigation and page-by-page details.

---

## 📚 Documentation

| Doc | Covers |
|---|---|
| [`docs/business_logic_and_terminology.md`](./docs/business_logic_and_terminology.md) | Core business logic, formulas, DAX/Power BI terminology, glossary |
| [`scripts/bronze/Readme.md`](./scripts/bronze/Readme.md) | Bronze table descriptions + load procedure |
| [`scripts/silver/Readme.md`](./scripts/silver/Readme.md) | Silver table descriptions + load procedure + DQ checks |
| [`scripts/gold/Readme.md`](./scripts/gold/Readme.md) | Gold star-schema, table descriptions, transformations, execution guide |
| [`powerbi/Readme.md`](./powerbi/Readme.md) | Dashboard pages, interactive features, key findings |
| [`dataset/Readme.md`](./dataset/Readme.md) | Dataset source + full-file download instructions |

## Folder Structure
```
├── dataset/
|   ├── samples/
|   │ ├── causal_data_sample.csv
|   │ └── transaction_data_sample.csv
|   ├── campaign_desc.csv
|   ├── campaign_table.csv
|   ├── coupon_redempt.csv
|   ├── coupon.csv
|   ├── hh_demographic.csv
|   ├── product.csv
|   └── Readme.md    # source + download instructions for full files
├── docs/
|   ├── business_logic_and_terminology.md
|   ├── data_architecture.png
|   ├── data_integration.png
|   ├── data_model.png
|   └── dunnhumby - The Complete Journey User Guide.pdf
├── powerbi/
|   ├── Readme.md  
|   └── Retail_Promotion_Intelligence_Dashboard.pdf
├── python/
|   └── baseline_and_lift_prototyping.ipynb
├── scripts/
|   ├── bronze/
|   |   ├── 1_DDL Bronze.sql
|   |   ├── 2_Procedure Load Bronze.sql
|   |   └── Readme.md     # contain tables descriptions as well
|   ├── gold/
|   |   ├── 1_DDL Gold.sql
|   |   ├── 2_Procedure Load Gold.sql
|   |   ├── 3_Index Gold.sql
|   |   └── Readme.md    # contain tables descriptions as well
|   ├── silver/
|   |   ├── 1_DDL Silver.sql
|   |   ├── 2_Procedure Load Silver.sql
|   |   ├── 3_Index Silver.sql
|   |   └── Readme.md    # contain tables descriptions as well
|   └── 0_initial database.sql
├── tests/
|   ├── procedure_check_data_quality_silver.sql
|   ├── procedure_dimension_check_data_quality_gold.sql
|   ├── procedure_fact_check_data_quality_gold.sql
|   ├── test_data_quality_gold.py
|   └── test_data_quality_silver.py
├── .gitignore
└── README.md