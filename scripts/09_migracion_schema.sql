-- ============================================================
-- SCRIPT: 09_migracion_schema
-- Descripción: Mueve todas las tablas del esquema public al
--              esquema data_warehouse por requerimiento de
--              seguridad de Supabase. Incluye tablas DQM, TMP_
--              y TXT_. Registra la ejecución en inventario y log.
-- Etapa: Adquisición
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-02
-- ============================================================


-- ============================================================
-- 1. CREAR ESQUEMA DESTINO
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_warehouse;


-- ============================================================
-- 2. MOVER TABLAS DQM
-- ============================================================

ALTER TABLE public.dqm_execution_log      SET SCHEMA data_warehouse;
ALTER TABLE public.dqm_integridad_tmp      SET SCHEMA data_warehouse;
ALTER TABLE public.dqm_perfilado           SET SCHEMA data_warehouse;
ALTER TABLE public.dqm_script_inventory   SET SCHEMA data_warehouse;
ALTER TABLE public.dqm_validacion_campo   SET SCHEMA data_warehouse;


-- ============================================================
-- 3. MOVER TABLAS TMP_
-- ============================================================

ALTER TABLE public.tmp_categories          SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_customers           SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_employee_territories SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_employees           SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_order_details       SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_orders              SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_products            SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_regions             SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_shippers            SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_suppliers           SET SCHEMA data_warehouse;
ALTER TABLE public.tmp_territories         SET SCHEMA data_warehouse;


-- ============================================================
-- 4. MOVER TABLAS TXT_
-- ============================================================

ALTER TABLE public.txt_categories          SET SCHEMA data_warehouse;
ALTER TABLE public.txt_customers           SET SCHEMA data_warehouse;
ALTER TABLE public.txt_employee_territories SET SCHEMA data_warehouse;
ALTER TABLE public.txt_employees           SET SCHEMA data_warehouse;
ALTER TABLE public.txt_order_details       SET SCHEMA data_warehouse;
ALTER TABLE public.txt_orders              SET SCHEMA data_warehouse;
ALTER TABLE public.txt_products            SET SCHEMA data_warehouse;
ALTER TABLE public.txt_regions             SET SCHEMA data_warehouse;
ALTER TABLE public.txt_shippers            SET SCHEMA data_warehouse;
ALTER TABLE public.txt_suppliers           SET SCHEMA data_warehouse;
ALTER TABLE public.txt_territories         SET SCHEMA data_warehouse;


-- ============================================================
-- 5. REGISTRO EN INVENTARIO Y LOG
--    Las tablas DQM ya están en data_warehouse después de los
--    ALTER TABLE anteriores, por eso se referencia ese esquema.
--    Sin patrón EN_PROCESO: es registro documental, no hay
--    lógica que pueda fallar a mitad (igual que 02_import_csv).
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES (
    '09_migracion_schema',
    'Movimiento de tablas de public a data_warehouse por política de seguridad Supabase',
    'adquisicion'
)
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log
    (script_id, fecha_inicio, fecha_fin, resultado, detalle, registros_proc)
VALUES (
    (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '09_migracion_schema'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'OK',
    'Tablas DQM, TMP_ y TXT_ movidas de public a data_warehouse. 27 tablas afectadas. Ejecutado por política de seguridad Supabase.',
    27
);