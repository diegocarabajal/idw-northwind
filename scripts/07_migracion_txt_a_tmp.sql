-- ============================================================
-- SCRIPT: 07_migracion_txt_a_tmp
-- Descripción: Migra datos de todas las tablas TXT_ a TMP_,
--              aplicando casteo de tipos y limpieza de NULLs
--              textuales. Solo se ejecuta si las validaciones
--              sobre TXT_ resultaron OK.
-- Etapa: Adquisición
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-02
--
-- Decisiones:
--   - Los valores 'NULL' textuales se convierten a NULL real
--   - Las fechas vienen como 'YYYY-MM-DD HH:MM:SS.mmm', se castean a DATE
--   - country='MX' ya fue corregido a 'Mexico' en 05_limpieza_datos_txt
--   - El orden de inserción respeta dependencias de FK
-- ============================================================


-- ============================================================
-- 1. INVENTARIO Y LOG DE INICIO
-- ============================================================

INSERT INTO public.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('07_migracion_txt_a_tmp', 'Migración de TXT_ a TMP_ con casteo de tipos', 'adquisicion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO public.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '07_migracion_txt_a_tmp'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO', 'Iniciando migración TXT_ → TMP_'
);


-- ============================================================
-- 2. MIGRACIÓN POR TABLA (orden respeta FKs)
-- ============================================================

-- ------------------------------------------------------------
-- TMP_REGIONS
-- ------------------------------------------------------------
INSERT INTO public.tmp_regions (region_id, region_description)
SELECT
    region_id::INTEGER,
    NULLIF(TRIM(region_description), 'NULL')
FROM public.txt_regions;


-- ------------------------------------------------------------
-- TMP_TERRITORIES (FK → regions)
-- ------------------------------------------------------------
INSERT INTO public.tmp_territories (territory_id, territory_description, region_id)
SELECT
    territory_id,                               -- VARCHAR: preserva leading zeros (ej: 01581)
    NULLIF(TRIM(territory_description), 'NULL'),
    region_id::INTEGER
FROM public.txt_territories;


-- ------------------------------------------------------------
-- TMP_CATEGORIES
-- ------------------------------------------------------------
INSERT INTO public.tmp_categories (category_id, category_name, description, picture)
SELECT
    category_id::INTEGER,
    NULLIF(TRIM(category_name), 'NULL'),
    NULLIF(TRIM(description), 'NULL'),
    NULLIF(TRIM(picture), 'NULL')   -- dato binario hex, no se llevará al DWA
FROM public.txt_categories;


-- ------------------------------------------------------------
-- TMP_CUSTOMERS
-- ------------------------------------------------------------
INSERT INTO public.tmp_customers (
    customer_id, company_name, contact_name, contact_title,
    address, city, region, postal_code, country, phone, fax
)
SELECT
    customer_id,
    NULLIF(TRIM(company_name), 'NULL'),
    NULLIF(TRIM(contact_name), 'NULL'),
    NULLIF(TRIM(contact_title), 'NULL'),
    NULLIF(TRIM(address), 'NULL'),
    NULLIF(TRIM(city), 'NULL'),
    NULLIF(TRIM(region), 'NULL'),
    NULLIF(TRIM(postal_code), 'NULL'),
    NULLIF(TRIM(country), 'NULL'),
    NULLIF(TRIM(phone), 'NULL'),
    NULLIF(TRIM(fax), 'NULL')
FROM public.txt_customers;


-- ------------------------------------------------------------
-- TMP_SUPPLIERS
-- ------------------------------------------------------------
INSERT INTO public.tmp_suppliers (
    supplier_id, company_name, contact_name, contact_title,
    address, city, region, postal_code, country,
    phone, fax, homepage
)
SELECT
    supplier_id::INTEGER,
    NULLIF(TRIM(company_name), 'NULL'),
    NULLIF(TRIM(contact_name), 'NULL'),
    NULLIF(TRIM(contact_title), 'NULL'),
    NULLIF(TRIM(address), 'NULL'),
    NULLIF(TRIM(city), 'NULL'),
    NULLIF(TRIM(region), 'NULL'),
    NULLIF(TRIM(postal_code), 'NULL'),
    NULLIF(TRIM(country), 'NULL'),
    NULLIF(TRIM(phone), 'NULL'),
    NULLIF(TRIM(fax), 'NULL'),
    NULLIF(TRIM(homepage), 'NULL')
FROM public.txt_suppliers;


-- ------------------------------------------------------------
-- TMP_SHIPPERS
-- ------------------------------------------------------------
INSERT INTO public.tmp_shippers (shipper_id, company_name, phone)
SELECT
    shipper_id::INTEGER,
    NULLIF(TRIM(company_name), 'NULL'),
    NULLIF(TRIM(phone), 'NULL')
FROM public.txt_shippers;


-- ------------------------------------------------------------
-- TMP_EMPLOYEES (FK auto-referencial: reports_to)
-- ------------------------------------------------------------
INSERT INTO public.tmp_employees (
    employee_id, last_name, first_name, title, title_of_courtesy,
    birth_date, hire_date, address, city, region, postal_code,
    country, home_phone, extension, photo, notes, reports_to,
    photo_path
)
SELECT
    employee_id::INTEGER,
    NULLIF(TRIM(last_name), 'NULL'),
    NULLIF(TRIM(first_name), 'NULL'),
    NULLIF(TRIM(title), 'NULL'),
    NULLIF(TRIM(title_of_courtesy), 'NULL'),
    NULLIF(TRIM(birth_date), 'NULL')::DATE,
    NULLIF(TRIM(hire_date), 'NULL')::DATE,
    NULLIF(TRIM(address), 'NULL'),
    NULLIF(TRIM(city), 'NULL'),
    NULLIF(TRIM(region), 'NULL'),
    NULLIF(TRIM(postal_code), 'NULL'),
    NULLIF(TRIM(country), 'NULL'),
    NULLIF(TRIM(home_phone), 'NULL'),
    NULLIF(TRIM(extension), 'NULL'),
    NULLIF(TRIM(photo), 'NULL'),   -- dato binario hex, no se llevará al DWA
    NULLIF(TRIM(notes), 'NULL'),
    NULLIF(TRIM(reports_to), 'NULL')::INTEGER,  -- NULL para el jefe máximo (Andrew Fuller)
    NULLIF(TRIM(photo_path), 'NULL')
FROM public.txt_employees;


-- ------------------------------------------------------------
-- TMP_EMPLOYEE_TERRITORIES (FK → employees, territories)
-- ------------------------------------------------------------
INSERT INTO public.tmp_employee_territories (employee_id, territory_id)
SELECT
    employee_id::INTEGER,
    territory_id
FROM public.txt_employee_territories;


-- ------------------------------------------------------------
-- TMP_PRODUCTS (FK → categories, suppliers)
-- ------------------------------------------------------------
INSERT INTO public.tmp_products (
    product_id, product_name, supplier_id, category_id,
    quantity_per_unit, unit_price, units_in_stock,
    units_on_order, reorder_level, discontinued
)
SELECT
    product_id::INTEGER,
    NULLIF(TRIM(product_name), 'NULL'),
    NULLIF(TRIM(supplier_id), 'NULL')::INTEGER,
    NULLIF(TRIM(category_id), 'NULL')::INTEGER,
    NULLIF(TRIM(quantity_per_unit), 'NULL'),
    NULLIF(TRIM(unit_price), 'NULL')::NUMERIC(10,2),
    NULLIF(TRIM(units_in_stock), 'NULL')::SMALLINT,
    NULLIF(TRIM(units_on_order), 'NULL')::SMALLINT,
    NULLIF(TRIM(reorder_level), 'NULL')::SMALLINT,
    NULLIF(TRIM(discontinued), 'NULL')::SMALLINT
FROM public.txt_products;


-- ------------------------------------------------------------
-- TMP_ORDERS (FK → customers, employees, shippers)
-- ------------------------------------------------------------
INSERT INTO public.tmp_orders (
    order_id, customer_id, employee_id, order_date,
    required_date, shipped_date, ship_via, freight,
    ship_name, ship_address, ship_city, ship_region,
    ship_postal_code, ship_country
)
SELECT
    order_id::INTEGER,
    NULLIF(TRIM(customer_id), 'NULL'),
    NULLIF(TRIM(employee_id), 'NULL')::INTEGER,
    NULLIF(TRIM(order_date), 'NULL')::DATE,
    NULLIF(TRIM(required_date), 'NULL')::DATE,
    NULLIF(TRIM(shipped_date), 'NULL')::DATE,   -- NULL válido: pedido aún no despachado
    NULLIF(TRIM(ship_via), 'NULL')::INTEGER,
    NULLIF(TRIM(freight), 'NULL')::NUMERIC(10,2),
    NULLIF(TRIM(ship_name), 'NULL'),
    NULLIF(TRIM(ship_address), 'NULL'),
    NULLIF(TRIM(ship_city), 'NULL'),
    NULLIF(TRIM(ship_region), 'NULL'),
    NULLIF(TRIM(ship_postal_code), 'NULL'),
    NULLIF(TRIM(ship_country), 'NULL')
FROM public.txt_orders;


-- ------------------------------------------------------------
-- TMP_ORDER_DETAILS (FK → orders, products)
-- ------------------------------------------------------------
INSERT INTO public.tmp_order_details (
    order_id, product_id, unit_price, quantity, discount
)
SELECT
    order_id::INTEGER,
    product_id::INTEGER,
    unit_price::NUMERIC(10,2),
    quantity::SMALLINT,
    discount::NUMERIC(4,2)
FROM public.txt_order_details;


-- ============================================================
-- 3. VERIFICACIÓN DE CONTEOS
-- ============================================================

SELECT 'tmp_regions'              AS tabla, COUNT(*) AS registros FROM public.tmp_regions
UNION ALL SELECT 'tmp_territories',          COUNT(*) FROM public.tmp_territories
UNION ALL SELECT 'tmp_categories',           COUNT(*) FROM public.tmp_categories
UNION ALL SELECT 'tmp_customers',            COUNT(*) FROM public.tmp_customers
UNION ALL SELECT 'tmp_suppliers',            COUNT(*) FROM public.tmp_suppliers
UNION ALL SELECT 'tmp_shippers',             COUNT(*) FROM public.tmp_shippers
UNION ALL SELECT 'tmp_employees',            COUNT(*) FROM public.tmp_employees
UNION ALL SELECT 'tmp_employee_territories', COUNT(*) FROM public.tmp_employee_territories
UNION ALL SELECT 'tmp_products',             COUNT(*) FROM public.tmp_products
UNION ALL SELECT 'tmp_orders',               COUNT(*) FROM public.tmp_orders
UNION ALL SELECT 'tmp_order_details',        COUNT(*) FROM public.tmp_order_details
ORDER BY tabla;


-- ============================================================
-- 4. CIERRE DE LOG
-- ============================================================

UPDATE public.dqm_execution_log
SET fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = 'OK',
    detalle        = 'Migración TXT_ → TMP_ completada. 11 tablas migradas con casteo de tipos.',
    registros_proc = (SELECT SUM(c) FROM (
        SELECT COUNT(*) c FROM public.tmp_regions
        UNION ALL SELECT COUNT(*) FROM public.tmp_territories
        UNION ALL SELECT COUNT(*) FROM public.tmp_categories
        UNION ALL SELECT COUNT(*) FROM public.tmp_customers
        UNION ALL SELECT COUNT(*) FROM public.tmp_suppliers
        UNION ALL SELECT COUNT(*) FROM public.tmp_shippers
        UNION ALL SELECT COUNT(*) FROM public.tmp_employees
        UNION ALL SELECT COUNT(*) FROM public.tmp_employee_territories
        UNION ALL SELECT COUNT(*) FROM public.tmp_products
        UNION ALL SELECT COUNT(*) FROM public.tmp_orders
        UNION ALL SELECT COUNT(*) FROM public.tmp_order_details
    ) t)
WHERE script_id = (
    SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '07_migracion_txt_a_tmp'
)
AND resultado = 'EN_PROCESO';