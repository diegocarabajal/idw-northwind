-- ============================================================
-- SCRIPT: 03_validacion_txt
-- Descripción: Valida campos de las 11 tablas TXT_. Persiste
--              resultados en dqm_validacion_campo. Cubre:
--                - Nulos en campos obligatorios
--                - Duplicados en claves primarias
--                - Compatibilidad de tipo
--                - Outliers y valores fuera de rango
--                - Inconsistencias de datos conocidas
-- Etapa: Adquisición
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-02
-- ============================================================


-- ============================================================
-- 1. INVENTARIO Y LOG DE INICIO
--    Registra este script en el inventario si no existe.
--    Inicia el log de ejecución antes de correr las validaciones.
-- ============================================================

INSERT INTO public.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('03_validacion_txt', 'Validación de datos crudos en tablas TXT_', 'adquisicion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO public.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '03_validacion_txt'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO', 'Iniciando validaciones sobre tablas TXT_'
);

TRUNCATE TABLE public.dqm_validacion_campo;


-- ============================================================
-- 2. TXT_CATEGORIES
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_categories', 'category_id', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros con category_id nulo' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_categories WHERE category_id IS NULL OR category_id = '';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_categories', 'category_id', 'SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin duplicados' ELSE 'Hay category_id duplicados' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT category_id FROM public.txt_categories GROUP BY category_id HAVING COUNT(*) > 1) d;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_categories', 'category_id', 'CASTEABLE_A_ENTERO',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los valores son casteables a INTEGER' ELSE 'Hay valores no casteables a INTEGER' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_categories
WHERE category_id IS NOT NULL AND TRIM(category_id) !~ '^\d+$';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_categories', 'category_name', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros sin category_name' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_categories WHERE category_name IS NULL OR category_name = '';


-- ============================================================
-- 3. TXT_CUSTOMERS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_customers', 'customer_id', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros con customer_id nulo' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers WHERE customer_id IS NULL OR customer_id = '';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_customers', 'customer_id', 'SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin duplicados' ELSE 'Hay customer_id duplicados' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT customer_id FROM public.txt_customers GROUP BY customer_id HAVING COUNT(*) > 1) d;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_customers', 'customer_id', 'LONGITUD_5',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos tienen longitud 5' ELSE 'Hay customer_id con longitud distinta de 5' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers WHERE LENGTH(customer_id) <> 5;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_customers', 'company_name', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros sin company_name' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers WHERE company_name IS NULL OR company_name = '';

-- Detección de country='MX': se registra como WARNING para corregir en 05_limpieza_datos_txt
INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_customers', 'country', 'VALOR_INCONSISTENTE',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'WARNING' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin inconsistencias'
         ELSE 'Hay registros con country=MX (debería ser Mexico): ' || STRING_AGG(customer_id, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers WHERE country = 'MX';


-- ============================================================
-- 4. TXT_EMPLOYEES
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_employees', 'employee_id', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros con employee_id nulo' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employees WHERE employee_id IS NULL OR employee_id = '';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_employees', 'employee_id', 'SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin duplicados' ELSE 'Hay employee_id duplicados' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT employee_id FROM public.txt_employees GROUP BY employee_id HAVING COUNT(*) > 1) d;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_employees', 'birth_date', 'FORMATO_FECHA',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todas las fechas son válidas' ELSE 'Hay fechas inválidas en birth_date' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employees
WHERE birth_date IS NOT NULL AND birth_date <> 'NULL'
  AND birth_date !~ '^\d{4}-\d{2}-\d{2}';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_employees', 'reports_to', 'ES_ENTERO_O_NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los valores son enteros o NULL' ELSE 'Hay valores inválidos en reports_to' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employees
WHERE reports_to IS NOT NULL AND reports_to <> 'NULL'
  AND TRIM(reports_to) !~ '^\d+$';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_employees', 'last_name', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros sin last_name' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employees WHERE last_name IS NULL OR last_name = '';


-- ============================================================
-- 5. TXT_PRODUCTS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_products', 'product_id', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay product_id nulos' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_products WHERE product_id IS NULL OR product_id = '';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_products', 'product_id', 'SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin duplicados' ELSE 'Hay product_id duplicados' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT product_id FROM public.txt_products GROUP BY product_id HAVING COUNT(*) > 1) d;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_products', 'product_name', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros sin product_name' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_products WHERE product_name IS NULL OR product_name = '';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_products', 'discontinued', 'VALOR_0_O_1',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los valores son 0 o 1'
         ELSE 'Valores inválidos: ' || STRING_AGG(DISTINCT discontinued, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_products WHERE discontinued NOT IN ('0', '1');

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_products', 'unit_price', 'ES_NUMERICO',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los valores son numéricos' ELSE 'Hay valores no numéricos en unit_price' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_products
WHERE unit_price IS NOT NULL AND unit_price !~ '^\d+(\.\d+)?$';


-- ============================================================
-- 6. TXT_ORDERS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_orders', 'order_id', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay order_id nulos' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_orders WHERE order_id IS NULL OR order_id = '';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_orders', 'order_id', 'SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin duplicados' ELSE 'Hay order_id duplicados' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT order_id FROM public.txt_orders GROUP BY order_id HAVING COUNT(*) > 1) d;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_orders', 'customer_id', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay órdenes sin customer_id' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_orders WHERE customer_id IS NULL OR customer_id = '';

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_orders', 'shipped_date', 'NULOS_ESPERADOS',
    'OK',
    COUNT(*) FILTER (WHERE shipped_date IS NULL OR shipped_date = 'NULL'),
    'shipped_date NULL es válido (pedido pendiente de envío). Cantidad: ' ||
        COUNT(*) FILTER (WHERE shipped_date IS NULL OR shipped_date = 'NULL'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_orders;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_orders', 'freight', 'ES_NUMERICO_POSITIVO',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los valores son numéricos y >= 0' ELSE 'Hay valores inválidos en freight' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_orders
WHERE freight IS NOT NULL
  AND (freight !~ '^\d+(\.\d+)?$' OR freight::NUMERIC < 0);


-- ============================================================
-- 7. TXT_ORDER_DETAILS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_order_details', 'order_id+product_id', 'PK_COMPUESTA_SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PK compuesta sin duplicados' ELSE 'Hay combinaciones order_id+product_id duplicadas' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT order_id, product_id FROM public.txt_order_details
      GROUP BY order_id, product_id HAVING COUNT(*) > 1) d;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_order_details', 'discount', 'RANGO_0_A_1',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'WARNING' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los descuentos están entre 0 y 1' ELSE 'Hay descuentos fuera del rango 0-1' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_order_details
WHERE discount IS NOT NULL
  AND (discount !~ '^\d+(\.\d+)?$' OR discount::NUMERIC < 0 OR discount::NUMERIC > 1);

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_order_details', 'quantity', 'ENTERO_POSITIVO',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todas las cantidades son enteros positivos' ELSE 'Hay cantidades inválidas' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_order_details
WHERE quantity !~ '^\d+$' OR quantity::INTEGER <= 0;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_order_details', 'unit_price', 'ES_NUMERICO_POSITIVO',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los precios son numéricos y >= 0' ELSE 'Hay valores inválidos en unit_price' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_order_details
WHERE unit_price IS NOT NULL
  AND (unit_price !~ '^\d+(\.\d+)?$' OR unit_price::NUMERIC < 0);


-- ============================================================
-- 8. TXT_SUPPLIERS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_suppliers', 'supplier_id', 'NOT NULL + SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PK válida' ELSE 'PK inválida en txt_suppliers' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT supplier_id FROM public.txt_suppliers WHERE supplier_id IS NULL OR supplier_id = ''
      UNION ALL
      SELECT supplier_id FROM public.txt_suppliers GROUP BY supplier_id HAVING COUNT(*) > 1) d;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_suppliers', 'company_name', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros sin company_name' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_suppliers WHERE company_name IS NULL OR company_name = '';


-- ============================================================
-- 9. TXT_SHIPPERS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_shippers', 'shipper_id', 'NOT NULL + SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PK válida' ELSE 'PK inválida en txt_shippers' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT shipper_id FROM public.txt_shippers WHERE shipper_id IS NULL OR shipper_id = ''
      UNION ALL
      SELECT shipper_id FROM public.txt_shippers GROUP BY shipper_id HAVING COUNT(*) > 1) d;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_shippers', 'company_name', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros sin company_name' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_shippers WHERE company_name IS NULL OR company_name = '';


-- ============================================================
-- 10. TXT_REGIONS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_regions', 'region_id', 'NOT NULL + SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PK válida' ELSE 'PK inválida en txt_regions' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT region_id FROM public.txt_regions WHERE region_id IS NULL OR region_id = ''
      UNION ALL
      SELECT region_id FROM public.txt_regions GROUP BY region_id HAVING COUNT(*) > 1) d;

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_regions', 'region_description', 'NOT NULL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin nulos' ELSE 'Hay registros sin region_description' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_regions WHERE region_description IS NULL OR region_description = '';


-- ============================================================
-- 11. TXT_TERRITORIES
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_territories', 'territory_id', 'NOT NULL + SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PK válida' ELSE 'PK inválida en txt_territories' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT territory_id FROM public.txt_territories WHERE territory_id IS NULL OR territory_id = ''
      UNION ALL
      SELECT territory_id FROM public.txt_territories GROUP BY territory_id HAVING COUNT(*) > 1) d;

-- En TXT_ todo es TEXT: se valida compatibilidad de tipo, no el tipo en sí
INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_territories', 'region_id', 'CASTEABLE_A_ENTERO',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los valores son casteables a INTEGER'
         ELSE 'Hay valores no casteables a INTEGER en region_id' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_territories
WHERE region_id IS NOT NULL
  AND region_id <> 'NULL'
  AND TRIM(region_id) !~ '^\d+$';


-- ============================================================
-- 12. TXT_EMPLOYEE_TERRITORIES
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_employee_territories', 'employee_id+territory_id', 'PK_COMPUESTA_SIN_DUPLICADOS',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PK compuesta válida' ELSE 'Hay combinaciones duplicadas' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM (SELECT employee_id, territory_id FROM public.txt_employee_territories
      GROUP BY employee_id, territory_id HAVING COUNT(*) > 1) d;

-- En TXT_ todo es TEXT: se valida compatibilidad de tipo, no el tipo en sí
INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_employee_territories', 'employee_id', 'CASTEABLE_A_ENTERO',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los valores son casteables a INTEGER'
         ELSE 'Hay valores no casteables a INTEGER en employee_id' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employee_territories
WHERE employee_id IS NOT NULL
  AND employee_id <> 'NULL'
  AND TRIM(employee_id) !~ '^\d+$';


-- ============================================================
-- 13. CIERRE DE LOG
-- ============================================================

UPDATE public.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = CASE
        WHEN EXISTS (SELECT 1 FROM public.dqm_validacion_campo WHERE resultado = 'ERROR')   THEN 'ERROR'
        WHEN EXISTS (SELECT 1 FROM public.dqm_validacion_campo WHERE resultado = 'WARNING') THEN 'WARNING'
        ELSE 'OK'
    END,
    detalle = 'Validaciones completadas. Errores: ' ||
        (SELECT COUNT(*) FROM public.dqm_validacion_campo WHERE resultado = 'ERROR') ||
        ' | Warnings: ' ||
        (SELECT COUNT(*) FROM public.dqm_validacion_campo WHERE resultado = 'WARNING'),
    registros_proc = (SELECT COUNT(*) FROM public.dqm_validacion_campo)
WHERE script_id = (
    SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '03_validacion_txt'
)
AND resultado = 'EN_PROCESO';


-- ============================================================
-- 14. CONSULTA DE RESULTADOS
-- ============================================================

SELECT tabla, campo, control, resultado, cant_errores, detalle
FROM public.dqm_validacion_campo
ORDER BY tabla, campo, control;
