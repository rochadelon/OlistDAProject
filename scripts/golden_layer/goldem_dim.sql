CREATE TABLE gold.dim_date (
    date_sk            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_date          DATE UNIQUE,
    year               SMALLINT,
    month              SMALLINT,
    month_name         VARCHAR(15),
    quarter            SMALLINT,
    day                SMALLINT,
    day_of_week        SMALLINT,
    day_of_week_name   VARCHAR(15),
    is_weekend         BOOLEAN
);

CREATE TABLE gold.dim_customer (
    customer_sk                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_unique_id         VARCHAR(32),    -- chave de negócio
    customer_id_source         VARCHAR(32),    -- opcional, id técnico da silver
    customer_zip_code_prefix   VARCHAR(5),
    customer_city              VARCHAR(80),
    customer_state             CHAR(2),

    -- atributos derivados
    first_order_date_sk        INTEGER,
    last_order_date_sk         INTEGER,
    total_orders               INTEGER,
    CONSTRAINT uq_dim_customer_unique_id UNIQUE (customer_unique_id),
    CONSTRAINT fk_dim_customer_first_date FOREIGN KEY (first_order_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_dim_customer_last_date  FOREIGN KEY (last_order_date_sk)  REFERENCES gold.dim_date(date_sk)
);

CREATE TABLE gold.dim_seller (
    seller_sk               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id               VARCHAR(32),   -- chave de negócio
    seller_zip_code_prefix  VARCHAR(5),
    seller_city             VARCHAR(80),
    seller_state            CHAR(2),
    first_order_date_sk     INTEGER,
    last_order_date_sk      INTEGER,
    total_orders            INTEGER,
    CONSTRAINT uq_dim_seller_id UNIQUE (seller_id),
    CONSTRAINT fk_dim_seller_first_date FOREIGN KEY (first_order_date_sk) REFERENCES gold.dim_date(date_sk),
    CONSTRAINT fk_dim_seller_last_date  FOREIGN KEY (last_order_date_sk)  REFERENCES gold.dim_date(date_sk)
);

CREATE TABLE gold.dim_product_category (
    product_category_sk          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_category_name        VARCHAR(80), -- original (pt)
    product_category_name_en     VARCHAR(80),
    CONSTRAINT uq_dim_product_category UNIQUE (product_category_name)
);

CREATE TABLE gold.dim_order_status (
    order_status_sk   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_status_code VARCHAR(20) UNIQUE,   -- ex: delivered, shipped, cancelled
    is_closed         BOOLEAN,
    is_cancelled      BOOLEAN
);

CREATE TABLE gold.dim_payment_type (
    payment_type_sk   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_type_code VARCHAR(20) UNIQUE,   -- credit_card, boleto, voucher...
    is_installment    BOOLEAN
);

CREATE TABLE gold.dim_geolocation (
    geolocation_sk             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    zip_code_prefix            VARCHAR(5) UNIQUE,
    geolocation_lat            NUMERIC(18, 14),
    geolocation_lng            NUMERIC(18, 14),
    geolocation_city           VARCHAR(80),
    geolocation_state          CHAR(2)
);

