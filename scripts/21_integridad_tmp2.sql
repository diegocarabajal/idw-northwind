-- ============================================================
-- SCRIPT: 21_integridad_tmp2
-- Descripcion: Valida integridad referencial y decide rechazos parciales.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.


INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('21_integridad_tmp2', 'Validacion de integridad referencial de TMP2 contra DWA/TMP', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES ((SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '21_integridad_tmp2'),
        NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires', 'EN_PROCESO', 'Iniciando controles de integridad TMP2');

-- Indicador: ordenes con cliente inexistente en DWA. Deberia detectar XXXXX.
INSERT INTO data_warehouse.dqm_indicador (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '21_integridad_tmp2')),
       'tmp2_orders','customer_id','PCT_FK_CLIENTE_INVALIDA','Porcentaje de ordenes cuyo cliente no existe en dwa_dim_cliente',
       CASE WHEN COUNT(*)=0 THEN 0 ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE c.sk_cliente IS NULL) / COUNT(*),4) END,
       0, 0,
       CASE WHEN COUNT(*) FILTER (WHERE c.sk_cliente IS NULL) = 0 THEN 'OK' ELSE 'ERROR' END
FROM data_warehouse.tmp2_orders o
LEFT JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id = o.customer_id;

INSERT INTO data_warehouse.dqm_registro_rechazado (log_id, tabla_origen, clave_registro, motivo_rechazo, decision)
SELECT (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '21_integridad_tmp2')),
       'tmp2_orders', o.order_id::TEXT, 'Cliente inexistente en DWA: ' || o.customer_id, 'RECHAZADO_PARCIAL'
FROM data_warehouse.tmp2_orders o
LEFT JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id = o.customer_id
WHERE c.sk_cliente IS NULL;

INSERT INTO data_warehouse.dqm_indicador (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '21_integridad_tmp2')),
       'tmp2_orders','employee_id','PCT_FK_EMPLEADO_INVALIDA','Ordenes cuyo empleado no existe en dwa_dim_empleado',
       CASE WHEN COUNT(*)=0 THEN 0 ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE e.sk_empleado IS NULL) / COUNT(*),4) END,
       0, 0,
       CASE WHEN COUNT(*) FILTER (WHERE e.sk_empleado IS NULL) = 0 THEN 'OK' ELSE 'ERROR' END
FROM data_warehouse.tmp2_orders o
LEFT JOIN data_warehouse.dwa_dim_empleado e ON e.nk_employee_id = o.employee_id
WHERE o.employee_id IS NOT NULL;

INSERT INTO data_warehouse.dqm_indicador (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '21_integridad_tmp2')),
       'tmp2_order_details','product_id','PCT_FK_PRODUCTO_INVALIDA','Detalles cuyo producto no existe ni en DWA ni en novedades de producto',
       CASE WHEN COUNT(*)=0 THEN 0 ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE dp.sk_producto IS NULL AND p2.product_id IS NULL) / COUNT(*),4) END,
       0, 0,
       CASE WHEN COUNT(*) FILTER (WHERE dp.sk_producto IS NULL AND p2.product_id IS NULL) = 0 THEN 'OK' ELSE 'ERROR' END
FROM data_warehouse.tmp2_order_details od
LEFT JOIN data_warehouse.dwa_dim_producto dp ON dp.nk_product_id = od.product_id
LEFT JOIN data_warehouse.tmp2_products p2 ON p2.product_id = od.product_id;

INSERT INTO data_warehouse.dqm_indicador (log_id, tabla, campo, indicador, descripcion, valor_calculado, umbral_warning, umbral_error, resultado)
SELECT (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '21_integridad_tmp2')),
       'tmp2_customers_score','customer_id','PCT_SCORE_CLIENTE_INVALIDO','Scores cuyo cliente no existe en DWA',
       CASE WHEN COUNT(*)=0 THEN 0 ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE c.sk_cliente IS NULL) / COUNT(*),4) END,
       0, 5,
       CASE WHEN COUNT(*) FILTER (WHERE c.sk_cliente IS NULL) = 0 THEN 'OK'
            WHEN ROUND(100.0 * COUNT(*) FILTER (WHERE c.sk_cliente IS NULL) / COUNT(*),4) <= 5 THEN 'WARNING'
            ELSE 'ERROR' END
FROM data_warehouse.tmp2_customers_score s
LEFT JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id = s.customer_id;

UPDATE data_warehouse.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = CASE WHEN EXISTS (
        SELECT 1 FROM data_warehouse.dqm_indicador i
        WHERE i.log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '21_integridad_tmp2'))
          AND i.resultado = 'ERROR'
    ) THEN 'WARNING' ELSE 'OK' END,
    detalle = 'Integridad TMP2 finalizada. Se permite carga parcial: las filas invalidas quedan en dqm_registro_rechazado.',
    registros_proc = (SELECT COUNT(*) FROM data_warehouse.dqm_indicador WHERE log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '21_integridad_tmp2')))
WHERE log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '21_integridad_tmp2'));
