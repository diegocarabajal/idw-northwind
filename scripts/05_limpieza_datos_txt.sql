-- ============================================================
-- SCRIPT: 05_limpieza_datos_txt
-- Descripción: Normalización y limpieza de datos en capa TXT_.
--              Corrige inconsistencias detectadas en 03_validacion_txt
--              antes de migrar a TMP_.
--              Correcciones aplicadas:
--                1. country='MX' → 'Mexico' en txt_customers
--                   (2 registros: ANATR, ANTON)
-- Etapa: Adquisición
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-02
-- ============================================================


-- ============================================================
-- 1. INVENTARIO Y LOG DE INICIO
-- ============================================================

INSERT INTO public.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('05_limpieza_datos_txt', 'Normalización de datos en capa TXT_', 'adquisicion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO public.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES (
    (SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '05_limpieza_datos_txt'),
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'EN_PROCESO', 'Iniciando limpieza de datos en tablas TXT_'
);


-- ============================================================
-- 2. CORRECCIÓN: country = 'MX' → 'Mexico' en txt_customers
--    Detectado en 03_validacion_txt como WARNING VALOR_INCONSISTENTE.
--    Los registros con 'MX' son: ANATR y ANTON.
-- ============================================================

UPDATE public.txt_customers
SET country = 'Mexico'
WHERE country = 'MX';


-- ============================================================
-- 3. VALIDACIÓN POST-LIMPIEZA
--    Verifica que no queden registros con country='MX'.
--    Persiste el resultado en dqm_validacion_campo.
-- ============================================================

INSERT INTO public.dqm_validacion_campo (tabla, campo, control, resultado, cant_errores, detalle, fecha_control)
SELECT 'txt_customers', 'country', 'POST_LIMPIEZA_SIN_MX',
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'Corrección aplicada: no quedan registros con country=MX'
         ELSE 'ALERTA: aún existen registros con country=MX' END,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires'
FROM public.txt_customers WHERE country = 'MX';


-- ============================================================
-- 4. CIERRE DE LOG
-- ============================================================

UPDATE public.dqm_execution_log
SET fecha_fin      = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado      = CASE
        WHEN EXISTS (
            SELECT 1 FROM public.dqm_validacion_campo
            WHERE control = 'POST_LIMPIEZA_SIN_MX' AND resultado = 'ERROR'
        ) THEN 'ERROR'
        ELSE 'OK'
    END,
    detalle        = 'Limpieza completada. Registros MX corregidos a Mexico: ' ||
                     (SELECT COUNT(*) FROM public.txt_customers WHERE country = 'Mexico'),
    registros_proc = (SELECT COUNT(*) FROM public.txt_customers WHERE country = 'Mexico')
WHERE script_id = (
    SELECT script_id FROM public.dqm_script_inventory WHERE script_nombre = '05_limpieza_datos_txt'
)
AND resultado = 'EN_PROCESO';


-- ============================================================
-- 5. CONSULTA DE VERIFICACIÓN
-- ============================================================

SELECT customer_id, country
FROM public.txt_customers
WHERE country IN ('MX', 'Mexico')
ORDER BY country, customer_id;
