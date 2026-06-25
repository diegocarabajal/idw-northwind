-- ============================================================
-- SCRIPT: 27_carga_data_products
-- Descripcion: Carga (TRUNCATE + INSERT) de las 5 tablas dp_
--              desde el star schema del DWA.
--              Este script es reejecutable: cada corrida trunca
--              y recarga desde cero. Se debe correr despues de
--              cualquier nueva ingesta (post script 24).
-- Etapa: Publicacion
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-25
-- ============================================================


-- ============================================================
-- 1. REGISTRO EN INVENTARIO DE SCRIPTS
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES (
    '27_carga_data_products',
    'Carga de las 5 tablas dp_ desde el star schema (reejecutable por ingesta)',
    'publicacion'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 2. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '27_carga_data_products'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Iniciando carga de Data Products desde star schema'
);


-- ============================================================
-- 3. CARGA dp_ventas_por_periodo
--    Agrega dwa_fact_ventas por año/trimestre/mes.
--    Fuente: dwa_fact_ventas JOIN dwa_dim_tiempo
-- ============================================================

TRUNCATE data_warehouse.dp_ventas_por_periodo;

INSERT INTO data_warehouse.dp_ventas_por_periodo
    (anio, trimestre, mes, nombre_mes,
     total_pedidos, total_lineas, total_clientes, total_productos,
     monto_bruto, monto_descuento, monto_neto, flete_total, ticket_promedio)
SELECT
    t.anio,
    t.trimestre,
    t.mes,
    t.nombre_mes,
    COUNT(DISTINCT f.nk_order_id)                                        AS total_pedidos,
    COUNT(*)                                                             AS total_lineas,
    COUNT(DISTINCT f.sk_cliente)                                         AS total_clientes,
    COUNT(DISTINCT f.sk_producto)                                        AS total_productos,
    COALESCE(SUM(f.monto_bruto), 0)                                     AS monto_bruto,
    COALESCE(SUM(f.monto_descuento), 0)                                 AS monto_descuento,
    COALESCE(SUM(f.monto_neto), 0)                                      AS monto_neto,
    COALESCE(SUM(f.flete_prorrateado), 0)                               AS flete_total,
    SUM(f.monto_neto) / NULLIF(COUNT(DISTINCT f.nk_order_id), 0)       AS ticket_promedio
FROM data_warehouse.dwa_fact_ventas f
JOIN data_warehouse.dwa_dim_tiempo t ON t.sk_tiempo = f.sk_tiempo
GROUP BY t.anio, t.trimestre, t.mes, t.nombre_mes
ORDER BY t.anio, t.trimestre, t.mes;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '27_carga_data_products')),
    'dp_ventas_por_periodo',
    (SELECT COUNT(*) FROM data_warehouse.dwa_fact_ventas),
    (SELECT COUNT(*) FROM data_warehouse.dp_ventas_por_periodo),
    0, 'CARGADO', NULL
);


-- ============================================================
-- 4. CARGA dp_ventas_por_cliente
--    Un registro por cliente vigente con metricas de enriquecimiento
--    y datos del pais.
--    Fuente: dwa_dim_cliente + dwa_enr_cliente + dwa_dim_pais
-- ============================================================

TRUNCATE data_warehouse.dp_ventas_por_cliente;

INSERT INTO data_warehouse.dp_ventas_por_cliente
    (sk_cliente, nk_customer_id, company_name, city, country,
     country_name_pais, capital_major_city,
     customer_score, customer_score_segmento, segmento,
     total_pedidos, total_lineas, monto_neto, monto_promedio_pedido,
     primer_pedido, ultimo_pedido, dias_como_cliente, rank_cliente)
SELECT
    c.sk_cliente,
    c.nk_customer_id,
    c.company_name,
    c.city,
    c.country,
    p.country_name                                                              AS country_name_pais,
    p.capital_major_city,
    c.customer_score,
    c.customer_score_segmento,
    e.segmento,
    COALESCE(e.total_pedidos, 0)                                               AS total_pedidos,
    COALESCE(e.total_lineas, 0)                                                AS total_lineas,
    COALESCE(e.monto_total_neto, 0)                                            AS monto_neto,
    e.monto_promedio_pedido,
    e.primer_pedido,
    e.ultimo_pedido,
    e.dias_como_cliente,
    RANK() OVER (ORDER BY COALESCE(e.monto_total_neto, 0) DESC)               AS rank_cliente
FROM data_warehouse.dwa_dim_cliente c
LEFT JOIN data_warehouse.dwa_dim_pais    p ON p.sk_pais    = c.sk_pais
LEFT JOIN data_warehouse.dwa_enr_cliente e ON e.sk_cliente = c.sk_cliente;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '27_carga_data_products')),
    'dp_ventas_por_cliente',
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_cliente),
    (SELECT COUNT(*) FROM data_warehouse.dp_ventas_por_cliente),
    0, 'CARGADO', NULL
);


-- ============================================================
-- 5. CARGA dp_ventas_por_producto
--    Un registro por producto vigente con metricas de enriquecimiento.
--    Fuente: dwa_dim_producto + dwa_enr_producto
-- ============================================================

TRUNCATE data_warehouse.dp_ventas_por_producto;

INSERT INTO data_warehouse.dp_ventas_por_producto
    (sk_producto, nk_product_id, product_name, category_name,
     supplier_name, supplier_country, precio_lista, discontinued,
     performance, rank_revenue,
     total_pedidos, total_unidades, revenue_total, revenue_promedio_pedido)
SELECT
    pr.sk_producto,
    pr.nk_product_id,
    pr.product_name,
    pr.category_name,
    pr.supplier_name,
    pr.supplier_country,
    pr.precio_lista,
    pr.discontinued,
    ep.performance,
    ep.rank_revenue,
    COALESCE(ep.total_pedidos, 0)                                              AS total_pedidos,
    COALESCE(ep.total_unidades, 0)                                             AS total_unidades,
    COALESCE(ep.revenue_total, 0)                                              AS revenue_total,
    ep.revenue_promedio_pedido
FROM data_warehouse.dwa_dim_producto     pr
LEFT JOIN data_warehouse.dwa_enr_producto ep ON ep.sk_producto = pr.sk_producto;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '27_carga_data_products')),
    'dp_ventas_por_producto',
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_producto),
    (SELECT COUNT(*) FROM data_warehouse.dp_ventas_por_producto),
    0, 'CARGADO', NULL
);


-- ============================================================
-- 6. CARGA dp_ventas_por_empleado
--    Un registro por empleado vigente con metricas de venta y ranking.
--    Fuente: dwa_dim_empleado + dwa_fact_ventas
-- ============================================================

TRUNCATE data_warehouse.dp_ventas_por_empleado;

WITH ventas_emp AS (
    SELECT
        f.sk_empleado,
        COUNT(DISTINCT f.nk_order_id)                                          AS total_pedidos,
        COUNT(DISTINCT f.sk_cliente)                                           AS total_clientes,
        SUM(f.monto_neto)                                                      AS monto_neto,
        SUM(f.monto_neto) / NULLIF(COUNT(DISTINCT f.nk_order_id), 0)          AS monto_promedio
    FROM data_warehouse.dwa_fact_ventas f
    GROUP BY f.sk_empleado
)
INSERT INTO data_warehouse.dp_ventas_por_empleado
    (sk_empleado, nk_employee_id, nombre_completo, title,
     total_pedidos, total_clientes, monto_neto, monto_promedio, rank_empleado)
SELECT
    e.sk_empleado,
    e.nk_employee_id,
    e.nombre_completo,
    e.title,
    COALESCE(v.total_pedidos, 0)                                               AS total_pedidos,
    COALESCE(v.total_clientes, 0)                                              AS total_clientes,
    COALESCE(v.monto_neto, 0)                                                  AS monto_neto,
    v.monto_promedio,
    RANK() OVER (ORDER BY COALESCE(v.monto_neto, 0) DESC)                     AS rank_empleado
FROM data_warehouse.dwa_dim_empleado e
LEFT JOIN ventas_emp v ON v.sk_empleado = e.sk_empleado;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '27_carga_data_products')),
    'dp_ventas_por_empleado',
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_empleado),
    (SELECT COUNT(*) FROM data_warehouse.dp_ventas_por_empleado),
    0, 'CARGADO', NULL
);


-- ============================================================
-- 7. CARGA dp_ventas_geografico
--    Un registro por pais del cliente con metricas de venta
--    y datos socioeconomicos de World Data 2023.
--    Solo paises que tienen al menos un cliente vigente.
--    Fuente: dwa_dim_pais + dwa_dim_cliente + dwa_fact_ventas
-- ============================================================

TRUNCATE data_warehouse.dp_ventas_geografico;

WITH ventas_pais AS (
    SELECT
        c.sk_pais,
        COUNT(DISTINCT c.sk_cliente)                                           AS total_clientes,
        COUNT(DISTINCT f.nk_order_id)                                          AS total_pedidos,
        COALESCE(SUM(f.monto_neto), 0)                                        AS monto_neto
    FROM data_warehouse.dwa_dim_cliente c
    LEFT JOIN data_warehouse.dwa_fact_ventas f ON f.sk_cliente = c.sk_cliente
    WHERE c.sk_pais IS NOT NULL
    GROUP BY c.sk_pais
),
total_global AS (
    SELECT COALESCE(SUM(monto_neto), 0) AS total FROM ventas_pais
)
INSERT INTO data_warehouse.dp_ventas_geografico
    (sk_pais, country_name, abbreviation, capital_major_city, currency_code,
     population, gdp, life_expectancy, unemployment_rate,
     total_clientes, total_pedidos, monto_neto, pct_monto_global,
     latitude, longitude)
SELECT
    p.sk_pais,
    p.country_name,
    p.abbreviation,
    p.capital_major_city,
    p.currency_code,
    p.population,
    p.gdp,
    p.life_expectancy,
    p.unemployment_rate,
    COALESCE(v.total_clientes, 0)                                              AS total_clientes,
    COALESCE(v.total_pedidos, 0)                                               AS total_pedidos,
    COALESCE(v.monto_neto, 0)                                                  AS monto_neto,
    CASE
        WHEN g.total > 0
        THEN ROUND((COALESCE(v.monto_neto, 0) / g.total * 100)::NUMERIC, 4)
        ELSE 0
    END                                                                        AS pct_monto_global,
    p.latitude,
    p.longitude
FROM data_warehouse.dwa_dim_pais p
LEFT JOIN ventas_pais  v ON v.sk_pais = p.sk_pais
CROSS JOIN total_global g;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '27_carga_data_products')),
    'dp_ventas_geografico',
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_pais),
    (SELECT COUNT(*) FROM data_warehouse.dp_ventas_geografico),
    0, 'CARGADO', NULL
);


-- ============================================================
-- 8. VERIFICACION
-- ============================================================

-- Conteo de registros por tabla dp_
SELECT
    'dp_ventas_por_periodo'  AS tabla, COUNT(*) AS registros FROM data_warehouse.dp_ventas_por_periodo
UNION ALL
SELECT 'dp_ventas_por_cliente',         COUNT(*) FROM data_warehouse.dp_ventas_por_cliente
UNION ALL
SELECT 'dp_ventas_por_producto',        COUNT(*) FROM data_warehouse.dp_ventas_por_producto
UNION ALL
SELECT 'dp_ventas_por_empleado',        COUNT(*) FROM data_warehouse.dp_ventas_por_empleado
UNION ALL
SELECT 'dp_ventas_geografico',          COUNT(*) FROM data_warehouse.dp_ventas_geografico
ORDER BY tabla;

-- ──────────────────────────────────────────────────────────────
-- Verificacion del período cubierto por el data product.
-- Caso de negocio: Análisis de ventas de Northwind Traders.
-- El período no se filtra porque las tablas dp_ publican
-- la totalidad del histórico disponible en el DWA.
-- ──────────────────────────────────────────────────────────────
SELECT
    'Caso de negocio'                                               AS parametro,
    'Análisis de ventas de Northwind Traders'                      AS valor
UNION ALL
SELECT
    'Período desde',
    MIN(anio)::TEXT || '-' || LPAD(MIN(mes)::TEXT, 2, '0')
FROM data_warehouse.dp_ventas_por_periodo
UNION ALL
SELECT
    'Período hasta',
    MAX(anio)::TEXT || '-' || LPAD(MAX(mes)::TEXT, 2, '0')
FROM data_warehouse.dp_ventas_por_periodo
UNION ALL
SELECT
    'Años cubiertos',
    COUNT(DISTINCT anio)::TEXT
FROM data_warehouse.dp_ventas_por_periodo
UNION ALL
SELECT
    'Meses cubiertos',
    COUNT(*)::TEXT
FROM data_warehouse.dp_ventas_por_periodo
UNION ALL
SELECT
    'Revenue neto total (USD)',
    TO_CHAR(SUM(monto_neto), 'FM999,999,999.00')
FROM data_warehouse.dp_ventas_por_periodo;


-- ============================================================
-- 9. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = 'OK',
    registros_proc = (SELECT COUNT(*) FROM data_warehouse.dp_ventas_por_periodo)
                   + (SELECT COUNT(*) FROM data_warehouse.dp_ventas_por_cliente)
                   + (SELECT COUNT(*) FROM data_warehouse.dp_ventas_por_producto)
                   + (SELECT COUNT(*) FROM data_warehouse.dp_ventas_por_empleado)
                   + (SELECT COUNT(*) FROM data_warehouse.dp_ventas_geografico),
    detalle        = 'Carga de Data Products completada: dp_ventas_por_periodo, dp_ventas_por_cliente, dp_ventas_por_producto, dp_ventas_por_empleado, dp_ventas_geografico.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '27_carga_data_products'
)
AND resultado = 'EN_PROCESO';
