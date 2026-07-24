# Dataset

**Source:** dunnhumby — "The Complete Journey" (official Source Files programme)
https://www.dunnhumby.com/source-files/

## What’s inside?
- A representation of household level transactions over two years from a group of 2,500 households who are frequent shoppers at a retailer

- All of a household’s purchases within the store, not just those from a limited number of categories

- Customer attributes and direct marketing contact history for select households

## Files

| File | Description | Rows (approx.) |
|---|---|---|
| `transaction_data.csv` | One row per product per basket — household, product, date, store, quantity, sales value, discounts | ~2.6M |
| `product.csv` | Product lookup — department, commodity, sub-commodity, manufacturer, brand | ~92K |
| `hh_demographic.csv` | Household demographics (age, income, household size, etc.) — covers a subset of all households | 801 |
| `campaign_desc.csv` | Campaign lookup — campaign ID, description, start/end day | 30 |
| `campaign_table.csv` | Which households were targeted by which campaign | ~7.2K |
| `coupon.csv` | Coupon lookup — links coupons to campaigns and products | ~124K |
| `coupon_redempt.csv` | Which households redeemed which coupons, and when | ~2.3K |
| `causal_data.csv` | Product-store-week level display/mailer promotional activity | ~36.8M |

## Folder Structure
```
dataset/
├── samples/
│ ├── transaction_data_sample.csv
│ └── causal_data_sample.csv
├── campaign_desc.csv
├── campaign_table.csv
├── coupon.csv
├── coupon_redempt.csv
├── hh_demographic.csv
├── product.csv
└── README.md # source + download instructions for full files

## Note on File Sizes

`transaction_data.csv` (~138 MB) and `causal_data.csv` (~679 MB) are **not included in this repo** as
both exceed GitHub's 100MB file size
limit. Small samples (first 500 rows) are included under `samples/`
so the file structure is visible without downloading the full dataset.

To reproduce the full pipeline, download all 8 files from dunnhumby's
Source Files page above and place them directly in this `dataset/`
folder before running the Bronze layer load scripts.