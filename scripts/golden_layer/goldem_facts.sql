CREATE OR REPLACE VIEW gold.fact_order_items AS
WITH product_map AS (
    SELECT
        p.product_id,
        DENSE_RANK() OVER (ORDER BY p.product_id)::INTEGER AS product_sk
    FROM (
        SELECT DISTINCT product_id
        FROM silver.olist_products
        WHERE product_id IS NOT NULL
    ) p
),
main_payment AS (
    SELECT
        x.order_id,
        x.payment_type
    FROM (
        SELECT
            op.order_id,
            op.payment_type,
            ROW_NUMBER() OVER (
                PARTITION BY op.order_id
                ORDER BY op.payment_value DESC NULLS LAST,
                         op.payment_sequential ASC NULLS LAST
            ) AS rn
        FROM silver.olist_order_payments op
        WHERE op.order_id IS NOT NULL
    ) x
    WHERE x.rn = 1
),
review_by_order AS (
    SELECT
        r.order_id,
        ROUND(AVG(r.review_score))::SMALLINT AS review_score
    FROM silver.olist_order_reviews r
    WHERE r.order_id IS NOT NULL
    GROUP BY r.order_id
)
SELECT
    oi.order_id,
    oi.order_item_id,
    d_order.date_sk AS order_date_sk,
    d_approved.date_sk AS approved_date_sk,
    d_carrier.date_sk AS delivered_carrier_date_sk,
    d_customer_deliv.date_sk AS delivered_customer_date_sk,
    d_estimated.date_sk AS estimated_delivery_date_sk,
    dc.customer_sk,
    ds.seller_sk,
    pm.product_sk,
    dos.order_status_sk,
    dpt.payment_type_sk AS main_payment_type_sk,
    oi.price::NUMERIC(10,2) AS item_price,
    oi.freight_value::NUMERIC(10,2) AS item_freight_value,
    oi.price::NUMERIC(10,2) AS item_gross_revenue,
    oi.price::NUMERIC(10,2) AS item_net_revenue,
    1::INTEGER AS item_qty,
    CASE
        WHEN o.order_approved_at IS NOT NULL
         AND o.order_purchase_timestamp IS NOT NULL
        THEN (o.order_approved_at::DATE - o.order_purchase_timestamp::DATE)
        ELSE NULL
    END::INTEGER AS days_approval,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_purchase_timestamp IS NOT NULL
        THEN (o.order_delivered_customer_date::DATE - o.order_purchase_timestamp::DATE)
        ELSE NULL
    END::INTEGER AS days_delivery,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
        THEN (o.order_delivered_customer_date::DATE - o.order_estimated_delivery_date::DATE)
        ELSE NULL
    END::INTEGER AS days_delay_vs_estimated,
    rb.review_score
FROM silver.olist_order_items oi
LEFT JOIN silver.olist_orders o
    ON o.order_id = oi.order_id
LEFT JOIN silver.olist_customers c
    ON c.customer_id = o.customer_id
LEFT JOIN gold.dim_customer dc
    ON dc.customer_unique_id = c.customer_unique_id
LEFT JOIN gold.dim_seller ds
    ON ds.seller_id = oi.seller_id
LEFT JOIN product_map pm
    ON pm.product_id = oi.product_id
LEFT JOIN gold.dim_order_status dos
    ON dos.order_status_code = o.order_status
LEFT JOIN main_payment mp
    ON mp.order_id = oi.order_id
LEFT JOIN gold.dim_payment_type dpt
    ON dpt.payment_type_code = mp.payment_type
LEFT JOIN gold.dim_date d_order
    ON d_order.full_date = o.order_purchase_timestamp::DATE
LEFT JOIN gold.dim_date d_approved
    ON d_approved.full_date = o.order_approved_at::DATE
LEFT JOIN gold.dim_date d_carrier
    ON d_carrier.full_date = o.order_delivered_carrier_date::DATE
LEFT JOIN gold.dim_date d_customer_deliv
    ON d_customer_deliv.full_date = o.order_delivered_customer_date::DATE
LEFT JOIN gold.dim_date d_estimated
    ON d_estimated.full_date = o.order_estimated_delivery_date::DATE
LEFT JOIN review_by_order rb
    ON rb.order_id = oi.order_id
WHERE oi.order_id IS NOT NULL
  AND oi.order_item_id IS NOT NULL;

CREATE OR REPLACE VIEW gold.fact_orders AS
WITH payment_total AS (
    SELECT
        op.order_id,
        SUM(op.payment_value)::NUMERIC(12,2) AS total_payment_value
    FROM silver.olist_order_payments op
    WHERE op.order_id IS NOT NULL
    GROUP BY op.order_id
),
review_by_order AS (
    SELECT
        r.order_id,
        ROUND(AVG(r.review_score))::SMALLINT AS review_score
    FROM silver.olist_order_reviews r
    WHERE r.order_id IS NOT NULL
    GROUP BY r.order_id
)
SELECT
    o.order_id,
    d_order.date_sk AS order_date_sk,
    d_approved.date_sk AS approved_date_sk,
    d_carrier.date_sk AS delivered_carrier_date_sk,
    d_customer_deliv.date_sk AS delivered_customer_date_sk,
    d_estimated.date_sk AS estimated_delivery_date_sk,
    dc.customer_sk,
    dos.order_status_sk,
    COUNT(oi.order_item_id)::INTEGER AS total_items,
    COALESCE(SUM(oi.price), 0)::NUMERIC(12,2) AS total_gross_revenue,
    COALESCE(SUM(oi.freight_value), 0)::NUMERIC(12,2) AS total_freight_value,
    COALESCE(pt.total_payment_value, 0)::NUMERIC(12,2) AS total_payment_value,
    AVG(oi.price)::NUMERIC(10,2) AS avg_item_price,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_purchase_timestamp IS NOT NULL
        THEN (o.order_delivered_customer_date::DATE - o.order_purchase_timestamp::DATE)
        ELSE NULL
    END::INTEGER AS days_delivery,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
        THEN (o.order_delivered_customer_date::DATE - o.order_estimated_delivery_date::DATE)
        ELSE NULL
    END::INTEGER AS days_delay_vs_estimated,
    rb.review_score
FROM silver.olist_orders o
LEFT JOIN silver.olist_order_items oi
    ON oi.order_id = o.order_id
LEFT JOIN silver.olist_customers c
    ON c.customer_id = o.customer_id
LEFT JOIN gold.dim_customer dc
    ON dc.customer_unique_id = c.customer_unique_id
LEFT JOIN gold.dim_order_status dos
    ON dos.order_status_code = o.order_status
LEFT JOIN gold.dim_date d_order
    ON d_order.full_date = o.order_purchase_timestamp::DATE
LEFT JOIN gold.dim_date d_approved
    ON d_approved.full_date = o.order_approved_at::DATE
LEFT JOIN gold.dim_date d_carrier
    ON d_carrier.full_date = o.order_delivered_carrier_date::DATE
LEFT JOIN gold.dim_date d_customer_deliv
    ON d_customer_deliv.full_date = o.order_delivered_customer_date::DATE
LEFT JOIN gold.dim_date d_estimated
    ON d_estimated.full_date = o.order_estimated_delivery_date::DATE
LEFT JOIN payment_total pt
    ON pt.order_id = o.order_id
LEFT JOIN review_by_order rb
    ON rb.order_id = o.order_id
WHERE o.order_id IS NOT NULL
GROUP BY
    o.order_id,
    d_order.date_sk,
    d_approved.date_sk,
    d_carrier.date_sk,
    d_customer_deliv.date_sk,
    d_estimated.date_sk,
    dc.customer_sk,
    dos.order_status_sk,
    pt.total_payment_value,
    o.order_delivered_customer_date,
    o.order_purchase_timestamp,
    o.order_estimated_delivery_date,
    rb.review_score;

CREATE OR REPLACE VIEW gold.fact_payments AS
SELECT
    op.order_id,
    op.payment_sequential,
    dpt.payment_type_sk,
    op.payment_installments,
    op.payment_value::NUMERIC(10,2) AS payment_value,
    d_order.date_sk AS order_date_sk,
    dc.customer_sk
FROM silver.olist_order_payments op
LEFT JOIN silver.olist_orders o
    ON o.order_id = op.order_id
LEFT JOIN silver.olist_customers c
    ON c.customer_id = o.customer_id
LEFT JOIN gold.dim_customer dc
    ON dc.customer_unique_id = c.customer_unique_id
LEFT JOIN gold.dim_payment_type dpt
    ON dpt.payment_type_code = op.payment_type
LEFT JOIN gold.dim_date d_order
    ON d_order.full_date = o.order_purchase_timestamp::DATE
WHERE op.order_id IS NOT NULL
  AND op.payment_sequential IS NOT NULL;

CREATE OR REPLACE VIEW gold.fact_reviews AS
SELECT
    r.review_id,
    r.order_id,
    dc.customer_sk,
    d_order.date_sk AS order_date_sk,
    d_review_creation.date_sk AS review_creation_date_sk,
    d_review_answer.date_sk AS review_answer_date_sk,
    r.review_score,
    (NULLIF(TRIM(COALESCE(r.review_comment_message, '')), '') IS NOT NULL) AS has_comment
FROM silver.olist_order_reviews r
LEFT JOIN silver.olist_orders o
    ON o.order_id = r.order_id
LEFT JOIN silver.olist_customers c
    ON c.customer_id = o.customer_id
LEFT JOIN gold.dim_customer dc
    ON dc.customer_unique_id = c.customer_unique_id
LEFT JOIN gold.dim_date d_order
    ON d_order.full_date = o.order_purchase_timestamp::DATE
LEFT JOIN gold.dim_date d_review_creation
    ON d_review_creation.full_date = r.review_creation_date::DATE
LEFT JOIN gold.dim_date d_review_answer
    ON d_review_answer.full_date = r.review_answer_timestamp::DATE
WHERE r.review_id IS NOT NULL;