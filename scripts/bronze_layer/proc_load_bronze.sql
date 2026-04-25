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
DECLARE
	v_error_code TEXT;
	v_error_message TEXT;
	v_error_detail TEXT;
	v_error_hint TEXT;
	v_error_context TEXT;
	v_start_time TIMESTAMP;
	v_end_time TIMESTAMP;
	v_duration_seconds NUMERIC;
BEGIN
	RAISE NOTICE '============================================================';
	RAISE NOTICE 'Iniciando carga da camada Bronze';
	RAISE NOTICE '============================================================';

	IF p_truncate THEN
		RAISE NOTICE '--- Limpando tabelas Bronze (TRUNCATE) ---';

		RAISE NOTICE 'Truncando tabela bronze.olist_customers';
		TRUNCATE TABLE bronze.olist_customers;

		RAISE NOTICE 'Truncando tabela bronze.olist_geolocation';
		TRUNCATE TABLE bronze.olist_geolocation;

		RAISE NOTICE 'Truncando tabela bronze.olist_order_items';
		TRUNCATE TABLE bronze.olist_order_items;

		RAISE NOTICE 'Truncando tabela bronze.olist_order_payments';
		TRUNCATE TABLE bronze.olist_order_payments;

		RAISE NOTICE 'Truncando tabela bronze.olist_order_reviews';
		TRUNCATE TABLE bronze.olist_order_reviews;

		RAISE NOTICE 'Truncando tabela bronze.olist_orders';
		TRUNCATE TABLE bronze.olist_orders;

		RAISE NOTICE 'Truncando tabela bronze.olist_products';
		TRUNCATE TABLE bronze.olist_products;

		RAISE NOTICE 'Truncando tabela bronze.olist_sellers';
		TRUNCATE TABLE bronze.olist_sellers;

		RAISE NOTICE 'Truncando tabela bronze.olist_product_category_name_translation';
		TRUNCATE TABLE bronze.olist_product_category_name_translation;
	ELSE
		RAISE NOTICE 'Parametro p_truncate=FALSE: etapa de TRUNCATE ignorada';
	END IF;

	RAISE NOTICE '============================================================';
	RAISE NOTICE 'Secao CRM - Cadastros de clientes e vendedores';
	RAISE NOTICE '============================================================';

	RAISE NOTICE 'Inserindo dados em bronze.olist_customers';
	v_start_time := clock_timestamp();

	COPY bronze.olist_customers
	FROM '/data/csv/olist_customers_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	v_end_time := clock_timestamp();
	v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
	RAISE NOTICE 'Duracao (s) bronze.olist_customers: %', v_duration_seconds::TEXT;

	RAISE NOTICE 'Inserindo dados em bronze.olist_sellers';
	v_start_time := clock_timestamp();

	COPY bronze.olist_sellers
	FROM '/data/csv/olist_sellers_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	v_end_time := clock_timestamp();
	v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
	RAISE NOTICE 'Duracao (s) bronze.olist_sellers: %', v_duration_seconds::TEXT;

	RAISE NOTICE '============================================================';
	RAISE NOTICE 'Secao GEO - Referencia geografica';
	RAISE NOTICE '============================================================';

	RAISE NOTICE 'Inserindo dados em bronze.olist_geolocation';
	v_start_time := clock_timestamp();

	COPY bronze.olist_geolocation
	FROM '/data/csv/olist_geolocation_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	v_end_time := clock_timestamp();
	v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
	RAISE NOTICE 'Duracao (s) bronze.olist_geolocation: %', v_duration_seconds::TEXT;

	RAISE NOTICE '============================================================';
	RAISE NOTICE 'Secao ERP - Pedidos, itens, pagamentos e reviews';
	RAISE NOTICE '============================================================';

	RAISE NOTICE 'Inserindo dados em bronze.olist_orders';
	v_start_time := clock_timestamp();

	COPY bronze.olist_orders
	FROM '/data/csv/olist_orders_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	v_end_time := clock_timestamp();
	v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
	RAISE NOTICE 'Duracao (s) bronze.olist_orders: %', v_duration_seconds::TEXT;

	RAISE NOTICE 'Inserindo dados em bronze.olist_order_items';
	v_start_time := clock_timestamp();

	COPY bronze.olist_order_items
	FROM '/data/csv/olist_order_items_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	v_end_time := clock_timestamp();
	v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
	RAISE NOTICE 'Duracao (s) bronze.olist_order_items: %', v_duration_seconds::TEXT;

	RAISE NOTICE 'Inserindo dados em bronze.olist_order_payments';
	v_start_time := clock_timestamp();

	COPY bronze.olist_order_payments
	FROM '/data/csv/olist_order_payments_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	v_end_time := clock_timestamp();
	v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
	RAISE NOTICE 'Duracao (s) bronze.olist_order_payments: %', v_duration_seconds::TEXT;

	RAISE NOTICE 'Inserindo dados em bronze.olist_order_reviews';
	v_start_time := clock_timestamp();

	COPY bronze.olist_order_reviews
	FROM '/data/csv/olist_order_reviews_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	v_end_time := clock_timestamp();
	v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
	RAISE NOTICE 'Duracao (s) bronze.olist_order_reviews: %', v_duration_seconds::TEXT;

	RAISE NOTICE '============================================================';
	RAISE NOTICE 'Secao PIM - Catalogo de produtos';
	RAISE NOTICE '============================================================';

	RAISE NOTICE 'Inserindo dados em bronze.olist_products';
	v_start_time := clock_timestamp();

	COPY bronze.olist_products
	FROM '/data/csv/olist_products_dataset.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	v_end_time := clock_timestamp();
	v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
	RAISE NOTICE 'Duracao (s) bronze.olist_products: %', v_duration_seconds::TEXT;

	RAISE NOTICE 'Inserindo dados em bronze.olist_product_category_name_translation';
	v_start_time := clock_timestamp();

	COPY bronze.olist_product_category_name_translation
	FROM '/data/csv/product_category_name_translation.csv'
	WITH (FORMAT CSV, HEADER, DELIMITER ',');

	v_end_time := clock_timestamp();
	v_duration_seconds := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
	RAISE NOTICE 'Duracao (s) bronze.olist_product_category_name_translation: %', v_duration_seconds::TEXT;

	RAISE NOTICE '============================================================';
	RAISE NOTICE 'Carga da camada Bronze concluida com sucesso';
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
		RAISE NOTICE 'Ocorreu um erro ao carregar a Bronze';
		RAISE NOTICE 'Numero/Codigo do erro: %', COALESCE(v_error_code, 'N/A');
		RAISE NOTICE 'Mensagem tecnica: %', COALESCE(v_error_message, 'N/A');
		RAISE NOTICE 'Detalhe tecnico: %', COALESCE(v_error_detail, 'N/A');
		RAISE NOTICE 'Hint tecnico: %', COALESCE(v_error_hint, 'N/A');
		RAISE NOTICE 'Contexto tecnico: %', COALESCE(v_error_context, 'N/A');
		RAISE NOTICE '============================================================';

		RAISE;
END;
$$;

-- Mantém o comportamento de carga automática no primeiro init do banco.
CALL bronze.proc_load_bronze(TRUE);
