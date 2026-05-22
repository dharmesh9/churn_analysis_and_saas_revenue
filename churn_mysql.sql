/* SaaS Churn & Revenue Analytics Project

This analysis explores customer churn, revenue performance, and customer behavior using subscription data.

Assumptions:
- CLV = Avg Monthly Revenue × Estimated Customer Lifespan
- CAC is blended average due to missing plan-level acquisition data
- Net New MRR is used instead of true NRR because expansion/contraction data is not available
*/


/* 1. Overall churn rate */

SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) AS churned_customers,
    SUM(CASE WHEN churned='No' THEN 1 ELSE 0 END) AS active_customers,
    ROUND(
        SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS overall_churn_rate_pct
FROM subscriptions;



/* 2. Monthly churn trend */

WITH churn_trend AS (
    SELECT
        month,
        monthly_churn_rate_pct,
        LAG(monthly_churn_rate_pct)
            OVER (ORDER BY STR_TO_DATE(month, '%Y-%m')) AS prev_month_churn,
        LAG(monthly_churn_rate_pct, 12)
            OVER (ORDER BY STR_TO_DATE(month, '%Y-%m')) AS prev_year_churn
    FROM monthly_revenue
)

SELECT
    month,
    ROUND(monthly_churn_rate_pct, 2) AS churn_rate_pct,
    ROUND(prev_month_churn, 2) AS prev_month_churn,
    ROUND(monthly_churn_rate_pct - prev_month_churn, 2) AS mom_change_pct,
    ROUND(prev_year_churn, 2) AS prev_year_churn,
    ROUND(monthly_churn_rate_pct - prev_year_churn, 2) AS yoy_change_pct,
    CASE
        WHEN prev_year_churn IS NULL THEN 'No prior year data'
        WHEN monthly_churn_rate_pct < prev_year_churn THEN 'Improving'
        WHEN monthly_churn_rate_pct > prev_year_churn THEN 'Worsening'
        ELSE 'Stable'
    END AS churn_trend
FROM churn_trend
ORDER BY STR_TO_DATE(month, '%Y-%m');



/* 3. Churn rate by subscription plan */

SELECT
    plan,
    COUNT(*) AS customers,
    SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(
        SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS churn_rate_pct,
    ROUND(AVG(monthly_revenue), 2) AS avg_plan_mrr
FROM subscriptions
GROUP BY plan
HAVING COUNT(*) >= 10
ORDER BY churn_rate_pct DESC;



/* 4. Billing cycle impact on retention */

SELECT
    billing_cycle,
    COUNT(*) AS customers,
    SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(
        SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS churn_rate_pct,
    ROUND(AVG(monthly_revenue), 2) AS avg_customer_mrr
FROM subscriptions
GROUP BY billing_cycle
HAVING COUNT(*) >= 10
ORDER BY churn_rate_pct DESC;



/* 5. Top churn reasons */

SELECT
    churn_reason,
    COUNT(*) AS churned_customers,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(),
        2
    ) AS pct_of_total_churn
FROM subscriptions
WHERE churned='Yes'
  AND churn_reason IS NOT NULL
GROUP BY churn_reason
ORDER BY churned_customers DESC
LIMIT 3;



/* 6. Churn reasons by plan */

SELECT
    plan,
    churn_reason,
    COUNT(*) AS churned_customers,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY plan),
        2
    ) AS pct_within_plan
FROM subscriptions
WHERE churned='Yes'
  AND churn_reason IS NOT NULL
GROUP BY plan, churn_reason
HAVING COUNT(*) >= 5
ORDER BY plan, churned_customers DESC;



/* 7. Churn reasons by company size */

SELECT
    company_size,
    churn_reason,
    COUNT(*) AS churned_customers,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY company_size),
        2
    ) AS pct_within_company_size
FROM subscriptions
WHERE churned='Yes'
  AND churn_reason IS NOT NULL
GROUP BY company_size, churn_reason
HAVING COUNT(*) >= 5
ORDER BY company_size, churned_customers DESC;



/* 8. Churn by acquisition channel */

SELECT
    acquisition_channel,
    COUNT(*) AS customers,
    ROUND(AVG(monthly_revenue), 2) AS avg_customer_value,
    ROUND(AVG(nps_score), 2) AS avg_nps,
    ROUND(
        SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS churn_rate_pct
FROM subscriptions
GROUP BY acquisition_channel
HAVING COUNT(*) >= 10
ORDER BY churn_rate_pct DESC;



/* 9. High-risk customer segments */

SELECT
    company_size,
    COUNT(*) AS customers,
    ROUND(AVG(seats), 0) AS avg_seats,
    ROUND(AVG(monthly_revenue), 2) AS avg_mrr,
    ROUND(AVG(feature_usage_pct), 2) AS avg_feature_usage,
    ROUND(AVG(nps_score), 2) AS avg_nps,
    ROUND(
        SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS churn_rate_pct
FROM subscriptions
GROUP BY company_size
HAVING COUNT(*) >= 10
ORDER BY churn_rate_pct DESC;



/* 10. Monthly MRR growth analysis */

WITH revenue_trend AS (
    SELECT
        month,
        total_mrr,
        new_customers,
        churned_customers,
        avg_revenue_per_customer,
        (new_customers * avg_revenue_per_customer) AS new_mrr,
        (churned_customers * avg_revenue_per_customer) AS churned_mrr,
        ((new_customers - churned_customers) * avg_revenue_per_customer) AS net_new_mrr,
        LAG(total_mrr)
            OVER (ORDER BY STR_TO_DATE(month, '%Y-%m')) AS prev_month_mrr
    FROM monthly_revenue
)

SELECT
    month,
    ROUND(total_mrr, 2) AS total_mrr,
    ROUND(new_mrr, 2) AS new_mrr,
    ROUND(churned_mrr, 2) AS churned_mrr,
    ROUND(net_new_mrr, 2) AS net_new_mrr,
    ROUND(total_mrr - prev_month_mrr, 2) AS mrr_growth,
    ROUND(
        ((total_mrr - prev_month_mrr) / NULLIF(prev_month_mrr, 0)) * 100,
        2
    ) AS mrr_growth_pct
FROM revenue_trend
ORDER BY STR_TO_DATE(month, '%Y-%m');



/* 11. Customer lifetime value by plan */

WITH clv_calc AS (
    SELECT
        plan,
        AVG(monthly_revenue) AS avg_mrr,
        SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS churn_rate
    FROM subscriptions
    GROUP BY plan
)

SELECT
    plan,
    ROUND(avg_mrr, 2) AS avg_monthly_revenue,
    ROUND(churn_rate * 100, 2) AS churn_rate_pct,
    ROUND(1 / NULLIF(churn_rate, 0), 2) AS estimated_customer_lifespan_months,
    ROUND(avg_mrr * (1 / NULLIF(churn_rate, 0)), 2) AS estimated_clv
FROM clv_calc
ORDER BY estimated_clv DESC;



/* 12. CLV vs CAC analysis */

WITH clv_calc AS (
    SELECT
        plan,
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
    ROUND(c.avg_mrr, 2) AS avg_mrr,
    ROUND(1 / NULLIF(c.churn_rate, 0), 2) AS est_lifespan_months,
    ROUND(c.avg_mrr * (1 / NULLIF(c.churn_rate, 0)), 2) AS estimated_clv,
    ROUND(k.avg_cac, 2) AS avg_cac,
    ROUND(
        (c.avg_mrr * (1 / NULLIF(c.churn_rate, 0))) / NULLIF(k.avg_cac, 0),
        2
    ) AS clv_cac_ratio,
    CASE
        WHEN ((c.avg_mrr * (1 / NULLIF(c.churn_rate, 0))) / NULLIF(k.avg_cac, 0)) >= 3 THEN 'Highly Profitable'
        WHEN ((c.avg_mrr * (1 / NULLIF(c.churn_rate, 0))) / NULLIF(k.avg_cac, 0)) >= 1.5 THEN 'Moderately Profitable'
        ELSE 'Low Profitability'
    END AS profitability_status
FROM clv_calc c
CROSS JOIN cac_calc k
ORDER BY clv_cac_ratio DESC;



/* 13. Usage, satisfaction, and churn */

SELECT
    CASE
        WHEN feature_usage_pct >= 80 THEN 'High Usage'
        WHEN feature_usage_pct >= 50 THEN 'Medium Usage'
        ELSE 'Low Usage'
    END AS usage_segment,
    COUNT(*) AS customers,
    ROUND(AVG(feature_usage_pct), 2) AS avg_feature_usage,
    ROUND(AVG(nps_score), 2) AS avg_nps,
    ROUND(AVG(monthly_revenue), 2) AS avg_mrr,
    ROUND(
        SUM(CASE WHEN churned='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS churn_rate_pct
FROM subscriptions
GROUP BY usage_segment
ORDER BY churn_rate_pct DESC;



/* 14. At-risk customers */

SELECT
    COUNT(*) AS active_customers,
    SUM(CASE WHEN feature_usage_pct < 50 THEN 1 ELSE 0 END) AS at_risk_customers,
    ROUND(
        SUM(CASE WHEN feature_usage_pct < 50 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS at_risk_pct,
    ROUND(
        SUM(CASE WHEN feature_usage_pct < 50 THEN monthly_revenue ELSE 0 END),
        2
    ) AS mrr_at_risk
FROM subscriptions
WHERE churned='No';



/* 15. High-risk customer list */

SELECT
    customer_id,
    plan,
    billing_cycle,
    company_size,
    monthly_revenue,
    feature_usage_pct,
    nps_score,
    support_tickets_12mo,

    ROUND(
        (100 - feature_usage_pct) * 0.45 +
        (10 - COALESCE(nps_score, 5)) * 3 +
        LEAST(COALESCE(support_tickets_12mo, 0), 15) * 1.5,
        2
    ) AS risk_score,

    CASE
        WHEN feature_usage_pct < 40 AND nps_score <= 5 THEN 'Critical'
        WHEN feature_usage_pct < 60 THEN 'At Risk'
        ELSE 'Monitor'
    END AS risk_status

FROM subscriptions
WHERE churned='No'
ORDER BY risk_score DESC
LIMIT 50;