-- ============================================================
-- SCRIPT: 08_integridad_referencial_tmp
-- Descripción: Valida la integridad referencial de las tablas
--              TMP_ verificando que todas las FKs apunten a
--              registros existentes en sus tablas padre.
--              Persiste resultados en dqm_validacion_campo.
-- Etapa: Adquisición
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-02
--
-- FKs validadas:
--   tmp_territories.region_id         → tmp_regions
--   tmp_products.supplier_id          → tmp_suppliers
--   tmp_products.category_id          → tmp_categories
--   tmp_orders.customer_id            → tmp_customers
--   tmp_orders.employee_id            → tmp_employees
--   tmp_orders.ship_via               → tmp_shippers
--   tmp_order_details.order_id        → tmp_orders
--   tmp_order_details.product_id      → tmp_products
--   tmp_employees.reports_to          → tmp_employees (auto-ref)
--   tmp_employee_territories.employee_id  → tmp_employees
--   tmp_employee_territories.territory_id → tmp_territories
-- ============================================================


-- ============================================================
-- 1. INVENTARIO Y LOG DE INICIO
-- ============================================================

INSERT INTO public.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('08_integridad_referencial_tmp', 'Validación de integridad referencial en tablas TMP_', 'adquisicion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO public.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '08_integridad_referencial_tmp'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO', 'Iniciando validación de integridad referencial en tablas TMP_'
);


-- ============================================================
-- 2. TMP_TERRITORIES → TMP_REGIONS
--    territory.region_id debe existir en regions
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_territories', 'region_id', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los region_id existen en tmp_regions'
         ELSE COUNT(*) || ' territory_id sin region_id válido: ' ||
              STRING_AGG(t.territory_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_territories t
WHERE t.region_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.tmp_regions r WHERE r.region_id = t.region_id);


-- ============================================================
-- 3. TMP_PRODUCTS → TMP_SUPPLIERS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_products', 'supplier_id', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los supplier_id existen en tmp_suppliers'
         ELSE COUNT(*) || ' productos con supplier_id inválido: ' ||
              STRING_AGG(p.product_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_products p
WHERE p.supplier_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.tmp_suppliers s WHERE s.supplier_id = p.supplier_id);


-- ============================================================
-- 4. TMP_PRODUCTS → TMP_CATEGORIES
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_products', 'category_id', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los category_id existen en tmp_categories'
         ELSE COUNT(*) || ' productos con category_id inválido: ' ||
              STRING_AGG(p.product_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_products p
WHERE p.category_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.tmp_categories c WHERE c.category_id = p.category_id);


-- ============================================================
-- 5. TMP_ORDERS → TMP_CUSTOMERS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_orders', 'customer_id', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los customer_id existen en tmp_customers'
         ELSE COUNT(*) || ' órdenes con customer_id inválido: ' ||
              STRING_AGG(o.order_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_orders o
WHERE o.customer_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.tmp_customers c WHERE c.customer_id = o.customer_id);


-- ============================================================
-- 6. TMP_ORDERS → TMP_EMPLOYEES
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_orders', 'employee_id', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los employee_id existen en tmp_employees'
         ELSE COUNT(*) || ' órdenes con employee_id inválido: ' ||
              STRING_AGG(o.order_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_orders o
WHERE o.employee_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.tmp_employees e WHERE e.employee_id = o.employee_id);


-- ============================================================
-- 7. TMP_ORDERS → TMP_SHIPPERS (ship_via)
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_orders', 'ship_via', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los ship_via existen en tmp_shippers'
         ELSE COUNT(*) || ' órdenes con ship_via inválido: ' ||
              STRING_AGG(o.order_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_orders o
WHERE o.ship_via IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.tmp_shippers s WHERE s.shipper_id = o.ship_via);


-- ============================================================
-- 8. TMP_ORDER_DETAILS → TMP_ORDERS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_order_details', 'order_id', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los order_id existen en tmp_orders'
         ELSE COUNT(*) || ' líneas con order_id inválido: ' ||
              STRING_AGG(DISTINCT od.order_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_order_details od
WHERE NOT EXISTS (SELECT 1 FROM public.tmp_orders o WHERE o.order_id = od.order_id);


-- ============================================================
-- 9. TMP_ORDER_DETAILS → TMP_PRODUCTS
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_order_details', 'product_id', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los product_id existen en tmp_products'
         ELSE COUNT(*) || ' líneas con product_id inválido: ' ||
              STRING_AGG(DISTINCT od.product_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_order_details od
WHERE NOT EXISTS (SELECT 1 FROM public.tmp_products p WHERE p.product_id = od.product_id);


-- ============================================================
-- 10. TMP_EMPLOYEES → TMP_EMPLOYEES (auto-referencial: reports_to)
--     NULL es válido: indica el jefe máximo (Andrew Fuller)
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_employees', 'reports_to', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los reports_to apuntan a un employee válido (NULL = jefe máximo)'
         ELSE COUNT(*) || ' empleados con reports_to inválido: ' ||
              STRING_AGG(e.employee_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_employees e
WHERE e.reports_to IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.tmp_employees e2 WHERE e2.employee_id = e.reports_to);


-- ============================================================
-- 11. TMP_EMPLOYEE_TERRITORIES → TMP_EMPLOYEES
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_employee_territories', 'employee_id', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los employee_id existen en tmp_employees'
         ELSE COUNT(*) || ' registros con employee_id inválido: ' ||
              STRING_AGG(et.employee_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_employee_territories et
WHERE NOT EXISTS (SELECT 1 FROM public.tmp_employees e WHERE e.employee_id = et.employee_id);


-- ============================================================
-- 12. TMP_EMPLOYEE_TERRITORIES → TMP_TERRITORIES
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'tmp_employee_territories', 'territory_id', 'INTEGRIDAD_REFERENCIAL',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Todos los territory_id existen en tmp_territories'
         ELSE COUNT(*) || ' registros con territory_id inválido: ' ||
              STRING_AGG(et.territory_id::TEXT, ', ') END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.tmp_employee_territories et
WHERE NOT EXISTS (SELECT 1 FROM public.tmp_territories t WHERE t.territory_id = et.territory_id);


-- ============================================================
-- 13. CIERRE DE LOG
-- ============================================================

UPDATE public.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = CASE
        WHEN EXISTS (SELECT 1 FROM public.dqm_validacion_campo
                     WHERE control = 'INTEGRIDAD_REFERENCIAL' AND resultado = 'ERROR')
        THEN 'ERROR' ELSE 'OK'
    END,
    detalle = 'Integridad referencial validada. Errores: ' ||
        (SELECT COUNT(*) FROM public.dqm_validacion_campo
         WHERE control = 'INTEGRIDAD_REFERENCIAL' AND resultado = 'ERROR'),
    registros_proc = (SELECT COUNT(*) FROM public.dqm_validacion_campo
                      WHERE control = 'INTEGRIDAD_REFERENCIAL')
WHERE script_id = (
    SELECT script_id FROM public.dqm_script_inventory
    WHERE script_nombre = '08_integridad_referencial_tmp'
)
AND resultado = 'EN_PROCESO';


-- ============================================================
-- 14. CONSULTA DE RESULTADOS
-- ============================================================

SELECT tabla, campo, control, resultado, cant_errores, detalle
FROM public.dqm_validacion_campo
WHERE control = 'INTEGRIDAD_REFERENCIAL'
ORDER BY tabla, campo;
