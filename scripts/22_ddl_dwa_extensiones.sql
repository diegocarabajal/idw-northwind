-- ============================================================
-- SCRIPT: 22_ddl_dwa_extensiones
-- Descripcion: Extiende el DWA para paises y score de clientes.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.


INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('22_ddl_dwa_extensiones', 'Extension del DWA: dimension pais y score de cliente', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES ((SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '22_ddl_dwa_extensiones'),
        NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires', 'EN_PROCESO', 'Iniciando extension de modelo DWA');

CREATE TABLE IF NOT EXISTS data_warehouse.dwa_dim_pais (
    sk_pais SERIAL PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL UNIQUE,
    abbreviation VARCHAR(10),
    capital_major_city VARCHAR(100),
    currency_code VARCHAR(10),
    population BIGINT,
    gdp NUMERIC(20,2),
    life_expectancy NUMERIC(10,4),
    unemployment_rate NUMERIC(10,4),
    urban_population BIGINT,
    latitude NUMERIC(12,8),
    longitude NUMERIC(12,8)
);

ALTER TABLE data_warehouse.dwa_dim_cliente
    ADD COLUMN IF NOT EXISTS sk_pais INT REFERENCES data_warehouse.dwa_dim_pais(sk_pais),
    ADD COLUMN IF NOT EXISTS customer_score INT,
    ADD COLUMN IF NOT EXISTS customer_score_segmento VARCHAR(20);

ALTER TABLE data_warehouse.dwa_dim_producto
    ADD COLUMN IF NOT EXISTS sk_pais_supplier INT REFERENCES data_warehouse.dwa_dim_pais(sk_pais);

UPDATE data_warehouse.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = 'OK',
    detalle = 'Extension DWA creada: dwa_dim_pais, score en cliente y relacion pais proveedor.',
    registros_proc = 4
WHERE log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '22_ddl_dwa_extensiones'));
