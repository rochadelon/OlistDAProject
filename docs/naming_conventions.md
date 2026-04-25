
# Naming Conventions

Este guia define padrões de nomenclatura para manter consistência entre **arquivos**, **schemas**, **tabelas** e **colunas** no projeto.

## 1) Padrões gerais

- Use **snake_case** (minúsculas + `_`) para tudo: tabelas, colunas, procedures, views.
- Evite abreviações ambíguas. Prefira nomes completos (ex.: `estimated_delivery_date` ao invés de `est_deliv_dt`).
- Nomes devem ser **descritivos** e estáveis (não mudam com frequência).
- Evite palavras reservadas do SQL (ex.: `table`, `user`, `order`). Se inevitável, prefira variações (`orders`, `user_id`).

## 2) Arquivos (scripts e docs)

### 2.1 Scripts SQL

Padrão recomendado: `NN_<tipo>_<camada>.sql` (quando fizer sentido numerar) ou `<tipo>_<camada>.sql`.

- Schemas: `01_schemas.sql`
- DDL Bronze: `ddl_bronze.sql`
- Procedimento de carga Bronze: `proc_load_bronze.sql`

Regras:
- Um arquivo, um propósito claro.
- Sem credenciais hardcoded.
- Incluir cabeçalho de documentação (Propósito / Processo / Parâmetros / Exemplo).

### 2.2 Documentação

- `docs/data_catalog.md`
- `docs/naming_conventions.md`

## 3) Schemas e camadas

Use schemas por camada:

- `bronze`: ingestão raw (tudo `TEXT` quando necessário)
- `silver`: dados tratados/limpos (tipos corretos, deduplicações)
- `gold`: dados modelados para consumo (métricas, agregados, marts)

## 4) Tabelas

### 4.1 Padrão

`<dominio>_<entidade>` em snake_case.

Exemplos (alinhados ao projeto):
- `olist_customers`
- `olist_orders`
- `olist_order_items`

### 4.2 Singular vs plural

- Prefira **plural** para tabelas que representam conjuntos de entidades (`customers`, `orders`, `products`).
- Prefira plural também para tabelas de relacionamento/itens (`order_items`, `order_payments`).

### 4.3 Prefixos e escopo

- Use prefixo do dataset/domínio quando houver risco de colisão (`olist_...`).
- Em camadas mais avançadas (silver/gold), só retire o prefixo se o catálogo estiver claramente organizado e não houver ambiguidade.

### 4.4 Tabelas de tradução/referência

- Use sufixos claros: `_translation`, `_lookup`, `_ref`.

Ex.: `olist_product_category_name_translation`.

## 5) Colunas

### 5.1 Padrão

- Snake case.
- Nomes de chaves terminam em `_id`.

Ex.: `order_id`, `customer_id`, `review_id`.

### 5.2 Sufixos de unidade

Quando houver unidade, explicite no nome:

- `*_cm`, `*_g`, `*_qty`

Ex.: `product_weight_g`, `product_length_cm`, `product_photos_qty`.

### 5.3 Datas e timestamps

- Use `_date` quando o campo for data (sem hora).
- Use `_timestamp` quando for data+hora.

Ex.: `order_purchase_timestamp`, `review_creation_date` (se virar timestamp na SILVER, considere renomear para `review_creation_timestamp`).

### 5.4 Flags e booleanos

- Prefixo `is_` / `has_`.

Ex.: `is_active`, `has_review`.

### 5.5 Sequenciais e ordens

- Use sufixo `_sequential` ou `_number` quando for contador/ordem.

Ex.: `payment_sequential`, `order_item_id`.

## 6) Chaves e relacionamentos

- PKs: `<entidade>_id` quando aplicável.
- FKs: mesmo nome da PK referenciada.

Ex.:
- `olist_orders.customer_id` referencia `olist_customers.customer_id`
- `olist_order_items.order_id` referencia `olist_orders.order_id`

## 7) Objetos SQL adicionais

- Views: prefixo `vw_` (ex.: `vw_orders_enriched`).
- Procedures: prefixo `proc_` (ex.: `proc_load_bronze`).
- Funções: prefixo `fn_`.

## 8) Consistência vs legado

Alguns nomes do dataset original têm grafia “legado” (ex.: `product_name_lenght`).

- Na BRONZE, mantenha **igual ao arquivo** para facilitar ingestão.
- Na SILVER/GOLD, padronize e corrija (`product_name_length`) se isso fizer parte do seu modelo.

