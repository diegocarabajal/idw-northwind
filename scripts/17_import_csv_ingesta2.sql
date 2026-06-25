-- ============================================================
-- SCRIPT: 17_import_csv_ingesta2
-- Descripcion: Registro documental de la importacion CSV de Ingesta2.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.


-- Este script NO carga archivos desde disco porque en Supabase/DBeaver la
-- importacion local se hace con el asistente "Import Data".
-- Antes de ejecutar este script, importar manualmente:
--
-- 1) customers - novedades.csv      -> data_warehouse.txt2_customers          separador coma
-- 2) orders - novedades.csv         -> data_warehouse.txt2_orders             separador coma
-- 3) order_details - novedades.csv  -> data_warehouse.txt2_order_details      separador coma
-- 4) products - novedades.csv       -> data_warehouse.txt2_products           separador coma
-- 5) customers_score.csv            -> data_warehouse.txt2_customers_score    separador punto y coma (;)
-- 6) world-data-2023.csv            -> data_warehouse.txt2_world_data_2023    separador coma, comillas dobles
--
-- IMPORTANTE: si reimportas, primero vacia las tablas TXT2 para no duplicar.
-- TRUNCATE data_warehouse.txt2_customers, data_warehouse.txt2_orders,
--          data_warehouse.txt2_order_details, data_warehouse.txt2_products,
--          data_warehouse.txt2_customers_score, data_warehouse.txt2_world_data_2023;

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('17_import_csv_ingesta2', 'Registro de importacion manual de CSV Ingesta2 a TXT2', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log
    (script_id, fecha_inicio, fecha_fin, resultado, detalle, registros_proc)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '17_import_csv_ingesta2'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'OK',
    'CSV de Ingesta2 importados manualmente a TXT2. customers_score usa separador punto y coma.',
    (SELECT COUNT(*) FROM data_warehouse.txt2_customers)
    + (SELECT COUNT(*) FROM data_warehouse.txt2_orders)
    + (SELECT COUNT(*) FROM data_warehouse.txt2_order_details)
    + (SELECT COUNT(*) FROM data_warehouse.txt2_products)
    + (SELECT COUNT(*) FROM data_warehouse.txt2_customers_score)
    + (SELECT COUNT(*) FROM data_warehouse.txt2_world_data_2023)
);
