# SaaS Churn Analysis & Revenue Analytics Project

> A comprehensive end-to-end SaaS analytics project — covering SQL-based data cleaning, churn analysis, revenue metrics, and an interactive Power BI dashboard to uncover retention risk and growth opportunities.

![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=flat)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat&logo=mysql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?style=flat&logo=powerbi&logoColor=black)

---

## 📚 Table of Contents

- [📁 Repository Structure](#-repository-structure)
- [🎯 Project Objectives](#-project-objectives)
- [📊 Dataset Overview](#-dataset-overview)
- [🧹 SQL Data Cleaning](#-sql-data-cleaning----churn_cleaning_datasql)
- [🗄️ SQL Analysis](#️-sql-analysis----churn_mysqlsql)
- [📊 Power BI Dashboard](#-power-bi-dashboard----churn_analysis_and_saas_revenuepbix)
- [🛠️ Tech Stack](#️-tech-stack)
- [🚀 Getting Started](#-getting-started)
- [🗃️ Database Schema](#️-database-schema)
- [📌 Key Insights](#-key-insights)
- [👤 Author](#-author)

---

## 🎯 Project Objectives

This project performs a **full-cycle SaaS analytics workflow** — from raw data quality checks through to executive-level revenue dashboards. The key objectives are:

- 🧹 **Clean** and validate subscription and revenue data across 9 quality dimensions
- 🔍 **Analyse** churn rates, trends, and drivers using SQL across multiple business lenses
- 💰 **Model** key SaaS metrics — MRR, CLV, CAC, CLV:CAC ratio, and at-risk MRR
- 📊 **Visualise** churn and revenue performance through an interactive Power BI dashboard
- 🎯 **Identify** high-risk customer segments and prioritise retention interventions
- 📈 **Answer** 15 real-world SaaS business questions spanning churn, revenue, usage, and customer profitability

---

## 📁 Repository Structure

```
churn_analysis_and_saas_revenue/
│
├── 📄 subscriptions.csv               # Raw subscription-level customer dataset
├── 📄 celan_subscriptions.csv         # Cleaned subscriptions dataset
├── 📄 monthly_revenue.csv             # Raw monthly aggregated revenue & churn metrics
├── 📄 clean_monthly_revenue.csv       # Cleaned monthly revenue dataset
│
├── 🧹 churn_cleaning_data.sql         # Data quality checks & validation scripts
├── 🗄️  churn_mysql.sql                # 15 analytical SQL queries across churn & revenue
│
└── 📊 churn_analysis_and_saas_revenue.pbix   # Interactive Power BI dashboard
```

---

## 📊 Dataset Overview

### 🗂️ `subscriptions.csv` — Customer-Level Dataset

| Property | Value |
|---|---|
| Rows | 600 |
| Columns | 17 |
| Missing Values | None ✅ |
| Duplicates | None ✅ |

#### 📋 Columns

| # | Column | Type | Description |
|---|---|---|---|
| 1 | `customer_id` | str | Unique customer identifier |
| 2 | `plan` | str | Subscription plan tier |
| 3 | `billing_cycle` | str | Monthly / Annual |
| 4 | `industry` | str | Customer's industry vertical |
| 5 | `company_size` | str | Size segment (e.g. SMB, Mid-Market, Enterprise) |
| 6 | `seats` | int | Number of seats on the subscription |
| 7 | `monthly_revenue` | float | Monthly revenue contributed by the customer |
| 8 | `acquisition_channel` | str | How the customer was acquired |
| 9 | `region` | str | Geographic region |
| 10 | `signup_date` | date | Date the customer signed up |
| 11 | `churned` | str | Whether the customer has churned: Yes / No |
| 12 | `churn_date` | date | Date of churn (NULL if active) |
| 13 | `churn_reason` | str | Self-reported or attributed churn reason |
| 14 | `support_tickets_12mo` | int | Support tickets raised in the last 12 months |
| 15 | `nps_score` | int | Net Promoter Score (0–10) |
| 16 | `feature_usage_pct` | float | Percentage of features actively used (0–100) |
| 17 | `upgraded` | str | Whether the customer has ever upgraded their plan |

---

### 🗂️ `monthly_revenue.csv` — Aggregated Monthly Metrics

| Property | Value |
|---|---|
| Rows | 48 |
| Columns | 8 |
| Missing Values | None ✅ |
| Duplicates | None ✅ |

| # | Column | Type | Description |
|---|---|---|---|
| 1 | `month` | str | Month in YYYY-MM format |
| 2 | `total_mrr` | float | Total Monthly Recurring Revenue |
| 3 | `new_customers` | int | New customers acquired that month |
| 4 | `churned_customers` | int | Customers lost that month |
| 5 | `total_active_customers` | int | Active customer count at month end |
| 6 | `monthly_churn_rate_pct` | float | Churn rate percentage for that month |
| 7 | `avg_revenue_per_customer` | float | Average MRR per active customer |
| 8 | `customer_acquisition_cost` | float | Blended CAC for the month |

---

## 🧹 SQL Data Cleaning — `churn_cleaning_data.sql`

A comprehensive data quality validation script covering **9 check categories** across both the `subscriptions` and `monthly_revenue` tables:

| # | Check Category | What It Validates |
|---|---|---|
| 1 | **Duplicate Checks** | Customer-level duplicates and full-row duplicate detection |
| 2 | **Missing Values** | NULL audit across all 17 columns in `subscriptions` |
| 3 | **Value Consistency** | Validates `churned`, `billing_cycle`, and `plan` field distributions |
| 4 | **Range Validation** | NPS score (0–10), feature usage (0–100), negative revenue/seats |
| 5 | **Date Consistency** | Future signup/churn dates, churn before signup detection |
| 6 | **Logical Integrity** | Churned with no churn date; active with a churn date |
| 7 | **Outlier Detection** | Z-score method for revenue outliers; zero-usage active customers |
| 8 | **Monthly Revenue Quality** | NULLs, negatives, and duplicate months in `monthly_revenue` |
| 9 | **Cross-Table Sanity** | Active/churned counts reconciled between both tables |

### 🔍 Sample Check

```sql
-- Logical mismatch: churned but no churn date
SELECT customer_id, churned, churn_date
FROM subscriptions
WHERE churned = 'Yes' AND churn_date IS NULL;

-- Revenue outliers via z-score
WITH rev_stats AS (
    SELECT AVG(monthly_revenue) AS avg_rev,
           STDDEV(monthly_revenue) AS std_rev
    FROM subscriptions
)
SELECT s.customer_id, s.plan, s.monthly_revenue,
       (s.monthly_revenue - rs.avg_rev) / NULLIF(rs.std_rev, 0) AS z_score
FROM subscriptions s
CROSS JOIN rev_stats rs
WHERE ABS((s.monthly_revenue - rs.avg_rev) / NULLIF(rs.std_rev, 0)) > 3;
```

---

## 🗄️ SQL Analysis — `churn_mysql.sql`

15 business-driven SQL queries written in **MySQL**, covering churn drivers, revenue performance, customer lifetime value, and at-risk identification:

| # | Analysis | Key Concepts |
|---|---|---|
| 1 | Overall Churn Rate | `CASE`, `COUNT`, aggregation |
| 2 | Monthly Churn Trend | `LAG`, `STR_TO_DATE`, MoM & YoY change, trend classification |
| 3 | Churn Rate by Plan | `GROUP BY`, `HAVING`, conditional aggregation |
| 4 | Billing Cycle Impact on Retention | Monthly vs Annual churn comparison |
| 5 | Top Churn Reasons | Window `SUM OVER()` for percentage of total |
| 6 | Churn Reasons by Plan | `PARTITION BY` plan, `HAVING` for significance filter |
| 7 | Churn Reasons by Company Size | Segmented root cause analysis |
| 8 | Churn by Acquisition Channel | Channel-level churn, NPS, and revenue comparison |
| 9 | High-Risk Customer Segments | Multi-metric segment profiling |
| 10 | Monthly MRR Growth Analysis | New MRR, churned MRR, net new MRR, MoM growth % |
| 11 | CLV by Plan | Churn-rate-based lifespan × average MRR |
| 12 | CLV vs CAC Analysis | `CROSS JOIN` CAC table, CLV:CAC ratio, profitability classification |
| 13 | Usage, Satisfaction & Churn | Feature usage banding, NPS, and churn correlation |
| 14 | At-Risk Customer Summary | Active customers with `feature_usage_pct < 50`, MRR at risk |
| 15 | High-Risk Customer List | Composite risk scoring with `Critical / At Risk / Monitor` flags |

### 🔍 Sample Business Questions Answered

- Which subscription plans have the highest churn rates?
- Is annual billing genuinely better for retention than monthly?
- What are the top 3 reasons customers leave, and do they differ by plan?
- Which acquisition channels produce the most loyal (low-churn, high-NPS) customers?
- What is the CLV:CAC ratio per plan, and which plans are highly profitable vs low profitability?
- How much active MRR is currently at risk from low-engagement customers?
- Which active customers should be flagged as Critical, At Risk, or Monitor?

### 🔍 Sample Query — CLV vs CAC

```sql
WITH clv_calc AS (
    SELECT plan,
           AVG(monthly_revenue) AS avg_mrr,
           SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS churn_rate
    FROM subscriptions
    GROUP BY plan
),
cac_calc AS (
    SELECT AVG(customer_acquisition_cost) AS avg_cac
    FROM monthly_revenue
)
SELECT
    c.plan,
    ROUND(c.avg_mrr * (1 / NULLIF(c.churn_rate, 0)), 2) AS estimated_clv,
    ROUND(k.avg_cac, 2) AS avg_cac,
    ROUND((c.avg_mrr * (1 / NULLIF(c.churn_rate, 0))) / NULLIF(k.avg_cac, 0), 2) AS clv_cac_ratio,
    CASE
        WHEN ((c.avg_mrr * (1 / NULLIF(c.churn_rate, 0))) / NULLIF(k.avg_cac, 0)) >= 3 THEN 'Highly Profitable'
        WHEN ((c.avg_mrr * (1 / NULLIF(c.churn_rate, 0))) / NULLIF(k.avg_cac, 0)) >= 1.5 THEN 'Moderately Profitable'
        ELSE 'Low Profitability'
    END AS profitability_status
FROM clv_calc c
CROSS JOIN cac_calc k
ORDER BY clv_cac_ratio DESC;
```

---

## 📊 Power BI Dashboard — `churn_analysis_and_saas_revenue.pbix`

Interactive dashboard built in **Microsoft Power BI** providing visual insights into:

- 📉 Churn rate trends over time (MoM and YoY)
- 💰 MRR growth, new MRR, and churned MRR by month
- 🏷️ Churn breakdown by plan, billing cycle, industry, and company size
- 📡 Acquisition channel performance (churn rate, NPS, revenue)
- ⚠️ At-risk MRR and high-risk customer identification
- 🔄 CLV:CAC ratio and plan-level profitability

Open `churn_analysis_and_saas_revenue.pbix` in **Microsoft Power BI Desktop** to explore the full dashboard.

---

## 🛠️ Tech Stack

| Tool | Purpose |
|---|---|
| ![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat&logo=mysql&logoColor=white) | Data cleaning & analytical SQL queries |
| ![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black) | Interactive churn & revenue dashboards |

---

## 🚀 Getting Started

### Prerequisites

- MySQL 8.0+
- Microsoft Power BI Desktop

### Run the Data Cleaning Script

```sql
-- Connect to your MySQL instance and run:
USE saas_analytics;
-- Then execute churn_cleaning_data.sql to validate data quality
```

### Run the Analytics Queries

```sql
-- After loading subscriptions and monthly_revenue tables:
USE saas_analytics;
-- Execute churn_mysql.sql to run all 15 analytical queries
```

### Load the Raw Data

```sql
-- Import CSVs into MySQL:
LOAD DATA INFILE 'subscriptions.csv'
INTO TABLE subscriptions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'monthly_revenue.csv'
INTO TABLE monthly_revenue
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
```

### Open the Power BI Dashboard

Open `churn_analysis_and_saas_revenue.pbix` in **Microsoft Power BI Desktop** and refresh the data source to point to your local CSV files.

---

## 🗃️ Database Schema

```
subscriptions
    ├── customer_id          (PK)
    ├── plan
    ├── billing_cycle
    ├── industry
    ├── company_size
    ├── seats
    ├── monthly_revenue
    ├── acquisition_channel
    ├── region
    ├── signup_date
    ├── churned
    ├── churn_date
    ├── churn_reason
    ├── support_tickets_12mo
    ├── nps_score
    ├── feature_usage_pct
    └── upgraded

monthly_revenue
    ├── month                (PK)
    ├── total_mrr
    ├── new_customers
    ├── churned_customers
    ├── total_active_customers
    ├── monthly_churn_rate_pct
    ├── avg_revenue_per_customer
    └── customer_acquisition_cost
```

> **Note on assumptions:** CLV is calculated as `Avg Monthly Revenue × Estimated Customer Lifespan (1 / churn_rate)`. CAC is a blended average due to missing plan-level acquisition data. Net New MRR is used instead of true NRR as expansion/contraction data is not available.

---

## 📌 Key Insights

- 📋 **Two datasets** — customer-level subscriptions and aggregated monthly revenue — cross-validated for consistency
- 🧹 **9 data quality dimensions** checked before any analysis — from nulls and duplicates to z-score outlier detection
- 💰 **MRR growth decomposed** into new MRR vs churned MRR with full MoM and YoY tracking
- ⚠️ **At-risk MRR quantified** — active customers with `feature_usage_pct < 50` flagged with total revenue exposure
- 🎯 **Composite risk scoring** ranks active customers as Critical, At Risk, or Monitor for targeted intervention
- 🔄 **CLV:CAC ratio** computed per plan to classify profitability as Highly Profitable, Moderately Profitable, or Low Profitability
- 📡 **Acquisition channel analysis** reveals which channels deliver high-value, low-churn customers

---

## 👤 Author

| | |
|---|---|
| **Name** | Dharmesh Makwana |
| **GitHub** | [@dharmesh9](https://github.com/dharmesh9) |

---

*⭐ If you found this project helpful, please consider giving it a star on GitHub!*

*Built as a comprehensive SaaS churn and revenue analytics portfolio project — 2026.*
