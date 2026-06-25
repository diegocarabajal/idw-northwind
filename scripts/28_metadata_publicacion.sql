-- ============================================================
-- SCRIPT: 28_metadata_publicacion
-- Descripcion: Documenta en met_entidades todas las columnas de
--              las 5 tablas dp_ (capa de Publicacion).
--              Es el cierre formal del pipeline ETL del proyecto.
-- Etapa: Publicacion
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-25
-- ============================================================


-- ============================================================
-- 1. REGISTRO EN INVENTARIO DE SCRIPTS
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES (
    '28_metadata_publicacion',
    'Documentacion de la capa dp_ (Data Products) en met_entidades. Cierre del pipeline ETL.',
    'publicacion'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 2. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '28_metadata_publicacion'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Documentando capa de Publicacion (dp_) en met_entidades'
);


-- ============================================================
-- 3. METADATA – CAPA DP (Data Products)
--    75 columnas en total distribuidas en 5 tablas dp_.
--    Idempotente: WHERE NOT EXISTS evita duplicados en reejecucion.
-- ============================================================

INSERT INTO data_warehouse.met_entidades
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
SELECT * FROM (VALUES

    -- --------------------------------------------------------
    -- dp_ventas_por_periodo (15 columnas)
    -- --------------------------------------------------------
    ('dp_ventas_por_periodo','periodo_id',      'SERIAL',        'PK autoincremental del periodo',                                              'dp', TRUE,  FALSE, NULL,                 NULL,        FALSE),
    ('dp_ventas_por_periodo','anio',            'INT',           'Año del periodo',                                                             'dp', FALSE, FALSE, NULL,                 NULL,        FALSE),
    ('dp_ventas_por_periodo','trimestre',       'INT',           'Trimestre del año (1 a 4)',                                                   'dp', FALSE, FALSE, NULL,                 NULL,        FALSE),
    ('dp_ventas_por_periodo','mes',             'INT',           'Numero de mes (1 a 12)',                                                      'dp', FALSE, FALSE, NULL,                 NULL,        FALSE),
    ('dp_ventas_por_periodo','nombre_mes',      'VARCHAR(20)',   'Nombre del mes en español',                                                   'dp', FALSE, FALSE, NULL,                 NULL,        FALSE),
    ('dp_ventas_por_periodo','total_pedidos',   'INT',           'Cantidad de pedidos distintos en el periodo (COUNT DISTINCT nk_order_id)',    'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),
    ('dp_ventas_por_periodo','total_lineas',    'INT',           'Cantidad de lineas de detalle (filas de fact) en el periodo',                 'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),
    ('dp_ventas_por_periodo','total_clientes',  'INT',           'Cantidad de clientes distintos que compraron en el periodo',                  'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),
    ('dp_ventas_por_periodo','total_productos', 'INT',           'Cantidad de productos distintos vendidos en el periodo',                      'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),
    ('dp_ventas_por_periodo','monto_bruto',     'NUMERIC(18,4)', 'Suma del monto bruto (precio_unitario * cantidad) en el periodo',             'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),
    ('dp_ventas_por_periodo','monto_descuento', 'NUMERIC(18,4)', 'Suma de descuentos aplicados en el periodo',                                  'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),
    ('dp_ventas_por_periodo','monto_neto',      'NUMERIC(18,4)', 'Suma del monto neto (bruto - descuento) en el periodo',                       'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),
    ('dp_ventas_por_periodo','flete_total',     'NUMERIC(18,4)', 'Suma del flete prorrateado de todos los pedidos del periodo',                 'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),
    ('dp_ventas_por_periodo','ticket_promedio', 'NUMERIC(18,4)', 'Monto neto promedio por pedido en el periodo (monto_neto / total_pedidos)',   'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),
    ('dp_ventas_por_periodo','create_date',     'TIMESTAMP',     'Fecha y hora de carga del registro en el data product',                      'dp', FALSE, FALSE, NULL,                 NULL,        TRUE),

    -- --------------------------------------------------------
    -- dp_ventas_por_cliente (19 columnas)
    -- --------------------------------------------------------
    ('dp_ventas_por_cliente','sk_cliente',              'INT',           'PK: surrogate key del cliente (de dwa_dim_cliente)',                          'dp', TRUE,  TRUE,  'dwa_dim_cliente',  'sk_cliente',  FALSE),
    ('dp_ventas_por_cliente','nk_customer_id',          'CHAR(5)',       'Clave natural del cliente (codigo de 5 caracteres de Northwind)',             'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','company_name',            'VARCHAR(100)',  'Nombre comercial del cliente',                                                'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','city',                    'VARCHAR(100)',  'Ciudad del cliente',                                                          'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','country',                 'VARCHAR(100)',  'Pais del cliente segun Northwind',                                            'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','country_name_pais',       'VARCHAR(100)',  'Nombre del pais normalizado segun dwa_dim_pais (World Data 2023)',            'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','capital_major_city',      'VARCHAR(100)',  'Capital o ciudad principal del pais del cliente',                             'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','customer_score',          'INT',           'Score externo del cliente (1 a 5)',                                           'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','customer_score_segmento', 'VARCHAR(20)',   'Segmento derivado del score: ALTO, MEDIO, BAJO',                              'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','segmento',                'VARCHAR(20)',   'Segmento de valor de compra: PREMIUM, REGULAR o BAJO (NTILE 5 sobre monto)',  'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','total_pedidos',           'INT',           'Cantidad de pedidos realizados por el cliente',                               'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','total_lineas',            'INT',           'Cantidad de lineas de detalle asociadas al cliente',                          'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','monto_neto',              'NUMERIC(18,4)', 'Monto neto total acumulado del cliente',                                      'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','monto_promedio_pedido',   'NUMERIC(18,4)', 'Monto neto promedio por pedido del cliente',                                  'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','primer_pedido',           'DATE',          'Fecha del primer pedido del cliente',                                         'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','ultimo_pedido',           'DATE',          'Fecha del ultimo pedido del cliente',                                         'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','dias_como_cliente',       'INT',           'Dias entre el primer y el ultimo pedido del cliente',                         'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','rank_cliente',            'INT',           'Ranking del cliente por monto neto total (1 = mayor comprador)',              'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_cliente','create_date',             'TIMESTAMP',     'Fecha y hora de carga del registro en el data product',                      'dp', FALSE, FALSE, NULL,               NULL,          TRUE),

    -- --------------------------------------------------------
    -- dp_ventas_por_producto (15 columnas)
    -- --------------------------------------------------------
    ('dp_ventas_por_producto','sk_producto',             'INT',           'PK: surrogate key del producto (de dwa_dim_producto)',                        'dp', TRUE,  TRUE,  'dwa_dim_producto', 'sk_producto', FALSE),
    ('dp_ventas_por_producto','nk_product_id',           'INT',           'Clave natural del producto (id de Northwind)',                                'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','product_name',            'VARCHAR(100)',  'Nombre del producto',                                                         'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','category_name',           'VARCHAR(100)',  'Categoria del producto',                                                      'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','supplier_name',           'VARCHAR(100)',  'Nombre del proveedor del producto',                                           'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','supplier_country',        'VARCHAR(100)',  'Pais del proveedor del producto',                                             'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','precio_lista',            'NUMERIC(10,4)', 'Precio de lista vigente del producto',                                        'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','discontinued',            'BOOLEAN',       'TRUE si el producto fue descontinuado',                                       'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','performance',             'VARCHAR(10)',   'Clasificacion de performance: TOP, MID o LOW (NTILE 5 sobre revenue)',        'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','rank_revenue',            'INT',           'Ranking del producto por revenue total (1 = mayor revenue)',                  'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','total_pedidos',           'INT',           'Cantidad de pedidos distintos en los que aparecio el producto',               'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','total_unidades',          'INT',           'Cantidad total de unidades vendidas del producto',                            'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','revenue_total',           'NUMERIC(18,4)', 'Revenue neto total acumulado del producto',                                   'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','revenue_promedio_pedido', 'NUMERIC(18,4)', 'Revenue neto promedio por pedido del producto',                               'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_producto','create_date',             'TIMESTAMP',     'Fecha y hora de carga del registro en el data product',                       'dp', FALSE, FALSE, NULL,               NULL,          TRUE),

    -- --------------------------------------------------------
    -- dp_ventas_por_empleado (10 columnas)
    -- --------------------------------------------------------
    ('dp_ventas_por_empleado','sk_empleado',     'INT',           'PK: surrogate key del empleado (de dwa_dim_empleado)',                        'dp', TRUE,  TRUE,  'dwa_dim_empleado', 'sk_empleado', FALSE),
    ('dp_ventas_por_empleado','nk_employee_id',  'INT',           'Clave natural del empleado (id de Northwind)',                                'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_empleado','nombre_completo', 'VARCHAR(200)',  'Nombre y apellido concatenados del empleado',                                 'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_empleado','title',           'VARCHAR(100)',  'Cargo del empleado en la empresa',                                            'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_empleado','total_pedidos',   'INT',           'Cantidad de pedidos gestionados por el empleado',                             'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_empleado','total_clientes',  'INT',           'Cantidad de clientes distintos atendidos por el empleado',                    'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_empleado','monto_neto',      'NUMERIC(18,4)', 'Monto neto total vendido por el empleado',                                    'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_empleado','monto_promedio',  'NUMERIC(18,4)', 'Monto neto promedio por pedido gestionado por el empleado',                   'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_empleado','rank_empleado',   'INT',           'Ranking del empleado por monto neto total (1 = mayor vendedor)',              'dp', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dp_ventas_por_empleado','create_date',     'TIMESTAMP',     'Fecha y hora de carga del registro en el data product',                       'dp', FALSE, FALSE, NULL,               NULL,          TRUE),

    -- --------------------------------------------------------
    -- dp_ventas_geografico (16 columnas)
    -- --------------------------------------------------------
    ('dp_ventas_geografico','sk_pais',           'INT',           'PK: surrogate key del pais (de dwa_dim_pais)',                               'dp', TRUE,  TRUE,  'dwa_dim_pais', 'sk_pais', FALSE),
    ('dp_ventas_geografico','country_name',      'VARCHAR(100)',  'Nombre del pais normalizado (clave unica de dwa_dim_pais)',                  'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','abbreviation',      'VARCHAR(10)',   'Abreviatura o codigo del pais',                                              'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','capital_major_city','VARCHAR(100)',  'Capital o ciudad principal del pais',                                        'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','currency_code',     'VARCHAR(10)',   'Codigo de moneda del pais',                                                  'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','population',        'BIGINT',        'Poblacion total del pais (World Data 2023)',                                  'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','gdp',               'NUMERIC(20,2)', 'Producto Bruto Interno del pais en USD (World Data 2023)',                   'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','life_expectancy',   'NUMERIC(10,4)', 'Expectativa de vida promedio del pais en años (World Data 2023)',            'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','unemployment_rate', 'NUMERIC(10,4)', 'Tasa de desempleo del pais (World Data 2023)',                               'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','total_clientes',    'INT',           'Cantidad de clientes del pais con al menos un pedido',                       'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','total_pedidos',     'INT',           'Cantidad de pedidos originados en el pais',                                  'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','monto_neto',        'NUMERIC(18,4)', 'Monto neto total facturado a clientes del pais',                             'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','pct_monto_global',  'NUMERIC(8,4)',  'Porcentaje del monto neto del pais sobre el total global de ventas',         'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','latitude',          'NUMERIC(12,8)', 'Latitud geografica del centroide del pais (para mapas)',                     'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','longitude',         'NUMERIC(12,8)', 'Longitud geografica del centroide del pais (para mapas)',                    'dp', FALSE, FALSE, NULL,           NULL,      TRUE),
    ('dp_ventas_geografico','create_date',       'TIMESTAMP',     'Fecha y hora de carga del registro en el data product',                      'dp', FALSE, FALSE, NULL,           NULL,      TRUE)

) AS v(nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
WHERE NOT EXISTS (
    SELECT 1 FROM data_warehouse.met_entidades m
    WHERE m.nombre_tabla   = v.nombre_tabla
      AND m.nombre_columna = v.nombre_columna
);


-- ============================================================
-- 4. VERIFICACION
-- ============================================================

SELECT
    nombre_tabla,
    COUNT(*)            AS columnas_documentadas,
    SUM(es_pk::INT)     AS pks,
    SUM(es_fk::INT)     AS fks
FROM data_warehouse.met_entidades
WHERE capa_dwh = 'dp'
GROUP BY nombre_tabla
ORDER BY nombre_tabla;


-- ============================================================
-- 5. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = 'OK',
    registros_proc = 75,
    detalle        = 'Metadata de Publicacion completada: 5 tablas dp_ documentadas en met_entidades (75 columnas). Pipeline ETL del proyecto finalizado.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '28_metadata_publicacion'
)
AND resultado = 'EN_PROCESO';
