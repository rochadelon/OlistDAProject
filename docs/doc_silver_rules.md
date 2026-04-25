# Documentacao de Regras da Camada Silver

## 1. Objetivo

Documentar as regras aplicadas na carga Bronze -> Silver para garantir:
- deduplicacao consistente
- padronizacao textual
- tipagem segura
- rastreabilidade operacional

Implementacao de referencia:
- scripts/silver_layer/ddl_silver.sql
- scripts/silver_layer/proc_load_silver.sql

## 2. Escopo

Tabelas Silver cobertas:
- silver.olist_customers
- silver.olist_geolocation
- silver.olist_order_items
- silver.olist_order_payments
- silver.olist_order_reviews
- silver.olist_orders
- silver.olist_products
- silver.olist_sellers
- silver.olist_product_category_name_translation

## 3. Regras Globais

### 3.1 Deduplicacao

Padrao base:
- usar ROW_NUMBER() OVER (PARTITION BY chave_de_dedup ORDER BY criterio_recencia DESC)
- manter somente rn = 1

Observacao:
- quando nao existe coluna clara de recencia, usa-se ctid DESC como desempate tecnico.

### 3.2 Limpeza e normalizacao

Regras aplicadas:
- TRIM em campos textuais
- NULLIF(TRIM(col), '') para converter vazio em NULL
- UPPER para UF (estado)
- LOWER para campos categoricos como order_status e payment_type
- LPAD(..., 5, '0') para prefixo de CEP

### 3.3 Cast seguro

Padrao aplicado antes de converter tipos:
- numericos: regex + CAST
- timestamps: regex + CAST
- valores invalidos: gravar NULL ao inves de falhar a carga

### 3.4 Carga e controle

Fluxo da procedure:
1. TRUNCATE opcional (p_truncate = TRUE)
2. INSERT por secao funcional (CRM, GEO, ERP, PIM)
3. logs de pre-check e pos-check
4. medicao de duracao por tabela
5. tratamento de erro com EXCEPTION e diagnostico tecnico

## 4. Regras por Tabela

## 4.1 silver.olist_customers

Deduplicacao:
- PARTITION BY customer_id
- ORDER BY customer_unique_id DESC NULLS LAST, ctid DESC

Regras:
- customer_id, customer_unique_id: TRIM + VARCHAR(32)
- customer_zip_code_prefix: TRIM + LPAD(5) + VARCHAR(5)
- customer_city: TRIM + VARCHAR(80)
- customer_state: TRIM + UPPER + CHAR(2)

Checks:
- pre: null_pk e dup_pk em bronze.customer_id
- pos: null_pk e dup_pk em silver.customer_id

## 4.2 silver.olist_sellers

Deduplicacao:
- PARTITION BY seller_id
- ORDER BY ctid DESC

Regras:
- seller_id: TRIM + VARCHAR(32)
- seller_zip_code_prefix: TRIM + LPAD(5) + VARCHAR(5)
- seller_city: TRIM + VARCHAR(80)
- seller_state: TRIM + UPPER + CHAR(2)

Checks:
- pre: null_pk e dup_pk em bronze.seller_id
- pos: null_pk e dup_pk em silver.seller_id

## 4.3 silver.olist_geolocation

Deduplicacao:
- PARTITION BY (zip_prefix, lat, lng, city, state)
- ORDER BY ctid DESC

Regras:
- geolocation_zip_code_prefix: TRIM + LPAD(5) + VARCHAR(5)
- geolocation_lat: regex numerica -> NUMERIC(18,14)
- geolocation_lng: regex numerica -> NUMERIC(18,14)
- geolocation_city: TRIM + VARCHAR(80)
- geolocation_state: TRIM + UPPER + CHAR(2)

Checks:
- pos: contagem de linhas carregadas e tempo

## 4.4 silver.olist_orders

Deduplicacao:
- PARTITION BY order_id
- ORDER BY order_purchase_timestamp DESC (quando valido), ctid DESC

Regras:
- order_id, customer_id: TRIM + VARCHAR(32)
- order_status: TRIM + LOWER + VARCHAR(20)
- colunas de data/hora: regex timestamp -> TIMESTAMP, senao NULL
  - order_purchase_timestamp
  - order_approved_at
  - order_delivered_carrier_date
  - order_delivered_customer_date
  - order_estimated_delivery_date

Checks:
- pre: null_pk e dup_pk em bronze.order_id
- pos: null_pk e dup_pk em silver.order_id

## 4.5 silver.olist_order_items

Deduplicacao:
- PARTITION BY (order_id, order_item_id)
- ORDER BY shipping_limit_date DESC (quando valido), ctid DESC

Regras:
- order_id, product_id, seller_id: TRIM + VARCHAR(32)
- order_item_id: regex inteiro -> SMALLINT
- shipping_limit_date: regex timestamp -> TIMESTAMP
- price: regex decimal -> NUMERIC(10,2)
- freight_value: regex decimal -> NUMERIC(10,2)

Checks:
- pos: contagem de linhas carregadas e tempo

## 4.6 silver.olist_order_payments

Deduplicacao:
- PARTITION BY (order_id, payment_sequential)
- ORDER BY ctid DESC

Regras:
- order_id: TRIM + VARCHAR(32)
- payment_sequential: regex inteiro -> SMALLINT
- payment_type: TRIM + LOWER + VARCHAR(20)
- payment_installments: regex inteiro -> SMALLINT
- payment_value: regex decimal -> NUMERIC(10,2)

Checks:
- pos: contagem de linhas carregadas e tempo

## 4.7 silver.olist_order_reviews

Deduplicacao:
- PARTITION BY review_id
- ORDER BY review_answer_timestamp DESC (valido), review_creation_date DESC (valido), ctid DESC

Regras:
- review_id, order_id: TRIM + VARCHAR(32)
- review_score: regex inteiro -> SMALLINT
- review_comment_title: TRIM + VARCHAR(80)
- review_comment_message: TRIM + NULLIF vazio
- review_creation_date: regex timestamp -> TIMESTAMP
- review_answer_timestamp: regex timestamp -> TIMESTAMP, vazio -> NULL

Checks:
- pos: contagem de linhas carregadas e tempo

## 4.8 silver.olist_products

Deduplicacao:
- PARTITION BY product_id
- ORDER BY ctid DESC

Regras:
- product_id: TRIM + VARCHAR(32)
- product_category_name: TRIM + VARCHAR(80)
- campos inteiros com regex + CAST:
  - product_name_lenght (SMALLINT)
  - product_description_lenght (SMALLINT)
  - product_photos_qty (SMALLINT)
  - product_weight_g (INTEGER)
  - product_length_cm (SMALLINT)
  - product_height_cm (SMALLINT)
  - product_width_cm (SMALLINT)

Checks:
- pos: contagem de linhas carregadas e tempo

## 4.9 silver.olist_product_category_name_translation

Deduplicacao:
- PARTITION BY product_category_name
- ORDER BY ctid DESC

Regras:
- product_category_name: TRIM + VARCHAR(80)
- product_category_name_english: TRIM + VARCHAR(80)

Checks:
- pos: contagem de linhas carregadas e tempo

## 5. Regras de Erro e Logging

Tratamento de erro:
- EXCEPTION WHEN OTHERS
- captura de diagnosticos:
  - RETURNED_SQLSTATE
  - MESSAGE_TEXT
  - PG_EXCEPTION_DETAIL
  - PG_EXCEPTION_HINT
  - PG_EXCEPTION_CONTEXT
- rethrow com RAISE para nao mascarar falhas

Logs operacionais:
- inicio/fim da carga
- seções por dominio (CRM, GEO, ERP, PIM)
- pre-check e pos-check
- duracao em segundos por tabela

## 6. Impacto de Deduplicacao (ultima execucao validada)

Resultado Bronze -> Silver observado:
- customers: 99441 -> 99441
- geolocation: 1000163 -> 738332
- order_items: 112650 -> 112650
- order_payments: 103886 -> 103886
- order_reviews: 99224 -> 98410
- orders: 99441 -> 99441
- products: 32951 -> 32951
- sellers: 3095 -> 3095
- translation: 71 -> 71

Interpretacao:
- houve remocao relevante de duplicatas em geolocation e order_reviews.

## 7. Boas Praticas para Evolucao

- substituir desempate por ctid por metadado de recencia (ex.: updated_at) quando existir
- adicionar constraints na Silver (PK/UK) apos estabilizar regras
- registrar auditoria de linhas descartadas por deduplicacao
- documentar alteracoes de regra por versao
