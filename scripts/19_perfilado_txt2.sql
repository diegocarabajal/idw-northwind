-- ============================================================
-- SCRIPT: 19_perfilado_txt2
-- Descripcion: Persiste perfilado basico de tablas TXT2 en DQM.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.


INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('19_perfilado_txt2', 'Perfilado de control de tablas TXT2 de Ingesta2', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES ((SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '19_perfilado_txt2'),
        NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires', 'EN_PROCESO', 'Iniciando perfilado TXT2');

-- Se perfilan campos clave y de negocio. No hace falta perfilar absolutamente todo.
INSERT INTO data_warehouse.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max)
SELECT 'txt2_customers','customer_id',COUNT(*),COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_id),'') IS NULL),COUNT(DISTINCT customer_id),MIN(customer_id),MAX(customer_id) FROM data_warehouse.txt2_customers;

INSERT INTO data_warehouse.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max)
SELECT 'txt2_orders','order_id',COUNT(*),COUNT(*) FILTER (WHERE NULLIF(TRIM(order_id),'') IS NULL),COUNT(DISTINCT order_id),MIN(order_id),MAX(order_id) FROM data_warehouse.txt2_orders;

INSERT INTO data_warehouse.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max)
SELECT 'txt2_orders','customer_id',COUNT(*),COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_id),'') IS NULL),COUNT(DISTINCT customer_id),MIN(customer_id),MAX(customer_id) FROM data_warehouse.txt2_orders;

INSERT INTO data_warehouse.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max)
SELECT 'txt2_order_details','order_id',COUNT(*),COUNT(*) FILTER (WHERE NULLIF(TRIM(order_id),'') IS NULL),COUNT(DISTINCT order_id),MIN(order_id),MAX(order_id) FROM data_warehouse.txt2_order_details;

INSERT INTO data_warehouse.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max)
SELECT 'txt2_products','product_id',COUNT(*),COUNT(*) FILTER (WHERE NULLIF(TRIM(product_id),'') IS NULL),COUNT(DISTINCT product_id),MIN(product_id),MAX(product_id) FROM data_warehouse.txt2_products;

INSERT INTO data_warehouse.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max)
SELECT 'txt2_customers_score','score',COUNT(*),COUNT(*) FILTER (WHERE NULLIF(TRIM(score),'') IS NULL),COUNT(DISTINCT score),MIN(score),MAX(score) FROM data_warehouse.txt2_customers_score;

INSERT INTO data_warehouse.dqm_perfilado (tabla, campo, total_registros, cant_nulos, cant_distintos, valor_min, valor_max)
SELECT 'txt2_world_data_2023','country',COUNT(*),COUNT(*) FILTER (WHERE NULLIF(TRIM(country),'') IS NULL),COUNT(DISTINCT country),MIN(country),MAX(country) FROM data_warehouse.txt2_world_data_2023;

UPDATE data_warehouse.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = 'OK',
    detalle = 'Perfilado TXT2 finalizado. Revisar data_warehouse.dqm_perfilado.',
    registros_proc = 7
WHERE log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '19_perfilado_txt2'));
