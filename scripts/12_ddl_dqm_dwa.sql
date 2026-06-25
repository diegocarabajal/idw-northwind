-- ============================================================
-- SCRIPT: 12_ddl_dqm_dwa
-- Descripción: Extensión del DQM para soportar los procesos
--              ejecutados sobre el DWA (Etapa 2 – Ingeniería).
--
--   Las tablas dqm_execution_log, dqm_perfilado y
--   dqm_validacion_campo ya existen desde la Etapa 1 y son
--   reutilizadas sin cambios para las validaciones del DWA.
--
--   Tablas nuevas:
--
--   dqm_carga_dwa   → registra cada operación de carga en una
--                     tabla DWA (dim, fact, dwm, enr). Permite
--                     saber cuántos registros se leyeron,
--                     insertaron y rechazaron, y cuál fue la
--                     decisión final (CARGADO / RECHAZADO /
--                     CARGADO_PARCIAL).
--
--   dqm_indicador   → persiste los indicadores de calidad con
--                     sus umbrales (warning / error) y el
--                     resultado de la evaluación para cada
--                     tabla procesada. Es la base para la
--                     decisión de aceptar o rechazar un dataset.
--
--   Relación entre tablas DQM:
--
--     dqm_script_inventory
--            ↓ (1:N)
--     dqm_execution_log
--            ↓ (1:N)              ↓ (1:N)
--     dqm_carga_dwa         dqm_indicador
--
--   Las tablas dqm_perfilado y dqm_validacion_campo también
--   referencian dqm_execution_log por convención de uso
--   (aunque no tienen FK formal para mantener flexibilidad).
--
-- Etapa: Ingeniería
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-16
-- ============================================================


-- ============================================================
-- 1. REGISTRO EN INVENTARIO
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES (
    '12_ddl_dqm_dwa',
    'Extensión del DQM para el DWA: tablas dqm_carga_dwa y dqm_indicador',
    'ingenieria'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 2. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log
    (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '12_ddl_dqm_dwa'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Creando tablas dqm_carga_dwa y dqm_indicador'
);


-- ============================================================
-- 3. dqm_carga_dwa
--    Registra cada operación de carga sobre una tabla DWA.
--    Una fila por tabla de destino por ejecución de script.
--
--    decisión posibles:
--      CARGADO         → todos los registros válidos se insertaron
--      CARGADO_PARCIAL → se insertó un subconjunto (supera umbral mínimo)
--      RECHAZADO       → no se cargó nada (no superó el umbral mínimo)
-- ============================================================

CREATE TABLE IF NOT EXISTS data_warehouse.dqm_carga_dwa (
    carga_id            SERIAL       PRIMARY KEY,
    log_id              INT          NOT NULL
                                     REFERENCES data_warehouse.dqm_execution_log(log_id),
    tabla_destino       VARCHAR(100) NOT NULL,   -- ej: 'dwa_dim_cliente'
    registros_leidos    INT          NOT NULL DEFAULT 0,
    registros_insertados INT         NOT NULL DEFAULT 0,
    registros_rechazados INT         NOT NULL DEFAULT 0,
    decision            VARCHAR(20)  NOT NULL
                                     CHECK (decision IN ('CARGADO','CARGADO_PARCIAL','RECHAZADO')),
    motivo_rechazo      TEXT,                    -- NULL si decisión = CARGADO
    fecha_carga         TIMESTAMP    NOT NULL
                                     DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

COMMENT ON TABLE data_warehouse.dqm_carga_dwa IS
    'Huella de cada operación de carga en una tabla DWA. Una fila por tabla de destino por ejecución. '
    'Complementa dqm_execution_log (nivel script) con detalle a nivel tabla. '
    'Decisiones: CARGADO = carga total, CARGADO_PARCIAL = subconjunto válido, RECHAZADO = no se cargó.';

COMMENT ON COLUMN data_warehouse.dqm_carga_dwa.registros_rechazados IS
    'Registros descartados por no superar validaciones previas a la carga (nulos en PK, FK inválidas, etc.)';

COMMENT ON COLUMN data_warehouse.dqm_carga_dwa.motivo_rechazo IS
    'Descripción del motivo cuando decision = RECHAZADO o CARGADO_PARCIAL. NULL si carga total exitosa.';


-- ============================================================
-- 4. dqm_indicador
--    Persiste los indicadores de calidad evaluados antes de
--    cada carga al DWA. Incluye el valor calculado, los
--    umbrales definidos y el resultado de la comparación.
--
--    Lógica de evaluación:
--      valor_calculado <= umbral_warning           → resultado = 'OK'
--      umbral_warning < valor_calculado <= umbral_error → resultado = 'WARNING'
--      valor_calculado > umbral_error              → resultado = 'ERROR'
--
--    Ejemplos de indicadores:
--      indicador           tabla              valor_calc  umb_warn  umb_error
--      PCT_NULOS           dwa_dim_cliente    2.5         5.0       10.0
--      PCT_FK_INVALIDAS    dwa_fact_ventas    0.0         1.0        5.0
--      PCT_DUPLICADOS_PK   dwa_dim_producto   0.0         0.0        0.1
--      PCT_PRECIOS_CERO    dwa_fact_ventas    1.2         2.0        5.0
--      PCT_OUTLIERS_MONTO  dwa_fact_ventas    3.1         5.0       10.0
-- ============================================================

CREATE TABLE IF NOT EXISTS data_warehouse.dqm_indicador (
    indicador_id      SERIAL        PRIMARY KEY,
    log_id            INT           NOT NULL
                                    REFERENCES data_warehouse.dqm_execution_log(log_id),
    tabla             VARCHAR(100)  NOT NULL,
    campo             VARCHAR(100),               -- NULL si el indicador aplica a la tabla completa
    indicador         VARCHAR(100)  NOT NULL,     -- nombre del indicador (ej: 'PCT_NULOS')
    descripcion       TEXT,
    valor_calculado   NUMERIC(10,4) NOT NULL,
    umbral_warning    NUMERIC(10,4) NOT NULL,     -- superar esto genera WARNING
    umbral_error      NUMERIC(10,4) NOT NULL,     -- superar esto genera ERROR y bloquea la carga
    resultado         VARCHAR(20)   NOT NULL
                                    CHECK (resultado IN ('OK','WARNING','ERROR')),
    fecha_control     TIMESTAMP     NOT NULL
                                    DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    CONSTRAINT chk_umbrales CHECK (umbral_warning <= umbral_error)
);

COMMENT ON TABLE data_warehouse.dqm_indicador IS
    'Indicadores de calidad evaluados antes de cada carga al DWA. '
    'Cada fila representa un control aplicado a una tabla (y opcionalmente a un campo específico). '
    'resultado = ERROR bloquea la carga de esa tabla. resultado = WARNING permite carga con advertencia. '
    'Los umbrales son definidos por el equipo en el script de carga correspondiente.';

COMMENT ON COLUMN data_warehouse.dqm_indicador.campo IS
    'NULL cuando el indicador aplica a la tabla entera (ej: PCT_FK_INVALIDAS, PCT_DUPLICADOS_PK). '
    'Nombre del campo cuando aplica a una columna específica (ej: PCT_NULOS para precio_unitario).';

COMMENT ON COLUMN data_warehouse.dqm_indicador.valor_calculado IS
    'El valor medido del indicador. Para porcentajes: entre 0 y 100.';


-- ============================================================
-- 5. DOCUMENTACIÓN EN met_entidades
-- ============================================================

-- dqm_carga_dwa
INSERT INTO data_warehouse.met_entidades
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dqm_carga_dwa', 'carga_id',             'SERIAL',       'PK: identificador único autoincremental de la operación de carga',               'dqm', TRUE,  FALSE, NULL,                   NULL,     FALSE),
    ('dqm_carga_dwa', 'log_id',               'INT',          'FK → dqm_execution_log: ejecución del script que originó esta carga',             'dqm', FALSE, TRUE,  'dqm_execution_log',    'log_id', FALSE),
    ('dqm_carga_dwa', 'tabla_destino',        'VARCHAR(100)', 'Nombre de la tabla DWA que fue cargada (ej: dwa_dim_cliente)',                    'dqm', FALSE, FALSE, NULL,                   NULL,     FALSE),
    ('dqm_carga_dwa', 'registros_leidos',     'INT',          'Total de registros leídos desde la tabla TMP de origen',                         'dqm', FALSE, FALSE, NULL,                   NULL,     FALSE),
    ('dqm_carga_dwa', 'registros_insertados', 'INT',          'Cantidad de registros efectivamente insertados en la tabla DWA',                  'dqm', FALSE, FALSE, NULL,                   NULL,     FALSE),
    ('dqm_carga_dwa', 'registros_rechazados', 'INT',          'Cantidad de registros descartados por no superar validaciones previas',           'dqm', FALSE, FALSE, NULL,                   NULL,     FALSE),
    ('dqm_carga_dwa', 'decision',             'VARCHAR(20)',  'Resultado de la operación: CARGADO, CARGADO_PARCIAL o RECHAZADO',                 'dqm', FALSE, FALSE, NULL,                   NULL,     FALSE),
    ('dqm_carga_dwa', 'motivo_rechazo',       'TEXT',         'Descripción del motivo de rechazo o carga parcial. NULL si carga total',         'dqm', FALSE, FALSE, NULL,                   NULL,     TRUE),
    ('dqm_carga_dwa', 'fecha_carga',          'TIMESTAMP',    'Fecha y hora de la operación de carga',                                          'dqm', FALSE, FALSE, NULL,                   NULL,     FALSE);

-- dqm_indicador
INSERT INTO data_warehouse.met_entidades
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dqm_indicador', 'indicador_id',    'SERIAL',        'PK: identificador único autoincremental del indicador',                             'dqm', TRUE,  FALSE, NULL,                'NULL',   FALSE),
    ('dqm_indicador', 'log_id',          'INT',           'FK → dqm_execution_log: ejecución del script que calculó este indicador',           'dqm', FALSE, TRUE,  'dqm_execution_log', 'log_id', FALSE),
    ('dqm_indicador', 'tabla',           'VARCHAR(100)',  'Tabla sobre la cual se evaluó el indicador',                                        'dqm', FALSE, FALSE, NULL,                NULL,     FALSE),
    ('dqm_indicador', 'campo',           'VARCHAR(100)',  'Campo evaluado. NULL si el indicador aplica a la tabla completa',                   'dqm', FALSE, FALSE, NULL,                NULL,     TRUE),
    ('dqm_indicador', 'indicador',       'VARCHAR(100)',  'Nombre del indicador (PCT_NULOS, PCT_FK_INVALIDAS, PCT_DUPLICADOS_PK, etc.)',        'dqm', FALSE, FALSE, NULL,                NULL,     FALSE),
    ('dqm_indicador', 'descripcion',     'TEXT',          'Descripción del indicador y qué mide',                                             'dqm', FALSE, FALSE, NULL,                NULL,     TRUE),
    ('dqm_indicador', 'valor_calculado', 'NUMERIC(10,4)', 'Valor medido del indicador. Para porcentajes: entre 0 y 100',                      'dqm', FALSE, FALSE, NULL,                NULL,     FALSE),
    ('dqm_indicador', 'umbral_warning',  'NUMERIC(10,4)', 'Umbral que al superarse genera WARNING (carga con advertencia)',                    'dqm', FALSE, FALSE, NULL,                NULL,     FALSE),
    ('dqm_indicador', 'umbral_error',    'NUMERIC(10,4)', 'Umbral que al superarse genera ERROR y bloquea la carga',                          'dqm', FALSE, FALSE, NULL,                NULL,     FALSE),
    ('dqm_indicador', 'resultado',       'VARCHAR(20)',   'Resultado de la evaluación: OK, WARNING o ERROR',                                   'dqm', FALSE, FALSE, NULL,                NULL,     FALSE),
    ('dqm_indicador', 'fecha_control',   'TIMESTAMP',     'Fecha y hora en que se evaluó el indicador',                                       'dqm', FALSE, FALSE, NULL,                NULL,     FALSE);


-- ============================================================
-- 6. VERIFICACIÓN
--    Vista del diseño DQM completo: tablas, propósito y capa.
-- ============================================================

SELECT
    nombre_tabla,
    COUNT(*)          AS columnas,
    SUM(es_pk::INT)   AS pks,
    SUM(es_fk::INT)   AS fks
FROM data_warehouse.met_entidades
WHERE capa_dwh = 'dqm'
GROUP BY nombre_tabla
ORDER BY nombre_tabla;


-- ============================================================
-- 7. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = 'OK',
    registros_proc = 2,
    detalle        = 'Tablas dqm_carga_dwa y dqm_indicador creadas y documentadas en met_entidades.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '12_ddl_dqm_dwa'
)
AND resultado = 'EN_PROCESO';
