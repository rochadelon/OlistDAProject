-- Executa a inicializacao completa das camadas em ordem.
-- Observacao: o entrypoint do Postgres executa apenas arquivos na raiz de /docker-entrypoint-initdb.d.

\i /docker-entrypoint-initdb.d/bronze_layer/ddl_bronze.sql
\i /docker-entrypoint-initdb.d/bronze_layer/proc_load_bronze.sql
\i /docker-entrypoint-initdb.d/silver_layer/ddl_silver.sql
\i /docker-entrypoint-initdb.d/silver_layer/proc_load_silver.sql
\i /docker-entrypoint-initdb.d/golden_layer/goldem_dim.sql
\i /docker-entrypoint-initdb.d/golden_layer/goldem_facts.sql
