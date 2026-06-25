-- ============================================================
-- SCRIPT: 04_perfilado_txt
-- Descripción: Persiste los totales de control (perfilado) de
--              las 11 tablas TXT_ en dqm_perfilado. Por cada
--              tabla registra: total de registros, nulos en
--              campos clave, valores distintos y rango min/max
--              de campos relevantes para el análisis.
-- Etapa: Adquisición
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-02
-- ============================================================


-- ============================================================
-- 1. INVENTARIO Y LOG DE INICIO
-- ============================================================

INSERT INTO public.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('04_perfilado_txt', 'Perfilado estadístico (totales de control) de tablas TXT_', 'adquisicion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO public.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '04_perfilado_txt'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO', 'Iniciando perfilado de tablas TXT_'
);


-- ============================================================
-- 2. TXT_CATEGORIES
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_categories', 'category_id',
    (SELECT COUNT(*) FROM public.txt_categories),
    COUNT(*) FILTER (WHERE category_id IS NULL OR category_id = ''),
    COUNT(DISTINCT category_id), MIN(category_id), MAX(category_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_categories;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_categories', 'category_name',
    (SELECT COUNT(*) FROM public.txt_categories),
    COUNT(*) FILTER (WHERE category_name IS NULL OR category_name = ''),
    COUNT(DISTINCT category_name), MIN(category_name), MAX(category_name),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_categories;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_categories', 'description',
    (SELECT COUNT(*) FROM public.txt_categories),
    COUNT(*) FILTER (WHERE description IS NULL OR description = ''),
    COUNT(DISTINCT description), MIN(description), MAX(description),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_categories;


-- ============================================================
-- 3. TXT_CUSTOMERS
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_customers', 'customer_id',
    (SELECT COUNT(*) FROM public.txt_customers),
    COUNT(*) FILTER (WHERE customer_id IS NULL OR customer_id = ''),
    COUNT(DISTINCT customer_id), MIN(customer_id), MAX(customer_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_customers', 'country',
    (SELECT COUNT(*) FROM public.txt_customers),
    COUNT(*) FILTER (WHERE country IS NULL OR country = ''),
    COUNT(DISTINCT country), MIN(country), MAX(country),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_customers', 'city',
    (SELECT COUNT(*) FROM public.txt_customers),
    COUNT(*) FILTER (WHERE city IS NULL OR city = ''),
    COUNT(DISTINCT city), MIN(city), MAX(city),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_customers', 'region',
    (SELECT COUNT(*) FROM public.txt_customers),
    COUNT(*) FILTER (WHERE region IS NULL OR region = 'NULL' OR region = ''),
    COUNT(DISTINCT region), MIN(region), MAX(region),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers;


-- ============================================================
-- 4. TXT_EMPLOYEES
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_employees', 'employee_id',
    (SELECT COUNT(*) FROM public.txt_employees),
    COUNT(*) FILTER (WHERE employee_id IS NULL OR employee_id = ''),
    COUNT(DISTINCT employee_id), MIN(employee_id), MAX(employee_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employees;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_employees', 'birth_date',
    (SELECT COUNT(*) FROM public.txt_employees),
    COUNT(*) FILTER (WHERE birth_date IS NULL OR birth_date = 'NULL'),
    COUNT(DISTINCT birth_date), MIN(birth_date), MAX(birth_date),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employees;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_employees', 'hire_date',
    (SELECT COUNT(*) FROM public.txt_employees),
    COUNT(*) FILTER (WHERE hire_date IS NULL OR hire_date = 'NULL'),
    COUNT(DISTINCT hire_date), MIN(hire_date), MAX(hire_date),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employees;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_employees', 'reports_to',
    (SELECT COUNT(*) FROM public.txt_employees),
    COUNT(*) FILTER (WHERE reports_to IS NULL OR reports_to = 'NULL'),
    COUNT(DISTINCT reports_to), MIN(reports_to), MAX(reports_to),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employees;


-- ============================================================
-- 5. TXT_PRODUCTS
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_products', 'product_id',
    (SELECT COUNT(*) FROM public.txt_products),
    COUNT(*) FILTER (WHERE product_id IS NULL OR product_id = ''),
    COUNT(DISTINCT product_id), MIN(product_id), MAX(product_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_products;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_products', 'unit_price',
    (SELECT COUNT(*) FROM public.txt_products),
    COUNT(*) FILTER (WHERE unit_price IS NULL OR unit_price = ''),
    COUNT(DISTINCT unit_price), MIN(unit_price), MAX(unit_price),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_products;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_products', 'discontinued',
    (SELECT COUNT(*) FROM public.txt_products),
    COUNT(*) FILTER (WHERE discontinued IS NULL OR discontinued = ''),
    COUNT(DISTINCT discontinued), MIN(discontinued), MAX(discontinued),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_products;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_products', 'units_in_stock',
    (SELECT COUNT(*) FROM public.txt_products),
    COUNT(*) FILTER (WHERE units_in_stock IS NULL OR units_in_stock = ''),
    COUNT(DISTINCT units_in_stock), MIN(units_in_stock), MAX(units_in_stock),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_products;


-- ============================================================
-- 6. TXT_ORDERS
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_orders', 'order_id',
    (SELECT COUNT(*) FROM public.txt_orders),
    COUNT(*) FILTER (WHERE order_id IS NULL OR order_id = ''),
    COUNT(DISTINCT order_id), MIN(order_id), MAX(order_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_orders;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_orders', 'order_date',
    (SELECT COUNT(*) FROM public.txt_orders),
    COUNT(*) FILTER (WHERE order_date IS NULL OR order_date = ''),
    COUNT(DISTINCT order_date), MIN(order_date), MAX(order_date),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_orders;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_orders', 'shipped_date',
    (SELECT COUNT(*) FROM public.txt_orders),
    COUNT(*) FILTER (WHERE shipped_date IS NULL OR shipped_date = 'NULL'),
    COUNT(DISTINCT shipped_date), MIN(shipped_date), MAX(shipped_date),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_orders;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_orders', 'freight',
    (SELECT COUNT(*) FROM public.txt_orders),
    COUNT(*) FILTER (WHERE freight IS NULL OR freight = ''),
    COUNT(DISTINCT freight), MIN(freight), MAX(freight),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_orders;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_orders', 'ship_country',
    (SELECT COUNT(*) FROM public.txt_orders),
    COUNT(*) FILTER (WHERE ship_country IS NULL OR ship_country = ''),
    COUNT(DISTINCT ship_country), MIN(ship_country), MAX(ship_country),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_orders;


-- ============================================================
-- 7. TXT_ORDER_DETAILS
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_order_details', 'unit_price',
    (SELECT COUNT(*) FROM public.txt_order_details),
    COUNT(*) FILTER (WHERE unit_price IS NULL OR unit_price = ''),
    COUNT(DISTINCT unit_price), MIN(unit_price), MAX(unit_price),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_order_details;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_order_details', 'quantity',
    (SELECT COUNT(*) FROM public.txt_order_details),
    COUNT(*) FILTER (WHERE quantity IS NULL OR quantity = ''),
    COUNT(DISTINCT quantity), MIN(quantity), MAX(quantity),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_order_details;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_order_details', 'discount',
    (SELECT COUNT(*) FROM public.txt_order_details),
    COUNT(*) FILTER (WHERE discount IS NULL OR discount = ''),
    COUNT(DISTINCT discount), MIN(discount), MAX(discount),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_order_details;


-- ============================================================
-- 8. TXT_SUPPLIERS
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_suppliers', 'supplier_id',
    (SELECT COUNT(*) FROM public.txt_suppliers),
    COUNT(*) FILTER (WHERE supplier_id IS NULL OR supplier_id = ''),
    COUNT(DISTINCT supplier_id), MIN(supplier_id), MAX(supplier_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_suppliers;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_suppliers', 'country',
    (SELECT COUNT(*) FROM public.txt_suppliers),
    COUNT(*) FILTER (WHERE country IS NULL OR country = ''),
    COUNT(DISTINCT country), MIN(country), MAX(country),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_suppliers;


-- ============================================================
-- 9. TXT_SHIPPERS
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_shippers', 'shipper_id',
    (SELECT COUNT(*) FROM public.txt_shippers),
    COUNT(*) FILTER (WHERE shipper_id IS NULL OR shipper_id = ''),
    COUNT(DISTINCT shipper_id), MIN(shipper_id), MAX(shipper_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_shippers;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_shippers', 'company_name',
    (SELECT COUNT(*) FROM public.txt_shippers),
    COUNT(*) FILTER (WHERE company_name IS NULL OR company_name = ''),
    COUNT(DISTINCT company_name), MIN(company_name), MAX(company_name),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_shippers;


-- ============================================================
-- 10. TXT_REGIONS
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_regions', 'region_id',
    (SELECT COUNT(*) FROM public.txt_regions),
    COUNT(*) FILTER (WHERE region_id IS NULL OR region_id = ''),
    COUNT(DISTINCT region_id), MIN(region_id), MAX(region_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_regions;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_regions', 'region_description',
    (SELECT COUNT(*) FROM public.txt_regions),
    COUNT(*) FILTER (WHERE region_description IS NULL OR region_description = ''),
    COUNT(DISTINCT region_description), MIN(region_description), MAX(region_description),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_regions;


-- ============================================================
-- 11. TXT_TERRITORIES
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_territories', 'territory_id',
    (SELECT COUNT(*) FROM public.txt_territories),
    COUNT(*) FILTER (WHERE territory_id IS NULL OR territory_id = ''),
    COUNT(DISTINCT territory_id), MIN(territory_id), MAX(territory_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_territories;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_territories', 'region_id',
    (SELECT COUNT(*) FROM public.txt_territories),
    COUNT(*) FILTER (WHERE region_id IS NULL OR region_id = ''),
    COUNT(DISTINCT region_id), MIN(region_id), MAX(region_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_territories;


-- ============================================================
-- 12. TXT_EMPLOYEE_TERRITORIES
-- ============================================================

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_employee_territories', 'employee_id',
    (SELECT COUNT(*) FROM public.txt_employee_territories),
    COUNT(*) FILTER (WHERE employee_id IS NULL OR employee_id = ''),
    COUNT(DISTINCT employee_id), MIN(employee_id), MAX(employee_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employee_territories;

INSERT INTO public.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max, fecha_perfilado)
SELECT 'txt_employee_territories', 'territory_id',
    (SELECT COUNT(*) FROM public.txt_employee_territories),
    COUNT(*) FILTER (WHERE territory_id IS NULL OR territory_id = ''),
    COUNT(DISTINCT territory_id), MIN(territory_id), MAX(territory_id),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_employee_territories;


-- ============================================================
-- 13. CIERRE DE LOG
-- ============================================================

UPDATE public.dqm_execution_log
SET fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = 'OK',
    detalle        = 'Perfilado completado. 11 tablas TXT_ procesadas.',
    registros_proc = (SELECT COUNT(*) FROM public.dqm_perfilado
                      WHERE fecha_perfilado >= (
                          SELECT fecha_inicio FROM public.dqm_execution_log
                          WHERE script_id = (
                              SELECT script_id FROM public.dqm_script_inventory
                              WHERE script_nombre = '04_perfilado_txt'
                          )
                          AND resultado = 'EN_PROCESO'
                      ))
WHERE script_id = (
    SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '04_perfilado_txt'
)
AND resultado = 'EN_PROCESO';


-- ============================================================
-- 14. CONSULTA DE RESULTADOS
-- ============================================================

SELECT tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max
FROM public.dqm_perfilado
ORDER BY tabla, campo;