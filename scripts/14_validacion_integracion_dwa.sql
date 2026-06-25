-- ============================================================
-- SCRIPT: 14_validacion_integracion_dwa
-- Descripción: Controles de calidad de INTEGRACIÓN entre tablas
--              TMP antes de cargar al DWA.
--              Verifica integridad referencial cruzada e
--              indicadores de comparación TXT vs TMP.
--
--   Indicadores aplicados:
--     Integridad referencial:
--       PCT_OD_SIN_ORDER      → order_details sin order en tmp_orders
--       PCT_OD_SIN_PRODUCTO   → order_details sin product en tmp_products
--       PCT_ORDER_SIN_SHIPPER → orders con ship_via no existente en shippers
--       PCT_PROD_SIN_CATEGORY → products con category_id inexistente
--       PCT_PROD_SIN_SUPPLIER → products con supplier_id inexistente
--
--     Comparación TXT vs TMP (totales de control):
--       DIFF_COUNT_ORDERS        → diferencia de filas entre txt y tmp
--       DIFF_COUNT_ORDER_DETAILS → ídem para order_details
--       DIFF_COUNT_PRODUCTS      → ídem para products
--       DIFF_COUNT_CUSTOMERS     → ídem para customers
--
--   Umbrales:
--     - Integridad referencial crítica: warning=0, error=0
--     - Diferencias TXT vs TMP: warning=0, error=0
--       (toda diferencia debe estar justificada por limpieza de Etapa 1)
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
    '14_validacion_integracion_dwa',
    'Controles de calidad de integración entre tablas TMP para carga al DWA',
    'ingenieria'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 2. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log
    (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Evaluando integridad referencial e indicadores de comparación entre tablas TMP'
);


-- ============================================================
-- 3. INTEGRIDAD REFERENCIAL
-- ============================================================

-- PCT_OD_SIN_ORDER
--   Líneas en tmp_order_details cuyo order_id no existe en tmp_orders.
--   Impacto directo en fact_ventas: esas líneas no podrían cargarse.
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE order_id NOT IN (SELECT order_id FROM data_warehouse.tmp_orders)
                 ) / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_order_details
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')),
    'tmp_order_details', 'order_id', 'PCT_OD_SIN_ORDER',
    'Porcentaje de líneas de detalle cuyo order_id no existe en tmp_orders',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- PCT_OD_SIN_PRODUCTO
--   Líneas en tmp_order_details cuyo product_id no existe en tmp_products.
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE product_id NOT IN (SELECT product_id FROM data_warehouse.tmp_products)
                 ) / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_order_details
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')),
    'tmp_order_details', 'product_id', 'PCT_OD_SIN_PRODUCTO',
    'Porcentaje de líneas de detalle cuyo product_id no existe en tmp_products',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- PCT_ORDER_SIN_SHIPPER
--   Pedidos con ship_via que no existe en tmp_shippers.
--   ship_via puede ser NULL (shipper no asignado), eso es válido.
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE ship_via IS NOT NULL
                       AND ship_via NOT IN (SELECT shipper_id FROM data_warehouse.tmp_shippers)
                 ) / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_orders
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')),
    'tmp_orders', 'ship_via', 'PCT_ORDER_SIN_SHIPPER',
    'Porcentaje de pedidos con shipper asignado que no existe en tmp_shippers',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- PCT_PROD_SIN_CATEGORY
--   Productos con category_id que no existe en tmp_categories.
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE category_id IS NOT NULL
                       AND category_id NOT IN (SELECT category_id FROM data_warehouse.tmp_categories)
                 ) / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_products
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')),
    'tmp_products', 'category_id', 'PCT_PROD_SIN_CATEGORY',
    'Porcentaje de productos con category_id que no existe en tmp_categories',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- PCT_PROD_SIN_SUPPLIER
--   Productos con supplier_id que no existe en tmp_suppliers.
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE supplier_id IS NOT NULL
                       AND supplier_id NOT IN (SELECT supplier_id FROM data_warehouse.tmp_suppliers)
                 ) / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_products
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')),
    'tmp_products', 'supplier_id', 'PCT_PROD_SIN_SUPPLIER',
    'Porcentaje de productos con supplier_id que no existe en tmp_suppliers',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;


-- ============================================================
-- 4. COMPARACIÓN TXT vs TMP (totales de control)
--    Detecta diferencias de cantidad de registros entre la capa
--    espejo (TXT) y la capa tipada (TMP).
--    Toda diferencia debería estar justificada por la limpieza
--    ejecutada en Etapa 1. Si hay diferencias no esperadas,
--    el indicador marcará WARNING para revisión.
-- ============================================================

WITH val AS (
    SELECT ABS(
        (SELECT COUNT(*) FROM data_warehouse.txt_orders) -
        (SELECT COUNT(*) FROM data_warehouse.tmp_orders)
    )::NUMERIC AS v
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')),
    'tmp_orders', NULL, 'DIFF_COUNT_TXT_VS_TMP',
    'Diferencia absoluta en cantidad de filas entre txt_orders y tmp_orders',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'WARNING' ELSE 'OK' END
FROM val;

WITH val AS (
    SELECT ABS(
        (SELECT COUNT(*) FROM data_warehouse.txt_order_details) -
        (SELECT COUNT(*) FROM data_warehouse.tmp_order_details)
    )::NUMERIC AS v
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')),
    'tmp_order_details', NULL, 'DIFF_COUNT_TXT_VS_TMP',
    'Diferencia absoluta en cantidad de filas entre txt_order_details y tmp_order_details',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'WARNING' ELSE 'OK' END
FROM val;

WITH val AS (
    SELECT ABS(
        (SELECT COUNT(*) FROM data_warehouse.txt_products) -
        (SELECT COUNT(*) FROM data_warehouse.tmp_products)
    )::NUMERIC AS v
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')),
    'tmp_products', NULL, 'DIFF_COUNT_TXT_VS_TMP',
    'Diferencia absoluta en cantidad de filas entre txt_products y tmp_products',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'WARNING' ELSE 'OK' END
FROM val;

WITH val AS (
    SELECT ABS(
        (SELECT COUNT(*) FROM data_warehouse.txt_customers) -
        (SELECT COUNT(*) FROM data_warehouse.tmp_customers)
    )::NUMERIC AS v
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')),
    'tmp_customers', NULL, 'DIFF_COUNT_TXT_VS_TMP',
    'Diferencia absoluta en cantidad de filas entre txt_customers y tmp_customers',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'WARNING' ELSE 'OK' END
FROM val;


-- ============================================================
-- 5. RESUMEN DE RESULTADOS
--    Revisar antes de ejecutar script 15.
--    Cualquier ERROR bloquea la carga del DWA.
-- ============================================================

SELECT
    tabla,
    campo,
    indicador,
    valor_calculado,
    resultado
FROM data_warehouse.dqm_indicador
WHERE log_id = (
    SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
    WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')
)
ORDER BY
    CASE resultado WHEN 'ERROR' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
    tabla;


-- ============================================================
-- 6. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = CASE
                         WHEN EXISTS (
                             SELECT 1 FROM data_warehouse.dqm_indicador
                             WHERE log_id = (
                                 SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
                                 WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')
                             ) AND resultado = 'ERROR'
                         ) THEN 'ERROR'
                         WHEN EXISTS (
                             SELECT 1 FROM data_warehouse.dqm_indicador
                             WHERE log_id = (
                                 SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
                                 WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')
                             ) AND resultado = 'WARNING'
                         ) THEN 'WARNING'
                         ELSE 'OK'
                     END,
    registros_proc = (
        SELECT COUNT(*) FROM data_warehouse.dqm_indicador
        WHERE log_id = (
            SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
            WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa')
        )
    ),
    detalle        = 'Evaluación de indicadores de integración completada. Ver dqm_indicador para detalle.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '14_validacion_integracion_dwa'
)
AND resultado = 'EN_PROCESO';
