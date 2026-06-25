-- ============================================================
-- SCRIPT: 20_migracion_txt2_a_tmp2
-- Descripcion: Convierte TXT2 crudo a TMP2 tipado.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.
--
-- Correccion aplicada:
-- Se migran a TMP2 solamente los scores validos entre 1 y 5.
-- Los scores invalidos quedan registrados como rechazados en DQM
-- y no pasan a tmp2_customers_score.
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('20_migracion_txt2_a_tmp2', 'Migracion tipada desde TXT2 hacia TMP2', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES ((SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '20_migracion_txt2_a_tmp2'),
        NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires', 'EN_PROCESO', 'Iniciando migracion TXT2 a TMP2');

TRUNCATE data_warehouse.tmp2_order_details, data_warehouse.tmp2_orders, data_warehouse.tmp2_products,
         data_warehouse.tmp2_customers, data_warehouse.tmp2_customers_score, data_warehouse.tmp2_world_data_2023;

INSERT INTO data_warehouse.tmp2_customers
SELECT TRIM(customer_id)::CHAR(5), NULLIF(TRIM(company_name),''), NULLIF(TRIM(contact_name),''), NULLIF(TRIM(contact_title),''),
       NULLIF(TRIM(address),''), NULLIF(TRIM(city),''), NULLIF(NULLIF(TRIM(region),''),'NULL'), NULLIF(TRIM(postal_code),''),
       NULLIF(TRIM(country),''), NULLIF(TRIM(phone),''), NULLIF(TRIM(fax),'')
FROM data_warehouse.txt2_customers;

INSERT INTO data_warehouse.tmp2_orders
SELECT TRIM(order_id)::INT,
       TRIM(customer_id)::CHAR(5),
       NULLIF(TRIM(employee_id),'')::INT,
       SUBSTRING(TRIM(order_date) FROM 1 FOR 10)::DATE,
       NULLIF(SUBSTRING(TRIM(required_date) FROM 1 FOR 10),'')::DATE,
       NULLIF(NULLIF(SUBSTRING(TRIM(shipped_date) FROM 1 FOR 10),''),'NULL')::DATE,
       NULLIF(TRIM(ship_via),'')::INT,
       NULLIF(TRIM(freight),'')::NUMERIC(10,4),
       NULLIF(TRIM(ship_name),''), NULLIF(TRIM(ship_address),''), NULLIF(TRIM(ship_city),''),
       NULLIF(NULLIF(TRIM(ship_region),''),'NULL'), NULLIF(TRIM(ship_postal_code),''), NULLIF(TRIM(ship_country),'')
FROM data_warehouse.txt2_orders;

INSERT INTO data_warehouse.tmp2_order_details
SELECT TRIM(order_id)::INT, TRIM(product_id)::INT,
       TRIM(unit_price)::NUMERIC(10,4), TRIM(quantity)::INT, TRIM(discount)::NUMERIC(5,4)
FROM data_warehouse.txt2_order_details;

INSERT INTO data_warehouse.tmp2_products
SELECT TRIM(product_id)::INT, NULLIF(TRIM(product_name),''), NULLIF(TRIM(supplier_id),'')::INT,
       NULLIF(TRIM(category_id),'')::INT, NULLIF(TRIM(quantity_per_unit),''),
       NULLIF(TRIM(unit_price),'')::NUMERIC(10,4), NULLIF(TRIM(units_in_stock),'')::INT,
       NULLIF(TRIM(units_on_order),'')::INT, NULLIF(TRIM(reorder_level),'')::INT,
       TRIM(discontinued)::INT
FROM data_warehouse.txt2_products;

-- Rechazo de scores invalidos antes de migrar a TMP2.
INSERT INTO data_warehouse.dqm_registro_rechazado
    (log_id, tabla_origen, clave_registro, motivo_rechazo, decision)
SELECT
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '20_migracion_txt2_a_tmp2')),
    'txt2_customers_score',
    TRIM(customer_id),
    'Score invalido: valor ' || COALESCE(NULLIF(TRIM(score), ''), '<vacio>') || '. La regla de calidad exige score entre 1 y 5.',
    'RECHAZADO'
FROM data_warehouse.txt2_customers_score s
WHERE (
        TRIM(score) !~ '^[0-9]+$'
     OR CAST(TRIM(score) AS INT) NOT BETWEEN 1 AND 5
)
AND NOT EXISTS (
    SELECT 1
    FROM data_warehouse.dqm_registro_rechazado r
    WHERE r.tabla_origen = 'txt2_customers_score'
      AND r.clave_registro = TRIM(s.customer_id)
      AND r.motivo_rechazo LIKE 'Score invalido:%'
);

-- Migracion de customers_score: solo scores numericos validos entre 1 y 5.
INSERT INTO data_warehouse.tmp2_customers_score (customer_id, score)
SELECT TRIM(customer_id)::CHAR(5), TRIM(score)::INT
FROM data_warehouse.txt2_customers_score
WHERE TRIM(score) ~ '^[0-9]+$'
  AND CAST(TRIM(score) AS INT) BETWEEN 1 AND 5;

-- Limpieza de numeros de World Data: quita %, $, comas y espacios.
INSERT INTO data_warehouse.tmp2_world_data_2023
SELECT
    NULLIF(TRIM(country),''),
    NULLIF(REGEXP_REPLACE(density_p_km2, '[^0-9\.-]', '', 'g'),'')::NUMERIC(14,4),
    NULLIF(TRIM(abbreviation),''),
    NULLIF(REGEXP_REPLACE(agricultural_land_pct, '[^0-9\.-]', '', 'g'),'')::NUMERIC(10,4),
    NULLIF(REGEXP_REPLACE(land_area_km2, '[^0-9\.-]', '', 'g'),'')::NUMERIC(18,4),
    NULLIF(TRIM(capital_major_city),''),
    NULLIF(TRIM(currency_code),''),
    NULLIF(REGEXP_REPLACE(gdp, '[^0-9\.-]', '', 'g'),'')::NUMERIC(20,2),
    NULLIF(REGEXP_REPLACE(life_expectancy, '[^0-9\.-]', '', 'g'),'')::NUMERIC(10,4),
    NULLIF(REGEXP_REPLACE(population, '[^0-9\.-]', '', 'g'),'')::BIGINT,
    NULLIF(REGEXP_REPLACE(unemployment_rate, '[^0-9\.-]', '', 'g'),'')::NUMERIC(10,4),
    NULLIF(REGEXP_REPLACE(urban_population, '[^0-9\.-]', '', 'g'),'')::BIGINT,
    NULLIF(REGEXP_REPLACE(latitude, '[^0-9\.-]', '', 'g'),'')::NUMERIC(12,8),
    NULLIF(REGEXP_REPLACE(longitude, '[^0-9\.-]', '', 'g'),'')::NUMERIC(12,8)
FROM data_warehouse.txt2_world_data_2023;

UPDATE data_warehouse.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = 'OK',
    detalle = 'Migracion TXT2 a TMP2 completada. Se excluyeron scores invalidos del pasaje a TMP2.',
    registros_proc = (SELECT COUNT(*) FROM data_warehouse.tmp2_customers)
                  + (SELECT COUNT(*) FROM data_warehouse.tmp2_orders)
                  + (SELECT COUNT(*) FROM data_warehouse.tmp2_order_details)
                  + (SELECT COUNT(*) FROM data_warehouse.tmp2_products)
                  + (SELECT COUNT(*) FROM data_warehouse.tmp2_customers_score)
                  + (SELECT COUNT(*) FROM data_warehouse.tmp2_world_data_2023)
WHERE log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '20_migracion_txt2_a_tmp2'));
