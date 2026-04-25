/*
Proposito:
  Criar e executar uma procedure para carregar a camada SILVER a partir da BRONZE,
  com deduplicacao, limpeza e validacoes pre e pos-carga.

Processo:
  (Opcional) TRUNCATE -> INSERT INTO ... SELECT (ROW_NUMBER + TRIM + CAST seguro).

Parametros:
  p_truncate BOOLEAN (default TRUE): se TRUE, limpa as tabelas silver antes do load.

Exemplo de Uso:
  CALL silver.proc_load_silver(TRUE);
*/

CREATE OR REPLACE PROCEDURE silver.proc_load_silver(p_truncate BOOLEAN DEFAULT TRUE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_code TEXT;
    v_error_message TEXT;
    v_error_detail TEXT;
    v_error_hint TEXT;
    v_error_context TEXT;

    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration_seconds NUMERIC;

    v_rows BIGINT;
    v_null_count BIGINT;
    v_dup_count BIGINT;
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Iniciando carga da camada Silver';
    RAISE NOTICE '============================================================';

    IF p_truncate THEN
        RAISE NOTICE '--- Limpando tabelas Silver (TRUNCATE) ---';

        TRUNCATE TABLE
            silver.olist_customers,
            silver.olist_geolocation,
            silver.olist_order_items,
            silver.olist_order_payments,
            silver.olist_order_reviews,
            silver.olist_orders,
            silver.olist_products,
            silver.olist_sellers,
            silver.olist_product_category_name_translation;
    ELSE
        RAISE NOTICE 'Parametro p_truncate=FALSE: etapa de TRUNCATE ignorada';
    END IF;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Secao CRM - Cadastros de clientes e vendedores';
    RAISE NOTICE '============================================================';

    SELECT COUNT(*)
      INTO v_null_count
      FROM bronze.olist_customers b
     WHERE NULLIF(TRIM(b.customer_id), '') IS NULL;

    SELECT COUNT(*)
      INTO v_dup_count
      FROM (
            SELECT NULLIF(TRIM(b.customer_id), '') AS customer_id
              FROM bronze.olist_customers b
             WHERE NULLIF(TRIM(b.customer_id), '') IS NOT NULL
             GROUP BY 1
            HAVING COUNT(*) > 1
      ) d;

    RAISE NOTICE 'Pre-check bronze.olist_customers -> null_pk: %, dup_pk: %', v_null_count, v_dup_count;

    RAISE NOTICE 'Inserindo dados em silver.olist_customers';
    v_start_time := clock_timestamp();

    WITH base AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(TRIM(b.customer_id), '')
                ORDER BY NULLIF(TRIM(b.customer_unique_id), '') DESC NULLS LAST, b.ctid DESC
            ) AS rn
        FROM bronze.olist_customers b
        WHERE NULLIF(TRIM(b.customer_id), '') IS NOT NULL
    )
    INSERT INTO silver.olist_customers (
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state
    )
    SELECT
        NULLIF(TRIM(customer_id), '')::VARCHAR(32),
        NULLIF(TRIM(customer_unique_id), '')::VARCHAR(32),
        LPAD(NULLIF(TRIM(customer_zip_code_prefix), ''), 5, '0')::VARCHAR(5),
        NULLIF(TRIM(customer_city), '')::VARCHAR(80),
        UPPER(NULLIF(TRIM(customer_state), ''))::CHAR(2)
    FROM base
    WHERE rn = 1;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    SELECT COUNT(*)
      INTO v_null_count
      FROM silver.olist_customers s
     WHERE s.customer_id IS NULL;

    SELECT COUNT(*)
      INTO v_dup_count
      FROM (
            SELECT s.customer_id
              FROM silver.olist_customers s
             GROUP BY s.customer_id
            HAVING COUNT(*) > 1
      ) d;

    RAISE NOTICE 'Pos-check silver.olist_customers -> rows: %, null_pk: %, dup_pk: %, duracao(s): %', v_rows, v_null_count, v_dup_count, v_duration_seconds::TEXT;

    SELECT COUNT(*)
      INTO v_null_count
      FROM bronze.olist_sellers b
     WHERE NULLIF(TRIM(b.seller_id), '') IS NULL;

    SELECT COUNT(*)
      INTO v_dup_count
      FROM (
            SELECT NULLIF(TRIM(b.seller_id), '') AS seller_id
              FROM bronze.olist_sellers b
             WHERE NULLIF(TRIM(b.seller_id), '') IS NOT NULL
             GROUP BY 1
            HAVING COUNT(*) > 1
      ) d;

    RAISE NOTICE 'Pre-check bronze.olist_sellers -> null_pk: %, dup_pk: %', v_null_count, v_dup_count;

    RAISE NOTICE 'Inserindo dados em silver.olist_sellers';
    v_start_time := clock_timestamp();

    WITH base AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(TRIM(b.seller_id), '')
                ORDER BY b.ctid DESC
            ) AS rn
        FROM bronze.olist_sellers b
        WHERE NULLIF(TRIM(b.seller_id), '') IS NOT NULL
    )
    INSERT INTO silver.olist_sellers (
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state
    )
    SELECT
        NULLIF(TRIM(seller_id), '')::VARCHAR(32),
        LPAD(NULLIF(TRIM(seller_zip_code_prefix), ''), 5, '0')::VARCHAR(5),
        NULLIF(TRIM(seller_city), '')::VARCHAR(80),
        UPPER(NULLIF(TRIM(seller_state), ''))::CHAR(2)
    FROM base
    WHERE rn = 1;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    SELECT COUNT(*) INTO v_null_count FROM silver.olist_sellers WHERE seller_id IS NULL;
    SELECT COUNT(*) INTO v_dup_count FROM (SELECT seller_id FROM silver.olist_sellers GROUP BY seller_id HAVING COUNT(*) > 1) d;

    RAISE NOTICE 'Pos-check silver.olist_sellers -> rows: %, null_pk: %, dup_pk: %, duracao(s): %', v_rows, v_null_count, v_dup_count, v_duration_seconds::TEXT;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Secao GEO - Referencia geografica';
    RAISE NOTICE '============================================================';

    RAISE NOTICE 'Inserindo dados em silver.olist_geolocation';
    v_start_time := clock_timestamp();

    WITH base AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    NULLIF(TRIM(b.geolocation_zip_code_prefix), ''),
                    NULLIF(TRIM(b.geolocation_lat), ''),
                    NULLIF(TRIM(b.geolocation_lng), ''),
                    NULLIF(TRIM(b.geolocation_city), ''),
                    NULLIF(TRIM(b.geolocation_state), '')
                ORDER BY b.ctid DESC
            ) AS rn
        FROM bronze.olist_geolocation b
    )
    INSERT INTO silver.olist_geolocation (
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    )
    SELECT
        LPAD(NULLIF(TRIM(geolocation_zip_code_prefix), ''), 5, '0')::VARCHAR(5),
        CASE WHEN TRIM(geolocation_lat) ~ '^[-]?[0-9]+([.][0-9]+)?$' THEN TRIM(geolocation_lat)::NUMERIC(18,14) ELSE NULL END,
        CASE WHEN TRIM(geolocation_lng) ~ '^[-]?[0-9]+([.][0-9]+)?$' THEN TRIM(geolocation_lng)::NUMERIC(18,14) ELSE NULL END,
        NULLIF(TRIM(geolocation_city), '')::VARCHAR(80),
        UPPER(NULLIF(TRIM(geolocation_state), ''))::CHAR(2)
    FROM base
    WHERE rn = 1;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    RAISE NOTICE 'Pos-check silver.olist_geolocation -> rows: %, duracao(s): %', v_rows, v_duration_seconds::TEXT;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Secao ERP - Pedidos, itens, pagamentos e reviews';
    RAISE NOTICE '============================================================';

    SELECT COUNT(*)
      INTO v_null_count
      FROM bronze.olist_orders b
     WHERE NULLIF(TRIM(b.order_id), '') IS NULL;

    SELECT COUNT(*)
      INTO v_dup_count
      FROM (
            SELECT NULLIF(TRIM(b.order_id), '') AS order_id
              FROM bronze.olist_orders b
             WHERE NULLIF(TRIM(b.order_id), '') IS NOT NULL
             GROUP BY 1
            HAVING COUNT(*) > 1
      ) d;

    RAISE NOTICE 'Pre-check bronze.olist_orders -> null_pk: %, dup_pk: %', v_null_count, v_dup_count;

    RAISE NOTICE 'Inserindo dados em silver.olist_orders';
    v_start_time := clock_timestamp();

    WITH base AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(TRIM(b.order_id), '')
                ORDER BY
                    CASE WHEN TRIM(b.order_purchase_timestamp) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                         THEN TRIM(b.order_purchase_timestamp)::TIMESTAMP END DESC NULLS LAST,
                    b.ctid DESC
            ) AS rn
        FROM bronze.olist_orders b
        WHERE NULLIF(TRIM(b.order_id), '') IS NOT NULL
    )
    INSERT INTO silver.olist_orders (
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date
    )
    SELECT
        NULLIF(TRIM(order_id), '')::VARCHAR(32),
        NULLIF(TRIM(customer_id), '')::VARCHAR(32),
        LOWER(NULLIF(TRIM(order_status), ''))::VARCHAR(20),
        CASE WHEN TRIM(order_purchase_timestamp) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN TRIM(order_purchase_timestamp)::TIMESTAMP ELSE NULL END,
        CASE
            WHEN TRIM(order_approved_at) = '' THEN NULL
            WHEN TRIM(order_approved_at) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN TRIM(order_approved_at)::TIMESTAMP
            ELSE NULL
        END,
        CASE
            WHEN TRIM(order_delivered_carrier_date) = '' THEN NULL
            WHEN TRIM(order_delivered_carrier_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN TRIM(order_delivered_carrier_date)::TIMESTAMP
            ELSE NULL
        END,
        CASE
            WHEN TRIM(order_delivered_customer_date) = '' THEN NULL
            WHEN TRIM(order_delivered_customer_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN TRIM(order_delivered_customer_date)::TIMESTAMP
            ELSE NULL
        END,
        CASE
            WHEN TRIM(order_estimated_delivery_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN TRIM(order_estimated_delivery_date)::TIMESTAMP
            ELSE NULL
        END
    FROM base
    WHERE rn = 1;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    SELECT COUNT(*) INTO v_null_count FROM silver.olist_orders WHERE order_id IS NULL;
    SELECT COUNT(*) INTO v_dup_count FROM (SELECT order_id FROM silver.olist_orders GROUP BY order_id HAVING COUNT(*) > 1) d;

    RAISE NOTICE 'Pos-check silver.olist_orders -> rows: %, null_pk: %, dup_pk: %, duracao(s): %', v_rows, v_null_count, v_dup_count, v_duration_seconds::TEXT;

    RAISE NOTICE 'Inserindo dados em silver.olist_order_items';
    v_start_time := clock_timestamp();

    WITH base AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(TRIM(b.order_id), ''), NULLIF(TRIM(b.order_item_id), '')
                ORDER BY
                    CASE WHEN TRIM(b.shipping_limit_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                         THEN TRIM(b.shipping_limit_date)::TIMESTAMP END DESC NULLS LAST,
                    b.ctid DESC
            ) AS rn
        FROM bronze.olist_order_items b
        WHERE NULLIF(TRIM(b.order_id), '') IS NOT NULL
    )
    INSERT INTO silver.olist_order_items (
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value
    )
    SELECT
        NULLIF(TRIM(order_id), '')::VARCHAR(32),
        CASE WHEN TRIM(order_item_id) ~ '^[0-9]+$' THEN TRIM(order_item_id)::SMALLINT ELSE NULL END,
        NULLIF(TRIM(product_id), '')::VARCHAR(32),
        NULLIF(TRIM(seller_id), '')::VARCHAR(32),
        CASE WHEN TRIM(shipping_limit_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN TRIM(shipping_limit_date)::TIMESTAMP ELSE NULL END,
        CASE WHEN TRIM(price) ~ '^[0-9]+([.][0-9]+)?$' THEN TRIM(price)::NUMERIC(10,2) ELSE NULL END,
        CASE WHEN TRIM(freight_value) ~ '^[0-9]+([.][0-9]+)?$' THEN TRIM(freight_value)::NUMERIC(10,2) ELSE NULL END
    FROM base
    WHERE rn = 1;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    RAISE NOTICE 'Pos-check silver.olist_order_items -> rows: %, duracao(s): %', v_rows, v_duration_seconds::TEXT;

    RAISE NOTICE 'Inserindo dados em silver.olist_order_payments';
    v_start_time := clock_timestamp();

    WITH base AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(TRIM(b.order_id), ''), NULLIF(TRIM(b.payment_sequential), '')
                ORDER BY b.ctid DESC
            ) AS rn
        FROM bronze.olist_order_payments b
        WHERE NULLIF(TRIM(b.order_id), '') IS NOT NULL
    )
    INSERT INTO silver.olist_order_payments (
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        payment_value
    )
    SELECT
        NULLIF(TRIM(order_id), '')::VARCHAR(32),
        CASE WHEN TRIM(payment_sequential) ~ '^[0-9]+$' THEN TRIM(payment_sequential)::SMALLINT ELSE NULL END,
        LOWER(NULLIF(TRIM(payment_type), ''))::VARCHAR(20),
        CASE WHEN TRIM(payment_installments) ~ '^[0-9]+$' THEN TRIM(payment_installments)::SMALLINT ELSE NULL END,
        CASE WHEN TRIM(payment_value) ~ '^[0-9]+([.][0-9]+)?$' THEN TRIM(payment_value)::NUMERIC(10,2) ELSE NULL END
    FROM base
    WHERE rn = 1;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    RAISE NOTICE 'Pos-check silver.olist_order_payments -> rows: %, duracao(s): %', v_rows, v_duration_seconds::TEXT;

    RAISE NOTICE 'Inserindo dados em silver.olist_order_reviews';
    v_start_time := clock_timestamp();

    WITH base AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(TRIM(b.review_id), '')
                ORDER BY
                    CASE WHEN TRIM(b.review_answer_timestamp) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                         THEN TRIM(b.review_answer_timestamp)::TIMESTAMP END DESC NULLS LAST,
                    CASE WHEN TRIM(b.review_creation_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                         THEN TRIM(b.review_creation_date)::TIMESTAMP END DESC NULLS LAST,
                    b.ctid DESC
            ) AS rn
        FROM bronze.olist_order_reviews b
        WHERE NULLIF(TRIM(b.review_id), '') IS NOT NULL
    )
    INSERT INTO silver.olist_order_reviews (
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp
    )
    SELECT
        NULLIF(TRIM(review_id), '')::VARCHAR(32),
        NULLIF(TRIM(order_id), '')::VARCHAR(32),
        CASE WHEN TRIM(review_score) ~ '^[0-9]+$' THEN TRIM(review_score)::SMALLINT ELSE NULL END,
        NULLIF(TRIM(review_comment_title), '')::VARCHAR(80),
        NULLIF(TRIM(review_comment_message), ''),
        CASE WHEN TRIM(review_creation_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN TRIM(review_creation_date)::TIMESTAMP ELSE NULL END,
        CASE
            WHEN TRIM(review_answer_timestamp) = '' THEN NULL
            WHEN TRIM(review_answer_timestamp) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN TRIM(review_answer_timestamp)::TIMESTAMP
            ELSE NULL
        END
    FROM base
    WHERE rn = 1;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    RAISE NOTICE 'Pos-check silver.olist_order_reviews -> rows: %, duracao(s): %', v_rows, v_duration_seconds::TEXT;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Secao PIM - Catalogo de produtos';
    RAISE NOTICE '============================================================';

    RAISE NOTICE 'Inserindo dados em silver.olist_products';
    v_start_time := clock_timestamp();

    WITH base AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(TRIM(b.product_id), '')
                ORDER BY b.ctid DESC
            ) AS rn
        FROM bronze.olist_products b
        WHERE NULLIF(TRIM(b.product_id), '') IS NOT NULL
    )
    INSERT INTO silver.olist_products (
        product_id,
        product_category_name,
        product_name_lenght,
        product_description_lenght,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
    )
    SELECT
        NULLIF(TRIM(product_id), '')::VARCHAR(32),
        NULLIF(TRIM(product_category_name), '')::VARCHAR(80),
        CASE WHEN TRIM(product_name_lenght) ~ '^[0-9]+$' THEN TRIM(product_name_lenght)::SMALLINT ELSE NULL END,
        CASE WHEN TRIM(product_description_lenght) ~ '^[0-9]+$' THEN TRIM(product_description_lenght)::SMALLINT ELSE NULL END,
        CASE WHEN TRIM(product_photos_qty) ~ '^[0-9]+$' THEN TRIM(product_photos_qty)::SMALLINT ELSE NULL END,
        CASE WHEN TRIM(product_weight_g) ~ '^[0-9]+$' THEN TRIM(product_weight_g)::INTEGER ELSE NULL END,
        CASE WHEN TRIM(product_length_cm) ~ '^[0-9]+$' THEN TRIM(product_length_cm)::SMALLINT ELSE NULL END,
        CASE WHEN TRIM(product_height_cm) ~ '^[0-9]+$' THEN TRIM(product_height_cm)::SMALLINT ELSE NULL END,
        CASE WHEN TRIM(product_width_cm) ~ '^[0-9]+$' THEN TRIM(product_width_cm)::SMALLINT ELSE NULL END
    FROM base
    WHERE rn = 1;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    RAISE NOTICE 'Pos-check silver.olist_products -> rows: %, duracao(s): %', v_rows, v_duration_seconds::TEXT;

    RAISE NOTICE 'Inserindo dados em silver.olist_product_category_name_translation';
    v_start_time := clock_timestamp();

    WITH base AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(TRIM(b.product_category_name), '')
                ORDER BY b.ctid DESC
            ) AS rn
        FROM bronze.olist_product_category_name_translation b
        WHERE NULLIF(TRIM(b.product_category_name), '') IS NOT NULL
    )
    INSERT INTO silver.olist_product_category_name_translation (
        product_category_name,
        product_category_name_english
    )
    SELECT
        NULLIF(TRIM(product_category_name), '')::VARCHAR(80),
        NULLIF(TRIM(product_category_name_english), '')::VARCHAR(80)
    FROM base
    WHERE rn = 1;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    RAISE NOTICE 'Pos-check silver.olist_product_category_name_translation -> rows: %, duracao(s): %', v_rows, v_duration_seconds::TEXT;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Carga da camada Silver concluida com sucesso';
    RAISE NOTICE '============================================================';

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_error_code = RETURNED_SQLSTATE,
            v_error_message = MESSAGE_TEXT,
            v_error_detail = PG_EXCEPTION_DETAIL,
            v_error_hint = PG_EXCEPTION_HINT,
            v_error_context = PG_EXCEPTION_CONTEXT;

        RAISE NOTICE '============================================================';
        RAISE NOTICE 'Ocorreu um erro ao carregar a Silver';
        RAISE NOTICE 'Numero/Codigo do erro: %', COALESCE(v_error_code, 'N/A');
        RAISE NOTICE 'Mensagem tecnica: %', COALESCE(v_error_message, 'N/A');
        RAISE NOTICE 'Detalhe tecnico: %', COALESCE(v_error_detail, 'N/A');
        RAISE NOTICE 'Hint tecnico: %', COALESCE(v_error_hint, 'N/A');
        RAISE NOTICE 'Contexto tecnico: %', COALESCE(v_error_context, 'N/A');
        RAISE NOTICE '============================================================';

        RAISE;
END;
$$;

-- Mantem o comportamento de carga automatica no primeiro init do banco.
CALL silver.proc_load_silver(TRUE);
