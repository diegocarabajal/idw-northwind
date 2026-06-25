-- ============================================================
-- SCRIPT: 25_actualizacion_metadata
-- Descripcion: Documenta en Metadata las extensiones de Etapa 3.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.


INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('25_actualizacion_metadata', 'Actualizacion de metadata por Ingesta2, paises y score', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES ((SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '25_actualizacion_metadata'),
        NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires', 'EN_PROCESO', 'Iniciando metadata Etapa 3');

-- Nota: en los scripts de Diego, met_dwa fue renombrada/documentada como met_entidades.
-- Si tu base mantiene el nombre met_dwa, reemplaza met_entidades por met_dwa en este script.

INSERT INTO data_warehouse.met_entidades
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
SELECT * FROM (VALUES
    -- TXT2 / TMP2 tablas de Ingesta2
    ('txt2_customers','customer_id','TEXT','Clave natural de cliente recibida en Ingesta2','txt',FALSE,FALSE,NULL,NULL,TRUE),
    ('tmp2_customers','customer_id','CHAR(5)','Clave natural tipada de cliente de Ingesta2','tmp',TRUE,FALSE,NULL,NULL,FALSE),
    ('txt2_orders','order_id','TEXT','Clave de orden recibida en Ingesta2','txt',FALSE,FALSE,NULL,NULL,TRUE),
    ('tmp2_orders','order_id','INT','Clave de orden tipada de Ingesta2','tmp',TRUE,FALSE,NULL,NULL,FALSE),
    ('txt2_order_details','order_id','TEXT','Clave de orden del detalle recibido en Ingesta2','txt',FALSE,FALSE,NULL,NULL,TRUE),
    ('tmp2_order_details','order_id','INT','Parte de PK compuesta de detalle de orden','tmp',TRUE,FALSE,NULL,NULL,FALSE),
    ('tmp2_order_details','product_id','INT','Parte de PK compuesta de detalle de orden','tmp',TRUE,FALSE,NULL,NULL,FALSE),
    ('txt2_products','product_id','TEXT','Clave de producto recibida en Ingesta2','txt',FALSE,FALSE,NULL,NULL,TRUE),
    ('tmp2_products','product_id','INT','Clave de producto tipada de Ingesta2','tmp',TRUE,FALSE,NULL,NULL,FALSE),
    ('tmp2_customers_score','customer_id','CHAR(5)','Cliente al que corresponde el score externo','tmp',TRUE,FALSE,NULL,NULL,FALSE),
    ('tmp2_customers_score','score','INT','Score externo del cliente entre 1 y 5','tmp',FALSE,FALSE,NULL,NULL,FALSE),
    ('tmp2_world_data_2023','country','VARCHAR(100)','Pais normalizado de World Data 2023','tmp',TRUE,FALSE,NULL,NULL,FALSE),
    -- dwa_dim_pais: todas las columnas
    ('dwa_dim_pais','sk_pais','SERIAL','Surrogate key de pais en DWA','dim',TRUE,FALSE,NULL,NULL,FALSE),
    ('dwa_dim_pais','country_name','VARCHAR(100)','Nombre de pais, clave natural unica para vincular clientes y proveedores','dim',FALSE,FALSE,NULL,NULL,FALSE),
    ('dwa_dim_pais','abbreviation','VARCHAR(10)','Codigo o abreviatura del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','capital_major_city','VARCHAR(100)','Capital o ciudad principal del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','currency_code','VARCHAR(10)','Codigo de moneda del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','population','BIGINT','Poblacion total del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','gdp','NUMERIC(20,2)','Producto Bruto Interno del pais en USD','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','life_expectancy','NUMERIC(10,4)','Expectativa de vida promedio en anos','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','unemployment_rate','NUMERIC(10,4)','Tasa de desempleo del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','urban_population','BIGINT','Poblacion urbana del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','latitude','NUMERIC(12,8)','Latitud geografica del centroide del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','longitude','NUMERIC(12,8)','Longitud geografica del centroide del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    -- columnas nuevas en dwa_dim_cliente y dwa_dim_producto
    ('dwa_dim_cliente','sk_pais','INT','FK al pais del cliente segun World Data 2023','dim',FALSE,TRUE,'dwa_dim_pais','sk_pais',TRUE),
    ('dwa_dim_cliente','customer_score','INT','Score externo del cliente entre 1 y 5','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_cliente','customer_score_segmento','VARCHAR(20)','Segmento derivado del score: ALTO, MEDIO, BAJO','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_producto','sk_pais_supplier','INT','FK al pais del proveedor segun World Data 2023','dim',FALSE,TRUE,'dwa_dim_pais','sk_pais',TRUE),
    -- dqm_registro_rechazado: todas las columnas
    ('dqm_registro_rechazado','rechazo_id','SERIAL','Surrogate key del registro rechazado','dqm',TRUE,FALSE,NULL,NULL,FALSE),
    ('dqm_registro_rechazado','log_id','INT','FK a la ejecucion del script que genero el rechazo','dqm',FALSE,TRUE,'dqm_execution_log','log_id',TRUE),
    ('dqm_registro_rechazado','tabla_origen','VARCHAR(100)','Tabla de la cual proviene el registro rechazado','dqm',FALSE,FALSE,NULL,NULL,FALSE),
    ('dqm_registro_rechazado','clave_registro','VARCHAR(200)','Identificador del registro rechazado (PK o NK)','dqm',FALSE,FALSE,NULL,NULL,TRUE),
    ('dqm_registro_rechazado','motivo_rechazo','TEXT','Explicacion de por que la fila no fue procesada','dqm',FALSE,FALSE,NULL,NULL,FALSE),
    ('dqm_registro_rechazado','decision','VARCHAR(30)','Resultado del rechazo: RECHAZADO o RECHAZADO_PARCIAL','dqm',FALSE,FALSE,NULL,NULL,FALSE),
    ('dqm_registro_rechazado','fecha_rechazo','TIMESTAMP','Fecha y hora del rechazo en zona horaria Argentina','dqm',FALSE,FALSE,NULL,NULL,FALSE)
) AS v(nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
WHERE NOT EXISTS (
    SELECT 1 FROM data_warehouse.met_entidades m
    WHERE m.nombre_tabla = v.nombre_tabla AND m.nombre_columna = v.nombre_columna
);

UPDATE data_warehouse.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = 'OK',
    detalle = 'Metadata de Etapa 3 actualizada: TXT2, TMP2, dwa_dim_pais (12 col), score y dqm_registro_rechazado (7 col).',
    registros_proc = 35
WHERE log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '25_actualizacion_metadata'));
