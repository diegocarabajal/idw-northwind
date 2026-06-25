-- ============================================================
-- SCRIPT: 24_actualizacion_memoria_enriquecimiento
-- Descripcion: Actualiza memoria SCD2 y recalcula enriquecimiento.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.


INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('24_actualizacion_memoria_enriquecimiento', 'Actualizacion de memoria SCD2 y enriquecimiento', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES ((SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '24_actualizacion_memoria_enriquecimiento'),
        NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires', 'EN_PROCESO', 'Iniciando memoria y enriquecimiento');

-- Fecha efectiva de la actualizacion: primera fecha de las ordenes nuevas.
-- Si no hubiera ordenes, usa CURRENT_DATE.

-- 1) Memoria de clientes: cierra version anterior si cambio localizacion o razon social.
WITH fecha AS (
    SELECT COALESCE(MIN(order_date), CURRENT_DATE) AS f FROM data_warehouse.tmp2_orders
), cambiados AS (
    SELECT m.dwm_cliente_id, c.sk_cliente, c.nk_customer_id, c.company_name, c.city, c.region, c.country, fecha.f
    FROM data_warehouse.dwm_cliente m
    JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id = m.nk_customer_id
    CROSS JOIN fecha
    WHERE m.es_vigente = TRUE
      AND (m.company_name IS DISTINCT FROM c.company_name
        OR m.city IS DISTINCT FROM c.city
        OR m.region IS DISTINCT FROM c.region
        OR m.country IS DISTINCT FROM c.country)
)
UPDATE data_warehouse.dwm_cliente m
SET fecha_hasta = c.f - INTERVAL '1 day', es_vigente = FALSE
FROM cambiados c
WHERE m.dwm_cliente_id = c.dwm_cliente_id;

WITH fecha AS (
    SELECT COALESCE(MIN(order_date), CURRENT_DATE) AS f FROM data_warehouse.tmp2_orders
)
INSERT INTO data_warehouse.dwm_cliente (nk_customer_id, sk_cliente, company_name, city, region, country, fecha_desde, fecha_hasta, es_vigente)
SELECT c.nk_customer_id, c.sk_cliente, c.company_name, c.city, c.region, c.country, fecha.f, NULL, TRUE
FROM data_warehouse.dwa_dim_cliente c
CROSS JOIN fecha
WHERE NOT EXISTS (
    SELECT 1 FROM data_warehouse.dwm_cliente m
    WHERE m.nk_customer_id = c.nk_customer_id
      AND m.es_vigente = TRUE
      AND m.company_name IS NOT DISTINCT FROM c.company_name
      AND m.city IS NOT DISTINCT FROM c.city
      AND m.region IS NOT DISTINCT FROM c.region
      AND m.country IS NOT DISTINCT FROM c.country
);

-- 2) Memoria de productos: cierra version anterior si cambio precio, nombre o discontinued.
WITH fecha AS (
    SELECT COALESCE(MIN(order_date), CURRENT_DATE) AS f FROM data_warehouse.tmp2_orders
), cambiados AS (
    SELECT m.dwm_producto_id, p.sk_producto, p.nk_product_id, p.product_name, p.precio_lista, p.discontinued, fecha.f
    FROM data_warehouse.dwm_producto m
    JOIN data_warehouse.dwa_dim_producto p ON p.nk_product_id = m.nk_product_id
    CROSS JOIN fecha
    WHERE m.es_vigente = TRUE
      AND (m.product_name IS DISTINCT FROM p.product_name
        OR m.precio_lista IS DISTINCT FROM p.precio_lista
        OR m.discontinued IS DISTINCT FROM p.discontinued)
)
UPDATE data_warehouse.dwm_producto m
SET fecha_hasta = c.f - INTERVAL '1 day', es_vigente = FALSE
FROM cambiados c
WHERE m.dwm_producto_id = c.dwm_producto_id;

WITH fecha AS (
    SELECT COALESCE(MIN(order_date), CURRENT_DATE) AS f FROM data_warehouse.tmp2_orders
)
INSERT INTO data_warehouse.dwm_producto (nk_product_id, sk_producto, product_name, precio_lista, discontinued, fecha_desde, fecha_hasta, es_vigente)
SELECT p.nk_product_id, p.sk_producto, p.product_name, p.precio_lista, p.discontinued, fecha.f, NULL, TRUE
FROM data_warehouse.dwa_dim_producto p
CROSS JOIN fecha
WHERE NOT EXISTS (
    SELECT 1 FROM data_warehouse.dwm_producto m
    WHERE m.nk_product_id = p.nk_product_id
      AND m.es_vigente = TRUE
      AND m.product_name IS NOT DISTINCT FROM p.product_name
      AND m.precio_lista IS NOT DISTINCT FROM p.precio_lista
      AND m.discontinued IS NOT DISTINCT FROM p.discontinued
);

-- 3) Recalculo de enriquecimiento de clientes.
TRUNCATE data_warehouse.dwa_enr_cliente;

WITH agg AS (
    SELECT
        c.sk_cliente,
        COUNT(DISTINCT f.nk_order_id) AS total_pedidos,
        COUNT(f.nk_order_id) AS total_lineas,
        SUM(f.monto_neto) AS monto_total_neto,
        SUM(f.monto_neto) / NULLIF(COUNT(DISTINCT f.nk_order_id),0) AS monto_promedio_pedido,
        MIN(t.fecha) AS primer_pedido,
        MAX(t.fecha) AS ultimo_pedido
    FROM data_warehouse.dwa_dim_cliente c
    LEFT JOIN data_warehouse.dwa_fact_ventas f ON f.sk_cliente = c.sk_cliente
    LEFT JOIN data_warehouse.dwa_dim_tiempo t ON t.sk_tiempo = f.sk_tiempo
    GROUP BY c.sk_cliente
), segmentado AS (
    SELECT *, NTILE(5) OVER (ORDER BY COALESCE(monto_total_neto,0)) AS tile
    FROM agg
)
INSERT INTO data_warehouse.dwa_enr_cliente
    (sk_cliente, total_pedidos, total_lineas, monto_total_neto, monto_promedio_pedido, primer_pedido, ultimo_pedido, dias_como_cliente, segmento)
SELECT sk_cliente, total_pedidos, total_lineas, COALESCE(monto_total_neto,0), monto_promedio_pedido,
       primer_pedido, ultimo_pedido,
       CASE WHEN primer_pedido IS NULL THEN NULL ELSE (ultimo_pedido - primer_pedido) END,
       CASE WHEN tile = 5 THEN 'PREMIUM' WHEN tile >= 2 THEN 'REGULAR' ELSE 'BAJO' END
FROM segmentado;

-- 4) Recalculo de enriquecimiento de productos.
TRUNCATE data_warehouse.dwa_enr_producto;

WITH agg AS (
    SELECT
        p.sk_producto,
        COUNT(DISTINCT f.nk_order_id) AS total_pedidos,
        COALESCE(SUM(f.cantidad),0) AS total_unidades,
        COALESCE(SUM(f.monto_neto),0) AS revenue_total,
        SUM(f.monto_neto) / NULLIF(COUNT(DISTINCT f.nk_order_id),0) AS revenue_promedio_pedido
    FROM data_warehouse.dwa_dim_producto p
    LEFT JOIN data_warehouse.dwa_fact_ventas f ON f.sk_producto = p.sk_producto
    GROUP BY p.sk_producto
), segmentado AS (
    SELECT *,
        RANK() OVER (ORDER BY revenue_total DESC) AS rk,
        NTILE(5) OVER (ORDER BY revenue_total) AS tile
    FROM agg
)
INSERT INTO data_warehouse.dwa_enr_producto
    (sk_producto, total_pedidos, total_unidades, revenue_total, revenue_promedio_pedido, rank_revenue, performance)
SELECT sk_producto, total_pedidos, total_unidades, revenue_total, revenue_promedio_pedido, rk,
       CASE WHEN tile = 5 THEN 'TOP' WHEN tile >= 2 THEN 'MID' ELSE 'LOW' END
FROM segmentado;

INSERT INTO data_warehouse.dqm_carga_dwa (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES
((SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '24_actualizacion_memoria_enriquecimiento')),
 'dwm_cliente', (SELECT COUNT(*) FROM data_warehouse.dwa_dim_cliente), (SELECT COUNT(*) FROM data_warehouse.dwm_cliente WHERE fecha_registro >= CURRENT_DATE), 0, 'CARGADO', NULL),
((SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '24_actualizacion_memoria_enriquecimiento')),
 'dwm_producto', (SELECT COUNT(*) FROM data_warehouse.dwa_dim_producto), (SELECT COUNT(*) FROM data_warehouse.dwm_producto WHERE fecha_registro >= CURRENT_DATE), 0, 'CARGADO', NULL),
((SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '24_actualizacion_memoria_enriquecimiento')),
 'dwa_enr_cliente', (SELECT COUNT(*) FROM data_warehouse.dwa_dim_cliente), (SELECT COUNT(*) FROM data_warehouse.dwa_enr_cliente), 0, 'CARGADO', NULL),
((SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '24_actualizacion_memoria_enriquecimiento')),
 'dwa_enr_producto', (SELECT COUNT(*) FROM data_warehouse.dwa_dim_producto), (SELECT COUNT(*) FROM data_warehouse.dwa_enr_producto), 0, 'CARGADO', NULL);

UPDATE data_warehouse.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = 'OK',
    detalle = 'Memoria SCD2 y enriquecimiento actualizados.',
    registros_proc = (SELECT COUNT(*) FROM data_warehouse.dwa_enr_cliente) + (SELECT COUNT(*) FROM data_warehouse.dwa_enr_producto)
WHERE log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '24_actualizacion_memoria_enriquecimiento'));
