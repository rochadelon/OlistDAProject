
# Olist Data Catalog

Este documento descreve os datasets do projeto (camada **BRONZE**), incluindo metadados e descrições de campos.

## Visão geral

**Fonte de dados (arquivos):** `files/olist/*.csv`

**Ingestão (container):** os CSVs são montados em `/data/csv` (ver `docker-compose.yml`) e carregados via `COPY`.

**Camada:** BRONZE (raw)

**Schema:** `bronze`

**DDL:** `scripts/ddl_bronze.sql`

**Carga:** `scripts/proc_load_bronze.sql` (procedure `bronze.proc_load_bronze(p_truncate BOOLEAN)`)

**Formato dos arquivos:** CSV com header e delimitador `,`.

**Observação sobre tipos:** na BRONZE, todos os campos são armazenados como `TEXT`. Conversões (datas/números) devem ser feitas em camadas posteriores.

## Inventário (tabelas)

Contagens validadas em 2026-04-24 (após execução de `CALL bronze.proc_load_bronze(TRUE)`):

| Tabela (bronze) | Arquivo de origem | Linhas |
|---|---|---:|
| `olist_customers` | `olist_customers_dataset.csv` | 99.441 |
| `olist_geolocation` | `olist_geolocation_dataset.csv` | 1.000.163 |
| `olist_order_items` | `olist_order_items_dataset.csv` | 112.650 |
| `olist_order_payments` | `olist_order_payments_dataset.csv` | 103.886 |
| `olist_order_reviews` | `olist_order_reviews_dataset.csv` | 99.224 |
| `olist_orders` | `olist_orders_dataset.csv` | 99.441 |
| `olist_products` | `olist_products_dataset.csv` | 32.951 |
| `olist_sellers` | `olist_sellers_dataset.csv` | 3.095 |
| `olist_product_category_name_translation` | `product_category_name_translation.csv` | 71 |

---

## bronze.olist_customers

**Descrição:** cadastro de clientes (identificadores e localização aproximada).

**Grão:** 1 linha por `customer_id`.

**Chave(s) sugerida(s):**
- PK (na prática): `customer_id`
- Identificador estável de cliente (entre pedidos): `customer_unique_id`

**Campos**

| Campo | Descrição |
|---|---|
| `customer_id` | Identificador do cliente no contexto do pedido (pode mudar entre compras do mesmo cliente). |
| `customer_unique_id` | Identificador estável do cliente (mesma pessoa/entidade). |
| `customer_zip_code_prefix` | Prefixo do CEP do cliente (geralmente 5 dígitos). |
| `customer_city` | Cidade do cliente. |
| `customer_state` | UF do cliente (ex.: SP, RJ). |

---

## bronze.olist_geolocation

**Descrição:** mapeamento de CEP (prefixo) para coordenadas e localidade.

**Grão:** múltiplas linhas por `geolocation_zip_code_prefix` (pode haver variações de coordenadas/cidade).

**Chave(s) sugerida(s):** não há chave natural única; tratar como tabela de referência e aplicar deduplicação/regra de escolha na SILVER.

**Campos**

| Campo | Descrição |
|---|---|
| `geolocation_zip_code_prefix` | Prefixo do CEP (chave de ligação com clientes/vendedores). |
| `geolocation_lat` | Latitude (texto na BRONZE). |
| `geolocation_lng` | Longitude (texto na BRONZE). |
| `geolocation_city` | Cidade associada ao prefixo do CEP. |
| `geolocation_state` | UF associada ao prefixo do CEP. |

---

## bronze.olist_orders

**Descrição:** pedidos (status e timestamps do fluxo logístico).

**Grão:** 1 linha por `order_id`.

**Chave(s) sugerida(s):** PK `order_id`.

**Campos**

| Campo | Descrição |
|---|---|
| `order_id` | Identificador do pedido. |
| `customer_id` | Cliente associado ao pedido (join com `olist_customers.customer_id`). |
| `order_status` | Status do pedido (ex.: delivered, shipped, canceled). |
| `order_purchase_timestamp` | Data/hora da compra. |
| `order_approved_at` | Data/hora de aprovação do pagamento. |
| `order_delivered_carrier_date` | Data/hora de entrega ao transportador. |
| `order_delivered_customer_date` | Data/hora de entrega ao cliente. |
| `order_estimated_delivery_date` | Data estimada de entrega. |

---

## bronze.olist_order_items

**Descrição:** itens de um pedido (produto, vendedor e valores por item).

**Grão:** 1 linha por item do pedido.

**Chave(s) sugerida(s):** (`order_id`, `order_item_id`).

**Campos**

| Campo | Descrição |
|---|---|
| `order_id` | Identificador do pedido (join com `olist_orders.order_id`). |
| `order_item_id` | Sequencial do item dentro do pedido (1..N). |
| `product_id` | Identificador do produto (join com `olist_products.product_id`). |
| `seller_id` | Identificador do vendedor (join com `olist_sellers.seller_id`). |
| `shipping_limit_date` | Limite de envio para o vendedor (SLA). |
| `price` | Preço do item (texto na BRONZE). |
| `freight_value` | Valor do frete do item (texto na BRONZE). |

---

## bronze.olist_order_payments

**Descrição:** pagamentos associados ao pedido (pode haver múltiplos registros por pedido).

**Grão:** 1 linha por pagamento (sequencial) dentro do pedido.

**Chave(s) sugerida(s):** (`order_id`, `payment_sequential`).

**Campos**

| Campo | Descrição |
|---|---|
| `order_id` | Identificador do pedido. |
| `payment_sequential` | Sequencial do pagamento dentro do pedido. |
| `payment_type` | Tipo de pagamento (ex.: credit_card, boleto). |
| `payment_installments` | Número de parcelas (texto na BRONZE). |
| `payment_value` | Valor pago no registro (texto na BRONZE). |

---

## bronze.olist_order_reviews

**Descrição:** avaliações/reviews do pedido.

**Grão:** 1 linha por review (`review_id`).

**Chave(s) sugerida(s):** PK `review_id`.

**Campos**

| Campo | Descrição |
|---|---|
| `review_id` | Identificador da avaliação. |
| `order_id` | Pedido avaliado (join com `olist_orders.order_id`). |
| `review_score` | Nota (tipicamente 1 a 5). |
| `review_comment_title` | Título do comentário (pode estar vazio). |
| `review_comment_message` | Mensagem do comentário (pode estar vazio). |
| `review_creation_date` | Data/hora de criação da avaliação. |
| `review_answer_timestamp` | Data/hora de resposta (quando aplicável). |

---

## bronze.olist_products

**Descrição:** catálogo de produtos e atributos físicos.

**Grão:** 1 linha por `product_id`.

**Chave(s) sugerida(s):** PK `product_id`.

**Campos**

| Campo | Descrição |
|---|---|
| `product_id` | Identificador do produto. |
| `product_category_name` | Categoria do produto (em PT-BR, pode ser nula). |
| `product_name_lenght` | Tamanho (em caracteres) do nome do produto (texto na BRONZE). |
| `product_description_lenght` | Tamanho (em caracteres) da descrição (texto na BRONZE). |
| `product_photos_qty` | Quantidade de fotos (texto na BRONZE). |
| `product_weight_g` | Peso em gramas (texto na BRONZE). |
| `product_length_cm` | Comprimento em cm (texto na BRONZE). |
| `product_height_cm` | Altura em cm (texto na BRONZE). |
| `product_width_cm` | Largura em cm (texto na BRONZE). |

---

## bronze.olist_sellers

**Descrição:** cadastro de vendedores e localização aproximada.

**Grão:** 1 linha por `seller_id`.

**Chave(s) sugerida(s):** PK `seller_id`.

**Campos**

| Campo | Descrição |
|---|---|
| `seller_id` | Identificador do vendedor. |
| `seller_zip_code_prefix` | Prefixo do CEP do vendedor. |
| `seller_city` | Cidade do vendedor. |
| `seller_state` | UF do vendedor. |

---

## bronze.olist_product_category_name_translation

**Descrição:** tradução do nome da categoria do produto (PT-BR -> EN).

**Grão:** 1 linha por categoria.

**Chave(s) sugerida(s):** PK `product_category_name`.

**Campos**

| Campo | Descrição |
|---|---|
| `product_category_name` | Nome da categoria em português (chave de ligação com `olist_products.product_category_name`). |
| `product_category_name_english` | Tradução do nome da categoria para inglês. |

---

## Notas de qualidade e governança

- **Dados sensíveis:** o dataset não contém nomes, e-mails ou documentos; ainda assim, `customer_id`/`customer_unique_id` são identificadores pseudônimos e devem ser tratados com cuidado.
- **Nulos e strings vazias:** alguns campos de comentário em reviews podem vir vazios.
- **Datas e números:** como tudo é `TEXT` na BRONZE, validações/conversões devem ocorrer na SILVER (ex.: timestamps, valores monetários e medidas).

