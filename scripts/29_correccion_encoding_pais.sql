-- ============================================================
-- SCRIPT: 29_correccion_encoding_pais
-- Descripcion: Corrige caracteres corruptos (U+FFFD) en la columna
--              capital_major_city de dwa_dim_pais, originados por
--              una incompatibilidad de encoding en la importacion
--              del archivo world-data-2023.csv.
--              Propaga la corrección a todas las tablas dp_ que
--              replican esa columna.
--              Causa raíz: el CSV contenía caracteres UTF-8 multi-byte
--              (tildes y caracteres especiales) que fueron sustituidos
--              por el caracter de reemplazo Unicode (U+FFFD / chr(65533))
--              durante la importacion manual en DBeaver.
-- Tablas afectadas: dwa_dim_pais (11 filas)
--                   dp_ventas_geografico (11 filas)
--                   dp_ventas_por_cliente (clientes de esos 11 paises)
-- Etapa: Publicacion (correctivo post-ingesta)
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-25
-- ============================================================


-- ============================================================
-- 1. EXTENSIÓN DEL CHECK CONSTRAINT EN dqm_carga_dwa
--    El constraint dqm_carga_dwa_decision_check solo permite
--    'CARGADO', 'CARGADO_PARCIAL', 'RECHAZADO'.
--    Se extiende para incluir 'CORREGIDO' (correctivos post-ingesta).
-- ============================================================

DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    SELECT tc.constraint_name INTO v_constraint_name
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema    = 'data_warehouse'
      AND tc.table_name      = 'dqm_carga_dwa'
      AND tc.constraint_type = 'CHECK'
      AND tc.constraint_name ILIKE '%decision%';

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE data_warehouse.dqm_carga_dwa DROP CONSTRAINT ' || v_constraint_name;
    END IF;
END $$;

ALTER TABLE data_warehouse.dqm_carga_dwa
    ADD CONSTRAINT dqm_carga_dwa_decision_check
    CHECK (decision IN ('CARGADO','CARGADO_PARCIAL','RECHAZADO','CORREGIDO'));


-- ============================================================
-- 3. REGISTRO EN INVENTARIO DE SCRIPTS
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES (
    '29_correccion_encoding_pais',
    'Corrección de encoding (U+FFFD) en capital_major_city de dwa_dim_pais y tablas dp_ derivadas',
    'publicacion'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 4. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '29_correccion_encoding_pais'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Iniciando corrección de encoding en capital_major_city (11 paises afectados)'
);


-- ============================================================
-- 5. CORRECCIÓN EN dwa_dim_pais
--    11 filas con capital_major_city corrupta.
--    1 fila (São Tomé, sk_pais=151) con country_name también corrupto.
--    Causa: chr(65533) = U+FFFD sustituye caracteres UTF-8 especiales.
-- ============================================================

UPDATE data_warehouse.dwa_dim_pais
SET
    capital_major_city = CASE sk_pais
        WHEN  24 THEN 'Brasília'
        WHEN  32 THEN 'Yaoundé'
        WHEN  38 THEN 'Bogotá'
        WHEN  41 THEN 'San José'
        WHEN  77 THEN 'Reykjavík'
        WHEN 105 THEN 'Malé'
        WHEN 113 THEN 'Chișinău'
        WHEN 137 THEN 'Asunción'
        WHEN 151 THEN 'São Tomé'
        WHEN 176 THEN 'Lomé'
        WHEN 177 THEN 'Nuku''alofa'
    END,
    country_name = CASE sk_pais
        WHEN 151 THEN 'São Tomé and Príncipe'
        ELSE country_name
    END
WHERE sk_pais IN (24, 32, 38, 41, 77, 105, 113, 137, 151, 176, 177);

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '29_correccion_encoding_pais')),
    'dwa_dim_pais',
    11,
    11,
    0,
    'CORREGIDO',
    'Encoding U+FFFD en capital_major_city. São Tomé: también corregido country_name.'
);


-- ============================================================
-- 6. PROPAGACIÓN A dp_ventas_geografico
--    Actualiza capital_major_city y country_name desde dwa_dim_pais
--    para los 11 paises corregidos.
-- ============================================================

UPDATE data_warehouse.dp_ventas_geografico dvg
SET
    capital_major_city = p.capital_major_city,
    country_name       = p.country_name
FROM data_warehouse.dwa_dim_pais p
WHERE p.sk_pais = dvg.sk_pais
  AND dvg.sk_pais IN (24, 32, 38, 41, 77, 105, 113, 137, 151, 176, 177);

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '29_correccion_encoding_pais')),
    'dp_ventas_geografico',
    11,
    11,
    0,
    'CORREGIDO',
    'Propagación de capital_major_city y country_name corregidos desde dwa_dim_pais.'
);


-- ============================================================
-- 7. PROPAGACIÓN A dp_ventas_por_cliente
--    Actualiza capital_major_city y country_name_pais para los
--    clientes cuyo sk_pais corresponde a los 11 paises afectados.
-- ============================================================

UPDATE data_warehouse.dp_ventas_por_cliente dvc
SET
    capital_major_city = p.capital_major_city,
    country_name_pais  = p.country_name
FROM data_warehouse.dwa_dim_pais    p
JOIN data_warehouse.dwa_dim_cliente c ON c.sk_pais = p.sk_pais
WHERE c.sk_cliente = dvc.sk_cliente
  AND p.sk_pais IN (24, 32, 38, 41, 77, 105, 113, 137, 151, 176, 177);

INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES (
    (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '29_correccion_encoding_pais')),
    'dp_ventas_por_cliente',
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_cliente WHERE sk_pais IN (24, 32, 38, 41, 77, 105, 113, 137, 151, 176, 177)),
    (SELECT COUNT(*) FROM data_warehouse.dwa_dim_cliente WHERE sk_pais IN (24, 32, 38, 41, 77, 105, 113, 137, 151, 176, 177)),
    0,
    'CORREGIDO',
    'Propagación de capital_major_city y country_name_pais corregidos desde dwa_dim_pais.'
);


-- ============================================================
-- 8. VERIFICACION
-- ============================================================

SELECT sk_pais, country_name, capital_major_city
FROM data_warehouse.dwa_dim_pais
WHERE sk_pais IN (24, 32, 38, 41, 77, 105, 113, 137, 151, 176, 177)
ORDER BY country_name;


-- ============================================================
-- 9. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = 'OK',
    registros_proc = 11
                   + 11
                   + (SELECT COUNT(*) FROM data_warehouse.dwa_dim_cliente
                      WHERE sk_pais IN (24, 32, 38, 41, 77, 105, 113, 137, 151, 176, 177)),
    detalle        = 'Encoding corregido: 11 paises en dwa_dim_pais, 11 filas en dp_ventas_geografico, clientes afectados en dp_ventas_por_cliente. Causa: U+FFFD en importacion CSV world-data-2023.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '29_correccion_encoding_pais'
)
AND resultado = 'EN_PROCESO';
