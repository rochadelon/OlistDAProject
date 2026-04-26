CREATE TABLE gold.fact_order_items (
    -- chaves de negócio da fonte (úteis para rastreio)
    order_id                    VARCHAR(32),
    order_item_id               SMALLINT,

    -- FKs dimensionais
    order_date_sk               INTEGER,      -- order_purchase_timestamp
    approved_date_sk            INTEGER,
    delivered_carrier_date_sk   INTEGER,
    delivered_customer_date_sk  INTEGER,
    estimated_delivery_date_sk  INTEGER,

    customer_sk                 INTEGER,
    seller_sk                   INTEGER,
    product_sk                  INTEGER,
    order_status_sk             SMALLINT,

    -- pagamento (agregado a nível do pedido ou do item)
    main_payment_type_sk        SMALLINT,     -- se quiser trazer o tipo principal

    -- medidas
    item_price                  NUMERIC(10,2),
    item_freight_value          NUMERIC(10,2),
    item_gross_revenue          NUMERIC(10,2), -- price
    item_net_revenue            NUMERIC(10,2), -- se tiver custo
    item_qty                    INTEGER DEFAULT 1,

    -- métricas de prazo (em dias)
    days_approval               INTEGER,
    days_delivery               INTEGER,
    days_delay_vs_estimated     INTEGER,

    -- review (opcionalmente trazida para o nível do item)
    review_score                SMALLINT,

    CONSTRAINT pk_fact_order_items PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_fact_order_items_order_date
        FOREIGN KEY (order_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_fact_order_items_approved_date
        FOREIGN KEY (approved_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_fact_order_items_delivered_carrier
        FOREIGN KEY (delivered_carrier_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_fact_order_items_delivered_customer
        FOREIGN KEY (delivered_customer_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_fact_order_items_estimated_delivery
        FOREIGN KEY (estimated_delivery_date_sk) REFERENCES gold.dim_date(date_sk),

    CONSTRAINT fk_fact_order_items_customer
        FOREIGN KEY (customer_sk) REFERENCES gold.dim_customer(customer_sk),
    CONSTRAINT fk_fact_order_items_seller
        FOREIGN KEY (seller_sk) REFERENCES gold.dim_seller(seller_sk),
    CONSTRAINT fk_fact_order_items_product
        FOREIGN KEY (product_sk) REFERENCES gold.dim_product(product_sk),
    CONSTRAINT fk_fact_order_items_status
        FOREIGN KEY (order_status_sk) REFERENCES gold.dim_order_status(order_status_sk),
    CONSTRAINT fk_fact_order_items_payment_type
        FOREIGN KEY (main_payment_type_sk) REFERENCES gold.dim_payment_type(payment_type_sk)
);

CREATE TABLE gold.fact_orders (
    order_id                    VARCHAR(32) PRIMARY KEY,

    order_date_sk               INTEGER,
    approved_date_sk            INTEGER,
    delivered_carrier_date_sk   INTEGER,
    delivered_customer_date_sk  INTEGER,
    estimated_delivery_date_sk  INTEGER,

    customer_sk                 INTEGER,
    order_status_sk             SMALLINT,

    total_items                 INTEGER,
    total_gross_revenue         NUMERIC(12,2),
    total_freight_value         NUMERIC(12,2),
    total_payment_value         NUMERIC(12,2),

    avg_item_price              NUMERIC(10,2),
    days_delivery               INTEGER,
    days_delay_vs_estimated     INTEGER,
    review_score                SMALLINT,

    CONSTRAINT fk_fact_orders_order_date
        FOREIGN KEY (order_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_fact_orders_customer
        FOREIGN KEY (customer_sk) REFERENCES gold.dim_customer(customer_sk),
    CONSTRAINT fk_fact_orders_status
        FOREIGN KEY (order_status_sk) REFERENCES gold.dim_order_status(order_status_sk)
);

CREATE TABLE gold.fact_payments (
    order_id                VARCHAR(32),
    payment_sequential      SMALLINT,
    payment_type_sk         SMALLINT,
    payment_installments    SMALLINT,
    payment_value           NUMERIC(10,2),

    order_date_sk           INTEGER,
    customer_sk             INTEGER,

    CONSTRAINT pk_fact_payments PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_fact_payments_payment_type FOREIGN KEY (payment_type_sk)
        REFERENCES gold.dim_payment_type(payment_type_sk),
    CONSTRAINT fk_fact_payments_order_date FOREIGN KEY (order_date_sk)
        REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_fact_payments_customer FOREIGN KEY (customer_sk)
        REFERENCES gold.dim_customer(customer_sk)
);

CREATE TABLE gold.fact_reviews (
    review_id              VARCHAR(32) PRIMARY KEY,
    order_id               VARCHAR(32),
    customer_sk            INTEGER,
    order_date_sk          INTEGER,
    review_creation_date_sk INTEGER,
    review_answer_date_sk   INTEGER,

    review_score           SMALLINT,
    has_comment            BOOLEAN,

    CONSTRAINT fk_fact_reviews_order_date
        FOREIGN KEY (order_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_fact_reviews_review_creation
        FOREIGN KEY (review_creation_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_fact_reviews_review_answer
        FOREIGN KEY (review_answer_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_fact_reviews_customer
        FOREIGN KEY (customer_sk) REFERENCES gold.dim_customer(customer_sk)
);