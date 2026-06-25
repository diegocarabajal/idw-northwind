-- ============================================================
-- SCRIPT: 10_metadata
-- Descripción: Creación de la tabla de Metadata (met_dwa) y
--              carga descriptiva de todas las entidades del DWA.
--              Cubre las capas: DQM, TXT (espejo), TMP (staging).
--              Las capas DIM/FACT/MEMORIA/ENRIQUECIMIENTO se
--              documentarán en el script de creación del modelo
--              dimensional (11_ddl_dwa.sql).
-- Etapa: Ingeniería
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-16
-- ============================================================


-- ============================================================
-- 1. REGISTRO EN INVENTARIO DE SCRIPTS
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES (
    '10_metadata',
    'Creación de tabla de Metadata y descripción de todas las entidades del DWA',
    'ingenieria'
)
ON CONFLICT (script_nombre) DO NOTHING;


-- ============================================================
-- 2. INICIO DE LOG
-- ============================================================

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '10_metadata'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO',
    'Creando tabla met_dwa y cargando metadata de entidades'
);


-- ============================================================
-- 3. CREACIÓN DE LA TABLA DE METADATA
--    Una fila por columna de cada entidad del DWA.
--    Columnas:
--      met_id            - PK autoincremental
--      nombre_tabla      - nombre de la tabla
--      nombre_columna    - nombre de la columna
--      tipo_dato         - tipo de dato PostgreSQL
--      descripcion       - descripción del campo
--      capa_dwh          - capa del DWA: dqm | txt | tmp | dim | fact | memoria | enriquecimiento
--      es_pk             - indica si es clave primaria
--      es_fk             - indica si es clave foránea
--      tabla_referencia  - tabla a la que apunta la FK (NULL si no aplica)
--      columna_referencia- columna a la que apunta la FK (NULL si no aplica)
--      nullable          - permite valores nulos
-- ============================================================

CREATE TABLE IF NOT EXISTS data_warehouse.met_dwa (
    met_id             SERIAL PRIMARY KEY,
    nombre_tabla       VARCHAR(100) NOT NULL,
    nombre_columna     VARCHAR(100) NOT NULL,
    tipo_dato          VARCHAR(100) NOT NULL,
    descripcion        TEXT         NOT NULL,
    capa_dwh           VARCHAR(50)  NOT NULL,
    es_pk              BOOLEAN      NOT NULL DEFAULT FALSE,
    es_fk              BOOLEAN      NOT NULL DEFAULT FALSE,
    tabla_referencia   VARCHAR(100),
    columna_referencia VARCHAR(100),
    nullable           BOOLEAN      NOT NULL DEFAULT TRUE,
    create_date        TIMESTAMP    DEFAULT (NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    CONSTRAINT chk_capa CHECK (capa_dwh IN ('dqm','txt','tmp','dim','fact','memoria','enriquecimiento'))
);

COMMENT ON TABLE data_warehouse.met_dwa IS
    'Catálogo de metadata del DWA. Describe a nivel columna todas las entidades de todas las capas.';

COMMENT ON COLUMN data_warehouse.met_dwa.capa_dwh IS
    'Capa del DWA a la que pertenece la entidad: dqm, txt, tmp, dim, fact, memoria, enriquecimiento.';


-- ============================================================
-- 4. METADATA – CAPA DQM
--    Tablas de control de calidad e inventario de scripts.
-- ============================================================

-- dqm_script_inventory
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dqm_script_inventory', 'script_id',     'SERIAL',        'Identificador único autoincremental del script',                              'dqm', TRUE,  FALSE, NULL, NULL, FALSE),
    ('dqm_script_inventory', 'script_nombre', 'VARCHAR(100)',   'Nombre único del script (usado como referencia en logs)',                     'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_script_inventory', 'script_desc',   'TEXT',          'Descripción del propósito del script',                                        'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('dqm_script_inventory', 'etapa',         'VARCHAR(50)',    'Etapa del proceso ETL al que pertenece (adquisicion, ingenieria, etc.)',       'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_script_inventory', 'create_date',   'TIMESTAMP',      'Fecha y hora de registro del script en el inventario',                       'dqm', FALSE, FALSE, NULL, NULL, TRUE);

-- dqm_execution_log
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dqm_execution_log', 'log_id',        'SERIAL',        'Identificador único autoincremental del registro de log',                         'dqm', TRUE,  FALSE, NULL,                    NULL,      FALSE),
    ('dqm_execution_log', 'script_id',     'INT',           'FK al script que generó este registro de ejecución',                             'dqm', FALSE, TRUE,  'dqm_script_inventory',  'script_id', TRUE),
    ('dqm_execution_log', 'fecha_inicio',  'TIMESTAMP',     'Fecha y hora de inicio de la ejecución del script',                              'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_execution_log', 'fecha_fin',     'TIMESTAMP',     'Fecha y hora de fin de la ejecución (NULL si aún está en proceso)',               'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('dqm_execution_log', 'resultado',     'VARCHAR(20)',   'Estado final de la ejecución: EN_PROCESO, OK, WARNING, ERROR',                    'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('dqm_execution_log', 'detalle',       'TEXT',          'Descripción detallada del resultado o error de la ejecución',                    'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('dqm_execution_log', 'registros_proc','INT',           'Cantidad de registros procesados por el script',                                  'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('dqm_execution_log', 'create_date',   'TIMESTAMP',     'Fecha y hora de inserción del registro en el log',                               'dqm', FALSE, FALSE, NULL, NULL, TRUE);

-- dqm_validacion_campo
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dqm_validacion_campo', 'validacion_id', 'SERIAL',       'Identificador único autoincremental de la validación',                         'dqm', TRUE,  FALSE, NULL, NULL, FALSE),
    ('dqm_validacion_campo', 'tabla',         'VARCHAR(100)', 'Nombre de la tabla sobre la cual se ejecutó el control de calidad',             'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_validacion_campo', 'campo',         'VARCHAR(100)', 'Nombre del campo sobre el cual se ejecutó el control',                          'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_validacion_campo', 'control',       'VARCHAR(100)', 'Tipo de control ejecutado (nulos, formato, outlier, etc.)',                     'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_validacion_campo', 'resultado',     'VARCHAR(20)',  'Resultado del control: OK, WARNING, ERROR',                                     'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_validacion_campo', 'cant_errores',  'INT',          'Cantidad de registros que no superaron el control',                             'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_validacion_campo', 'detalle',       'TEXT',         'Descripción adicional o ejemplos de los valores que fallaron',                  'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('dqm_validacion_campo', 'fecha_control', 'TIMESTAMP',    'Fecha y hora en que se ejecutó el control',                                    'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_validacion_campo', 'create_date',   'TIMESTAMP',    'Fecha y hora de inserción del registro',                                       'dqm', FALSE, FALSE, NULL, NULL, TRUE);

-- dqm_perfilado
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('dqm_perfilado', 'perfilado_id',    'SERIAL',        'Identificador único autoincremental del registro de perfilado',                    'dqm', TRUE,  FALSE, NULL, NULL, FALSE),
    ('dqm_perfilado', 'tabla',           'VARCHAR(100)',  'Nombre de la tabla perfilada',                                                     'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_perfilado', 'campo',           'VARCHAR(100)',  'Nombre del campo perfilado',                                                       'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_perfilado', 'total_registros', 'INT',           'Cantidad total de registros en la tabla al momento del perfilado',                  'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_perfilado', 'cant_nulos',      'INT',           'Cantidad de valores nulos encontrados en el campo',                                'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_perfilado', 'cant_distintos',  'INT',           'Cantidad de valores distintos (cardinalidad) del campo',                           'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_perfilado', 'valor_min',       'TEXT',          'Valor mínimo encontrado (representado como texto)',                                 'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('dqm_perfilado', 'valor_max',       'TEXT',          'Valor máximo encontrado (representado como texto)',                                 'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('dqm_perfilado', 'fecha_perfilado', 'TIMESTAMP',     'Fecha y hora de ejecución del perfilado',                                          'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('dqm_perfilado', 'create_date',     'TIMESTAMP',     'Fecha y hora de inserción del registro',                                           'dqm', FALSE, FALSE, NULL, NULL, TRUE);

-- met_dwa (auto-referencia: la tabla de metadata se describe a sí misma)
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('met_dwa', 'met_id',             'SERIAL',        'Identificador único autoincremental del registro de metadata',                    'dqm', TRUE,  FALSE, NULL, NULL, FALSE),
    ('met_dwa', 'nombre_tabla',       'VARCHAR(100)',  'Nombre de la tabla descripta',                                                    'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('met_dwa', 'nombre_columna',     'VARCHAR(100)',  'Nombre de la columna descripta',                                                  'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('met_dwa', 'tipo_dato',          'VARCHAR(100)',  'Tipo de dato PostgreSQL de la columna',                                           'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('met_dwa', 'descripcion',        'TEXT',          'Descripción funcional de la columna',                                            'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('met_dwa', 'capa_dwh',           'VARCHAR(50)',   'Capa del DWA: dqm, txt, tmp, dim, fact, memoria, enriquecimiento',                'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('met_dwa', 'es_pk',              'BOOLEAN',       'TRUE si la columna es clave primaria de su tabla',                               'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('met_dwa', 'es_fk',              'BOOLEAN',       'TRUE si la columna es clave foránea hacia otra tabla',                           'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('met_dwa', 'tabla_referencia',   'VARCHAR(100)',  'Tabla destino de la FK (NULL si no es FK)',                                      'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('met_dwa', 'columna_referencia', 'VARCHAR(100)',  'Columna destino de la FK (NULL si no es FK)',                                    'dqm', FALSE, FALSE, NULL, NULL, TRUE),
    ('met_dwa', 'nullable',           'BOOLEAN',       'TRUE si la columna admite valores nulos',                                        'dqm', FALSE, FALSE, NULL, NULL, FALSE),
    ('met_dwa', 'create_date',        'TIMESTAMP',     'Fecha y hora de inserción del registro de metadata',                             'dqm', FALSE, FALSE, NULL, NULL, TRUE);


-- ============================================================
-- 5. METADATA – CAPA TXT (espejo CSV, todos los campos TEXT)
-- ============================================================

-- txt_categories
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_categories', 'category_id',   'TEXT', 'Identificador de categoría (texto crudo del CSV)',        'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_categories', 'category_name', 'TEXT', 'Nombre de la categoría',                                  'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_categories', 'description',   'TEXT', 'Descripción de la categoría',                             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_categories', 'picture',       'TEXT', 'Ruta o referencia a la imagen de la categoría (no se carga al DWA)', 'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_customers
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_customers', 'customer_id',    'TEXT', 'Código de cliente de 5 caracteres',                       'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'company_name',   'TEXT', 'Nombre de la empresa del cliente',                        'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'contact_name',   'TEXT', 'Nombre del contacto en la empresa',                       'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'contact_title',  'TEXT', 'Título o cargo del contacto',                             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'address',        'TEXT', 'Dirección postal del cliente',                             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'city',           'TEXT', 'Ciudad del cliente',                                      'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'region',         'TEXT', 'Región o estado del cliente',                             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'postal_code',    'TEXT', 'Código postal del cliente',                               'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'country',        'TEXT', 'País del cliente',                                        'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'phone',          'TEXT', 'Teléfono del cliente',                                    'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_customers', 'fax',            'TEXT', 'Fax del cliente',                                         'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_employees
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_employees', 'employee_id',        'TEXT', 'Identificador del empleado',                          'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'last_name',          'TEXT', 'Apellido del empleado',                               'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'first_name',         'TEXT', 'Nombre del empleado',                                 'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'title',              'TEXT', 'Título profesional del empleado',                     'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'title_of_courtesy',  'TEXT', 'Tratamiento (Mr., Ms., Dr., etc.)',                   'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'birth_date',         'TEXT', 'Fecha de nacimiento (texto crudo del CSV)',           'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'hire_date',          'TEXT', 'Fecha de contratación (texto crudo del CSV)',         'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'address',            'TEXT', 'Dirección del empleado',                              'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'city',              'TEXT', 'Ciudad de residencia del empleado',                    'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'region',             'TEXT', 'Región del empleado',                                 'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'postal_code',        'TEXT', 'Código postal del empleado',                         'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'country',            'TEXT', 'País del empleado',                                   'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'home_phone',         'TEXT', 'Teléfono del hogar del empleado',                    'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'extension',          'TEXT', 'Extensión telefónica interna',                        'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'photo',              'TEXT', 'Referencia a foto del empleado (no se carga al DWA)', 'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'notes',              'TEXT', 'Notas biográficas del empleado',                      'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'reports_to',         'TEXT', 'ID del supervisor directo (texto crudo)',             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employees', 'photo_path',         'TEXT', 'Ruta de archivo de foto (no se carga al DWA)',       'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_suppliers
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_suppliers', 'supplier_id',    'TEXT', 'Identificador del proveedor',                             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'company_name',   'TEXT', 'Nombre de la empresa proveedora',                         'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'contact_name',   'TEXT', 'Nombre del contacto en el proveedor',                     'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'contact_title',  'TEXT', 'Cargo del contacto',                                      'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'address',        'TEXT', 'Dirección del proveedor',                                 'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'city',           'TEXT', 'Ciudad del proveedor',                                    'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'region',         'TEXT', 'Región del proveedor',                                    'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'postal_code',    'TEXT', 'Código postal del proveedor',                             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'country',        'TEXT', 'País del proveedor',                                      'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'phone',          'TEXT', 'Teléfono del proveedor',                                  'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'fax',            'TEXT', 'Fax del proveedor',                                       'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_suppliers', 'homepage',       'TEXT', 'Sitio web del proveedor',                                 'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_products
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_products', 'product_id',        'TEXT', 'Identificador del producto',                            'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_products', 'product_name',      'TEXT', 'Nombre del producto',                                   'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_products', 'supplier_id',       'TEXT', 'ID del proveedor (texto crudo)',                        'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_products', 'category_id',       'TEXT', 'ID de la categoría (texto crudo)',                      'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_products', 'quantity_per_unit', 'TEXT', 'Descripción de la unidad de venta',                     'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_products', 'unit_price',        'TEXT', 'Precio unitario (texto crudo)',                         'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_products', 'units_in_stock',    'TEXT', 'Unidades en stock (texto crudo)',                       'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_products', 'units_on_order',    'TEXT', 'Unidades en pedido (texto crudo)',                      'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_products', 'reorder_level',     'TEXT', 'Nivel de reposición (texto crudo)',                     'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_products', 'discontinued',      'TEXT', 'Indicador de descontinuación (texto crudo)',            'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_orders
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_orders', 'order_id',         'TEXT', 'Identificador del pedido',                                 'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'customer_id',      'TEXT', 'ID del cliente (texto crudo)',                             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'employee_id',      'TEXT', 'ID del empleado que gestionó el pedido (texto crudo)',     'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'order_date',       'TEXT', 'Fecha del pedido (texto crudo)',                           'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'required_date',    'TEXT', 'Fecha requerida de entrega (texto crudo)',                 'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'shipped_date',     'TEXT', 'Fecha de despacho (texto crudo, puede ser vacío)',         'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'ship_via',         'TEXT', 'ID del shipper (texto crudo)',                             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'freight',          'TEXT', 'Costo de flete (texto crudo)',                             'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'ship_name',        'TEXT', 'Nombre del destinatario del envío',                       'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'ship_address',     'TEXT', 'Dirección de entrega',                                    'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'ship_city',        'TEXT', 'Ciudad de entrega',                                       'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'ship_region',      'TEXT', 'Región de entrega',                                       'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'ship_postal_code', 'TEXT', 'Código postal de entrega',                                'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_orders', 'ship_country',     'TEXT', 'País de entrega',                                         'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_order_details
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_order_details', 'order_id',    'TEXT', 'ID del pedido (texto crudo)',                            'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_order_details', 'product_id',  'TEXT', 'ID del producto (texto crudo)',                          'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_order_details', 'unit_price',  'TEXT', 'Precio unitario al momento de la venta (texto crudo)',   'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_order_details', 'quantity',    'TEXT', 'Cantidad vendida (texto crudo)',                         'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_order_details', 'discount',    'TEXT', 'Descuento aplicado entre 0 y 1 (texto crudo)',           'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_shippers
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_shippers', 'shipper_id',   'TEXT', 'Identificador del transportista',                           'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_shippers', 'company_name', 'TEXT', 'Nombre de la empresa transportista',                        'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_shippers', 'phone',        'TEXT', 'Teléfono del transportista',                                'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_regions
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_regions', 'region_id',          'TEXT', 'Identificador de la región',                           'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_regions', 'region_description', 'TEXT', 'Descripción de la región geográfica de ventas',        'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_territories
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_territories', 'territory_id',          'TEXT', 'Identificador del territorio de ventas',        'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_territories', 'territory_description', 'TEXT', 'Descripción del territorio',                   'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_territories', 'region_id',             'TEXT', 'ID de la región a la que pertenece (texto crudo)', 'txt', FALSE, FALSE, NULL, NULL, TRUE);

-- txt_employee_territories
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('txt_employee_territories', 'employee_id',  'TEXT', 'ID del empleado (texto crudo)',                 'txt', FALSE, FALSE, NULL, NULL, TRUE),
    ('txt_employee_territories', 'territory_id', 'TEXT', 'ID del territorio asignado (texto crudo)',      'txt', FALSE, FALSE, NULL, NULL, TRUE);


-- ============================================================
-- 6. METADATA – CAPA TMP (staging tipado según DER Northwind)
-- ============================================================

-- tmp_categories
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_categories', 'category_id',   'INT',          'PK: Identificador único de la categoría de producto',    'tmp', TRUE,  FALSE, NULL, NULL, FALSE),
    ('tmp_categories', 'category_name', 'VARCHAR(100)', 'Nombre de la categoría (ej: Beverages, Dairy)',           'tmp', FALSE, FALSE, NULL, NULL, FALSE),
    ('tmp_categories', 'description',   'TEXT',         'Descripción de los productos que contiene la categoría', 'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_categories', 'picture',       'TEXT',         'Referencia a imagen; no se propaga al DWA',             'tmp', FALSE, FALSE, NULL, NULL, TRUE);

-- tmp_customers
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_customers', 'customer_id',   'CHAR(5)',       'PK: Código alfanumérico de 5 caracteres del cliente',   'tmp', TRUE,  FALSE, NULL, NULL, FALSE),
    ('tmp_customers', 'company_name',  'VARCHAR(100)',  'Nombre comercial de la empresa cliente',                 'tmp', FALSE, FALSE, NULL, NULL, FALSE),
    ('tmp_customers', 'contact_name',  'VARCHAR(100)',  'Nombre completo del contacto principal',                 'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_customers', 'contact_title', 'VARCHAR(100)',  'Cargo o función del contacto',                          'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_customers', 'address',       'VARCHAR(150)',  'Dirección postal completa',                              'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_customers', 'city',          'VARCHAR(100)',  'Ciudad del cliente',                                     'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_customers', 'region',        'VARCHAR(100)',  'Estado, provincia o región del cliente',                 'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_customers', 'postal_code',   'VARCHAR(50)',   'Código postal',                                          'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_customers', 'country',       'VARCHAR(100)',  'País del cliente',                                       'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_customers', 'phone',         'VARCHAR(50)',   'Teléfono principal del cliente',                         'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_customers', 'fax',           'VARCHAR(50)',   'Número de fax del cliente',                             'tmp', FALSE, FALSE, NULL, NULL, TRUE);

-- tmp_employees
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_employees', 'employee_id',       'INT',          'PK: Identificador único del empleado',                      'tmp', TRUE,  FALSE, NULL,            NULL,          FALSE),
    ('tmp_employees', 'last_name',         'VARCHAR(100)', 'Apellido del empleado',                                      'tmp', FALSE, FALSE, NULL,            NULL,          FALSE),
    ('tmp_employees', 'first_name',        'VARCHAR(100)', 'Nombre del empleado',                                        'tmp', FALSE, FALSE, NULL,            NULL,          FALSE),
    ('tmp_employees', 'title',             'VARCHAR(100)', 'Título o cargo dentro de la empresa',                        'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'title_of_courtesy', 'VARCHAR(50)',  'Tratamiento formal (Mr., Ms., Dr., etc.)',                   'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'birth_date',        'DATE',         'Fecha de nacimiento del empleado',                           'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'hire_date',         'DATE',         'Fecha de incorporación a la empresa',                        'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'address',           'VARCHAR(150)', 'Dirección del hogar del empleado',                           'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'city',              'VARCHAR(100)', 'Ciudad de residencia',                                       'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'region',            'VARCHAR(100)', 'Región de residencia',                                       'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'postal_code',       'VARCHAR(50)',  'Código postal de la residencia',                             'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'country',           'VARCHAR(100)', 'País de residencia',                                         'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'home_phone',        'VARCHAR(50)',  'Teléfono del hogar',                                         'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'extension',         'VARCHAR(20)',  'Extensión telefónica interna de la empresa',                 'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'photo',             'TEXT',         'Referencia a foto del empleado; no se propaga al DWA',      'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'notes',             'TEXT',         'Notas biográficas del empleado',                             'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_employees', 'reports_to',        'INT',          'FK auto-referencial: ID del supervisor directo (NULL = jefe máximo)', 'tmp', FALSE, TRUE, 'tmp_employees', 'employee_id', TRUE),
    ('tmp_employees', 'photo_path',        'VARCHAR(255)', 'Ruta al archivo de foto; no se propaga al DWA',             'tmp', FALSE, FALSE, NULL,            NULL,          TRUE);

-- tmp_suppliers
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_suppliers', 'supplier_id',   'INT',          'PK: Identificador único del proveedor',                  'tmp', TRUE,  FALSE, NULL, NULL, FALSE),
    ('tmp_suppliers', 'company_name',  'VARCHAR(100)', 'Nombre comercial del proveedor',                         'tmp', FALSE, FALSE, NULL, NULL, FALSE),
    ('tmp_suppliers', 'contact_name',  'VARCHAR(100)', 'Nombre del contacto principal en el proveedor',          'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_suppliers', 'contact_title', 'VARCHAR(100)', 'Cargo del contacto',                                     'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_suppliers', 'address',       'VARCHAR(150)', 'Dirección del proveedor',                                'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_suppliers', 'city',          'VARCHAR(100)', 'Ciudad del proveedor',                                   'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_suppliers', 'region',        'VARCHAR(100)', 'Región del proveedor',                                   'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_suppliers', 'postal_code',   'VARCHAR(50)',  'Código postal del proveedor',                            'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_suppliers', 'country',       'VARCHAR(100)', 'País del proveedor',                                     'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_suppliers', 'phone',         'VARCHAR(50)',  'Teléfono del proveedor',                                 'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_suppliers', 'fax',           'VARCHAR(50)',  'Fax del proveedor',                                      'tmp', FALSE, FALSE, NULL, NULL, TRUE),
    ('tmp_suppliers', 'homepage',      'TEXT',         'Sitio web del proveedor',                                'tmp', FALSE, FALSE, NULL, NULL, TRUE);

-- tmp_products
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_products', 'product_id',        'INT',            'PK: Identificador único del producto',                         'tmp', TRUE,  FALSE, NULL,             NULL,         FALSE),
    ('tmp_products', 'product_name',      'VARCHAR(100)',   'Nombre del producto',                                           'tmp', FALSE, FALSE, NULL,             NULL,         FALSE),
    ('tmp_products', 'supplier_id',       'INT',            'FK: ID del proveedor que suministra el producto',              'tmp', FALSE, TRUE,  'tmp_suppliers',  'supplier_id', TRUE),
    ('tmp_products', 'category_id',       'INT',            'FK: ID de la categoría del producto',                          'tmp', FALSE, TRUE,  'tmp_categories', 'category_id', TRUE),
    ('tmp_products', 'quantity_per_unit', 'VARCHAR(100)',   'Descripción de la cantidad por unidad de venta',               'tmp', FALSE, FALSE, NULL,             NULL,         TRUE),
    ('tmp_products', 'unit_price',        'NUMERIC(10,4)',  'Precio de lista del producto',                                  'tmp', FALSE, FALSE, NULL,             NULL,         TRUE),
    ('tmp_products', 'units_in_stock',    'INT',            'Cantidad de unidades disponibles en inventario',                'tmp', FALSE, FALSE, NULL,             NULL,         TRUE),
    ('tmp_products', 'units_on_order',    'INT',            'Cantidad de unidades actualmente pedidas a proveedor',          'tmp', FALSE, FALSE, NULL,             NULL,         TRUE),
    ('tmp_products', 'reorder_level',     'INT',            'Nivel mínimo de stock que dispara una reposición',             'tmp', FALSE, FALSE, NULL,             NULL,         TRUE),
    ('tmp_products', 'discontinued',      'INT',            'Indicador: 1 = producto descontinuado, 0 = activo',            'tmp', FALSE, FALSE, NULL,             NULL,         FALSE);

-- tmp_orders
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_orders', 'order_id',         'INT',           'PK: Identificador único del pedido',                               'tmp', TRUE,  FALSE, NULL,           NULL,          FALSE),
    ('tmp_orders', 'customer_id',      'CHAR(5)',        'FK: Código del cliente que realizó el pedido',                    'tmp', FALSE, TRUE,  'tmp_customers', 'customer_id', TRUE),
    ('tmp_orders', 'employee_id',      'INT',            'FK: ID del empleado que gestionó el pedido',                     'tmp', FALSE, TRUE,  'tmp_employees', 'employee_id', TRUE),
    ('tmp_orders', 'order_date',       'DATE',           'Fecha en que se registró el pedido',                              'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_orders', 'required_date',    'DATE',           'Fecha comprometida de entrega al cliente',                        'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_orders', 'shipped_date',     'DATE',           'Fecha real de despacho (NULL si aún no fue enviado)',             'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_orders', 'ship_via',         'INT',            'FK: ID del transportista utilizado',                              'tmp', FALSE, TRUE,  'tmp_shippers',  'shipper_id',  TRUE),
    ('tmp_orders', 'freight',          'NUMERIC(10,4)',  'Costo de flete del pedido en dólares',                           'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_orders', 'ship_name',        'VARCHAR(100)',   'Nombre del destinatario del envío',                              'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_orders', 'ship_address',     'VARCHAR(150)',   'Dirección de entrega del pedido',                                'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_orders', 'ship_city',        'VARCHAR(100)',   'Ciudad de entrega',                                               'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_orders', 'ship_region',      'VARCHAR(100)',   'Región de entrega',                                               'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_orders', 'ship_postal_code', 'VARCHAR(50)',    'Código postal de entrega',                                        'tmp', FALSE, FALSE, NULL,            NULL,          TRUE),
    ('tmp_orders', 'ship_country',     'VARCHAR(100)',   'País de entrega',                                                 'tmp', FALSE, FALSE, NULL,            NULL,          TRUE);

-- tmp_order_details
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_order_details', 'order_id',   'INT',           'PK+FK: ID del pedido al que pertenece la línea de detalle',       'tmp', TRUE,  TRUE,  'tmp_orders',   'order_id',   FALSE),
    ('tmp_order_details', 'product_id', 'INT',           'PK+FK: ID del producto vendido en esta línea',                    'tmp', TRUE,  TRUE,  'tmp_products', 'product_id', FALSE),
    ('tmp_order_details', 'unit_price', 'NUMERIC(10,4)', 'Precio unitario pactado para esta línea (puede diferir del catálogo)', 'tmp', FALSE, FALSE, NULL, NULL, FALSE),
    ('tmp_order_details', 'quantity',   'INT',           'Cantidad de unidades vendidas del producto en esta línea',         'tmp', FALSE, FALSE, NULL, NULL, FALSE),
    ('tmp_order_details', 'discount',   'NUMERIC(5,4)',  'Descuento aplicado (0.00 a 1.00, representando 0% a 100%)',       'tmp', FALSE, FALSE, NULL, NULL, FALSE);

-- tmp_shippers
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_shippers', 'shipper_id',   'INT',          'PK: Identificador único del transportista',                       'tmp', TRUE,  FALSE, NULL, NULL, FALSE),
    ('tmp_shippers', 'company_name', 'VARCHAR(100)', 'Nombre de la empresa de transporte',                              'tmp', FALSE, FALSE, NULL, NULL, FALSE),
    ('tmp_shippers', 'phone',        'VARCHAR(50)',  'Teléfono de contacto del transportista',                         'tmp', FALSE, FALSE, NULL, NULL, TRUE);

-- tmp_regions
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_regions', 'region_id',          'INT',          'PK: Identificador único de la región de ventas',             'tmp', TRUE,  FALSE, NULL, NULL, FALSE),
    ('tmp_regions', 'region_description', 'VARCHAR(100)', 'Nombre descriptivo de la región (ej: Eastern, Western)',     'tmp', FALSE, FALSE, NULL, NULL, FALSE);

-- tmp_territories
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_territories', 'territory_id',          'VARCHAR(50)',  'PK: Código del territorio (preserva ceros a la izquierda)',     'tmp', TRUE,  FALSE, NULL,         NULL,        FALSE),
    ('tmp_territories', 'territory_description', 'VARCHAR(100)', 'Nombre o descripción del territorio de ventas',                 'tmp', FALSE, FALSE, NULL,         NULL,        FALSE),
    ('tmp_territories', 'region_id',             'INT',          'FK: Región a la que pertenece el territorio',                   'tmp', FALSE, TRUE,  'tmp_regions', 'region_id', FALSE);

-- tmp_employee_territories
INSERT INTO data_warehouse.met_dwa
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
VALUES
    ('tmp_employee_territories', 'employee_id',  'INT',         'PK+FK: ID del empleado asignado al territorio',                  'tmp', TRUE, TRUE, 'tmp_employees',  'employee_id',  FALSE),
    ('tmp_employee_territories', 'territory_id', 'VARCHAR(50)', 'PK+FK: Código del territorio asignado al empleado',              'tmp', TRUE, TRUE, 'tmp_territories', 'territory_id', FALSE);


-- ============================================================
-- 7. VERIFICACIÓN
-- ============================================================

-- Resumen de entidades documentadas por capa
SELECT
    capa_dwh,
    nombre_tabla,
    COUNT(*)           AS columnas_documentadas,
    SUM(es_pk::INT)    AS claves_primarias,
    SUM(es_fk::INT)    AS claves_foraneas
FROM data_warehouse.met_dwa
GROUP BY capa_dwh, nombre_tabla
ORDER BY capa_dwh, nombre_tabla;


-- ============================================================
-- 8. CIERRE DE LOG
-- ============================================================

UPDATE data_warehouse.dqm_execution_log
SET
    fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = 'OK',
    registros_proc = (SELECT COUNT(*) FROM data_warehouse.met_dwa),
    detalle        = 'Metadata creada y cargada exitosamente para capas DQM, TXT y TMP.'
WHERE script_id = (
    SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '10_metadata'
)
AND resultado = 'EN_PROCESO';
