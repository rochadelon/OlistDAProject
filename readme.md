# Olist Data Warehouse

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Status](https://img.shields.io/badge/status-em%20desenvolvimento-F2C94C)

Projeto de Engenharia de Dados com PostgreSQL e arquitetura em camadas (Bronze, Silver e Gold), usando dados publicos da Olist.

## Objetivo

Construir uma base analitica organizada para estudos de BI e analytics, com foco em:

- ingestao dos CSVs originais na camada Bronze
- padronizacao, tipagem e qualidade de dados na camada Silver
- modelagem dimensional na camada Gold

## Fonte dos dados

Os dados publicos utilizados neste projeto estao disponiveis no Kaggle:

- Brazilian E-Commerce Public Dataset by Olist: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce


## Arquitetura de dados

- Bronze (`schema bronze`): dados brutos, proximos da origem (majoritariamente `TEXT`)
- Silver (`schema silver`): dados limpos, tipados e deduplicados
- Gold (`schema gold`): dimensoes e fatos para analise

Fluxo resumido:

1. CSVs em `files/olist`
2. Carga Bronze via `COPY` com procedure `bronze.proc_load_bronze`
3. Transformacao Bronze -> Silver via procedure `silver.proc_load_silver`
4. Camada Gold com views dimensionais e factuais para consumo analitico

## Estrutura do repositorio

```text
.
|-- docker-compose.yml
|-- readme.md
|-- docs/
|-- files/
|   `-- olist/
`-- scripts/
	|-- 01_schemas.sql
	|-- 02_init_all_layers.sql
	|-- bronze_layer/
	|   |-- ddl_bronze.sql
	|   `-- proc_load_bronze.sql
	|-- silver_layer/
	|   |-- ddl_silver.sql
	|   `-- proc_load_silver.sql
	`-- golden_layer/
		|-- goldem_dim.sql
		`-- goldem_facts.sql
```

## Pre-requisitos

- Docker Desktop
- Docker Compose
- Cliente SQL opcional (`psql`, DBeaver, DataGrip)

## Como executar

### 1) Subir o banco

```bash
docker compose up -d
```

O container expoe o PostgreSQL em `localhost:5555`.

Credenciais atuais em `docker-compose.yml`:

- usuario: `postgres`
- senha: `NovaSenhaMuitoForte123`
- database: `olist_db`

### 2) Entender o que roda automaticamente

No primeiro bootstrap (volume vazio), o Postgres executa automaticamente os arquivos SQL da raiz de `/docker-entrypoint-initdb.d`:

- `01_schemas.sql`
- `02_init_all_layers.sql`

O arquivo `02_init_all_layers.sql` encadeia a execucao de Bronze, Silver e Gold na ordem correta.

### 3) Reprocessar cargas manualmente (quando necessario)

Conecte no banco e execute:

```sql
CALL bronze.proc_load_bronze(TRUE);
CALL silver.proc_load_silver(TRUE);
```

### 4) Recriar objetos Gold

Os objetos da Gold sao **views** e podem ser recriados manualmente com:

```sql
\i /docker-entrypoint-initdb.d/golden_layer/goldem_dim.sql
\i /docker-entrypoint-initdb.d/golden_layer/goldem_facts.sql
```

## Validacoes rapidas

```sql
-- Conferir schemas
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('bronze', 'silver', 'gold')
ORDER BY schema_name;

-- Contar linhas de algumas tabelas
SELECT 'bronze.olist_orders' AS tabela, COUNT(*) AS linhas FROM bronze.olist_orders
UNION ALL
SELECT 'silver.olist_orders', COUNT(*) FROM silver.olist_orders
UNION ALL
SELECT 'bronze.olist_geolocation', COUNT(*) FROM bronze.olist_geolocation
UNION ALL
SELECT 'silver.olist_geolocation', COUNT(*) FROM silver.olist_geolocation;

-- Validar views da Gold (se necessario, desative paralelismo na sessao)
SET max_parallel_workers_per_gather = 0;

SELECT 'gold.dim_customer' AS view_name, COUNT(*) AS linhas FROM gold.dim_customer
UNION ALL
SELECT 'gold.dim_date', COUNT(*) FROM gold.dim_date
UNION ALL
SELECT 'gold.fact_orders', COUNT(*) FROM gold.fact_orders
UNION ALL
SELECT 'gold.fact_order_items', COUNT(*) FROM gold.fact_order_items;

-- Listar views da camada Gold
\dv gold.*
```

## Documentacao

- Catalogo de dados (Bronze, Silver e Gold): `docs/data_catalog.md`
- Fluxo de dados: `docs/data_flow_diagram.md`
- Documentacao Bronze: `docs/doc_bronze.md`
- Regras Silver: `docs/doc_silver_rules.md`
- Convencoes de nomes: `docs/naming_conventions.md`

## Observacoes importantes

- A carga Bronze usa caminhos de arquivos no container (`/data/csv/...`).
- Em execucoes repetidas, prefira chamar procedures com `p_truncate = TRUE` para evitar duplicidades.
- A tabela `silver.olist_geolocation` tende a reduzir bastante o volume por regra de deduplicacao.
- Os scripts da Gold estao nomeados como `goldem_dim.sql` e `goldem_facts.sql` no repositorio.

## Proximos passos

- [X] adicionar script de inicializacao completa por camadas (`scripts/02_init_all_layers.sql`)
- [X] criar views de consumo para BI
- [ ] expandir testes de qualidade automatizados (null checks, duplicidade, ranges)
- [ ] automatizar pipeline com CI/CD
