-- ============================================================
-- SCRIPT: 13_validacion_ingesta_dwa
-- Descripción: Controles de calidad de INGESTA para cada tabla
--              TMP antes de cargar al DWA.
--              Evalúa indicadores campo a campo y persiste
--              resultados en dqm_indicador con umbrales.
--
--   Indicadores aplicados por tabla:
--     tmp_shippers        → PCT_NULOS (company_name)
--     tmp_categories      → PCT_NULOS (category_name)
--     tmp_suppliers       → PCT_NULOS (company_name)
--     tmp_customers       → PCT_NULOS (company_name, country)
--     tmp_employees       → PCT_NULOS (nombre), PCT_REPORTS_TO_INVALIDO
--     tmp_products        → PCT_NULOS (product_name), PCT_PRECIO_NEGATIVO,
--                           PCT_PRECIO_CERO, PCT_OUTLIERS_PRECIO,
--                           PCT_DISCONTINUED_INVALIDO
--     tmp_orders          → PCT_NULOS (order_date), PCT_SHIPPED_BEFORE_ORDER,
--                           PCT_OUTLIERS_FREIGHT
--     tmp_order_details   → PCT_PRECIO_NEGATIVO, PCT_PRECIO_CERO,
--                           PCT_CANTIDAD_INVALIDA, PCT_DESCUENTO_INVALIDO,
--                           PCT_OUTLIERS_PRECIO, PCT_OUTLIERS_CANTIDAD
--
--   Lógica de umbrales:
--     valor <= umbral_warning              → OK
--     umbral_warning < valor <= umbral_error → WARNING (carga con advertencia)
--     valor > umbral_error                 → ERROR   (bloquea carga)
--
--   Umbrales definidos:
--     - Campos NOT NULL del DWA: warning=0, error=0 (tolerancia cero)
--     - Campos opcionales del DWA: warning=10, error=30
--     - Violaciones de reglas de negocio: warning=0, error=1
--     - Outliers estadísticos (3×IQR): warning=5, error=15
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
    '13_validacion_ingesta_dwa',
    'Controles de calidad de ingesta para carga al DWA: indicadores por tabla TMP',
    'ingenieria'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 2. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log
    (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Evaluando indicadores de calidad de ingesta sobre tablas TMP'
);


-- ============================================================
-- 3. INDICADORES POR TABLA
-- ============================================================

-- ------------------------------------------------------------
-- tmp_shippers → dwa_dim_shipper
--   company_name es NOT NULL en el DWA: tolerancia cero.
-- ------------------------------------------------------------

WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE company_name IS NULL)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_shippers
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_shippers', 'company_name', 'PCT_NULOS',
    'Porcentaje de filas con company_name nulo (campo NOT NULL en dwa_dim_shipper)',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;


-- ------------------------------------------------------------
-- tmp_categories → colapsa en dwa_dim_producto
-- ------------------------------------------------------------

WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE category_name IS NULL)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_categories
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_categories', 'category_name', 'PCT_NULOS',
    'Porcentaje de filas con category_name nulo',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;


-- ------------------------------------------------------------
-- tmp_suppliers → colapsa en dwa_dim_producto
-- ------------------------------------------------------------

WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE company_name IS NULL)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_suppliers
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_suppliers', 'company_name', 'PCT_NULOS',
    'Porcentaje de filas con company_name nulo',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;


-- ------------------------------------------------------------
-- tmp_customers → dwa_dim_cliente
-- ------------------------------------------------------------

-- company_name: NOT NULL en el DWA
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE company_name IS NULL)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_customers
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_customers', 'company_name', 'PCT_NULOS',
    'Porcentaje de clientes sin nombre de empresa',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- country: nullable en el DWA pero crítico para análisis geográfico
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE country IS NULL)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_customers
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_customers', 'country', 'PCT_NULOS',
    'Porcentaje de clientes sin país (afecta análisis geográfico)',
    v, 10.0, 30.0,
    CASE WHEN v > 30.0 THEN 'ERROR' WHEN v > 10.0 THEN 'WARNING' ELSE 'OK' END
FROM val;


-- ------------------------------------------------------------
-- tmp_employees → dwa_dim_empleado
-- ------------------------------------------------------------

-- Nombre: NOT NULL en el DWA (nombre_completo = first || last)
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE first_name IS NULL OR last_name IS NULL)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_employees
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_employees', 'first_name / last_name', 'PCT_NULOS',
    'Porcentaje de empleados con first_name o last_name nulo (campo NOT NULL en dwa_dim_empleado)',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- reports_to auto-referencia: el ID referenciado debe existir en la misma tabla
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE reports_to IS NOT NULL
                       AND reports_to NOT IN (SELECT employee_id FROM data_warehouse.tmp_employees)
                 ) / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_employees
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_employees', 'reports_to', 'PCT_REPORTS_TO_INVALIDO',
    'Porcentaje de empleados con reports_to que no existe como employee_id',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;


-- ------------------------------------------------------------
-- tmp_products → dwa_dim_producto
-- ------------------------------------------------------------

-- product_name: NOT NULL en el DWA
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE product_name IS NULL)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_products
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_products', 'product_name', 'PCT_NULOS',
    'Porcentaje de productos sin nombre',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- unit_price negativo: regla de negocio (precio no puede ser negativo)
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE unit_price < 0)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_products
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_products', 'unit_price', 'PCT_PRECIO_NEGATIVO',
    'Porcentaje de productos con precio de lista negativo',
    v, 0.0, 1.0,
    CASE WHEN v > 1.0 THEN 'ERROR' WHEN v > 0.0 THEN 'WARNING' ELSE 'OK' END
FROM val;

-- unit_price = 0: sospechoso para productos activos
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE unit_price = 0 AND discontinued = 0)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_products
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_products', 'unit_price', 'PCT_PRECIO_CERO',
    'Porcentaje de productos activos con precio de lista igual a cero',
    v, 0.0, 5.0,
    CASE WHEN v > 5.0 THEN 'ERROR' WHEN v > 0.0 THEN 'WARNING' ELSE 'OK' END
FROM val;

-- outliers de unit_price en products (3×IQR)
WITH iqr AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS q3,
        COUNT(*) AS total
    FROM data_warehouse.tmp_products WHERE unit_price IS NOT NULL AND unit_price > 0
),
val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE unit_price > (SELECT q3 + 3*(q3-q1) FROM iqr)
                        OR unit_price < GREATEST(0, (SELECT q1 - 3*(q3-q1) FROM iqr))
                 ) / NULLIF((SELECT total FROM iqr), 0), 2) AS v
    FROM data_warehouse.tmp_products
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_products', 'unit_price', 'PCT_OUTLIERS',
    'Porcentaje de precios de lista fuera del rango [Q1-3×IQR, Q3+3×IQR]',
    v, 5.0, 15.0,
    CASE WHEN v > 15.0 THEN 'ERROR' WHEN v > 5.0 THEN 'WARNING' ELSE 'OK' END
FROM val;

-- discontinued: debe ser 0 o 1 (INT en TMP)
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE discontinued NOT IN (0,1))
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_products
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_products', 'discontinued', 'PCT_VALOR_INVALIDO',
    'Porcentaje de productos con valor de discontinued distinto de 0 o 1',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;


-- ------------------------------------------------------------
-- tmp_orders → dwa_fact_ventas (vía dim_tiempo)
-- ------------------------------------------------------------

-- order_date: NULL implica que la venta no puede linkear a dim_tiempo → bloquea
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE order_date IS NULL)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_orders
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_orders', 'order_date', 'PCT_NULOS',
    'Porcentaje de pedidos sin fecha de pedido (necesario para unión con dwa_dim_tiempo)',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- shipped_date < order_date: imposible cronológicamente
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE shipped_date IS NOT NULL AND shipped_date < order_date
                 ) / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_orders
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_orders', 'shipped_date', 'PCT_SHIPPED_BEFORE_ORDER',
    'Porcentaje de pedidos con fecha de despacho anterior a la fecha del pedido',
    v, 0.0, 1.0,
    CASE WHEN v > 1.0 THEN 'ERROR' WHEN v > 0.0 THEN 'WARNING' ELSE 'OK' END
FROM val;

-- freight outliers (3×IQR, excluyendo NULLs y ceros)
WITH iqr AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY freight) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY freight) AS q3,
        COUNT(*) AS total
    FROM data_warehouse.tmp_orders WHERE freight IS NOT NULL AND freight >= 0
),
val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE freight > (SELECT q3 + 3*(q3-q1) FROM iqr)
                 ) / NULLIF((SELECT total FROM iqr), 0), 2) AS v
    FROM data_warehouse.tmp_orders
    WHERE freight IS NOT NULL
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_orders', 'freight', 'PCT_OUTLIERS',
    'Porcentaje de fletes por encima del límite Q3+3×IQR',
    v, 5.0, 15.0,
    CASE WHEN v > 15.0 THEN 'ERROR' WHEN v > 5.0 THEN 'WARNING' ELSE 'OK' END
FROM val;


-- ------------------------------------------------------------
-- tmp_order_details → dwa_fact_ventas (medidas principales)
-- ------------------------------------------------------------

-- unit_price negativo
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE unit_price < 0)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_order_details
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_order_details', 'unit_price', 'PCT_PRECIO_NEGATIVO',
    'Porcentaje de líneas con precio de venta negativo',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- unit_price = 0: puede ser válido (promo) pero es sospechoso
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE unit_price = 0)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_order_details
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_order_details', 'unit_price', 'PCT_PRECIO_CERO',
    'Porcentaje de líneas con precio de venta igual a cero',
    v, 1.0, 5.0,
    CASE WHEN v > 5.0 THEN 'ERROR' WHEN v > 1.0 THEN 'WARNING' ELSE 'OK' END
FROM val;

-- quantity <= 0: cantidad inválida
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE quantity <= 0)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_order_details
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_order_details', 'quantity', 'PCT_CANTIDAD_INVALIDA',
    'Porcentaje de líneas con cantidad menor o igual a cero',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- discount fuera de [0, 1]
WITH val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE discount < 0 OR discount > 1)
                 / NULLIF(COUNT(*), 0), 2) AS v
    FROM data_warehouse.tmp_order_details
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_order_details', 'discount', 'PCT_DESCUENTO_INVALIDO',
    'Porcentaje de líneas con descuento fuera del rango [0, 1]',
    v, 0.0, 0.0,
    CASE WHEN v > 0.0 THEN 'ERROR' ELSE 'OK' END
FROM val;

-- outliers de unit_price en order_details (3×IQR, excluyendo ceros)
WITH iqr AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS q3,
        COUNT(*) AS total
    FROM data_warehouse.tmp_order_details WHERE unit_price > 0
),
val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE unit_price > (SELECT q3 + 3*(q3-q1) FROM iqr)
                 ) / NULLIF((SELECT total FROM iqr), 0), 2) AS v
    FROM data_warehouse.tmp_order_details
    WHERE unit_price > 0
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_order_details', 'unit_price', 'PCT_OUTLIERS',
    'Porcentaje de precios de venta por encima de Q3+3×IQR',
    v, 5.0, 15.0,
    CASE WHEN v > 15.0 THEN 'ERROR' WHEN v > 5.0 THEN 'WARNING' ELSE 'OK' END
FROM val;

-- outliers de quantity en order_details (3×IQR)
WITH iqr AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY quantity) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY quantity) AS q3,
        COUNT(*) AS total
    FROM data_warehouse.tmp_order_details WHERE quantity > 0
),
val AS (
    SELECT ROUND(100.0 * COUNT(*) FILTER (
                     WHERE quantity > (SELECT q3 + 3*(q3-q1) FROM iqr)
                 ) / NULLIF((SELECT total FROM iqr), 0), 2) AS v
    FROM data_warehouse.tmp_order_details
    WHERE quantity > 0
)
INSERT INTO data_warehouse.dqm_indicador
    (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')),
    'tmp_order_details', 'quantity', 'PCT_OUTLIERS',
    'Porcentaje de cantidades por encima de Q3+3×IQR',
    v, 5.0, 15.0,
    CASE WHEN v > 15.0 THEN 'ERROR' WHEN v > 5.0 THEN 'WARNING' ELSE 'OK' END
FROM val;


-- ============================================================
-- 4. RESUMEN DE RESULTADOS
--    Revisar esta salida antes de ejecutar el script 15.
--    Si existe algún resultado = 'ERROR', la carga será bloqueada.
-- ============================================================

SELECT
    tabla,
    campo,
    indicador,
    valor_calculado,
    umbral_warning,
    umbral_error,
    resultado
FROM data_warehouse.dqm_indicador
WHERE log_id = (
    SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
    WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')
)
ORDER BY
    CASE resultado WHEN 'ERROR' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
    tabla, campo;


-- ============================================================
-- 5. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = CASE
                         WHEN EXISTS (
                             SELECT 1 FROM data_warehouse.dqm_indicador
                             WHERE log_id = (
                                 SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
                                 WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')
                             ) AND resultado = 'ERROR'
                         ) THEN 'ERROR'
                         WHEN EXISTS (
                             SELECT 1 FROM data_warehouse.dqm_indicador
                             WHERE log_id = (
                                 SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
                                 WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')
                             ) AND resultado = 'WARNING'
                         ) THEN 'WARNING'
                         ELSE 'OK'
                     END,
    registros_proc = (
        SELECT COUNT(*) FROM data_warehouse.dqm_indicador
        WHERE log_id = (
            SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
            WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa')
        )
    ),
    detalle        = 'Evaluación de indicadores de ingesta completada. Ver dqm_indicador para detalle.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '13_validacion_ingesta_dwa'
)
AND resultado = 'EN_PROCESO';
