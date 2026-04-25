
# Documentacao da Camada Bronze

## 1. Objetivo

A camada Bronze e a zona de ingestao bruta (raw) do projeto Olist. O foco e carregar os arquivos CSV para o PostgreSQL com baixa transformacao, preservando fidelidade da origem e rastreabilidade do processo.

Principios da Bronze:
- Preservar estrutura original dos arquivos.
- Priorizar carga robusta e observabilidade.
- Deixar tipagem e tratamento de qualidade para Silver/Gold.

## 2. Escopo

Camada abrangida:
- Schema: bronze
- Fonte: arquivos CSV em files/olist
- Tipo de carga: full load com opcao de truncate

Tabelas carregadas:
- bronze.olist_customers
- bronze.olist_geolocation
- bronze.olist_order_items
- bronze.olist_order_payments
- bronze.olist_order_reviews
- bronze.olist_orders
- bronze.olist_products
- bronze.olist_sellers
- bronze.olist_product_category_name_translation

## 3. Arquitetura de scripts

Scripts principais:
- [scripts/01_schemas.sql](scripts/01_schemas.sql): cria schemas bronze, silver e gold.
- [scripts/ddl_bronze.sql](scripts/ddl_bronze.sql): cria tabelas da camada bronze.
- [scripts/proc_load_bronze.sql](scripts/proc_load_bronze.sql): cria a procedure de carga e executa a carga inicial.

Ordem esperada de execucao:
1. 01_schemas.sql
2. ddl_bronze.sql
3. proc_load_bronze.sql

No ambiente Docker, esses scripts sao executados automaticamente na inicializacao do banco quando o volume de dados e criado pela primeira vez.

## 4. Modelo de dados Bronze

Decisao de modelagem:
- Todas as colunas sao armazenadas como TEXT na Bronze.

Motivacao:
- Evitar falhas de ingestao por parse prematuro de data/numero.
- Manter compatibilidade com variacao da origem.
- Permitir tratamento controlado nas camadas seguintes.

Observacao:
- Existe nomenclatura legada herdada da origem, como product_name_lenght e product_description_lenght.

## 5. Procedimento de carga

Procedure:
- Nome: bronze.proc_load_bronze
- Parametro: p_truncate BOOLEAN DEFAULT TRUE

Comportamento:
1. Inicia log da execucao.
2. Se p_truncate = TRUE, executa TRUNCATE em todas as tabelas bronze com log por tabela.
3. Executa COPY para cada tabela a partir de /data/csv com log de inicio por tabela.
4. Mede tempo de cada carga e imprime duracao em segundos.
5. Em erro, captura diagnosticos tecnicos e repropaga a excecao.

Exemplo de uso:

```sql
CALL bronze.proc_load_bronze(TRUE);
```

## 6. Organizacao e observabilidade

A procedure possui:
- Mensagem inicial: Iniciando carga da camada Bronze.
- Divisores visuais por secao funcional:
	- CRM (clientes e vendedores)
	- GEO (geolocalizacao)
	- ERP (pedidos, itens, pagamentos e reviews)
	- PIM (produtos e traducao de categoria)
- Logs por etapa:
	- Truncando tabela X
	- Inserindo dados em X
- Mensagem final de sucesso.

Beneficio:
- Facilita diagnostico de falhas e entendimento do passo atual durante o ETL.

## 7. Tratamento de erros

Implementacao:
- Bloco EXCEPTION WHEN OTHERS (equivalente funcional a TRY/CATCH no PostgreSQL).

Mensagem amigavel:
- Ocorreu um erro ao carregar a Bronze.

Detalhes tecnicos capturados:
- Codigo SQLSTATE
- Mensagem tecnica
- Detalhe tecnico
- Hint tecnico
- Contexto tecnico

Comportamento em falha:
- A procedure registra os detalhes e executa RAISE para nao mascarar erro.

## 8. Medicao de performance

Para cada tabela:
- t_inicio = clock_timestamp() antes do COPY
- t_fim = clock_timestamp() apos o COPY
- duracao_segundos = EXTRACT(EPOCH FROM (t_fim - t_inicio))

Saida de log por tabela:
- Duracao (s) bronze.nome_tabela: valor

Uso pratico:
- Identificar gargalos de carga e priorizar otimizacoes.

## 9. Validacao operacional

Validacoes recomendadas apos carga:
1. Conferir existencia das tabelas bronze.
2. Conferir contagem de linhas por tabela.
3. Revisar logs para confirmar secoes e duracoes.

Exemplo de conferencia de tabelas:

```sql
\dt bronze.*
```

## 10. Dependencias e ambiente

Infra:
- PostgreSQL 16 via Docker Compose.
- Montagem de volumes:
	- files/olist -> /data/csv
	- scripts -> /docker-entrypoint-initdb.d

Ponto de atencao:
- Scripts de init em /docker-entrypoint-initdb.d sao executados automaticamente apenas na inicializacao do cluster (primeira criacao do volume).

## 11. Limites e proximos passos

Limites atuais da Bronze:
- Sem constraints de PK/FK para nao bloquear ingestao raw.
- Sem padronizacao de tipos alem de TEXT.

Evolucoes sugeridas (Silver):
1. Tipar datas, numericos e medidas.
2. Padronizar nomenclatura legada quando apropriado.
3. Implementar regras de qualidade e deduplicacao.
4. Criar visoes de auditoria de carga (linhas, duracao, status).

## 12. Referencias

- [docs/data_catalog.md](docs/data_catalog.md)
- [docs/naming_conventions.md](docs/naming_conventions.md)
- [scripts/ddl_bronze.sql](scripts/ddl_bronze.sql)
- [scripts/proc_load_bronze.sql](scripts/proc_load_bronze.sql)
