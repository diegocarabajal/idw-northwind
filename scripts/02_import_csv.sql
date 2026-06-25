-- ============================================================
-- SCRIPT: 02_Log_Importacion_CSV
-- Descripción: Registra en el DQM la carga manual de los CSV
--              de Ingesta1 en la capa TXT_ mediante DBeaver
--              Import Data. No es un script ejecutable sino un
--              registro documental del proceso realizado.
-- Etapa: Adquisición
-- Autores: Sofia Cremydas, Jorge Barbona, Nicolas Caggiano, Diego Carabajal
-- Fecha: 2026-06-02
-- ============================================================

INSERT INTO public.dqm_execution_log (
    script_id, fecha_inicio, fecha_fin, resultado, detalle, registros_proc
)
VALUES (
    2,
    NULL,
    NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    'OK',
    'CSV de Ingesta1 importados manualmente via DBeaver Import Data. Separador ";" en customers.csv.',
    3311
);