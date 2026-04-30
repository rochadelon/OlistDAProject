CREATE OR REPLACE VIEW gold.dim_date AS
WITH all_dates AS (
    SELECT o.order_purchase_timestamp::DATE AS full_date
    FROM silver.olist_orders o
    WHERE o.order_purchase_timestamp IS NOT NULL

    UNION

    SELECT o.order_approved_at::DATE AS full_date
    FROM silver.olist_orders o
    WHERE o.order_approved_at IS NOT NULL

    UNION

    SELECT o.order_delivered_carrier_date::DATE AS full_date
    FROM silver.olist_orders o
    WHERE o.order_delivered_carrier_date IS NOT NULL

    UNION

    SELECT o.order_delivered_customer_date::DATE AS full_date
    FROM silver.olist_orders o
    WHERE o.order_delivered_customer_date IS NOT NULL

    UNION

    SELECT o.order_estimated_delivery_date::DATE AS full_date
    FROM silver.olist_orders o
    WHERE o.order_estimated_delivery_date IS NOT NULL

    UNION

    SELECT r.review_creation_date::DATE AS full_date
    FROM silver.olist_order_reviews r
    WHERE r.review_creation_date IS NOT NULL

    UNION

    SELECT r.review_answer_timestamp::DATE AS full_date
    FROM silver.olist_order_reviews r
    WHERE r.review_answer_timestamp IS NOT NULL
)
SELECT
    DENSE_RANK() OVER (ORDER BY d.full_date)::INTEGER AS date_sk,
    d.full_date,
    EXTRACT(YEAR FROM d.full_date)::SMALLINT AS year,
    EXTRACT(MONTH FROM d.full_date)::SMALLINT AS month,
    TO_CHAR(d.full_date, 'FMMonth')::VARCHAR(15) AS month_name,
    EXTRACT(QUARTER FROM d.full_date)::SMALLINT AS quarter,
    EXTRACT(DAY FROM d.full_date)::SMALLINT AS day,
    EXTRACT(ISODOW FROM d.full_date)::SMALLINT AS day_of_week,
    TO_CHAR(d.full_date, 'FMDay')::VARCHAR(15) AS day_of_week_name,
    (EXTRACT(ISODOW FROM d.full_date) IN (6, 7)) AS is_weekend
FROM all_dates d;

CREATE OR REPLACE VIEW gold.dim_customer AS
WITH customer_base AS (
    SELECT
        c.customer_id,
        c.customer_unique_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state
    FROM silver.olist_customers c
    WHERE c.customer_unique_id IS NOT NULL
),
customer_orders AS (
    SELECT
        cb.customer_unique_id,
        MIN(o.order_purchase_timestamp::DATE) AS first_purchase_date,
        MAX(o.order_purchase_timestamp::DATE) AS last_purchase_date,
        COUNT(DISTINCT o.order_id)::INTEGER AS total_orders
    FROM customer_base cb
    LEFT JOIN silver.olist_orders o
        ON o.customer_id = cb.customer_id
    GROUP BY cb.customer_unique_id
),
ranked_customer AS (
    SELECT
        cb.customer_id,
        cb.customer_unique_id,
        cb.customer_zip_code_prefix,
        cb.customer_city,
        cb.customer_state,
        ROW_NUMBER() OVER (
            PARTITION BY cb.customer_unique_id
            ORDER BY cb.customer_id DESC
        ) AS rn
    FROM customer_base cb
)
SELECT
    DENSE_RANK() OVER (ORDER BY rc.customer_unique_id)::INTEGER AS customer_sk,
    rc.customer_unique_id,
    rc.customer_id AS customer_id_source,
    rc.customer_zip_code_prefix,
    rc.customer_city,
    rc.customer_state,
    d_first.date_sk AS first_order_date_sk,
    d_last.date_sk AS last_order_date_sk,
    COALESCE(co.total_orders, 0)::INTEGER AS total_orders
FROM ranked_customer rc
LEFT JOIN customer_orders co
    ON co.customer_unique_id = rc.customer_unique_id
LEFT JOIN gold.dim_date d_first
    ON d_first.full_date = co.first_purchase_date
LEFT JOIN gold.dim_date d_last
    ON d_last.full_date = co.last_purchase_date
WHERE rc.rn = 1;

CREATE OR REPLACE VIEW gold.dim_seller AS
WITH seller_orders AS (
    SELECT
        oi.seller_id,
        MIN(o.order_purchase_timestamp::DATE) AS first_purchase_date,
        MAX(o.order_purchase_timestamp::DATE) AS last_purchase_date,
        COUNT(DISTINCT oi.order_id)::INTEGER AS total_orders
    FROM silver.olist_order_items oi
    LEFT JOIN silver.olist_orders o
        ON o.order_id = oi.order_id
    WHERE oi.seller_id IS NOT NULL
    GROUP BY oi.seller_id
),
seller_base AS (
    SELECT
        s.seller_id,
        s.seller_zip_code_prefix,
        s.seller_city,
        s.seller_state,
        ROW_NUMBER() OVER (
            PARTITION BY s.seller_id
            ORDER BY s.seller_id DESC
        ) AS rn
    FROM silver.olist_sellers s
    WHERE s.seller_id IS NOT NULL
)
SELECT
    DENSE_RANK() OVER (ORDER BY sb.seller_id)::INTEGER AS seller_sk,
    sb.seller_id,
    sb.seller_zip_code_prefix,
    sb.seller_city,
    sb.seller_state,
    d_first.date_sk AS first_order_date_sk,
    d_last.date_sk AS last_order_date_sk,
    COALESCE(so.total_orders, 0)::INTEGER AS total_orders
FROM seller_base sb
LEFT JOIN seller_orders so
    ON so.seller_id = sb.seller_id
LEFT JOIN gold.dim_date d_first
    ON d_first.full_date = so.first_purchase_date
LEFT JOIN gold.dim_date d_last
    ON d_last.full_date = so.last_purchase_date
WHERE sb.rn = 1;

CREATE OR REPLACE VIEW gold.dim_product_category AS
WITH categories AS (
    SELECT DISTINCT p.product_category_name
    FROM silver.olist_products p
    WHERE p.product_category_name IS NOT NULL

    UNION

    SELECT DISTINCT t.product_category_name
    FROM silver.olist_product_category_name_translation t
    WHERE t.product_category_name IS NOT NULL
),
translation AS (
    SELECT
        t.product_category_name,
        MAX(t.product_category_name_english) AS product_category_name_english
    FROM silver.olist_product_category_name_translation t
    GROUP BY t.product_category_name
)
SELECT
    DENSE_RANK() OVER (ORDER BY c.product_category_name)::INTEGER AS product_category_sk,
    c.product_category_name,
    tr.product_category_name_english::VARCHAR(80) AS product_category_name_en
FROM categories c
LEFT JOIN translation tr
    ON tr.product_category_name = c.product_category_name;

CREATE OR REPLACE VIEW gold.dim_order_status AS
SELECT
    DENSE_RANK() OVER (ORDER BY o.order_status)::SMALLINT AS order_status_sk,
    o.order_status::VARCHAR(20) AS order_status_code,
    (o.order_status IN ('delivered', 'canceled', 'cancelled', 'unavailable')) AS is_closed,
    (o.order_status IN ('canceled', 'cancelled')) AS is_cancelled
FROM (
    SELECT DISTINCT order_status
    FROM silver.olist_orders
    WHERE order_status IS NOT NULL
) o;

CREATE OR REPLACE VIEW gold.dim_payment_type AS
WITH payment_stats AS (
    SELECT
        op.payment_type,
        MAX(COALESCE(op.payment_installments, 0)) AS max_installments
    FROM silver.olist_order_payments op
    WHERE op.payment_type IS NOT NULL
    GROUP BY op.payment_type
)
SELECT
    DENSE_RANK() OVER (ORDER BY ps.payment_type)::SMALLINT AS payment_type_sk,
    ps.payment_type::VARCHAR(20) AS payment_type_code,
    (ps.max_installments > 1) AS is_installment
FROM payment_stats ps;

CREATE OR REPLACE VIEW gold.dim_geolocation AS
WITH ranked_geo AS (
    SELECT
        g.geolocation_zip_code_prefix,
        g.geolocation_lat,
        g.geolocation_lng,
        g.geolocation_city,
        g.geolocation_state,
        ROW_NUMBER() OVER (
            PARTITION BY g.geolocation_zip_code_prefix
            ORDER BY g.geolocation_lat DESC NULLS LAST,
                     g.geolocation_lng DESC NULLS LAST,
                     g.geolocation_city DESC NULLS LAST
        ) AS rn
    FROM silver.olist_geolocation g
    WHERE g.geolocation_zip_code_prefix IS NOT NULL
)
SELECT
    DENSE_RANK() OVER (ORDER BY rg.geolocation_zip_code_prefix)::INTEGER AS geolocation_sk,
    rg.geolocation_zip_code_prefix::VARCHAR(5) AS zip_code_prefix,
    rg.geolocation_lat::NUMERIC(18, 14) AS geolocation_lat,
    rg.geolocation_lng::NUMERIC(18, 14) AS geolocation_lng,
    rg.geolocation_city::VARCHAR(80) AS geolocation_city,
    rg.geolocation_state::CHAR(2) AS geolocation_state
FROM ranked_geo rg
WHERE rg.rn = 1;

