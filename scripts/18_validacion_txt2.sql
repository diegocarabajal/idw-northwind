-- ============================================================
-- SCRIPT: 18_validacion_txt2
-- Descripcion: Valida formatos basicos, nulos y duplicados en TXT2.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.


INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('18_validacion_txt2', 'Validaciones de formato, nulos y PK sobre TXT2', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES ((SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '18_validacion_txt2'),
        NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires', 'EN_PROCESO', 'Iniciando validaciones TXT2');

-- Limpio validaciones previas de este mismo script para que sea reejecutable.
DELETE FROM data_warehouse.dqm_validacion_campo
WHERE fecha_control >= CURRENT_DATE
  AND tabla LIKE 'txt2_%';

-- PK vacias / invalidas.
INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_customers','customer_id','PK no nula y largo 5',
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'customer_id debe venir informado y tener 5 caracteres'
FROM data_warehouse.txt2_customers
WHERE NULLIF(TRIM(customer_id),'') IS NULL OR LENGTH(TRIM(customer_id)) <> 5;

INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_orders','order_id','PK numerica no nula', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'order_id debe ser numerico'
FROM data_warehouse.txt2_orders
WHERE NULLIF(TRIM(order_id),'') IS NULL OR TRIM(order_id) !~ '^[0-9]+$';

INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_products','product_id','PK numerica no nula', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'product_id debe ser numerico'
FROM data_warehouse.txt2_products
WHERE NULLIF(TRIM(product_id),'') IS NULL OR TRIM(product_id) !~ '^[0-9]+$';

INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_order_details','order_id/product_id','PK compuesta numerica', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'order_id y product_id deben ser numericos'
FROM data_warehouse.txt2_order_details
WHERE TRIM(order_id) !~ '^[0-9]+$' OR TRIM(product_id) !~ '^[0-9]+$';

-- Duplicados de claves.
INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_orders','order_id','Duplicados de PK', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'No deberia haber order_id repetidos en novedades'
FROM (SELECT order_id FROM data_warehouse.txt2_orders GROUP BY order_id HAVING COUNT(*) > 1) d;

INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_order_details','order_id/product_id','Duplicados de PK compuesta', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'No deberia repetirse la combinacion order_id + product_id'
FROM (SELECT order_id, product_id FROM data_warehouse.txt2_order_details GROUP BY order_id, product_id HAVING COUNT(*) > 1) d;

-- Formatos numericos y rangos.
INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_order_details','quantity','Cantidad positiva', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'quantity debe ser entero mayor a cero'
FROM data_warehouse.txt2_order_details
WHERE TRIM(quantity) !~ '^[0-9]+$' OR TRIM(quantity)::INT <= 0;

INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_order_details','discount','Descuento entre 0 y 1', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'discount debe ser numerico entre 0 y 1'
FROM data_warehouse.txt2_order_details
WHERE TRIM(discount) !~ '^[0-9]+(\.[0-9]+)?$' OR TRIM(discount)::NUMERIC < 0 OR TRIM(discount)::NUMERIC > 1;

INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_products','discontinued','Flag 0/1', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'discontinued debe valer 0 o 1'
FROM data_warehouse.txt2_products
WHERE TRIM(discontinued) NOT IN ('0','1');

INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_customers_score','score','Score entre 1 y 5', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'score debe ser entero entre 1 y 5'
FROM data_warehouse.txt2_customers_score
WHERE TRIM(score) !~ '^[0-9]+$' OR TRIM(score)::INT NOT BETWEEN 1 AND 5;

-- Fechas: se acepta formato que empieza con YYYY-MM-DD.
INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_orders','order_date','Fecha valida', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'order_date debe comenzar con YYYY-MM-DD'
FROM data_warehouse.txt2_orders
WHERE NULLIF(TRIM(order_date),'') IS NULL OR TRIM(order_date) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}';

-- World data: pais obligatorio.
INSERT INTO data_warehouse.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle)
SELECT 'txt2_world_data_2023','country','Pais obligatorio', CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'ERROR' END,
       COUNT(*), 'country no puede venir vacio'
FROM data_warehouse.txt2_world_data_2023
WHERE NULLIF(TRIM(country),'') IS NULL;

UPDATE data_warehouse.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = CASE WHEN EXISTS (SELECT 1 FROM data_warehouse.dqm_validacion_campo WHERE tabla LIKE 'txt2_%' AND resultado = 'ERROR' AND fecha_control >= CURRENT_DATE)
                     THEN 'ERROR' ELSE 'OK' END,
    detalle = 'Validaciones TXT2 finalizadas. Revisar data_warehouse.dqm_validacion_campo.',
    registros_proc = (SELECT COUNT(*) FROM data_warehouse.dqm_validacion_campo WHERE tabla LIKE 'txt2_%' AND fecha_control >= CURRENT_DATE)
WHERE log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '18_validacion_txt2'));
