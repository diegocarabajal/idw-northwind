-- ============================================================
-- SCRIPT: 11_ddl_dwa
-- Descripción: Creación del Modelo Dimensional del DWA.
--
--   Capas creadas:
--     dwa_  → Dimensiones (dim_) y tabla de Hechos (fact_)
--     dwm_  → Memoria institucional (SCD Type 2)
--     dwa_enr_ → Enriquecimiento (métricas y segmentos derivados)
--
--   Además:
--     - Renombra met_dwa → met_entidades (corrección de prefijo)
--     - Documenta todas las entidades nuevas en met_entidades
--
--   Decisiones de diseño:
--     - Grain de fact_ventas: 1 fila por línea de pedido (order_detail)
--     - categories y suppliers se colapsan dentro de dim_producto
--       (no tienen valor analítico propio separado del producto)
--     - regions y territories se colapsan en dim_empleado
--       (solo relevantes en contexto organizacional del empleado)
--     - Memoria solo para producto y cliente: son las entidades
--       que traen novedades en Ingesta2 y cuyos cambios afectan
--       el análisis histórico (precios, localización)
--     - Enriquecimiento: métricas agregadas + segmentos derivados
--       por cliente y por producto; se recalculan en cada carga
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
    '11_ddl_dwa',
    'Creación del modelo dimensional: DWA_, DWM_ y enriquecimiento.',
    'ingenieria'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 2. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log
    (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '11_ddl_dwa'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Iniciando creación de modelo dimensional: dwa_, dmm_ y enriquecimiento'
);


-- ============================================================
-- 3. CAPA dwa_ — DIMENSIONES
-- ============================================================

-- ------------------------------------------------------------
-- dwa_dim_tiempo
--   Dimensión generada (no viene del source): se construye a
--   partir del rango de fechas de los pedidos.
--   sk_tiempo: surrogate key (YYYYMMDD como INT para legibilidad)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_warehouse."dwa_dim_tiempo" (
    sk_tiempo        INT          PRIMARY KEY,  -- formato YYYYMMDD
    fecha            DATE         NOT NULL UNIQUE,
    anio             INT          NOT NULL,
    trimestre        INT          NOT NULL CHECK (trimestre BETWEEN 1 AND 4),
    mes              INT          NOT NULL CHECK (mes BETWEEN 1 AND 12),
    nombre_mes       VARCHAR(20)  NOT NULL,
    semana_anio      INT          NOT NULL,
    dia              INT          NOT NULL CHECK (dia BETWEEN 1 AND 31),
    dia_semana       INT          NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),  -- 1=lunes, 7=domingo
    nombre_dia       VARCHAR(20)  NOT NULL,
    es_fin_de_semana BOOLEAN      NOT NULL
);

COMMENT ON TABLE data_warehouse."dwa_dim_tiempo" IS
    'Dimensión temporal generada. Cubre todas las fechas del rango de pedidos de Northwind. SK = YYYYMMDD.';

-- ------------------------------------------------------------
-- dwa_dim_cliente
--   Solo atributos analíticamente relevantes.
--   Se excluyen: address, postal_code, phone, fax
--   (operativos, sin valor para análisis de ventas).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_warehouse."dwa_dim_cliente" (
    sk_cliente     SERIAL        PRIMARY KEY,
    nk_customer_id CHAR(5)       NOT NULL UNIQUE,  -- natural key del source
    company_name   VARCHAR(100)  NOT NULL,
    contact_name   VARCHAR(100),
    contact_title  VARCHAR(100),
    city           VARCHAR(100),
    region         VARCHAR(100),
    country        VARCHAR(100)
);

COMMENT ON TABLE data_warehouse."dwa_dim_cliente" IS
    'Dimensión cliente. nk_customer_id es el ID original de Northwind. Excluye campos operativos (address, phone, fax).';

-- ------------------------------------------------------------
-- dwa_dim_empleado
--   Incluye jerarquía de reporte (self-referencial).
--   Se colapsan territories/regions: solo relevantes como contexto
--   organizacional, sin valor analítico en ventas.
--   Se excluyen: address, photo, photo_path, extension.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_warehouse."dwa_dim_empleado" (
    sk_empleado      SERIAL        PRIMARY KEY,
    nk_employee_id   INT           NOT NULL UNIQUE,
    nombre_completo  VARCHAR(200)  NOT NULL,  -- derivado: first_name || ' ' || last_name
    title            VARCHAR(100),
    hire_date        DATE,
    city             VARCHAR(100),
    country          VARCHAR(100),
    reports_to_sk    INT           REFERENCES data_warehouse."dwa_dim_empleado"(sk_empleado)
                                   -- NULL = jefe máximo (sin supervisor)
);

COMMENT ON TABLE data_warehouse."dwa_dim_empleado" IS
    'Dimensión empleado con jerarquía de reporte. nombre_completo es campo derivado del source. reports_to_sk es auto-referencial; NULL indica el nivel más alto de la jerarquía.';

-- ------------------------------------------------------------
-- dwa_dim_producto
--   Dimensión desnormalizada: colapsa categories y suppliers.
--   Se incluye precio_lista como atributo descriptivo del producto
--   (precio vigente). El precio real de cada venta va en fact_ventas.
--   Se excluye: quantity_per_unit (operativo), picture.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_warehouse."dwa_dim_producto" (
    sk_producto          SERIAL        PRIMARY KEY,
    nk_product_id        INT           NOT NULL UNIQUE,
    product_name         VARCHAR(100)  NOT NULL,
    precio_lista         NUMERIC(10,4),           -- precio actual del catálogo
    discontinued         BOOLEAN       NOT NULL DEFAULT FALSE,
    -- atributos colapsados de categories:
    category_name        VARCHAR(100),
    category_description TEXT,
    -- atributos colapsados de suppliers:
    supplier_name        VARCHAR(100),
    supplier_country     VARCHAR(100)
);

COMMENT ON TABLE data_warehouse."dwa_dim_producto" IS
    'Dimensión producto desnormalizada. Incluye atributos de categories y suppliers para evitar JOINs en consultas analíticas. precio_lista refleja el precio vigente; el precio real de cada transacción está en dwa_fact_ventas.precio_unitario.';

-- ------------------------------------------------------------
-- dwa_dim_shipper
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_warehouse."dwa_dim_shipper" (
    sk_shipper     SERIAL        PRIMARY KEY,
    nk_shipper_id  INT           NOT NULL UNIQUE,
    company_name   VARCHAR(100)  NOT NULL,
    phone          VARCHAR(50)
);

COMMENT ON TABLE data_warehouse."dwa_dim_shipper" IS
    'Dimensión transportista. Representa el medio de despacho del pedido.';


-- ============================================================
-- 4. CAPA dwa_ — TABLA DE HECHOS
--
--   Grain: 1 fila por línea de pedido (order_id + product_id).
--   Dimensiones: tiempo, cliente, empleado, producto, shipper.
--   nk_order_id: dimensión degenerada — no tiene tabla de
--     dimensión propia pero permite trazar la línea al pedido.
--   Medidas atómicas: cantidad, precio_unitario, descuento, flete.
--   Medidas derivadas (calculadas en el ETL):
--     monto_bruto    = cantidad × precio_unitario
--     monto_descuento= monto_bruto × descuento
--     monto_neto     = monto_bruto − monto_descuento
--     flete_prorrateado = freight del pedido / cant. líneas
-- ============================================================

CREATE TABLE IF NOT EXISTS data_warehouse."dwa_fact_ventas" (
    -- claves de dimensión
    sk_tiempo          INT           NOT NULL REFERENCES data_warehouse."dwa_dim_tiempo"(sk_tiempo),
    sk_cliente         INT           REFERENCES data_warehouse."dwa_dim_cliente"(sk_cliente),
    sk_empleado        INT           REFERENCES data_warehouse."dwa_dim_empleado"(sk_empleado),
    sk_producto        INT           NOT NULL REFERENCES data_warehouse."dwa_dim_producto"(sk_producto),
    sk_shipper         INT           REFERENCES data_warehouse."dwa_dim_shipper"(sk_shipper),
    -- dimensión degenerada (sin tabla de dimensión propia)
    nk_order_id        INT           NOT NULL,
    -- medidas atómicas
    cantidad           INT           NOT NULL,
    precio_unitario    NUMERIC(10,4) NOT NULL,   -- precio pactado en la venta
    descuento          NUMERIC(5,4)  NOT NULL DEFAULT 0,
    flete_prorrateado  NUMERIC(10,4) NOT NULL DEFAULT 0,
    -- medidas derivadas (calculadas en el ETL de carga)
    monto_bruto        NUMERIC(12,4) NOT NULL,   -- cantidad × precio_unitario
    monto_descuento    NUMERIC(12,4) NOT NULL,   -- monto_bruto × descuento
    monto_neto         NUMERIC(12,4) NOT NULL,   -- monto_bruto − monto_descuento
    -- PK: grain natural de la tabla
    PRIMARY KEY (nk_order_id, sk_producto)
);

COMMENT ON TABLE data_warehouse."dwa_fact_ventas" IS
    'Tabla de hechos central. Grain: 1 fila por línea de pedido (order_detail). nk_order_id es dimensión degenerada. monto_neto = cantidad × precio_unitario × (1 - descuento). flete_prorrateado = freight del pedido / cantidad de líneas del pedido.';


-- ============================================================
-- 5. CAPA dwm_ — MEMORIA (SCD Type 2)
--
--   Registra el historial de cambios de atributos clave.
--   Patrón SCD2: cada cambio genera una fila nueva con
--   fecha_desde/fecha_hasta delimitando su vigencia.
--   La fila vigente tiene fecha_hasta = NULL y es_vigente = TRUE.
-- ============================================================

-- ------------------------------------------------------------
-- dwm_producto
--   Trackea cambios en precio y estado de descontinuación.
--   Justificación: Ingesta2 trae novedades de productos; el precio
--   al momento de la venta se preserva en fact_ventas.precio_unitario,
--   pero la memoria permite auditar la evolución del catálogo.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_warehouse."dwm_producto" (
    dwm_producto_id  SERIAL        PRIMARY KEY,
    nk_product_id    INT           NOT NULL,
    sk_producto      INT           REFERENCES data_warehouse."dwa_dim_producto"(sk_producto),
    product_name     VARCHAR(100)  NOT NULL,
    precio_lista     NUMERIC(10,4),
    discontinued     BOOLEAN       NOT NULL,
    -- control de vigencia
    fecha_desde      DATE          NOT NULL,
    fecha_hasta      DATE,                       -- NULL = registro vigente
    es_vigente       BOOLEAN       NOT NULL DEFAULT TRUE,
    fecha_registro   TIMESTAMP     DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    CONSTRAINT chk_dwm_prod_fechas CHECK (fecha_hasta IS NULL OR fecha_hasta >= fecha_desde)
);

COMMENT ON TABLE data_warehouse."dwm_producto" IS
    'Memoria SCD2 de productos. Registra el historial de cambios en precio_lista y discontinued. fecha_hasta NULL indica la versión vigente.';

-- ------------------------------------------------------------
-- dwm_cliente
--   Trackea cambios de localización (city, region, country).
--   Justificación: Ingesta2 trae novedades de clientes; los cambios
--   geográficos afectan análisis de ventas por región histórica.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_warehouse."dwm_cliente" (
    dwm_cliente_id  SERIAL        PRIMARY KEY,
    nk_customer_id  CHAR(5)       NOT NULL,
    sk_cliente      INT           REFERENCES data_warehouse."dwa_dim_cliente"(sk_cliente),
    company_name    VARCHAR(100)  NOT NULL,
    city            VARCHAR(100),
    region          VARCHAR(100),
    country         VARCHAR(100),
    -- control de vigencia
    fecha_desde     DATE          NOT NULL,
    fecha_hasta     DATE,                        -- NULL = registro vigente
    es_vigente      BOOLEAN       NOT NULL DEFAULT TRUE,
    fecha_registro  TIMESTAMP     DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    CONSTRAINT chk_dwm_cli_fechas CHECK (fecha_hasta IS NULL OR fecha_hasta >= fecha_desde)
);

COMMENT ON TABLE data_warehouse."dwm_cliente" IS
    'Memoria SCD2 de clientes. Registra historial de cambios en city, region y country. Permite análisis geográfico histórico preciso.';


-- ============================================================
-- 6. CAPA ENRIQUECIMIENTO (dwa_enr_)
--
--   Tablas de métricas pre-calculadas y segmentos derivados.
--   Se recalculan completamente en cada carga del DWA.
--   Permiten consultas rápidas de KPIs sin agregaciones costosas.
-- ============================================================

-- ------------------------------------------------------------
-- dwa_enr_cliente
--   Métricas agregadas por cliente + segmento de valor.
--   Segmento calculado por monto_total_neto:
--     PREMIUM  → top 20% por revenue
--     REGULAR  → siguiente 60%
--     BAJO     → bottom 20%
--   (los umbrales se aplican en el script de carga)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_warehouse."dwa_enr_cliente" (
    sk_cliente             INT           PRIMARY KEY
                                         REFERENCES data_warehouse."dwa_dim_cliente"(sk_cliente),
    total_pedidos          INT           NOT NULL DEFAULT 0,
    total_lineas           INT           NOT NULL DEFAULT 0,
    monto_total_neto       NUMERIC(14,4) NOT NULL DEFAULT 0,
    monto_promedio_pedido  NUMERIC(12,4),
    primer_pedido          DATE,
    ultimo_pedido          DATE,
    dias_como_cliente      INT,           -- ultimo_pedido - primer_pedido
    segmento               VARCHAR(20)   CHECK (segmento IN ('PREMIUM','REGULAR','BAJO')),
    fecha_calculo          TIMESTAMP     DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

COMMENT ON TABLE data_warehouse."dwa_enr_cliente" IS
    'Enriquecimiento por cliente. Métricas agregadas desde dwa_fact_ventas + segmento de valor (PREMIUM/REGULAR/BAJO) calculado por percentil de monto_total_neto. Se recalcula en cada carga.';

-- ------------------------------------------------------------
-- dwa_enr_producto
--   Métricas agregadas por producto + performance relativa.
--   Performance calculada por revenue_total:
--     TOP  → top 20% por revenue
--     MID  → siguiente 60%
--     LOW  → bottom 20%
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_warehouse."dwa_enr_producto" (
    sk_producto              INT           PRIMARY KEY
                                           REFERENCES data_warehouse."dwa_dim_producto"(sk_producto),
    total_pedidos            INT           NOT NULL DEFAULT 0,
    total_unidades           INT           NOT NULL DEFAULT 0,
    revenue_total            NUMERIC(14,4) NOT NULL DEFAULT 0,
    revenue_promedio_pedido  NUMERIC(12,4),
    rank_revenue             INT,           -- ranking por revenue_total (1 = mayor)
    performance              VARCHAR(20)   CHECK (performance IN ('TOP','MID','LOW')),
    fecha_calculo            TIMESTAMP     DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires')
);

COMMENT ON TABLE data_warehouse."dwa_enr_producto" IS
    'Enriquecimiento por producto. Métricas agregadas desde dwa_fact_ventas + ranking y categoría de performance (TOP/MID/LOW) por revenue_total. Se recalcula en cada carga.';


-- ============================================================
-- 7. DOCUMENTACIÓN EN met_entidades
-- ============================================================

-- dwa_dim_tiempo
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwa_dim_tiempo', 'sk_tiempo',        'INT',         'PK: surrogate key en formato YYYYMMDD para legibilidad',          'dim', TRUE,  FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'fecha',            'DATE',        'Fecha calendar única que representa esta fila',                    'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'anio',             'INT',         'Año de la fecha (ej: 1997)',                                       'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'trimestre',        'INT',         'Trimestre del año (1 a 4)',                                        'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'mes',              'INT',         'Mes del año (1 a 12)',                                             'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'nombre_mes',       'VARCHAR(20)', 'Nombre del mes en español (Enero, Febrero, ...)',                  'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'semana_anio',      'INT',         'Número de semana del año (ISO)',                                   'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'dia',              'INT',         'Día del mes (1 a 31)',                                             'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'dia_semana',       'INT',         'Día de la semana: 1=lunes, 7=domingo',                            'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'nombre_dia',       'VARCHAR(20)', 'Nombre del día en español (Lunes, Martes, ...)',                   'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_tiempo', 'es_fin_de_semana', 'BOOLEAN',     'TRUE si el día es sábado o domingo',                              'dim', FALSE, FALSE, NULL, NULL, FALSE);

-- dwa_dim_cliente
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwa_dim_cliente', 'sk_cliente',     'SERIAL',       'PK: surrogate key autoincremental del cliente en el DWA',         'dim', TRUE,  FALSE, NULL, NULL, FALSE),
    ('dwa_dim_cliente', 'nk_customer_id', 'CHAR(5)',       'NK: código de cliente original del sistema transaccional',        'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_cliente', 'company_name',   'VARCHAR(100)', 'Nombre comercial de la empresa cliente',                           'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_cliente', 'contact_name',   'VARCHAR(100)', 'Nombre del contacto principal',                                    'dim', FALSE, FALSE, NULL, NULL, TRUE),
    ('dwa_dim_cliente', 'contact_title',  'VARCHAR(100)', 'Cargo o función del contacto',                                     'dim', FALSE, FALSE, NULL, NULL, TRUE),
    ('dwa_dim_cliente', 'city',           'VARCHAR(100)', 'Ciudad del cliente (permite análisis geográfico)',                  'dim', FALSE, FALSE, NULL, NULL, TRUE),
    ('dwa_dim_cliente', 'region',         'VARCHAR(100)', 'Estado o región del cliente',                                      'dim', FALSE, FALSE, NULL, NULL, TRUE),
    ('dwa_dim_cliente', 'country',        'VARCHAR(100)', 'País del cliente (permite análisis por mercado)',                   'dim', FALSE, FALSE, NULL, NULL, TRUE);

-- dwa_dim_empleado
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwa_dim_empleado', 'sk_empleado',     'SERIAL',       'PK: surrogate key autoincremental del empleado en el DWA',      'dim', TRUE,  FALSE, NULL,               NULL,          FALSE),
    ('dwa_dim_empleado', 'nk_employee_id',  'INT',          'NK: ID original del empleado en el sistema transaccional',      'dim', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_dim_empleado', 'nombre_completo', 'VARCHAR(200)', 'Campo derivado: first_name || '' '' || last_name del source',   'dim', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_dim_empleado', 'title',           'VARCHAR(100)', 'Cargo o título del empleado dentro de la empresa',              'dim', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dwa_dim_empleado', 'hire_date',       'DATE',         'Fecha de incorporación del empleado a la empresa',              'dim', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dwa_dim_empleado', 'city',            'VARCHAR(100)', 'Ciudad de residencia del empleado',                             'dim', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dwa_dim_empleado', 'country',         'VARCHAR(100)', 'País de residencia del empleado',                               'dim', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dwa_dim_empleado', 'reports_to_sk',   'INT',          'FK auto-referencial: SK del supervisor directo (NULL = jefe máximo)', 'dim', FALSE, TRUE, 'dwa_dim_empleado', 'sk_empleado', TRUE);

-- dwa_dim_producto
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwa_dim_producto', 'sk_producto',          'SERIAL',       'PK: surrogate key del producto en el DWA',                         'dim', TRUE,  FALSE, NULL, NULL, FALSE),
    ('dwa_dim_producto', 'nk_product_id',         'INT',          'NK: ID original del producto en el sistema transaccional',         'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_producto', 'product_name',          'VARCHAR(100)', 'Nombre del producto',                                              'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_producto', 'precio_lista',          'NUMERIC(10,4)','Precio de catálogo vigente (no el precio de venta)',               'dim', FALSE, FALSE, NULL, NULL, TRUE),
    ('dwa_dim_producto', 'discontinued',          'BOOLEAN',      'TRUE si el producto fue descontinuado',                            'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_producto', 'category_name',         'VARCHAR(100)', 'Nombre de la categoría (colapsado de tmp_categories)',             'dim', FALSE, FALSE, NULL, NULL, TRUE),
    ('dwa_dim_producto', 'category_description',  'TEXT',         'Descripción de la categoría (colapsada)',                          'dim', FALSE, FALSE, NULL, NULL, TRUE),
    ('dwa_dim_producto', 'supplier_name',         'VARCHAR(100)', 'Nombre del proveedor (colapsado de tmp_suppliers)',                'dim', FALSE, FALSE, NULL, NULL, TRUE),
    ('dwa_dim_producto', 'supplier_country',      'VARCHAR(100)', 'País del proveedor (colapsado de tmp_suppliers)',                   'dim', FALSE, FALSE, NULL, NULL, TRUE);

-- dwa_dim_shipper
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwa_dim_shipper', 'sk_shipper',    'SERIAL',       'PK: surrogate key del transportista en el DWA',                   'dim', TRUE,  FALSE, NULL, NULL, FALSE),
    ('dwa_dim_shipper', 'nk_shipper_id', 'INT',          'NK: ID original del transportista en el sistema transaccional',   'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_shipper', 'company_name',  'VARCHAR(100)', 'Nombre de la empresa de transporte',                               'dim', FALSE, FALSE, NULL, NULL, FALSE),
    ('dwa_dim_shipper', 'phone',         'VARCHAR(50)',  'Teléfono del transportista',                                       'dim', FALSE, FALSE, NULL, NULL, TRUE);

-- dwa_fact_ventas
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwa_fact_ventas', 'sk_tiempo',         'INT',           'PK+FK → dwa_dim_tiempo. Fecha del pedido como surrogate key YYYYMMDD',  'fact', TRUE,  TRUE,  'dwa_dim_tiempo',   'sk_tiempo',   FALSE),
    ('dwa_fact_ventas', 'sk_cliente',        'INT',           'FK → dwa_dim_cliente. NULL si el cliente fue eliminado del source',      'fact', FALSE, TRUE,  'dwa_dim_cliente',  'sk_cliente',  TRUE),
    ('dwa_fact_ventas', 'sk_empleado',       'INT',           'FK → dwa_dim_empleado. NULL si el empleado fue eliminado del source',   'fact', FALSE, TRUE,  'dwa_dim_empleado', 'sk_empleado', TRUE),
    ('dwa_fact_ventas', 'sk_producto',       'INT',           'PK+FK → dwa_dim_producto. Producto vendido en esta línea',              'fact', TRUE,  TRUE,  'dwa_dim_producto', 'sk_producto', FALSE),
    ('dwa_fact_ventas', 'sk_shipper',        'INT',           'FK → dwa_dim_shipper. Transportista del pedido',                        'fact', FALSE, TRUE,  'dwa_dim_shipper',  'sk_shipper',  TRUE),
    ('dwa_fact_ventas', 'nk_order_id',       'INT',           'Dimensión degenerada: ID del pedido del source. Permite trazabilidad',  'fact', TRUE,  FALSE, NULL,               NULL,          FALSE),
    ('dwa_fact_ventas', 'cantidad',          'INT',           'Cantidad de unidades del producto vendidas en esta línea',              'fact', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_fact_ventas', 'precio_unitario',   'NUMERIC(10,4)', 'Precio pactado por unidad en esta venta (puede diferir del catálogo)', 'fact', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_fact_ventas', 'descuento',         'NUMERIC(5,4)',  'Descuento aplicado: 0.00 = sin descuento, 1.00 = 100% de descuento',    'fact', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_fact_ventas', 'flete_prorrateado', 'NUMERIC(10,4)', 'Flete del pedido dividido por cantidad de líneas del mismo pedido',    'fact', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_fact_ventas', 'monto_bruto',       'NUMERIC(12,4)', 'Medida derivada: cantidad × precio_unitario',                          'fact', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_fact_ventas', 'monto_descuento',   'NUMERIC(12,4)', 'Medida derivada: monto_bruto × descuento',                             'fact', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_fact_ventas', 'monto_neto',        'NUMERIC(12,4)', 'Medida derivada: monto_bruto − monto_descuento. Métrica principal',    'fact', FALSE, FALSE, NULL,               NULL,          FALSE);

-- dwm_producto
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwm_producto', 'dwm_producto_id', 'SERIAL',        'PK: surrogate key autoincremental del registro de memoria',         'memoria', TRUE,  FALSE, NULL,               NULL,          FALSE),
    ('dwm_producto', 'nk_product_id',   'INT',            'NK del producto en el sistema fuente',                              'memoria', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwm_producto', 'sk_producto',     'INT',            'FK → dwa_dim_producto. SK del producto al que pertenece el cambio', 'memoria', FALSE, TRUE,  'dwa_dim_producto', 'sk_producto', TRUE),
    ('dwm_producto', 'product_name',    'VARCHAR(100)',   'Nombre del producto en el período de vigencia',                     'memoria', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwm_producto', 'precio_lista',    'NUMERIC(10,4)',  'Precio de catálogo vigente en el período',                          'memoria', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dwm_producto', 'discontinued',    'BOOLEAN',        'Estado de descontinuación en el período',                           'memoria', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwm_producto', 'fecha_desde',     'DATE',           'Inicio del período de vigencia de esta versión del producto',       'memoria', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwm_producto', 'fecha_hasta',     'DATE',           'Fin del período de vigencia. NULL = versión actualmente vigente',   'memoria', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dwm_producto', 'es_vigente',      'BOOLEAN',        'TRUE si esta es la versión actualmente vigente del producto',       'memoria', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwm_producto', 'fecha_registro',  'TIMESTAMP',      'Fecha y hora en que se insertó este registro de memoria',          'memoria', FALSE, FALSE, NULL,               NULL,          TRUE);

-- dwm_cliente
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwm_cliente', 'dwm_cliente_id', 'SERIAL',        'PK: surrogate key autoincremental del registro de memoria',           'memoria', TRUE,  FALSE, NULL,              NULL,          FALSE),
    ('dwm_cliente', 'nk_customer_id', 'CHAR(5)',        'NK del cliente en el sistema fuente',                                 'memoria', FALSE, FALSE, NULL,              NULL,          FALSE),
    ('dwm_cliente', 'sk_cliente',     'INT',            'FK → dwa_dim_cliente. SK del cliente al que pertenece el cambio',    'memoria', FALSE, TRUE,  'dwa_dim_cliente', 'sk_cliente',  TRUE),
    ('dwm_cliente', 'company_name',   'VARCHAR(100)',   'Nombre de la empresa en el período de vigencia',                     'memoria', FALSE, FALSE, NULL,              NULL,          FALSE),
    ('dwm_cliente', 'city',           'VARCHAR(100)',   'Ciudad del cliente en el período de vigencia',                       'memoria', FALSE, FALSE, NULL,              NULL,          TRUE),
    ('dwm_cliente', 'region',         'VARCHAR(100)',   'Región del cliente en el período de vigencia',                       'memoria', FALSE, FALSE, NULL,              NULL,          TRUE),
    ('dwm_cliente', 'country',        'VARCHAR(100)',   'País del cliente en el período de vigencia',                         'memoria', FALSE, FALSE, NULL,              NULL,          TRUE),
    ('dwm_cliente', 'fecha_desde',    'DATE',           'Inicio del período de vigencia de esta versión del cliente',         'memoria', FALSE, FALSE, NULL,              NULL,          FALSE),
    ('dwm_cliente', 'fecha_hasta',    'DATE',           'Fin del período de vigencia. NULL = versión actualmente vigente',    'memoria', FALSE, FALSE, NULL,              NULL,          TRUE),
    ('dwm_cliente', 'es_vigente',     'BOOLEAN',        'TRUE si esta es la versión actualmente vigente del cliente',         'memoria', FALSE, FALSE, NULL,              NULL,          FALSE),
    ('dwm_cliente', 'fecha_registro', 'TIMESTAMP',      'Fecha y hora en que se insertó este registro de memoria',           'memoria', FALSE, FALSE, NULL,              NULL,          TRUE);

-- dwa_enr_cliente
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwa_enr_cliente', 'sk_cliente',            'INT',           'PK+FK → dwa_dim_cliente. Una fila por cliente',                       'enriquecimiento', TRUE,  TRUE,  'dwa_dim_cliente', 'sk_cliente', FALSE),
    ('dwa_enr_cliente', 'total_pedidos',          'INT',           'Cantidad de pedidos distintos realizados por el cliente',             'enriquecimiento', FALSE, FALSE, NULL,              NULL,         FALSE),
    ('dwa_enr_cliente', 'total_lineas',           'INT',           'Cantidad total de líneas de pedido (productos distintos) del cliente','enriquecimiento', FALSE, FALSE, NULL,              NULL,         FALSE),
    ('dwa_enr_cliente', 'monto_total_neto',       'NUMERIC(14,4)', 'Suma de monto_neto de todas las ventas del cliente',                  'enriquecimiento', FALSE, FALSE, NULL,              NULL,         FALSE),
    ('dwa_enr_cliente', 'monto_promedio_pedido',  'NUMERIC(12,4)', 'Promedio de monto_neto por pedido',                                   'enriquecimiento', FALSE, FALSE, NULL,              NULL,         TRUE),
    ('dwa_enr_cliente', 'primer_pedido',          'DATE',          'Fecha del primer pedido registrado del cliente',                      'enriquecimiento', FALSE, FALSE, NULL,              NULL,         TRUE),
    ('dwa_enr_cliente', 'ultimo_pedido',          'DATE',          'Fecha del último pedido registrado del cliente',                      'enriquecimiento', FALSE, FALSE, NULL,              NULL,         TRUE),
    ('dwa_enr_cliente', 'dias_como_cliente',      'INT',           'Diferencia en días entre primer y último pedido',                     'enriquecimiento', FALSE, FALSE, NULL,              NULL,         TRUE),
    ('dwa_enr_cliente', 'segmento',               'VARCHAR(20)',   'Segmento de valor: PREMIUM (top 20%), REGULAR (60%), BAJO (20%)',     'enriquecimiento', FALSE, FALSE, NULL,              NULL,         TRUE),
    ('dwa_enr_cliente', 'fecha_calculo',          'TIMESTAMP',     'Timestamp del último recálculo de estas métricas',                   'enriquecimiento', FALSE, FALSE, NULL,              NULL,         TRUE);

-- dwa_enr_producto
INSERT INTO data_warehouse."met_entidades"
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dwa_enr_producto', 'sk_producto',             'INT',           'PK+FK → dwa_dim_producto. Una fila por producto',                    'enriquecimiento', TRUE,  TRUE,  'dwa_dim_producto', 'sk_producto', FALSE),
    ('dwa_enr_producto', 'total_pedidos',            'INT',           'Cantidad de pedidos distintos que incluyeron este producto',         'enriquecimiento', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_enr_producto', 'total_unidades',           'INT',           'Suma de unidades vendidas del producto',                             'enriquecimiento', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_enr_producto', 'revenue_total',            'NUMERIC(14,4)', 'Suma de monto_neto de todas las ventas del producto',                'enriquecimiento', FALSE, FALSE, NULL,               NULL,          FALSE),
    ('dwa_enr_producto', 'revenue_promedio_pedido',  'NUMERIC(12,4)', 'Promedio de monto_neto por pedido del producto',                     'enriquecimiento', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dwa_enr_producto', 'rank_revenue',             'INT',           'Ranking del producto por revenue_total (1 = mayor revenue)',         'enriquecimiento', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dwa_enr_producto', 'performance',              'VARCHAR(20)',   'Categoría de performance: TOP (20%), MID (60%), LOW (20%)',          'enriquecimiento', FALSE, FALSE, NULL,               NULL,          TRUE),
    ('dwa_enr_producto', 'fecha_calculo',            'TIMESTAMP',     'Timestamp del último recálculo de estas métricas',                  'enriquecimiento', FALSE, FALSE, NULL,               NULL,          TRUE);


-- ============================================================
-- 8. VERIFICACIÓN
-- ============================================================

-- Resumen del modelo completo por capa
SELECT
    capa_dwh,
    nombre_tabla,
    COUNT(*)        AS columnas,
    SUM(es_pk::INT) AS pks,
    SUM(es_fk::INT) AS fks
FROM data_warehouse."met_entidades"
GROUP BY capa_dwh, nombre_tabla
ORDER BY
    CASE capa_dwh
        WHEN 'dqm'              THEN 1
        WHEN 'txt'              THEN 2
        WHEN 'tmp'              THEN 3
        WHEN 'dim'              THEN 4
        WHEN 'fact'             THEN 5
        WHEN 'memoria'          THEN 6
        WHEN 'enriquecimiento'  THEN 7
        ELSE 8
    END,
    nombre_tabla;


-- ============================================================
-- 9. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = 'OK',
    registros_proc = (
        SELECT COUNT(*) FROM data_warehouse."met_entidades"
        WHERE capa_dwh IN ('dim','fact','memoria','enriquecimiento')
    ),
    detalle        = 'Modelo dimensional creado: 5 dims, 1 fact, 2 DWM_, 2 enr_. MET_entidades documentada y renombrada.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '11_ddl_dwa'
)
AND resultado = 'EN_PROCESO';



