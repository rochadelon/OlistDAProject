# Azure Scope - Olist DW

## Context

This project reuses the existing `dw_olist_project` as the functional baseline and evolves it into an Azure edition.
The local solution already provides a Bronze -> Silver -> Gold flow in PostgreSQL, so the Azure version should preserve the business logic and reduce the scope to a demonstrable cloud architecture.

## Local flow

The current repository follows this path:

1. CSV files in `files/olist`
2. Bronze load via `bronze.proc_load_bronze`
3. Silver transformation via `silver.proc_load_silver`
4. Gold dimensional model via `scripts/golden_layer/*`

## Local table inventory

### Bronze tables

- `bronze.olist_customers`
- `bronze.olist_geolocation`
- `bronze.olist_order_items`
- `bronze.olist_order_payments`
- `bronze.olist_order_reviews`
- `bronze.olist_orders`
- `bronze.olist_products`
- `bronze.olist_sellers`
- `bronze.olist_product_category_name_translation`

### Silver tables

- `silver.olist_customers`
- `silver.olist_geolocation`
- `silver.olist_order_items`
- `silver.olist_order_payments`
- `silver.olist_order_reviews`
- `silver.olist_orders`
- `silver.olist_products`
- `silver.olist_sellers`
- `silver.olist_product_category_name_translation`

### Gold tables in the local project

- `gold.dim_date`
- `gold.dim_customer`
- `gold.dim_seller`
- `gold.dim_product_category`
- `gold.dim_order_status`
- `gold.dim_payment_type`
- `gold.dim_geolocation`
- `gold.fact_order_items`
- `gold.fact_orders`
- `gold.fact_payments`
- `gold.fact_reviews`

## Azure scope for the first edition

### Source tables

The Azure version must focus on these tables only:

- `olist_orders`
- `olist_order_items`
- `olist_customers`
- `olist_products`

If time allows, `olist_order_payments` can be added later as an optional extension.

### Minimum Gold model

The minimum Gold layer for Azure must contain only:

- `dim_date`
- `dim_customer`
- `fact_order_items`

### Out of scope for the first Azure edition

The following tables and objects are not required for the first migration wave unless there is an explicit business need:

- `olist_geolocation`
- `olist_order_reviews`
- `olist_sellers`
- `olist_product_category_name_translation`
- `dim_seller`
- `dim_product_category`
- `dim_order_status`
- `dim_payment_type`
- `dim_geolocation`
- `fact_orders`
- `fact_payments`
- `fact_reviews`

## Delivery intent

The Azure edition should show that the analytical logic was preserved while the implementation moved from local PostgreSQL to Azure services such as ADF, ADLS Gen2, Synapse Serverless and Power BI.
The goal is a smaller but complete cloud version, not a full 1:1 recreation of every local artifact.
