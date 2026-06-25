-- ============================================================
-- SCRIPT: 26_ddl_data_products
-- Descripcion: Creacion de las tablas de Data Products (dp_)
--              para la capa de Publicacion (Etapa 4).
--              Las tablas dp_ son vistas pre-agregadas y aplanadas
--              del star schema, pensadas para consumo directo por
--              herramientas de visualizacion (Power BI, Metabase, etc.)
--              sin necesidad de JOINs adicionales.
-- Etapa: Publicacion
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-25
-- ============================================================


-- ============================================================
-- 1. REGISTRO EN INVENTARIO DE SCRIPTS
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES (
    '26_ddl_data_products',
    'DDL de la capa de Data Products (dp_): tablas pre-agregadas para publicacion y visualizacion',
    'publicacion'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 2. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '26_ddl_data_products'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Creando tablas de Data Products para capa de Publicacion'
);


-- ============================================================
-- 3. EXTENSION DEL CHECK CONSTRAINT EN met_entidades
--    La capa 'dp' (Data Products) no existia en Etapas anteriores.
--    Se descarta el constraint actual y se recrea incluyendo 'dp'.
-- ============================================================

DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    -- Buscar el constraint de capa_dwh en met_entidades
    SELECT tc.constraint_name INTO v_constraint_name
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema    = 'data_warehouse'
      AND tc.table_name      = 'met_entidades'
      AND tc.constraint_type = 'CHECK'
      AND tc.constraint_name ILIKE '%capa%';

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE data_warehouse.met_entidades DROP CONSTRAINT ' || v_constraint_name;
    END IF;
END $$;

ALTER TABLE data_warehouse.met_entidades
    ADD CONSTRAINT chk_capa
    CHECK (capa_dwh IN ('dqm','txt','tmp','dim','fact','memoria','enriquecimiento','dp'));


-- ============================================================
-- 4. CASO DE NEGOCIO Y PERÍODO
--    Caso: Análisis de ventas de Northwind Traders.
--    Período: julio 1996 – mayo 1998 (totalidad del histórico disponible).
--    Las tablas dp_ publican el DWA como un producto de datos plano
--    consumible directamente por herramientas de visualización,
--    sin necesidad de JOINs adicionales.
--    El período queda documentado en los COMMENTs de cada tabla
--    y verificado en el script de carga (27_carga_data_products).
-- ============================================================


-- ============================================================
-- 5. TABLAS DE DATA PRODUCTS
-- ============================================================

-- ------------------------------------------------------------
-- 4a. dp_ventas_por_periodo
--     Ventas agregadas por año, trimestre y mes.
--     Responde: ¿cómo evolucionaron las ventas en el tiempo?
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS data_warehouse.dp_ventas_por_periodo (
    periodo_id          SERIAL          PRIMARY KEY,
    anio                INT             NOT NULL,
    trimestre           INT             NOT NULL,
    mes                 INT             NOT NULL,
    nombre_mes          VARCHAR(20)     NOT NULL,
    total_pedidos       INT,
    total_lineas        INT,
    total_clientes      INT,
    total_productos     INT,
    monto_bruto         NUMERIC(18,4),
    monto_descuento     NUMERIC(18,4),
    monto_neto          NUMERIC(18,4),
    flete_total         NUMERIC(18,4),
    ticket_promedio     NUMERIC(18,4),
    create_date         TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    CONSTRAINT uq_dp_periodo UNIQUE (anio, trimestre, mes)
);

COMMENT ON TABLE data_warehouse.dp_ventas_por_periodo IS
    'Data Product | Caso: Análisis de ventas Northwind Traders | Período: julio 1996 – mayo 1998 | Granularidad: año/trimestre/mes | Fuente: dwa_fact_ventas + dwa_dim_tiempo.';


-- ------------------------------------------------------------
-- 4b. dp_ventas_por_cliente
--     Un registro por cliente vigente con métricas de ventas,
--     segmentación y datos geográficos.
--     Responde: ¿quiénes son mis mejores clientes y dónde están?
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS data_warehouse.dp_ventas_por_cliente (
    sk_cliente              INT             PRIMARY KEY,
    nk_customer_id          CHAR(5),
    company_name            VARCHAR(100),
    city                    VARCHAR(100),
    country                 VARCHAR(100),
    country_name_pais       VARCHAR(100),
    capital_major_city      VARCHAR(100),
    customer_score          INT,
    customer_score_segmento VARCHAR(20),
    segmento                VARCHAR(20),
    total_pedidos           INT,
    total_lineas            INT,
    monto_neto              NUMERIC(18,4),
    monto_promedio_pedido   NUMERIC(18,4),
    primer_pedido           DATE,
    ultimo_pedido           DATE,
    dias_como_cliente       INT,
    rank_cliente            INT,
    create_date             TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

COMMENT ON TABLE data_warehouse.dp_ventas_por_cliente IS
    'Data Product | Caso: Análisis de ventas Northwind Traders | Período: julio 1996 – mayo 1998 | Granularidad: cliente vigente | Fuente: dwa_dim_cliente + dwa_enr_cliente + dwa_dim_pais.';


-- ------------------------------------------------------------
-- 4c. dp_ventas_por_producto
--     Un registro por producto vigente con métricas de ventas
--     y segmentación de performance.
--     Responde: ¿qué productos generan más revenue y cómo se clasifican?
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS data_warehouse.dp_ventas_por_producto (
    sk_producto             INT             PRIMARY KEY,
    nk_product_id           INT,
    product_name            VARCHAR(100),
    category_name           VARCHAR(100),
    supplier_name           VARCHAR(100),
    supplier_country        VARCHAR(100),
    precio_lista            NUMERIC(10,4),
    discontinued            BOOLEAN,
    performance             VARCHAR(10),
    rank_revenue            INT,
    total_pedidos           INT,
    total_unidades          INT,
    revenue_total           NUMERIC(18,4),
    revenue_promedio_pedido NUMERIC(18,4),
    create_date             TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

COMMENT ON TABLE data_warehouse.dp_ventas_por_producto IS
    'Data Product | Caso: Análisis de ventas Northwind Traders | Período: julio 1996 – mayo 1998 | Granularidad: producto vigente | Fuente: dwa_dim_producto + dwa_enr_producto.';


-- ------------------------------------------------------------
-- 4d. dp_ventas_por_empleado
--     Un registro por empleado con métricas de ventas y ranking.
--     Responde: ¿cuál es la performance individual de cada vendedor?
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS data_warehouse.dp_ventas_por_empleado (
    sk_empleado         INT             PRIMARY KEY,
    nk_employee_id      INT,
    nombre_completo     VARCHAR(200),
    title               VARCHAR(100),
    total_pedidos       INT,
    total_clientes      INT,
    monto_neto          NUMERIC(18,4),
    monto_promedio      NUMERIC(18,4),
    rank_empleado       INT,
    create_date         TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

COMMENT ON TABLE data_warehouse.dp_ventas_por_empleado IS
    'Data Product | Caso: Análisis de ventas Northwind Traders | Período: julio 1996 – mayo 1998 | Granularidad: empleado vigente | Fuente: dwa_fact_ventas + dwa_dim_empleado.';


-- ------------------------------------------------------------
-- 4e. dp_ventas_geografico
--     Un registro por país del cliente con métricas de ventas
--     y datos socioeconómicos de World Data 2023.
--     Responde: ¿cómo se distribuyen las ventas por país
--     y qué relación tienen con el PBI o la población?
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS data_warehouse.dp_ventas_geografico (
    sk_pais             INT             PRIMARY KEY,
    country_name        VARCHAR(100),
    abbreviation        VARCHAR(10),
    capital_major_city  VARCHAR(100),
    currency_code       VARCHAR(10),
    population          BIGINT,
    gdp                 NUMERIC(20,2),
    life_expectancy     NUMERIC(10,4),
    unemployment_rate   NUMERIC(10,4),
    total_clientes      INT,
    total_pedidos       INT,
    monto_neto          NUMERIC(18,4),
    pct_monto_global    NUMERIC(8,4),
    latitude            NUMERIC(12,8),
    longitude           NUMERIC(12,8),
    create_date         TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

COMMENT ON TABLE data_warehouse.dp_ventas_geografico IS
    'Data Product | Caso: Análisis de ventas Northwind Traders | Período: julio 1996 – mayo 1998 | Granularidad: país del cliente | Fuente: dwa_dim_pais + dwa_dim_cliente + dwa_fact_ventas + World Data 2023.';


-- ============================================================
-- 6. VERIFICACION
-- ============================================================

SELECT table_name, obj_description(
    ('"data_warehouse"."' || table_name || '"')::regclass, 'pg_class'
) AS descripcion
FROM information_schema.tables
WHERE table_schema = 'data_warehouse'
  AND table_name LIKE 'dp_%'
ORDER BY table_name;


-- ============================================================
-- 7. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = 'OK',
    registros_proc = 5,
    detalle        = 'DDL Publicacion completado: 5 tablas dp_ creadas (ventas_por_periodo, ventas_por_cliente, ventas_por_producto, ventas_por_empleado, ventas_geografico). Constraint chk_capa extendido con capa dp.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '26_ddl_data_products'
)
AND resultado = 'EN_PROCESO';
