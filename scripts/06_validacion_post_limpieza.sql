-- ============================================================
-- SCRIPT: 06_validacion_post_limpieza
-- Descripción: Validación de datos en TXT_ tras ejecutar
--              05_limpieza_datos_txt. Verifica que no queden
--              inconsistencias corregidas en la limpieza.
-- Etapa: Adquisición
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-02
-- ============================================================


-- ============================================================
-- 1. INVENTARIO Y LOG DE INICIO
-- ============================================================

INSERT INTO public.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('06_validacion_post_limpieza', 'Control de calidad post-limpieza de tablas TXT_', 'adquisicion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO public.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '06_validacion_post_limpieza'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO', 'Iniciando validación post-limpieza sobre tablas TXT_'
);


-- ============================================================
-- 2. VALIDACIÓN: country NO debe ser MX en txt_customers
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_customers', 'country', 'POST_LIMPIEZA_SIN_MX',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Sin registros MX encontrados'
         ELSE 'ALERTA: aún existen registros con country=MX' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers WHERE country = 'MX';


-- ============================================================
-- 3. CIERRE DE LOG
-- ============================================================

UPDATE public.dqm_execution_log
SET fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = CASE
        WHEN EXISTS (SELECT 1 FROM public.dqm_validacion_campo
                     WHERE control = 'POST_LIMPIEZA_SIN_MX' AND resultado = 'ERROR')
        THEN 'ERROR' ELSE 'OK'
    END,
    detalle        = 'Validación post-limpieza completada.',
    registros_proc = (SELECT COUNT(*) FROM public.txt_customers)
WHERE script_id = (
    SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '06_validacion_post_limpieza'
)
AND resultado = 'EN_PROCESO';
