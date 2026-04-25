/*
Propósito:
  Criar as tabelas da camada silver (raw) do projeto Olist no schema `silver`.

Processo:
  DDL -> CREATE TABLE IF NOT EXISTS.

Parâmetros:
  Nenhum.

Exemplo de Uso:
  -- Execução via init do container (docker-entrypoint-initdb.d)
  -- ou manual via cliente SQL/psql executando este arquivo.
*/

CREATE TABLE IF NOT EXISTS silver.olist_customers (
	customer_id VARCHAR(32),
	customer_unique_id VARCHAR(32),
	customer_zip_code_prefix VARCHAR(5),
	customer_city VARCHAR(80),
	customer_state CHAR(2)
);

CREATE TABLE IF NOT EXISTS silver.olist_geolocation (
	geolocation_zip_code_prefix VARCHAR(5),
	geolocation_lat NUMERIC(18,14),
	geolocation_lng NUMERIC(18,14),
	geolocation_city VARCHAR(80),
	geolocation_state CHAR(2)
);

CREATE TABLE IF NOT EXISTS silver.olist_order_items (
	order_id VARCHAR(32),
	order_item_id SMALLINT,
	product_id VARCHAR(32),
	seller_id VARCHAR(32),
	shipping_limit_date TIMESTAMP,
	price NUMERIC(10,2),
	freight_value NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS silver.olist_order_payments (
	order_id VARCHAR(32),
	payment_sequential SMALLINT,
	payment_type VARCHAR(20),
	payment_installments SMALLINT,
	payment_value NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS silver.olist_order_reviews (
	review_id VARCHAR(32),
	order_id VARCHAR(32),
	review_score SMALLINT,
	review_comment_title VARCHAR(80),
	review_comment_message TEXT,
	review_creation_date TIMESTAMP,
	review_answer_timestamp TIMESTAMP
);

CREATE TABLE IF NOT EXISTS silver.olist_orders (
	order_id VARCHAR(32),
	customer_id VARCHAR(32),
	order_status VARCHAR(20),
	order_purchase_timestamp TIMESTAMP,
	order_approved_at TIMESTAMP,
	order_delivered_carrier_date TIMESTAMP,
	order_delivered_customer_date TIMESTAMP,
	order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE IF NOT EXISTS silver.olist_products (
	product_id VARCHAR(32),
	product_category_name VARCHAR(80),
	product_name_lenght SMALLINT,
	product_description_lenght SMALLINT,
	product_photos_qty SMALLINT,
	product_weight_g INTEGER,
	product_length_cm SMALLINT,
	product_height_cm SMALLINT,
	product_width_cm SMALLINT
);

CREATE TABLE IF NOT EXISTS silver.olist_sellers (
	seller_id VARCHAR(32),
	seller_zip_code_prefix VARCHAR(5),
	seller_city VARCHAR(80),
	seller_state CHAR(2)
);

CREATE TABLE IF NOT EXISTS silver.olist_product_category_name_translation (
	product_category_name VARCHAR(80),
	product_category_name_english VARCHAR(80)
);
