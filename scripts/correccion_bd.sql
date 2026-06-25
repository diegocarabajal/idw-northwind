-- ============================================================
-- SCRIPT: correccion_bd
-- Descripcion: Correcciones silenciosas sobre el estado actual del DWA.
--              No registra en dqm_script_inventory ni dqm_execution_log.
--              Deja la base como si los scripts 21, 23, 24 y 25 hubieran
--              sido ejecutados ya en su version corregida.
-- Etapa: Actualizacion (correctivo post-ejecucion)
-- Motor esperado: PostgreSQL / Supabase SQL.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1) Vincular sk_pais para los 89 clientes sin FK de pais.
--    (Script 23 original solo seteaba los 2 del upsert.)
-- ─────────────────────────────────────────────────────────────
UPDATE data_warehouse.dwa_dim_cliente c
SET sk_pais = p.sk_pais
FROM data_warehouse.dwa_dim_pais p
WHERE p.country_name = c.country
  AND c.sk_pais IS NULL;

-- ─────────────────────────────────────────────────────────────
-- 2) Vincular sk_pais_supplier para todos los productos.
--    (Script 23 original no propagaba esta FK a productos de Ingesta1.)
-- ─────────────────────────────────────────────────────────────
UPDATE data_warehouse.dwa_dim_producto pr
SET sk_pais_supplier = p.sk_pais
FROM data_warehouse.dwa_dim_pais p
WHERE p.country_name = pr.supplier_country
  AND pr.sk_pais_supplier IS NULL;

-- ─────────────────────────────────────────────────────────────
-- 3) Recalcular dwa_enr_cliente con NTILE(5) y COUNT correcto.
--    Script 24 original usaba PERCENT_RANK y COUNT(*) (incorrecto
--    para clientes sin ventas con LEFT JOIN).
-- ─────────────────────────────────────────────────────────────
TRUNCATE data_warehouse.dwa_enr_cliente;

WITH agg AS (
    SELECT
        c.sk_cliente,
        COUNT(DISTINCT f.nk_order_id)                                AS total_pedidos,
        COUNT(f.nk_order_id)                                         AS total_lineas,
        SUM(f.monto_neto)                                            AS monto_total_neto,
        SUM(f.monto_neto) / NULLIF(COUNT(DISTINCT f.nk_order_id),0) AS monto_promedio_pedido,
        MIN(t.fecha)                                                  AS primer_pedido,
        MAX(t.fecha)                                                  AS ultimo_pedido
    FROM data_warehouse.dwa_dim_cliente c
    LEFT JOIN data_warehouse.dwa_fact_ventas f  ON f.sk_cliente = c.sk_cliente
    LEFT JOIN data_warehouse.dwa_dim_tiempo  t  ON t.sk_tiempo  = f.sk_tiempo
    GROUP BY c.sk_cliente
), segmentado AS (
    SELECT *, NTILE(5) OVER (ORDER BY COALESCE(monto_total_neto,0)) AS tile
    FROM agg
)
INSERT INTO data_warehouse.dwa_enr_cliente
    (sk_cliente, total_pedidos, total_lineas, monto_total_neto, monto_promedio_pedido,
     primer_pedido, ultimo_pedido, dias_como_cliente, segmento)
SELECT
    sk_cliente,
    total_pedidos,
    total_lineas,
    COALESCE(monto_total_neto, 0),
    monto_promedio_pedido,
    primer_pedido,
    ultimo_pedido,
    CASE WHEN primer_pedido IS NULL THEN NULL ELSE (ultimo_pedido - primer_pedido) END,
    CASE WHEN tile = 5 THEN 'PREMIUM' WHEN tile >= 2 THEN 'REGULAR' ELSE 'BAJO' END
FROM segmentado;

-- ─────────────────────────────────────────────────────────────
-- 4) Recalcular dwa_enr_producto con NTILE(5).
--    Script 24 original usaba PERCENT_RANK.
-- ─────────────────────────────────────────────────────────────
TRUNCATE data_warehouse.dwa_enr_producto;

WITH agg AS (
    SELECT
        p.sk_producto,
        COUNT(DISTINCT f.nk_order_id)                                AS total_pedidos,
        COALESCE(SUM(f.cantidad),0)                                  AS total_unidades,
        COALESCE(SUM(f.monto_neto),0)                                AS revenue_total,
        SUM(f.monto_neto) / NULLIF(COUNT(DISTINCT f.nk_order_id),0) AS revenue_promedio_pedido
    FROM data_warehouse.dwa_dim_producto p
    LEFT JOIN data_warehouse.dwa_fact_ventas f ON f.sk_producto = p.sk_producto
    GROUP BY p.sk_producto
), segmentado AS (
    SELECT *,
        RANK()   OVER (ORDER BY revenue_total DESC) AS rk,
        NTILE(5) OVER (ORDER BY revenue_total)      AS tile
    FROM agg
)
INSERT INTO data_warehouse.dwa_enr_producto
    (sk_producto, total_pedidos, total_unidades, revenue_total, revenue_promedio_pedido,
     rank_revenue, performance)
SELECT
    sk_producto,
    total_pedidos,
    total_unidades,
    revenue_total,
    revenue_promedio_pedido,
    rk,
    CASE WHEN tile = 5 THEN 'TOP' WHEN tile >= 2 THEN 'MID' ELSE 'LOW' END
FROM segmentado;

-- ─────────────────────────────────────────────────────────────
-- 5) Eliminar registro duplicado en dqm_registro_rechazado.
--    Script 21 se ejecuto dos veces → orden 11078 quedó duplicada.
--    Se conserva la primera insercion (menor rechazo_id).
-- ─────────────────────────────────────────────────────────────
DELETE FROM data_warehouse.dqm_registro_rechazado
WHERE rechazo_id IN (
    SELECT rechazo_id
    FROM (
        SELECT rechazo_id,
               ROW_NUMBER() OVER (PARTITION BY clave_registro ORDER BY rechazo_id) AS rn
        FROM data_warehouse.dqm_registro_rechazado
        WHERE clave_registro = '11078'
    ) sub
    WHERE rn > 1
);

-- ─────────────────────────────────────────────────────────────
-- 6) Agregar entrada dqm_carga_dwa para dwa_dim_producto
--    que faltaba en la ejecucion del script 23.
-- ─────────────────────────────────────────────────────────────
INSERT INTO data_warehouse.dqm_carga_dwa
    (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
SELECT
    (SELECT log_id FROM data_warehouse.dqm_execution_log
     WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory
                        WHERE script_nombre = '23_actualizacion_dwa_ingesta2')
     ORDER BY log_id
     LIMIT 1),
    'dwa_dim_producto',
    (SELECT COUNT(*) FROM data_warehouse.tmp2_products),
    (SELECT COUNT(*) FROM data_warehouse.tmp2_products),
    0, 'CARGADO', NULL
WHERE NOT EXISTS (
    SELECT 1 FROM data_warehouse.dqm_carga_dwa
    WHERE tabla_destino = 'dwa_dim_producto'
      AND log_id = (SELECT log_id FROM data_warehouse.dqm_execution_log
                   WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory
                                      WHERE script_nombre = '23_actualizacion_dwa_ingesta2')
                   ORDER BY log_id
                   LIMIT 1)
);

-- ─────────────────────────────────────────────────────────────
-- 7) Completar met_entidades: columnas faltantes de dwa_dim_pais
--    y de dqm_registro_rechazado que script 25 no incluyó.
-- ─────────────────────────────────────────────────────────────
INSERT INTO data_warehouse.met_entidades
    (nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
SELECT * FROM (VALUES
    ('dwa_dim_pais','abbreviation','VARCHAR(10)','Codigo o abreviatura del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','capital_major_city','VARCHAR(100)','Capital o ciudad principal del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','currency_code','VARCHAR(10)','Codigo de moneda del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','population','BIGINT','Poblacion total del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','gdp','NUMERIC(20,2)','Producto Bruto Interno del pais en USD','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','life_expectancy','NUMERIC(10,4)','Expectativa de vida promedio en anos','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','unemployment_rate','NUMERIC(10,4)','Tasa de desempleo del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','urban_population','BIGINT','Poblacion urbana del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','latitude','NUMERIC(12,8)','Latitud geografica del centroide del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dwa_dim_pais','longitude','NUMERIC(12,8)','Longitud geografica del centroide del pais','dim',FALSE,FALSE,NULL,NULL,TRUE),
    ('dqm_registro_rechazado','log_id','INT','FK a la ejecucion del script que genero el rechazo','dqm',FALSE,TRUE,'dqm_execution_log','log_id',TRUE),
    ('dqm_registro_rechazado','tabla_origen','VARCHAR(100)','Tabla de la cual proviene el registro rechazado','dqm',FALSE,FALSE,NULL,NULL,FALSE),
    ('dqm_registro_rechazado','clave_registro','VARCHAR(200)','Identificador del registro rechazado (PK o NK)','dqm',FALSE,FALSE,NULL,NULL,TRUE),
    ('dqm_registro_rechazado','decision','VARCHAR(30)','Resultado del rechazo: RECHAZADO o RECHAZADO_PARCIAL','dqm',FALSE,FALSE,NULL,NULL,FALSE),
    ('dqm_registro_rechazado','fecha_rechazo','TIMESTAMP','Fecha y hora del rechazo en zona horaria Argentina','dqm',FALSE,FALSE,NULL,NULL,FALSE)
) AS v(nombre_tabla, nombre_columna, tipo_dato, descripcion, capa_dwh, es_pk, es_fk, tabla_referencia, columna_referencia, nullable)
WHERE NOT EXISTS (
    SELECT 1 FROM data_warehouse.met_entidades m
    WHERE m.nombre_tabla = v.nombre_tabla AND m.nombre_columna = v.nombre_columna
);
