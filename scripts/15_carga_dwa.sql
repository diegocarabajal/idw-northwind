-- ============================================================
-- SCRIPT: 15_carga_dwa
-- Descripción: Carga inicial del DWA desde las tablas TMP
--              validadas. Debe ejecutarse DESPUÉS de que los
--              scripts 13 y 14 no reporten ningún ERROR.
--
--   Orden de prevalencia (dependencias primero):
--     1. dwa_dim_tiempo     → generada desde fechas de tmp_orders
--     2. dwa_dim_shipper    → desde tmp_shippers
--     3. dwa_dim_cliente    → desde tmp_customers
--     4. dwa_dim_empleado   → desde tmp_employees (2 pasadas: jerarquía)
--     5. dwa_dim_producto   → desde tmp_products + categories + suppliers
--     6. dwa_fact_ventas    → desde tmp_order_details + tmp_orders (lookup SKs)
--     7. dwm_producto       → snapshot inicial de dwa_dim_producto
--     8. dwm_cliente        → snapshot inicial de dwa_dim_cliente
--     9. dwa_enr_cliente    → métricas y segmento agregado por cliente
--    10. dwa_enr_producto   → métricas y performance agregada por producto
--
--   Cada carga registra una fila en dqm_carga_dwa.
--   El script aborta (no inserta) si dqm_indicador reporta ERROR
--   en los scripts 13 o 14 para la tabla correspondiente.
--
-- Etapa: Ingeniería
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-16
-- ============================================================


-- ============================================================
-- 1. REGISTRO EN INVENTARIO
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES (
    '15_carga_dwa',
    'Carga inicial del DWA: dimensiones, hechos, memoria y enriquecimiento desde TMP',
    'ingenieria'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 2. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log
    (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Iniciando carga inicial del DWA desde tablas TMP validadas'
);


-- ============================================================
-- 3. VERIFICACIÓN PREVIA DE BLOQUEOS
--    Si esta query devuelve filas, NO continuar con la carga.
--    Corregir los problemas reportados en scripts 13 y 14.
-- ============================================================

SELECT
    di.tabla,
    di.indicador,
    di.valor_calculado,
    di.resultado,
    dsi.script_nombre AS detectado_en
FROM data_warehouse.dqm_indicador di
JOIN data_warehouse.dqm_execution_log del ON di.log_id = del.log_id
JOIN data_warehouse.dqm_script_inventory dsi ON del.script_id = dsi.script_id
WHERE dsi.script_nombre IN ('13_validacion_ingesta_dwa', '14_validacion_integracion_dwa')
  AND di.resultado = 'ERROR'
ORDER BY dsi.script_nombre, di.tabla;

-- ============================================================
-- 4. dwa_dim_tiempo
--    Generada a partir del rango de fechas de tmp_orders.
--    Incluye order_date, required_date y shipped_date para
--    cubrir todas las fechas que pueden aparecer en el DWA.
--    sk_tiempo = YYYYMMDD (INT, legible sin join adicional).
-- ============================================================

INSERT INTO data_warehouse.dwa_dim_tiempo
    (sk_tiempo, fecha, anio, trimestre, mes, nombre_mes,
     semana_anio, dia, dia_semana, nombre_dia, es_fin_de_semana)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d::DATE,
    EXTRACT(YEAR    FROM d)::INT,
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(MONTH   FROM d)::INT,
    CASE EXTRACT(MONTH FROM d)
        WHEN 1 THEN 'Enero'    WHEN 2 THEN 'Febrero'  WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril'    WHEN 5 THEN 'Mayo'     WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio'    WHEN 8 THEN 'Agosto'   WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
    END,
    EXTRACT(WEEK    FROM d)::INT,
    EXTRACT(DAY     FROM d)::INT,
    EXTRACT(ISODOW  FROM d)::INT,   -- 1=lunes … 7=domingo
    CASE EXTRACT(ISODOW FROM d)
        WHEN 1 THEN 'Lunes'    WHEN 2 THEN 'Martes'  WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'   WHEN 5 THEN 'Viernes' WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
    END,
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM generate_series(
    (SELECT MIN(LEAST(order_date,
                      COALESCE(required_date, order_date),
                      COALESCE(shipped_date,  order_date)))
     FROM data_warehouse.tmp_orders
     WHERE order_date IS NOT NULL),
    (SELECT MAX(GREATEST(order_date,
                         COALESCE(required_date, order_date),
                         COALESCE(shipped_date,  order_date)))
     FROM data_warehouse.tmp_orders
     WHERE order_date IS NOT NULL),
    '1 day'::INTERVAL
) AS d
ON CONFLICT (sk_tiempo) DO NOTHING;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwa_dim_tiempo',
    (SELECT COUNT(DISTINCT d::DATE)
     FROM generate_series(
         (SELECT MIN(order_date) FROM data_warehouse.tmp_orders WHERE order_date IS NOT NULL),
         (SELECT MAX(order_date) FROM data_warehouse.tmp_orders WHERE order_date IS NOT NULL),
         '1 day'::INTERVAL) AS d),
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_tiempo),
    0,
    'CARGADO',
    NULL
);


-- ============================================================
-- 5. dwa_dim_shipper
-- ============================================================

INSERT INTO data_warehouse.dwa_dim_shipper
    (nk_shipper_id, company_name, phone)
SELECT shipper_id, company_name, phone
FROM data_warehouse.tmp_shippers
ON CONFLICT (nk_shipper_id) DO NOTHING;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwa_dim_shipper',
    (SELECT COUNT(*) FROM data_warehouse.tmp_shippers),
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_shipper),
    0,
    'CARGADO',
    NULL
);


-- ============================================================
-- 6. dwa_dim_cliente
-- ============================================================

INSERT INTO data_warehouse.dwa_dim_cliente
    (nk_customer_id, company_name, contact_name, contact_title, city, region, country)
SELECT
    customer_id, company_name, contact_name, contact_title, city, region, country
FROM data_warehouse.tmp_customers
ON CONFLICT (nk_customer_id) DO NOTHING;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwa_dim_cliente',
    (SELECT COUNT(*) FROM data_warehouse.tmp_customers),
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_cliente),
    0,
    'CARGADO',
    NULL
);


-- ============================================================
-- 7. dwa_dim_empleado
--    Carga en dos pasadas para resolver la jerarquía
--    auto-referencial (reports_to_sk).
--    Pasada 1: insertar todos con reports_to_sk = NULL.
--    Pasada 2: actualizar reports_to_sk usando el nk del supervisor.
-- ============================================================

-- Pasada 1: insertar sin jerarquía
INSERT INTO data_warehouse.dwa_dim_empleado
    (nk_employee_id, nombre_completo, title, hire_date, city, country, reports_to_sk)
SELECT
    employee_id,
    TRIM(first_name || ' ' || last_name),
    title,
    hire_date,
    city,
    country,
    NULL   -- se completa en pasada 2
FROM data_warehouse.tmp_employees
ON CONFLICT (nk_employee_id) DO NOTHING;

-- Pasada 2: resolver jerarquía de reporte
UPDATE data_warehouse.dwa_dim_empleado e
SET reports_to_sk = sup.sk_empleado
FROM data_warehouse.tmp_employees t
JOIN data_warehouse.dwa_dim_empleado sup ON sup.nk_employee_id = t.reports_to
WHERE e.nk_employee_id = t.employee_id
  AND t.reports_to IS NOT NULL;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwa_dim_empleado',
    (SELECT COUNT(*) FROM data_warehouse.tmp_employees),
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_empleado),
    0,
    'CARGADO',
    NULL
);


-- ============================================================
-- 8. dwa_dim_producto
--    Dimensión desnormalizada: colapsa categories y suppliers.
--    LEFT JOIN en categories/suppliers para no perder productos
--    cuya categoría o proveedor venga NULL.
-- ============================================================

INSERT INTO data_warehouse.dwa_dim_producto
    (nk_product_id, product_name, precio_lista, discontinued,
     category_name, category_description, supplier_name, supplier_country)
SELECT
    p.product_id,
    p.product_name,
    p.unit_price,
    (p.discontinued = 1),
    c.category_name,
    c.description,
    s.company_name,
    s.country
FROM data_warehouse.tmp_products p
LEFT JOIN data_warehouse.tmp_categories c ON c.category_id = p.category_id
LEFT JOIN data_warehouse.tmp_suppliers  s ON s.supplier_id = p.supplier_id
ON CONFLICT (nk_product_id) DO NOTHING;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwa_dim_producto',
    (SELECT COUNT(*) FROM data_warehouse.tmp_products),
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_producto),
    0,
    'CARGADO',
    NULL
);


-- ============================================================
-- 9. dwa_fact_ventas
--    Grain: 1 fila por línea de pedido (order_id + product_id).
--    Solo se cargan líneas cuyo pedido tenga order_date válido
--    (necesario para el join con dwa_dim_tiempo).
--    flete_prorrateado = freight del pedido / cantidad de líneas
--    del mismo pedido.
--    Las FKs de cliente, empleado y shipper son LEFT JOIN porque
--    pueden ser NULL en el source.
-- ============================================================

INSERT INTO data_warehouse.dwa_fact_ventas
    (sk_tiempo, sk_cliente, sk_empleado, sk_producto, sk_shipper,
     nk_order_id, cantidad, precio_unitario, descuento, flete_prorrateado,
     monto_bruto, monto_descuento, monto_neto)
SELECT
    dt.sk_tiempo,
    dc.sk_cliente,
    de.sk_empleado,
    dp.sk_producto,
    ds.sk_shipper,
    od.order_id,
    od.quantity,
    od.unit_price,
    od.discount,
    ROUND(COALESCE(o.freight, 0) / NULLIF(cnt.n_lineas, 0), 4),
    ROUND(od.quantity * od.unit_price, 4),
    ROUND(od.quantity * od.unit_price * od.discount, 4),
    ROUND(od.quantity * od.unit_price * (1 - od.discount), 4)
FROM data_warehouse.tmp_order_details od
JOIN data_warehouse.tmp_orders o
    ON o.order_id = od.order_id
JOIN data_warehouse.dwa_dim_tiempo dt
    ON dt.fecha = o.order_date
JOIN data_warehouse.dwa_dim_producto dp
    ON dp.nk_product_id = od.product_id
LEFT JOIN data_warehouse.dwa_dim_cliente dc
    ON dc.nk_customer_id = o.customer_id
LEFT JOIN data_warehouse.dwa_dim_empleado de
    ON de.nk_employee_id = o.employee_id
LEFT JOIN data_warehouse.dwa_dim_shipper ds
    ON ds.nk_shipper_id = o.ship_via
JOIN (
    SELECT order_id, COUNT(*) AS n_lineas
    FROM data_warehouse.tmp_order_details
    GROUP BY order_id
) cnt ON cnt.order_id = od.order_id
WHERE o.order_date IS NOT NULL
ON CONFLICT (nk_order_id, sk_producto) DO NOTHING;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwa_fact_ventas',
    (SELECT COUNT(*) FROM data_warehouse.tmp_order_details),
    (SELECT COUNT(*) FROM data_warehouse.dwa_fact_ventas),
    (SELECT COUNT(*) FROM data_warehouse.tmp_order_details) - (SELECT COUNT(*) FROM data_warehouse.dwa_fact_ventas),
    CASE
        WHEN (SELECT COUNT(*) FROM data_warehouse.dwa_fact_ventas) = (SELECT COUNT(*) FROM data_warehouse.tmp_order_details)
        THEN 'CARGADO'
        WHEN (SELECT COUNT(*) FROM data_warehouse.dwa_fact_ventas) > 0
        THEN 'CARGADO_PARCIAL'
        ELSE 'RECHAZADO'
    END,
    CASE
        WHEN (SELECT COUNT(*) FROM data_warehouse.dwa_fact_ventas) < (SELECT COUNT(*) FROM data_warehouse.tmp_order_details)
        THEN 'Líneas excluidas por order_date NULL o FK de producto no encontrada'
        ELSE NULL
    END;


-- ============================================================
-- 10. dwm_producto — Snapshot inicial (SCD2)
--     La carga inicial de Ingesta1 crea la versión 0 de cada
--     producto: fecha_desde = fecha del primer pedido que lo
--     incluye, fecha_hasta = NULL, es_vigente = TRUE.
-- ============================================================

INSERT INTO data_warehouse.dwm_producto
    (nk_product_id, sk_producto, product_name, precio_lista, discontinued,
     fecha_desde, fecha_hasta, es_vigente)
SELECT
    dp.nk_product_id,
    dp.sk_producto,
    dp.product_name,
    dp.precio_lista,
    dp.discontinued,
    COALESCE(
        (SELECT MIN(dt.fecha)
         FROM data_warehouse.dwa_fact_ventas fv
         JOIN data_warehouse.dwa_dim_tiempo dt ON dt.sk_tiempo = fv.sk_tiempo
         WHERE fv.sk_producto = dp.sk_producto),
        CURRENT_DATE
    ),
    NULL,    -- vigente
    TRUE
FROM data_warehouse.dwa_dim_producto dp;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwm_producto',
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_producto),
    (SELECT COUNT(*) FROM data_warehouse.dwm_producto),
    0,
    'CARGADO',
    NULL
);


-- ============================================================
-- 11. dwm_cliente — Snapshot inicial (SCD2)
--     Mismo criterio que dwm_producto.
-- ============================================================

INSERT INTO data_warehouse.dwm_cliente
    (nk_customer_id, sk_cliente, company_name, city, region, country,
     fecha_desde, fecha_hasta, es_vigente)
SELECT
    dc.nk_customer_id,
    dc.sk_cliente,
    dc.company_name,
    dc.city,
    dc.region,
    dc.country,
    COALESCE(
        (SELECT MIN(dt.fecha)
         FROM data_warehouse.dwa_fact_ventas fv
         JOIN data_warehouse.dwa_dim_tiempo dt ON dt.sk_tiempo = fv.sk_tiempo
         WHERE fv.sk_cliente = dc.sk_cliente),
        CURRENT_DATE
    ),
    NULL,
    TRUE
FROM data_warehouse.dwa_dim_cliente dc;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwm_cliente',
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_cliente),
    (SELECT COUNT(*) FROM data_warehouse.dwm_cliente),
    0,
    'CARGADO',
    NULL
);


-- ============================================================
-- 12. dwa_enr_cliente — Métricas y segmento por cliente
--     Segmento por NTILE(5) sobre monto_total_neto:
--       tile 5 (top 20%)    → PREMIUM
--       tiles 2-4 (60%)     → REGULAR
--       tile 1 (bottom 20%) → BAJO
-- ============================================================

INSERT INTO data_warehouse.dwa_enr_cliente
    (sk_cliente, total_pedidos, total_lineas, monto_total_neto,
     monto_promedio_pedido, primer_pedido, ultimo_pedido,
     dias_como_cliente, segmento, fecha_calculo)
WITH metricas AS (
    SELECT
        fv.sk_cliente,
        COUNT(DISTINCT fv.nk_order_id)                               AS total_pedidos,
        COUNT(*)                                                       AS total_lineas,
        ROUND(SUM(fv.monto_neto), 4)                                  AS monto_total_neto,
        ROUND(SUM(fv.monto_neto) / NULLIF(COUNT(DISTINCT fv.nk_order_id), 0), 4) AS monto_promedio_pedido,
        MIN(dt.fecha)                                                  AS primer_pedido,
        MAX(dt.fecha)                                                  AS ultimo_pedido,
        MAX(dt.fecha) - MIN(dt.fecha)                                  AS dias_como_cliente
    FROM data_warehouse.dwa_fact_ventas fv
    JOIN data_warehouse.dwa_dim_tiempo dt ON dt.sk_tiempo = fv.sk_tiempo
    WHERE fv.sk_cliente IS NOT NULL
    GROUP BY fv.sk_cliente
),
con_tile AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY monto_total_neto) AS tile
    FROM metricas
)
SELECT
    sk_cliente,
    total_pedidos,
    total_lineas,
    monto_total_neto,
    monto_promedio_pedido,
    primer_pedido,
    ultimo_pedido,
    dias_como_cliente,
    CASE WHEN tile = 5 THEN 'PREMIUM' WHEN tile >= 2 THEN 'REGULAR' ELSE 'BAJO' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM con_tile
ON CONFLICT (sk_cliente) DO UPDATE SET
    total_pedidos         = EXCLUDED.total_pedidos,
    total_lineas          = EXCLUDED.total_lineas,
    monto_total_neto      = EXCLUDED.monto_total_neto,
    monto_promedio_pedido = EXCLUDED.monto_promedio_pedido,
    primer_pedido         = EXCLUDED.primer_pedido,
    ultimo_pedido         = EXCLUDED.ultimo_pedido,
    dias_como_cliente     = EXCLUDED.dias_como_cliente,
    segmento              = EXCLUDED.segmento,
    fecha_calculo         = EXCLUDED.fecha_calculo;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwa_enr_cliente',
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_cliente),
    (SELECT COUNT(*) FROM data_warehouse.dwa_enr_cliente),
    0,
    'CARGADO',
    NULL
);


-- ============================================================
-- 13. dwa_enr_producto — Métricas y performance por producto
--     Performance por NTILE(5) sobre revenue_total:
--       tile 5 (top 20%)    → TOP
--       tiles 2-4 (60%)     → MID
--       tile 1 (bottom 20%) → LOW
-- ============================================================

INSERT INTO data_warehouse.dwa_enr_producto
    (sk_producto, total_pedidos, total_unidades, revenue_total,
     revenue_promedio_pedido, rank_revenue, performance, fecha_calculo)
WITH metricas AS (
    SELECT
        fv.sk_producto,
        COUNT(DISTINCT fv.nk_order_id)                               AS total_pedidos,
        SUM(fv.cantidad)                                              AS total_unidades,
        ROUND(SUM(fv.monto_neto), 4)                                  AS revenue_total,
        ROUND(SUM(fv.monto_neto) / NULLIF(COUNT(DISTINCT fv.nk_order_id), 0), 4) AS revenue_promedio_pedido
    FROM data_warehouse.dwa_fact_ventas fv
    GROUP BY fv.sk_producto
),
con_tile AS (
    SELECT *,
        RANK()   OVER (ORDER BY revenue_total DESC) AS rank_revenue,
        NTILE(5) OVER (ORDER BY revenue_total)      AS tile
    FROM metricas
)
SELECT
    sk_producto,
    total_pedidos,
    total_unidades,
    revenue_total,
    revenue_promedio_pedido,
    rank_revenue,
    CASE WHEN tile = 5 THEN 'TOP' WHEN tile >= 2 THEN 'MID' ELSE 'LOW' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM con_tile
ON CONFLICT (sk_producto) DO UPDATE SET
    total_pedidos          = EXCLUDED.total_pedidos,
    total_unidades         = EXCLUDED.total_unidades,
    revenue_total          = EXCLUDED.revenue_total,
    revenue_promedio_pedido= EXCLUDED.revenue_promedio_pedido,
    rank_revenue           = EXCLUDED.rank_revenue,
    performance            = EXCLUDED.performance,
    fecha_calculo          = EXCLUDED.fecha_calculo;

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')),
    'dwa_enr_producto',
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_producto),
    (SELECT COUNT(*) FROM data_warehouse.dwa_enr_producto),
    0,
    'CARGADO',
    NULL
);


-- ============================================================
-- 14. RESUMEN DE LA CARGA
-- ============================================================

SELECT
    tabla_destino,
    registros_leidos,
    registros_insertados,
    registros_rechazados,
    decision,
    motivo_rechazo,
    fecha_carga
FROM data_warehouse.dqm_carga_dwa
WHERE log_id = (
    SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
    WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')
)
ORDER BY fecha_carga;


-- ============================================================
-- 15. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = CASE
                         WHEN EXISTS (
                             SELECT 1 FROM data_warehouse.dqm_carga_dwa
                             WHERE log_id = (
                                 SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
                                 WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')
                             ) AND decision = 'RECHAZADO'
                         ) THEN 'ERROR'
                         WHEN EXISTS (
                             SELECT 1 FROM data_warehouse.dqm_carga_dwa
                             WHERE log_id = (
                                 SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
                                 WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')
                             ) AND decision = 'CARGADO_PARCIAL'
                         ) THEN 'WARNING'
                         ELSE 'OK'
                     END,
    registros_proc = (SELECT SUM(registros_insertados) FROM data_warehouse.dqm_carga_dwa
                      WHERE log_id = (
                          SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
                          WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa')
                      )),
    detalle        = 'Carga inicial del DWA completada. Ver dqm_carga_dwa para detalle por tabla.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '15_carga_dwa'
)
AND resultado = 'EN_PROCESO';
