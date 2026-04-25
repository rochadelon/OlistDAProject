/*
Propósito:
  Criar e executar uma procedure para carregar (bulk load) os CSVs da pasta /data/csv
  nas tabelas da camada BRONZE.

Processo:
  (Opcional) TRUNCATE -> COPY (Bulk Insert).

Parâmetros:
  p_truncate BOOLEAN (default TRUE): se TRUE, limpa as tabelas bronze antes do load.

Exemplo de Uso:
  -- PostgreSQL:
  CALL bronze.proc_load_bronze(TRUE);
  -- Observação: em alguns SGBDs o comando equivalente é EXEC.
*/

CREATE OR REPLACE PROCEDURE bronze.proc_load_bronze(p_truncate BOOLEAN DEFAULT TRUE)
LANGUAGE plpgsql
AS $$
BEGIN
	IF p_truncate THEN
		TRUNCATE TABLE
			bronze.olist_customers,
			bronze.olist_geolocation,
			bronze.olist_order_items,
			bronze.olist_order_payments,
			bronze.olist_order_reviews,
			bronze.olist_orders,
			bronze.olist_products,
			bronze.olist_sellers,
			bronze.olist_product_category_name_translation;
	END IF;

	COPY bronze.olist_customers
	FROM '/data/csv/olist_customers_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	COPY bronze.olist_geolocation
	FROM '/data/csv/olist_geolocation_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	COPY bronze.olist_order_items
	FROM '/data/csv/olist_order_items_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	COPY bronze.olist_order_payments
	FROM '/data/csv/olist_order_payments_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	COPY bronze.olist_order_reviews
	FROM '/data/csv/olist_order_reviews_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	COPY bronze.olist_orders
	FROM '/data/csv/olist_orders_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	COPY bronze.olist_products
	FROM '/data/csv/olist_products_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	COPY bronze.olist_sellers
	FROM '/data/csv/olist_sellers_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	COPY bronze.olist_product_category_name_translation
	FROM '/data/csv/product_category_name_translation.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');
END;
$$;

-- Mantém o comportamento de carga automática no primeiro init do banco.
CALL bronze.proc_load_bronze(TRUE);
