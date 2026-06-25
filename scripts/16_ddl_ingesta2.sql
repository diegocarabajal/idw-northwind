-- ============================================================
-- SCRIPT: 16_ddl_ingesta2
-- Descripcion: Crea tablas TXT2 y TMP2 para procesar Ingesta2.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.


INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('16_ddl_ingesta2', 'Creacion de estructuras TXT2/TMP2 para Ingesta2', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '16_ddl_ingesta2'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Iniciando creacion de tablas temporales de actualizacion'
);

-- Tabla auxiliar para registrar registros rechazados a nivel fila.
CREATE TABLE IF NOT EXISTS data_warehouse.dqm_registro_rechazado (
    rechazo_id      SERIAL PRIMARY KEY,
    log_id          INT REFERENCES data_warehouse.dqm_execution_log(log_id),
    tabla_origen    VARCHAR(100) NOT NULL,
    clave_registro  VARCHAR(200),
    motivo_rechazo  TEXT NOT NULL,
    decision        VARCHAR(30) NOT NULL DEFAULT 'RECHAZADO',
    fecha_rechazo   TIMESTAMP NOT NULL DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

-- ============================================================
-- TXT2: tablas crudas. Todo TEXT, como pide la etapa temporal.
-- ============================================================
CREATE TABLE IF NOT EXISTS data_warehouse.txt2_customers (
    customer_id TEXT, company_name TEXT, contact_name TEXT, contact_title TEXT,
    address TEXT, city TEXT, region TEXT, postal_code TEXT, country TEXT, phone TEXT, fax TEXT
);

CREATE TABLE IF NOT EXISTS data_warehouse.txt2_orders (
    order_id TEXT, customer_id TEXT, employee_id TEXT, order_date TEXT, required_date TEXT,
    shipped_date TEXT, ship_via TEXT, freight TEXT, ship_name TEXT, ship_address TEXT,
    ship_city TEXT, ship_region TEXT, ship_postal_code TEXT, ship_country TEXT
);

CREATE TABLE IF NOT EXISTS data_warehouse.txt2_order_details (
    order_id TEXT, product_id TEXT, unit_price TEXT, quantity TEXT, discount TEXT
);

CREATE TABLE IF NOT EXISTS data_warehouse.txt2_products (
    product_id TEXT, product_name TEXT, supplier_id TEXT, category_id TEXT,
    quantity_per_unit TEXT, unit_price TEXT, units_in_stock TEXT, units_on_order TEXT,
    reorder_level TEXT, discontinued TEXT
);

CREATE TABLE IF NOT EXISTS data_warehouse.txt2_customers_score (
    customer_id TEXT, score TEXT
);

-- World Data trae 35 columnas. Se crean con nombres SQL seguros.
CREATE TABLE IF NOT EXISTS data_warehouse.txt2_world_data_2023 (
    country TEXT,
    density_p_km2 TEXT,
    abbreviation TEXT,
    agricultural_land_pct TEXT,
    land_area_km2 TEXT,
    armed_forces_size TEXT,
    birth_rate TEXT,
    calling_code TEXT,
    capital_major_city TEXT,
    co2_emissions TEXT,
    cpi TEXT,
    cpi_change_pct TEXT,
    currency_code TEXT,
    fertility_rate TEXT,
    forested_area_pct TEXT,
    gasoline_price TEXT,
    gdp TEXT,
    gross_primary_education_enrollment_pct TEXT,
    gross_tertiary_education_enrollment_pct TEXT,
    infant_mortality TEXT,
    largest_city TEXT,
    life_expectancy TEXT,
    maternal_mortality_ratio TEXT,
    minimum_wage TEXT,
    official_language TEXT,
    out_of_pocket_health_expenditure TEXT,
    physicians_per_thousand TEXT,
    population TEXT,
    population_labor_force_participation_pct TEXT,
    tax_revenue_pct TEXT,
    total_tax_rate TEXT,
    unemployment_rate TEXT,
    urban_population TEXT,
    latitude TEXT,
    longitude TEXT
);

-- ============================================================
-- TMP2: tablas tipadas y con claves.
-- ============================================================
CREATE TABLE IF NOT EXISTS data_warehouse.tmp2_customers (
    customer_id CHAR(5) PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    contact_name VARCHAR(100),
    contact_title VARCHAR(100),
    address VARCHAR(150),
    city VARCHAR(100),
    region VARCHAR(100),
    postal_code VARCHAR(50),
    country VARCHAR(100),
    phone VARCHAR(50),
    fax VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS data_warehouse.tmp2_orders (
    order_id INT PRIMARY KEY,
    customer_id CHAR(5),
    employee_id INT,
    order_date DATE,
    required_date DATE,
    shipped_date DATE,
    ship_via INT,
    freight NUMERIC(10,4),
    ship_name VARCHAR(100),
    ship_address VARCHAR(150),
    ship_city VARCHAR(100),
    ship_region VARCHAR(100),
    ship_postal_code VARCHAR(50),
    ship_country VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS data_warehouse.tmp2_order_details (
    order_id INT,
    product_id INT,
    unit_price NUMERIC(10,4) NOT NULL,
    quantity INT NOT NULL,
    discount NUMERIC(5,4) NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE IF NOT EXISTS data_warehouse.tmp2_products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    supplier_id INT,
    category_id INT,
    quantity_per_unit VARCHAR(100),
    unit_price NUMERIC(10,4),
    units_in_stock INT,
    units_on_order INT,
    reorder_level INT,
    discontinued INT NOT NULL
);

CREATE TABLE IF NOT EXISTS data_warehouse.tmp2_customers_score (
    customer_id CHAR(5) PRIMARY KEY,
    score INT NOT NULL CHECK (score BETWEEN 1 AND 5)
);

CREATE TABLE IF NOT EXISTS data_warehouse.tmp2_world_data_2023 (
    country VARCHAR(100) PRIMARY KEY,
    density_p_km2 NUMERIC(14,4),
    abbreviation VARCHAR(10),
    agricultural_land_pct NUMERIC(10,4),
    land_area_km2 NUMERIC(18,4),
    capital_major_city VARCHAR(100),
    currency_code VARCHAR(10),
    gdp NUMERIC(20,2),
    life_expectancy NUMERIC(10,4),
    population BIGINT,
    unemployment_rate NUMERIC(10,4),
    urban_population BIGINT,
    latitude NUMERIC(12,8),
    longitude NUMERIC(12,8)
);

UPDATE data_warehouse.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = 'OK',
    detalle = 'Tablas TXT2, TMP2 y soporte de rechazos creados correctamente.',
    registros_proc = 12
WHERE log_id = (
    SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
    WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '16_ddl_ingesta2')
);
