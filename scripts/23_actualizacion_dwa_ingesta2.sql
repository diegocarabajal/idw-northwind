-- ============================================================
-- SCRIPT: 23_actualizacion_dwa_ingesta2
-- Descripcion: Aplica altas/modificaciones/bajas logicas al DWA.
-- Etapa: Actualizacion
-- ============================================================
-- IMPORTANTE:
-- Estos scripts asumen que ya corriste los scripts 01 a 15 de Diego
-- y que las tablas viven en el esquema data_warehouse.
-- Motor esperado: PostgreSQL / Supabase SQL.
--
-- Correcciones aplicadas:
-- 1) Se usa la columna real customer_score_segmento.
-- 2) Si hay FK de cliente invalida, el log cierra en WARNING y la carga queda parcial.
-- ============================================================

INSERT INTO data_warehouse.dqm_script_inventory (script_nombre, script_desc, etapa)
VALUES ('23_actualizacion_dwa_ingesta2', 'Actualizacion DWA con novedades de Ingesta2', 'actualizacion')
ON CONFLICT (script_nombre) DO NOTHING;

INSERT INTO data_warehouse.dqm_execution_log (script_id, fecha_inicio, resultado, detalle)
VALUES ((SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '23_actualizacion_dwa_ingesta2'),
        NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires', 'EN_PROCESO', 'Iniciando actualizacion DWA Ingesta2');

-- 1) Alta/actualizacion de paises.
INSERT INTO data_warehouse.dwa_dim_pais
    (country_name, abbreviation, capital_major_city, currency_code, population, gdp, life_expectancy, unemployment_rate, urban_population, latitude, longitude)
SELECT country, abbreviation, capital_major_city, currency_code, population, gdp, life_expectancy, unemployment_rate, urban_population, latitude, longitude
FROM data_warehouse.tmp2_world_data_2023
WHERE country IS NOT NULL
ON CONFLICT (country_name) DO UPDATE SET
    abbreviation = EXCLUDED.abbreviation,
    capital_major_city = EXCLUDED.capital_major_city,
    currency_code = EXCLUDED.currency_code,
    population = EXCLUDED.population,
    gdp = EXCLUDED.gdp,
    life_expectancy = EXCLUDED.life_expectancy,
    unemployment_rate = EXCLUDED.unemployment_rate,
    urban_population = EXCLUDED.urban_population,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude;

-- 2) Clientes: si existe, actualiza; si no existe, inserta alta.
INSERT INTO data_warehouse.dwa_dim_cliente
    (nk_customer_id, company_name, contact_name, contact_title, city, region, country, sk_pais)
SELECT c.customer_id, c.company_name, c.contact_name, c.contact_title, c.city, c.region, c.country, p.sk_pais
FROM data_warehouse.tmp2_customers c
LEFT JOIN data_warehouse.dwa_dim_pais p ON p.country_name = c.country
ON CONFLICT (nk_customer_id) DO UPDATE SET
    company_name = EXCLUDED.company_name,
    contact_name = EXCLUDED.contact_name,
    contact_title = EXCLUDED.contact_title,
    city = EXCLUDED.city,
    region = EXCLUDED.region,
    country = EXCLUDED.country,
    sk_pais = EXCLUDED.sk_pais;

-- 2b) Propagar sk_pais a todos los clientes existentes que no vinieron en esta ingesta.
UPDATE data_warehouse.dwa_dim_cliente c
SET sk_pais = p.sk_pais
FROM data_warehouse.dwa_dim_pais p
WHERE p.country_name = c.country
  AND c.sk_pais IS NULL;

-- 3) Score de clientes.
-- Solo llega a TMP2 el score valido. En esta base la columna se llama customer_score_segmento.
UPDATE data_warehouse.dwa_dim_cliente c
SET customer_score = s.score,
    customer_score_segmento = CASE
        WHEN s.score >= 4 THEN 'ALTO'
        WHEN s.score = 3 THEN 'MEDIO'
        ELSE 'BAJO'
    END
FROM data_warehouse.tmp2_customers_score s
WHERE c.nk_customer_id = s.customer_id;

-- 4) Productos: altas/modificaciones y baja logica si discontinued = 1.
INSERT INTO data_warehouse.dwa_dim_producto
    (nk_product_id, product_name, precio_lista, discontinued, category_name, category_description, supplier_name, supplier_country, sk_pais_supplier)
SELECT p.product_id, p.product_name, p.unit_price, (p.discontinued = 1),
       c.category_name, c.description, s.company_name, s.country, dpais.sk_pais
FROM data_warehouse.tmp2_products p
LEFT JOIN data_warehouse.tmp_categories c ON c.category_id = p.category_id
LEFT JOIN data_warehouse.tmp_suppliers s ON s.supplier_id = p.supplier_id
LEFT JOIN data_warehouse.dwa_dim_pais dpais ON dpais.country_name = s.country
ON CONFLICT (nk_product_id) DO UPDATE SET
    product_name = EXCLUDED.product_name,
    precio_lista = EXCLUDED.precio_lista,
    discontinued = EXCLUDED.discontinued,
    category_name = EXCLUDED.category_name,
    category_description = EXCLUDED.category_description,
    supplier_name = EXCLUDED.supplier_name,
    supplier_country = EXCLUDED.supplier_country,
    sk_pais_supplier = EXCLUDED.sk_pais_supplier;

-- 4b) Propagar sk_pais_supplier a todos los productos existentes sin FK de pais.
UPDATE data_warehouse.dwa_dim_producto pr
SET sk_pais_supplier = p.sk_pais
FROM data_warehouse.dwa_dim_pais p
WHERE p.country_name = pr.supplier_country
  AND pr.sk_pais_supplier IS NULL;

-- 5) Dimension tiempo: agrega fechas nuevas de Ingesta2.
INSERT INTO data_warehouse.dwa_dim_tiempo
    (sk_tiempo, fecha, anio, trimestre, mes, nombre_mes, semana_anio, dia, dia_semana, nombre_dia, es_fin_de_semana)
SELECT DISTINCT
    TO_CHAR(d.fecha, 'YYYYMMDD')::INT,
    d.fecha,
    EXTRACT(YEAR FROM d.fecha)::INT,
    EXTRACT(QUARTER FROM d.fecha)::INT,
    EXTRACT(MONTH FROM d.fecha)::INT,
    CASE EXTRACT(MONTH FROM d.fecha)
        WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo' WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio' WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Septiembre' WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
    END,
    EXTRACT(WEEK FROM d.fecha)::INT,
    EXTRACT(DAY FROM d.fecha)::INT,
    EXTRACT(ISODOW FROM d.fecha)::INT,
    CASE EXTRACT(ISODOW FROM d.fecha)
        WHEN 1 THEN 'Lunes' WHEN 2 THEN 'Martes' WHEN 3 THEN 'Miércoles' WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes' WHEN 6 THEN 'Sabado' WHEN 7 THEN 'Domingo'
    END,
    EXTRACT(ISODOW FROM d.fecha) IN (6,7)
FROM (
    SELECT order_date AS fecha FROM data_warehouse.tmp2_orders WHERE order_date IS NOT NULL
    UNION SELECT required_date FROM data_warehouse.tmp2_orders WHERE required_date IS NOT NULL
    UNION SELECT shipped_date FROM data_warehouse.tmp2_orders WHERE shipped_date IS NOT NULL
) d
ON CONFLICT (sk_tiempo) DO NOTHING;

-- 6) Hechos: se cargan solo lineas cuyas FK son validas.
-- La orden 11078 queda afuera si customer_id = XXXXX.
WITH lineas_por_orden AS (
    SELECT order_id, COUNT(*) AS cant_lineas
    FROM data_warehouse.tmp2_order_details
    GROUP BY order_id
), base AS (
    SELECT
        TO_CHAR(o.order_date, 'YYYYMMDD')::INT AS sk_tiempo,
        dc.sk_cliente,
        de.sk_empleado,
        dp.sk_producto,
        ds.sk_shipper,
        od.order_id AS nk_order_id,
        od.quantity AS cantidad,
        od.unit_price AS precio_unitario,
        od.discount AS descuento,
        COALESCE(o.freight,0) / NULLIF(l.cant_lineas,0) AS flete_prorrateado,
        od.quantity * od.unit_price AS monto_bruto,
        od.quantity * od.unit_price * od.discount AS monto_descuento,
        od.quantity * od.unit_price * (1 - od.discount) AS monto_neto
    FROM data_warehouse.tmp2_order_details od
    JOIN data_warehouse.tmp2_orders o ON o.order_id = od.order_id
    JOIN lineas_por_orden l ON l.order_id = od.order_id
    JOIN data_warehouse.dwa_dim_cliente dc ON dc.nk_customer_id = o.customer_id
    LEFT JOIN data_warehouse.dwa_dim_empleado de ON de.nk_employee_id = o.employee_id
    JOIN data_warehouse.dwa_dim_producto dp ON dp.nk_product_id = od.product_id
    LEFT JOIN data_warehouse.dwa_dim_shipper ds ON ds.nk_shipper_id = o.ship_via
)
INSERT INTO data_warehouse.dwa_fact_ventas
    (sk_tiempo, sk_cliente, sk_empleado, sk_producto, sk_shipper, nk_order_id,
     cantidad, precio_unitario, descuento, flete_prorrateado, monto_bruto, monto_descuento, monto_neto)
SELECT * FROM base
ON CONFLICT (nk_order_id, sk_producto) DO UPDATE SET
    sk_tiempo = EXCLUDED.sk_tiempo,
    sk_cliente = EXCLUDED.sk_cliente,
    sk_empleado = EXCLUDED.sk_empleado,
    sk_shipper = EXCLUDED.sk_shipper,
    cantidad = EXCLUDED.cantidad,
    precio_unitario = EXCLUDED.precio_unitario,
    descuento = EXCLUDED.descuento,
    flete_prorrateado = EXCLUDED.flete_prorrateado,
    monto_bruto = EXCLUDED.monto_bruto,
    monto_descuento = EXCLUDED.monto_descuento,
    monto_neto = EXCLUDED.monto_neto;

-- Huella DQM de cargas.
INSERT INTO data_warehouse.dqm_carga_dwa (log_id, tabla_destino, registros_leidos, registros_insertados, registros_rechazados, decision, motivo_rechazo)
VALUES
((SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '23_actualizacion_dwa_ingesta2')),
 'dwa_dim_pais', (SELECT COUNT(*) FROM data_warehouse.tmp2_world_data_2023), (SELECT COUNT(*) FROM data_warehouse.tmp2_world_data_2023), 0, 'CARGADO', NULL),
((SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '23_actualizacion_dwa_ingesta2')),
 'dwa_dim_cliente', (SELECT COUNT(*) FROM data_warehouse.tmp2_customers), (SELECT COUNT(*) FROM data_warehouse.tmp2_customers), 0, 'CARGADO', NULL),
((SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '23_actualizacion_dwa_ingesta2')),
 'dwa_dim_producto', (SELECT COUNT(*) FROM data_warehouse.tmp2_products), (SELECT COUNT(*) FROM data_warehouse.tmp2_products), 0, 'CARGADO', NULL),
((SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '23_actualizacion_dwa_ingesta2')),
 'dwa_fact_ventas', (SELECT COUNT(*) FROM data_warehouse.tmp2_order_details),
 (SELECT COUNT(*) FROM data_warehouse.tmp2_order_details od JOIN data_warehouse.tmp2_orders o ON o.order_id=od.order_id JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id=o.customer_id),
 (SELECT COUNT(*) FROM data_warehouse.tmp2_order_details od JOIN data_warehouse.tmp2_orders o ON o.order_id=od.order_id LEFT JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id=o.customer_id WHERE c.sk_cliente IS NULL),
 CASE WHEN EXISTS (SELECT 1 FROM data_warehouse.tmp2_orders o LEFT JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id=o.customer_id WHERE c.sk_cliente IS NULL) THEN 'CARGADO_PARCIAL' ELSE 'CARGADO' END,
 CASE WHEN EXISTS (SELECT 1 FROM data_warehouse.tmp2_orders o LEFT JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id=o.customer_id WHERE c.sk_cliente IS NULL)
      THEN 'Se rechazan lineas de ordenes con FK invalida. Ver dqm_registro_rechazado.' ELSE NULL END);

UPDATE data_warehouse.dqm_execution_log
SET fecha_fin = NOW() AT TIME ZONE 'America/Argentina/Buenos_Aires',
    resultado = CASE WHEN EXISTS (
        SELECT 1
        FROM data_warehouse.tmp2_orders o
        LEFT JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id = o.customer_id
        WHERE c.sk_cliente IS NULL
    ) THEN 'WARNING' ELSE 'OK' END,
    detalle = CASE WHEN EXISTS (
        SELECT 1
        FROM data_warehouse.tmp2_orders o
        LEFT JOIN data_warehouse.dwa_dim_cliente c ON c.nk_customer_id = o.customer_id
        WHERE c.sk_cliente IS NULL
    ) THEN 'Actualizacion DWA finalizada con carga parcial. Existen ordenes rechazadas por FK cliente invalida.'
      ELSE 'Actualizacion DWA finalizada correctamente.' END,
    registros_proc = (SELECT COUNT(*) FROM data_warehouse.tmp2_customers) + (SELECT COUNT(*) FROM data_warehouse.tmp2_products) + (SELECT COUNT(*) FROM data_warehouse.tmp2_order_details)
WHERE log_id = (SELECT MAX(log_id) FROM data_warehouse.dqm_execution_log WHERE script_id = (SELECT script_id FROM data_warehouse.dqm_script_inventory WHERE script_nombre = '23_actualizacion_dwa_ingesta2'));
