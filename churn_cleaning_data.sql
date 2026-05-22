/* Data Quality Check – SaaS Analytics Project

This script checks data quality issues across:
- subscriptions
- monthly_revenue
*/



/* 1. Duplicate checks in subscriptions */

-- Check if any customer appears more than once
SELECT
    customer_id,
    COUNT(*) AS dup_count
FROM subscriptions
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- Full-row duplicate check (if no primary key enforcement)
SELECT
    customer_id,
    plan,
    billing_cycle,
    industry,
    company_size,
    seats,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    acquisition_channel,
    region,
    signup_date,
    churned,
    churn_date,
    churn_reason,
    support_tickets_12mo,
    nps_score,
    feature_usage_pct,
    upgraded,
    COUNT(*) AS row_count
FROM subscriptions
GROUP BY
    customer_id, plan, billing_cycle, industry, company_size,
    seats, monthly_revenue, acquisition_channel, region,
    signup_date, churned, churn_date, churn_reason,
    support_tickets_12mo, nps_score, feature_usage_pct, upgraded
HAVING COUNT(*) > 1;



/* 2. Missing values check (subscriptions) */

-- Overview of NULLs across key fields
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN plan IS NULL THEN 1 ELSE 0 END) AS null_plan,
    SUM(CASE WHEN billing_cycle IS NULL THEN 1 ELSE 0 END) AS null_billing_cycle,
    SUM(CASE WHEN industry IS NULL THEN 1 ELSE 0 END) AS null_industry,
    SUM(CASE WHEN company_size IS NULL THEN 1 ELSE 0 END) AS null_company_size,
    SUM(CASE WHEN seats IS NULL THEN 1 ELSE 0 END) AS null_seats,
    SUM(CASE WHEN monthly_revenue IS NULL THEN 1 ELSE 0 END) AS null_monthly_revenue,
    SUM(CASE WHEN acquisition_channel IS NULL THEN 1 ELSE 0 END) AS null_acquisition_channel,
    SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS null_region,
    SUM(CASE WHEN signup_date IS NULL THEN 1 ELSE 0 END) AS null_signup_date,
    SUM(CASE WHEN churned IS NULL THEN 1 ELSE 0 END) AS null_churned,
    SUM(CASE WHEN churn_date IS NULL THEN 1 ELSE 0 END) AS null_churn_date,
    SUM(CASE WHEN churn_reason IS NULL THEN 1 ELSE 0 END) AS null_churn_reason,
    SUM(CASE WHEN support_tickets_12mo IS NULL THEN 1 ELSE 0 END) AS null_support_tickets,
    SUM(CASE WHEN nps_score IS NULL THEN 1 ELSE 0 END) AS null_nps_score,
    SUM(CASE WHEN feature_usage_pct IS NULL THEN 1 ELSE 0 END) AS null_feature_usage,
    SUM(CASE WHEN upgraded IS NULL THEN 1 ELSE 0 END) AS null_upgraded
FROM subscriptions;


-- Rows with missing critical fields
SELECT
    customer_id,
    plan,
    billing_cycle,
    signup_date,
    churned,
    monthly_revenue
FROM subscriptions
WHERE
    customer_id IS NULL
    OR plan IS NULL
    OR billing_cycle IS NULL
    OR signup_date IS NULL
    OR churned IS NULL
    OR monthly_revenue IS NULL;



/* 3. Value consistency checks */

-- Churn field validation
SELECT churned, COUNT(*) AS cnt
FROM subscriptions
GROUP BY churned;


-- Billing cycle consistency
SELECT billing_cycle, COUNT(*) AS cnt
FROM subscriptions
GROUP BY billing_cycle;


-- Plan distribution check
SELECT plan, COUNT(*) AS cnt
FROM subscriptions
GROUP BY plan;



/* 4. Range validation checks */

-- NPS score should be between 0 and 10
SELECT
    MIN(nps_score) AS min_nps,
    MAX(nps_score) AS max_nps,
    AVG(nps_score) AS avg_nps,
    COUNT(*) AS total
FROM subscriptions
WHERE nps_score IS NOT NULL;


-- Invalid NPS values
SELECT customer_id, nps_score
FROM subscriptions
WHERE nps_score < 0 OR nps_score > 10;


-- Feature usage should be 0–100
SELECT
    MIN(feature_usage_pct) AS min_usage,
    MAX(feature_usage_pct) AS max_usage
FROM subscriptions
WHERE feature_usage_pct IS NOT NULL;


-- Invalid feature usage values
SELECT customer_id, feature_usage_pct
FROM subscriptions
WHERE feature_usage_pct < 0 OR feature_usage_pct > 100;


-- Negative revenue check
SELECT customer_id, monthly_revenue
FROM subscriptions
WHERE monthly_revenue < 0;


-- Negative seats check
SELECT customer_id, seats
FROM subscriptions
WHERE seats < 0;



/* 5. Date consistency checks */

-- Future signup dates
SELECT customer_id, signup_date
FROM subscriptions
WHERE signup_date > CURDATE();


-- Future churn dates
SELECT customer_id, churn_date
FROM subscriptions
WHERE churn_date > CURDATE();


-- Logical mismatch: churned but no churn date
SELECT customer_id, churned, churn_date
FROM subscriptions
WHERE churned = 'Yes' AND churn_date IS NULL;


-- Logical mismatch: no churn but churn date exists
SELECT customer_id, churned, churn_date
FROM subscriptions
WHERE churned = 'No' AND churn_date IS NOT NULL;


-- Churn date before signup date
SELECT customer_id, signup_date, churn_date
FROM subscriptions
WHERE churned = 'Yes'
  AND churn_date < signup_date;



/* 6. Outlier detection */

-- Revenue outliers using z-score
WITH rev_stats AS (
    SELECT AVG(monthly_revenue) AS avg_rev,
           STDDEV(monthly_revenue) AS std_rev
    FROM subscriptions
)
SELECT
    s.customer_id,
    s.plan,
    s.monthly_revenue,
    (s.monthly_revenue - rs.avg_rev) / NULLIF(rs.std_rev, 0) AS z_score
FROM subscriptions s
CROSS JOIN rev_stats rs
WHERE ABS((s.monthly_revenue - rs.avg_rev) / NULLIF(rs.std_rev, 0)) > 3;


-- Zero usage active customers (potential data issue or disengagement)
SELECT
    customer_id,
    plan,
    feature_usage_pct,
    churned
FROM subscriptions
WHERE churned = 'No'
  AND feature_usage_pct = 0;



/* 7. monthly_revenue data quality */

-- NULL check
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN month IS NULL THEN 1 ELSE 0 END) AS null_month,
    SUM(CASE WHEN total_mrr IS NULL THEN 1 ELSE 0 END) AS null_total_mrr,
    SUM(CASE WHEN new_customers IS NULL THEN 1 ELSE 0 END) AS null_new_customers,
    SUM(CASE WHEN churned_customers IS NULL THEN 1 ELSE 0 END) AS null_churned_customers,
    SUM(CASE WHEN monthly_churn_rate_pct IS NULL THEN 1 ELSE 0 END) AS null_churn_rate,
    SUM(CASE WHEN avg_revenue_per_customer IS NULL THEN 1 ELSE 0 END) AS null_avg_revenue,
    SUM(CASE WHEN customer_acquisition_cost IS NULL THEN 1 ELSE 0 END) AS null_cac
FROM monthly_revenue;


-- Negative values check
SELECT *
FROM monthly_revenue
WHERE total_mrr < 0
   OR new_customers < 0
   OR churned_customers < 0
   OR monthly_churn_rate_pct < 0
   OR avg_revenue_per_customer < 0
   OR customer_acquisition_cost < 0;


-- Duplicate month check
SELECT month, COUNT(*) AS cnt
FROM monthly_revenue
GROUP BY month
HAVING COUNT(*) > 1;



/* 8. Cross-table sanity checks */

-- Active customers comparison
SELECT
    (SELECT COUNT(*) FROM subscriptions WHERE churned='No') AS active_from_subscriptions,
    (SELECT total_active_customers
     FROM monthly_revenue
     ORDER BY STR_TO_DATE(month,'%Y-%m') DESC
     LIMIT 1) AS active_from_monthly;



-- Churned customers comparison
SELECT
    (SELECT COUNT(*) FROM subscriptions WHERE churned='Yes') AS churned_from_subscriptions,
    (SELECT churned_customers
     FROM monthly_revenue
     ORDER BY STR_TO_DATE(month,'%Y-%m') DESC
     LIMIT 1) AS churned_from_monthly;



/* 9. Quick summary view */

SELECT
    'subscriptions' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS nulls_customer_id,
    SUM(CASE WHEN churned IS NULL THEN 1 ELSE 0 END) AS nulls_churned,
    SUM(CASE WHEN monthly_revenue IS NULL THEN 1 ELSE 0 END) AS nulls_revenue
FROM subscriptions

UNION ALL

SELECT
    'monthly_revenue',
    COUNT(*),
    SUM(CASE WHEN month IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN monthly_churn_rate_pct IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN total_mrr IS NULL THEN 1 ELSE 0 END)
FROM monthly_revenue;