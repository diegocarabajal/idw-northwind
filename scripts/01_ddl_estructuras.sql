-- ============================================================
-- SCRIPT: 01_DDL_Estructuras
-- Descripción: Creación de tablas DQM, capa espejo TXT_ (TEXT)
--              y capa intermedia TMP_ (tipada según DER).
--              Carga del inventario de scripts del proceso.
-- Etapa: Adquisición
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-02
-- ============================================================


-- ============================================================
-- 1. INFRAESTRUCTURA DQM
--    Tablas de soporte para control de calidad, logging y
--    perfilado. Deben crearse antes que cualquier otro objeto.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.dqm_script_inventory (
    script_id     SERIAL PRIMARY KEY,
    script_nombre VARCHAR(100) UNIQUE NOT NULL,
    script_desc   TEXT,
    etapa         VARCHAR(50) NOT NULL,
    create_date   TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

CREATE TABLE IF NOT EXISTS public.dqm_execution_log (
    log_id        SERIAL PRIMARY KEY,
    script_id     INT REFERENCES public.dqm_script_inventory(script_id),
    fecha_inicio  TIMESTAMP NOT NULL DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    fecha_fin     TIMESTAMP,
    resultado     VARCHAR(20),    -- 'EN_PROCESO', 'OK', 'WARNING', 'ERROR'
    detalle       TEXT,
    registros_proc INT,
    create_date   TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

CREATE TABLE IF NOT EXISTS public.dqm_validacion_campo (
    validacion_id SERIAL PRIMARY KEY,
    tabla         VARCHAR(100) NOT NULL,
    campo         VARCHAR(100) NOT NULL,
    control       VARCHAR(100) NOT NULL,
    resultado     VARCHAR(20)  NOT NULL,  -- 'OK', 'WARNING', 'ERROR'
    cant_errores  INT NOT NULL,
    detalle       TEXT,
    fecha_control TIMESTAMP NOT NULL DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    create_date   TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

CREATE TABLE IF NOT EXISTS public.dqm_perfilado (
    perfilado_id    SERIAL PRIMARY KEY,
    tabla           VARCHAR(100) NOT NULL,
    campo           VARCHAR(100) NOT NULL,
    total_registros INT NOT NULL,
    cant_nulos      INT NOT NULL,
    cant_distintos  INT NOT NULL,
    valor_min       TEXT,
    valor_max       TEXT,
    fecha_perfilado TIMESTAMP NOT NULL DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    create_date     TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);


-- ============================================================
-- 2. INVENTARIO DE SCRIPTS
--    Catálogo estático de todos los scripts del proceso.
--    Se registran una sola vez; el log registra cada ejecución.
-- ============================================================

INSERT INTO public.dqm_script_inventory (script_id, script_nombre, script_desc, etapa)
VALUES
    (1, '01_ddl_estructuras', 'Creación de esquemas y tablas',   'adquisicion'),
    (2, '02_import_csv',      'Carga inicial de archivos CSV',   'adquisicion')
ON CONFLICT (script_id) DO NOTHING;


-- ============================================================
-- 3. INICIO DE LOG
--    Se registra antes de ejecutar cualquier DDL para capturar
--    el tiempo real de inicio.
-- ============================================================

INSERT INTO public.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    1,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Iniciando creación de estructuras DQM, TXT_ y TMP_'
);


-- ============================================================
-- 4. CAPA TXT_  — Espejo de los CSV, todos los campos TEXT
-- ============================================================

CREATE TABLE IF NOT EXISTS public.txt_categories          (category_id TEXT, category_name TEXT, description TEXT, picture TEXT);
CREATE TABLE IF NOT EXISTS public.txt_customers           (customer_id TEXT, company_name TEXT, contact_name TEXT, contact_title TEXT, address TEXT, city TEXT, region TEXT, postal_code TEXT, country TEXT, phone TEXT, fax TEXT);
CREATE TABLE IF NOT EXISTS public.txt_employees           (employee_id TEXT, last_name TEXT, first_name TEXT, title TEXT, title_of_courtesy TEXT, birth_date TEXT, hire_date TEXT, address TEXT, city TEXT, region TEXT, postal_code TEXT, country TEXT, home_phone TEXT, extension TEXT, photo TEXT, notes TEXT, reports_to TEXT, photo_path TEXT);
CREATE TABLE IF NOT EXISTS public.txt_products            (product_id TEXT, product_name TEXT, supplier_id TEXT, category_id TEXT, quantity_per_unit TEXT, unit_price TEXT, units_in_stock TEXT, units_on_order TEXT, reorder_level TEXT, discontinued TEXT);
CREATE TABLE IF NOT EXISTS public.txt_orders              (order_id TEXT, customer_id TEXT, employee_id TEXT, order_date TEXT, required_date TEXT, shipped_date TEXT, ship_via TEXT, freight TEXT, ship_name TEXT, ship_address TEXT, ship_city TEXT, ship_region TEXT, ship_postal_code TEXT, ship_country TEXT);
CREATE TABLE IF NOT EXISTS public.txt_order_details       (order_id TEXT, product_id TEXT, unit_price TEXT, quantity TEXT, discount TEXT);
CREATE TABLE IF NOT EXISTS public.txt_suppliers           (supplier_id TEXT, company_name TEXT, contact_name TEXT, contact_title TEXT, address TEXT, city TEXT, region TEXT, postal_code TEXT, country TEXT, phone TEXT, fax TEXT, homepage TEXT);
CREATE TABLE IF NOT EXISTS public.txt_shippers            (shipper_id TEXT, company_name TEXT, phone TEXT);
CREATE TABLE IF NOT EXISTS public.txt_regions             (region_id TEXT, region_description TEXT);
CREATE TABLE IF NOT EXISTS public.txt_territories         (territory_id TEXT, territory_description TEXT, region_id TEXT);
CREATE TABLE IF NOT EXISTS public.txt_employee_territories(employee_id TEXT, territory_id TEXT);


-- ============================================================
-- 5. CAPA TMP_  — Tipada según el DER Northwind
--    Incluye claves primarias y tipos de datos correctos.
--    Decisiones:
--      - territory_id: VARCHAR(50) para preservar leading zeros
--      - discontinued: INT (0=activo, 1=discontinuado)
--      - reports_to: INT nullable (NULL = jefe máximo)
--      - shipped_date: DATE nullable (pedido aún no despachado)
--      - picture/photo: TEXT, no se llevarán al DWA
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tmp_categories          (category_id INT PRIMARY KEY, category_name VARCHAR(100) NOT NULL, description TEXT, picture TEXT);
CREATE TABLE IF NOT EXISTS public.tmp_customers           (customer_id CHAR(5) PRIMARY KEY, company_name VARCHAR(100) NOT NULL, contact_name VARCHAR(100), contact_title VARCHAR(100), address VARCHAR(150), city VARCHAR(100), region VARCHAR(100), postal_code VARCHAR(50), country VARCHAR(100), phone VARCHAR(50), fax VARCHAR(50));
CREATE TABLE IF NOT EXISTS public.tmp_employees           (employee_id INT PRIMARY KEY, last_name VARCHAR(100) NOT NULL, first_name VARCHAR(100) NOT NULL, title VARCHAR(100), title_of_courtesy VARCHAR(50), birth_date DATE, hire_date DATE, address VARCHAR(150), city VARCHAR(100), region VARCHAR(100), postal_code VARCHAR(50), country VARCHAR(100), home_phone VARCHAR(50), extension VARCHAR(20), photo TEXT, notes TEXT, reports_to INT, photo_path VARCHAR(255));
CREATE TABLE IF NOT EXISTS public.tmp_products            (product_id INT PRIMARY KEY, product_name VARCHAR(100) NOT NULL, supplier_id INT, category_id INT, quantity_per_unit VARCHAR(100), unit_price NUMERIC(10,4), units_in_stock INT, units_on_order INT, reorder_level INT, discontinued INT NOT NULL);
CREATE TABLE IF NOT EXISTS public.tmp_orders              (order_id INT PRIMARY KEY, customer_id CHAR(5), employee_id INT, order_date DATE, required_date DATE, shipped_date DATE, ship_via INT, freight NUMERIC(10,4), ship_name VARCHAR(100), ship_address VARCHAR(150), ship_city VARCHAR(100), ship_region VARCHAR(100), ship_postal_code VARCHAR(50), ship_country VARCHAR(100));
CREATE TABLE IF NOT EXISTS public.tmp_order_details       (order_id INT, product_id INT, unit_price NUMERIC(10,4) NOT NULL, quantity INT NOT NULL, discount NUMERIC(5,4) NOT NULL, PRIMARY KEY (order_id, product_id));
CREATE TABLE IF NOT EXISTS public.tmp_suppliers           (supplier_id INT PRIMARY KEY, company_name VARCHAR(100) NOT NULL, contact_name VARCHAR(100), contact_title VARCHAR(100), address VARCHAR(150), city VARCHAR(100), region VARCHAR(100), postal_code VARCHAR(50), country VARCHAR(100), phone VARCHAR(50), fax VARCHAR(50), homepage TEXT);
CREATE TABLE IF NOT EXISTS public.tmp_shippers            (shipper_id INT PRIMARY KEY, company_name VARCHAR(100) NOT NULL, phone VARCHAR(50));
CREATE TABLE IF NOT EXISTS public.tmp_regions             (region_id INT PRIMARY KEY, region_description VARCHAR(100) NOT NULL);
CREATE TABLE IF NOT EXISTS public.tmp_territories         (territory_id VARCHAR(50) PRIMARY KEY, territory_description VARCHAR(100) NOT NULL, region_id INT);
CREATE TABLE IF NOT EXISTS public.tmp_employee_territories(employee_id INT, territory_id VARCHAR(50), PRIMARY KEY (employee_id, territory_id));

-- ============================================================
-- 6. CIERRE DE LOG
-- ============================================================

UPDATE public.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = 'OK',
    detalle   = 'Estructuras DQM, TXT_ y TMP_ generadas exitosamente.'
WHERE script_id = 1
AND resultado = 'EN_PROCESO';