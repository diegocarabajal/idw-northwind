"""
Northwind DWA — Dashboard
=========================
Tab 1: Métricas de Ventas   (fuente: tablas dp_)
Tab 2: Analítica del DW     (fuente: tablas dqm_)

Conexión: PostgreSQL en Supabase via SQLAlchemy.
La URL de conexión se configura en .streamlit/secrets.toml (local)
o en Settings > Secrets de Streamlit Community Cloud (producción).
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from sqlalchemy import create_engine, text

# ─────────────────────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────────────────────

st.set_page_config(
    page_title="Northwind DWA",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# Paleta corporativa
COLOR_PRIMARY   = "#1f77b4"
COLOR_SUCCESS   = "#2ca02c"
COLOR_WARNING   = "#ff7f0e"
COLOR_DANGER    = "#d62728"
COLOR_SEQ       = px.colors.sequential.Blues

SCHEMA = "data_warehouse"


# ─────────────────────────────────────────────────────────────
# CONEXIÓN
# ─────────────────────────────────────────────────────────────

@st.cache_resource
def get_engine():
    raw_url = st.secrets["db"]["url"]
    # psycopg3 requiere el prefijo postgresql+psycopg://
    url = (raw_url
           .replace("postgresql+psycopg2://", "postgresql+psycopg://")
           .replace("postgresql://", "postgresql+psycopg://")
           .replace("postgres://", "postgresql+psycopg://"))
    return create_engine(url, pool_pre_ping=True,
                         connect_args={"sslmode": "require"})


@st.cache_data(ttl=300)  # cache 5 min
def run_query(sql: str) -> pd.DataFrame:
    engine = get_engine()
    with engine.connect() as conn:
        return pd.read_sql(text(sql), conn)


# ─────────────────────────────────────────────────────────────
# HEADER
# ─────────────────────────────────────────────────────────────

st.title("📊 Northwind — Data Warehouse Analítico")
st.caption("Universidad Austral · Introducción a Data Warehousing · Trabajo Final")
st.divider()

tab_ventas, tab_dw = st.tabs(["📈 Métricas de Ventas", "🔍 Analítica del DW"])


# ═════════════════════════════════════════════════════════════
# TAB 1 — MÉTRICAS DE VENTAS
# ═════════════════════════════════════════════════════════════

with tab_ventas:

    # ── Filtro de año ──────────────────────────────────────
    df_anios = run_query(f"""
        SELECT DISTINCT anio FROM {SCHEMA}.dp_ventas_por_periodo ORDER BY anio
    """)
    anios_disponibles = ["Todos"] + df_anios["anio"].astype(str).tolist()
    anio_sel = st.selectbox("Filtrar por año", anios_disponibles, index=0)

    filtro_periodo = "" if anio_sel == "Todos" else f"WHERE anio = {anio_sel}"
    filtro_cliente = "" if anio_sel == "Todos" else f"""
        WHERE sk_cliente IN (
            SELECT DISTINCT f.sk_cliente
            FROM {SCHEMA}.dwa_fact_ventas f
            JOIN {SCHEMA}.dwa_dim_tiempo  t ON t.sk_tiempo = f.sk_tiempo
            WHERE t.anio = {anio_sel}
        )
    """
    filtro_producto = "" if anio_sel == "Todos" else f"""
        WHERE sk_producto IN (
            SELECT DISTINCT f.sk_producto
            FROM {SCHEMA}.dwa_fact_ventas f
            JOIN {SCHEMA}.dwa_dim_tiempo  t ON t.sk_tiempo = f.sk_tiempo
            WHERE t.anio = {anio_sel}
        )
    """

    # ── KPIs globales ──────────────────────────────────────
    df_kpi = run_query(f"""
        SELECT
            SUM(total_pedidos)              AS pedidos,
            SUM(total_lineas)               AS lineas,
            SUM(total_clientes)             AS clientes,
            ROUND(SUM(monto_neto)::NUMERIC, 2)           AS revenue,
            ROUND(AVG(ticket_promedio)::NUMERIC, 2)      AS ticket_prom
        FROM {SCHEMA}.dp_ventas_por_periodo
        {filtro_periodo}
    """)

    k = df_kpi.iloc[0]
    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("💼 Pedidos",          f"{int(k['pedidos']):,}")
    c2.metric("📦 Líneas de detalle", f"{int(k['lineas']):,}")
    c3.metric("👥 Clientes activos",  f"{int(k['clientes']):,}")
    c4.metric("💰 Revenue neto",      f"USD {float(k['revenue']):,.0f}")
    c5.metric("🎯 Ticket promedio",   f"USD {float(k['ticket_prom']):,.0f}")

    st.divider()

    # ── Evolución temporal ─────────────────────────────────
    st.subheader("Evolución de ventas")

    df_periodo = run_query(f"""
        SELECT
            anio, trimestre, mes, nombre_mes,
            monto_neto, total_pedidos,
            CONCAT(anio, '-', LPAD(mes::TEXT, 2, '0')) AS periodo_label
        FROM {SCHEMA}.dp_ventas_por_periodo
        {filtro_periodo}
        ORDER BY anio, mes
    """)

    col_left, col_right = st.columns(2)

    with col_left:
        fig_rev = px.bar(
            df_periodo, x="periodo_label", y="monto_neto",
            labels={"periodo_label": "Periodo", "monto_neto": "Revenue neto (USD)"},
            color="monto_neto", color_continuous_scale=COLOR_SEQ,
            title="Revenue neto por mes",
        )
        fig_rev.update_coloraxes(showscale=False)
        fig_rev.update_layout(xaxis_tickangle=-45)
        st.plotly_chart(fig_rev, use_container_width=True)

    with col_right:
        fig_ped = px.line(
            df_periodo, x="periodo_label", y="total_pedidos",
            markers=True,
            labels={"periodo_label": "Periodo", "total_pedidos": "Pedidos"},
            title="Cantidad de pedidos por mes",
            color_discrete_sequence=[COLOR_PRIMARY],
        )
        fig_ped.update_layout(xaxis_tickangle=-45)
        st.plotly_chart(fig_ped, use_container_width=True)

    st.divider()

    # ── Clientes y Productos ───────────────────────────────
    st.subheader("Clientes y Productos")

    col_a, col_b = st.columns(2)

    with col_a:
        df_cli = run_query(f"""
            SELECT company_name, monto_neto, segmento, country
            FROM {SCHEMA}.dp_ventas_por_cliente
            {filtro_cliente}
            ORDER BY monto_neto DESC
            LIMIT 15
        """)
        fig_cli = px.bar(
            df_cli, x="monto_neto", y="company_name",
            orientation="h",
            color="segmento",
            color_discrete_map={
                "PREMIUM": "#1f77b4",
                "REGULAR": "#aec7e8",
                "BAJO":    "#d9d9d9",
            },
            labels={"monto_neto": "Revenue neto (USD)", "company_name": ""},
            title="Top 15 clientes por revenue",
        )
        fig_cli.update_layout(yaxis={"categoryorder": "total ascending"}, legend_title="Segmento")
        st.plotly_chart(fig_cli, use_container_width=True)

    with col_b:
        df_prod = run_query(f"""
            SELECT product_name, revenue_total, performance, category_name
            FROM {SCHEMA}.dp_ventas_por_producto
            {filtro_producto}
            ORDER BY revenue_total DESC
            LIMIT 15
        """)
        fig_prod = px.bar(
            df_prod, x="revenue_total", y="product_name",
            orientation="h",
            color="performance",
            color_discrete_map={
                "TOP": "#1f77b4",
                "MID": "#aec7e8",
                "LOW": "#d9d9d9",
            },
            labels={"revenue_total": "Revenue neto (USD)", "product_name": ""},
            title="Top 15 productos por revenue",
        )
        fig_prod.update_layout(yaxis={"categoryorder": "total ascending"}, legend_title="Performance")
        st.plotly_chart(fig_prod, use_container_width=True)

    st.divider()

    # ── Segmentación y Empleados ───────────────────────────
    st.subheader("Segmentación y Performance de vendedores")

    col_c, col_d, col_e = st.columns([1, 1, 2])

    with col_c:
        df_seg = run_query(f"""
            SELECT segmento, COUNT(*) AS cantidad
            FROM {SCHEMA}.dp_ventas_por_cliente
            {filtro_cliente}
            GROUP BY segmento
            ORDER BY segmento
        """)
        fig_seg = px.pie(
            df_seg, names="segmento", values="cantidad",
            color="segmento",
            color_discrete_map={
                "PREMIUM": "#1f77b4",
                "REGULAR": "#aec7e8",
                "BAJO":    "#d9d9d9",
            },
            title="Distribución de clientes por segmento",
            hole=0.4,
        )
        st.plotly_chart(fig_seg, use_container_width=True)

    with col_d:
        df_perf = run_query(f"""
            SELECT performance, COUNT(*) AS productos
            FROM {SCHEMA}.dp_ventas_por_producto
            {filtro_producto}
            GROUP BY performance
            ORDER BY performance
        """)
        fig_perf = px.pie(
            df_perf, names="performance", values="productos",
            color="performance",
            color_discrete_map={
                "TOP": "#1f77b4",
                "MID": "#aec7e8",
                "LOW": "#d9d9d9",
            },
            title="Distribución de productos por performance",
            hole=0.4,
        )
        st.plotly_chart(fig_perf, use_container_width=True)

    with col_e:
        df_emp = run_query(f"""
            SELECT nombre_completo, monto_neto, total_pedidos, total_clientes, title, rank_empleado
            FROM {SCHEMA}.dp_ventas_por_empleado
            ORDER BY rank_empleado
        """)
        st.markdown("**Ranking de vendedores**")
        st.dataframe(
            df_emp.rename(columns={
                "nombre_completo": "Vendedor",
                "title":           "Cargo",
                "monto_neto":      "Revenue (USD)",
                "total_pedidos":   "Pedidos",
                "total_clientes":  "Clientes",
                "rank_empleado":   "Rank",
            }).style.format({"Revenue (USD)": "{:,.0f}"}),
            hide_index=True,
            use_container_width=True,
        )

    st.divider()

    # ── Mapa geográfico ────────────────────────────────────
    st.subheader("Distribución geográfica de ventas")

    df_geo = run_query(f"""
        SELECT country_name, monto_neto, total_clientes, total_pedidos,
               pct_monto_global, latitude, longitude
        FROM {SCHEMA}.dp_ventas_geografico
        WHERE monto_neto > 0
          AND latitude  IS NOT NULL
          AND longitude IS NOT NULL
    """)

    fig_map = px.scatter_geo(
        df_geo,
        lat="latitude", lon="longitude",
        size="monto_neto",
        color="pct_monto_global",
        hover_name="country_name",
        hover_data={
            "monto_neto":      ":,.0f",
            "total_clientes":  True,
            "total_pedidos":   True,
            "pct_monto_global":":,.2f",
            "latitude":        False,
            "longitude":       False,
        },
        color_continuous_scale=COLOR_SEQ,
        size_max=50,
        projection="natural earth",
        title="Revenue neto por país (tamaño = monto, color = % del total)",
        labels={
            "monto_neto":       "Revenue (USD)",
            "pct_monto_global": "% del total",
            "total_clientes":   "Clientes",
            "total_pedidos":    "Pedidos",
        },
    )
    fig_map.update_layout(height=500)
    st.plotly_chart(fig_map, use_container_width=True)


# ═════════════════════════════════════════════════════════════
# TAB 2 — ANALÍTICA DEL DW
# ═════════════════════════════════════════════════════════════

with tab_dw:

    # ── KPIs del pipeline ──────────────────────────────────
    df_log_kpi = run_query(f"""
        SELECT
            COUNT(*)                                          AS total_ejecuciones,
            SUM(CASE WHEN resultado = 'OK'      THEN 1 END)  AS ok,
            SUM(CASE WHEN resultado = 'WARNING' THEN 1 END)  AS warnings,
            SUM(CASE WHEN resultado = 'ERROR'   THEN 1 END)  AS errores,
            SUM(registros_proc)                               AS total_registros_proc
        FROM {SCHEMA}.dqm_execution_log
    """)
    k2 = df_log_kpi.iloc[0]

    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("🔄 Ejecuciones totales",    f"{int(k2['total_ejecuciones']):,}")
    c2.metric("✅ Finalizadas OK",          f"{int(k2['ok'] or 0):,}")
    c3.metric("⚠️ Con WARNING",            f"{int(k2['warnings'] or 0):,}")
    c4.metric("❌ Con ERROR",              f"{int(k2['errores'] or 0):,}")
    c5.metric("📋 Registros procesados",   f"{int(k2['total_registros_proc'] or 0):,}")

    st.divider()

    # ── Historial de ejecuciones ───────────────────────────
    st.subheader("Historial de ejecuciones de scripts")

    df_log = run_query(f"""
        SELECT
            l.log_id,
            s.script_nombre,
            s.etapa,
            l.fecha_inicio,
            l.fecha_fin,
            l.resultado,
            l.registros_proc,
            l.detalle
        FROM {SCHEMA}.dqm_execution_log l
        JOIN {SCHEMA}.dqm_script_inventory s ON s.script_id = l.script_id
        ORDER BY l.log_id
    """)

    def colorear_resultado(val):
        colores = {
            "OK":         "background-color: #d4edda; color: #155724",
            "WARNING":    "background-color: #fff3cd; color: #856404",
            "ERROR":      "background-color: #f8d7da; color: #721c24",
            "EN_PROCESO": "background-color: #cce5ff; color: #004085",
        }
        return colores.get(val, "")

    st.dataframe(
        df_log.rename(columns={
            "log_id":        "ID",
            "script_nombre": "Script",
            "etapa":         "Etapa",
            "fecha_inicio":  "Inicio",
            "fecha_fin":     "Fin",
            "resultado":     "Resultado",
            "registros_proc":"Registros",
            "detalle":       "Detalle",
        }).style.map(colorear_resultado, subset=["Resultado"]),
        hide_index=True,
        use_container_width=True,
        height=300,
    )

    st.divider()

    # ── Registros cargados por tabla (dqm_carga_dwa) ──────
    st.subheader("Registros cargados por tabla destino")

    df_carga = run_query(f"""
        SELECT
            c.tabla_destino,
            SUM(c.registros_insertados)  AS insertados,
            SUM(c.registros_rechazados)  AS rechazados,
            SUM(c.registros_leidos)      AS leidos
        FROM {SCHEMA}.dqm_carga_dwa c
        GROUP BY c.tabla_destino
        ORDER BY insertados DESC
    """)

    col_f, col_g = st.columns([2, 1])

    with col_f:
        fig_carga = px.bar(
            df_carga, x="insertados", y="tabla_destino",
            orientation="h",
            color="insertados", color_continuous_scale=COLOR_SEQ,
            labels={"insertados": "Registros insertados", "tabla_destino": ""},
            title="Registros insertados por tabla destino",
        )
        fig_carga.update_coloraxes(showscale=False)
        fig_carga.update_layout(yaxis={"categoryorder": "total ascending"})
        st.plotly_chart(fig_carga, use_container_width=True)

    with col_g:
        st.markdown("**Detalle de carga**")
        st.dataframe(
            df_carga.rename(columns={
                "tabla_destino": "Tabla",
                "leidos":        "Leídos",
                "insertados":    "Insertados",
                "rechazados":    "Rechazados",
            }),
            hide_index=True,
            use_container_width=True,
        )

    st.divider()

    # ── Validaciones de calidad ────────────────────────────
    st.subheader("Controles de calidad por tabla (dqm_validacion_campo)")

    df_val = run_query(f"""
        SELECT
            tabla,
            SUM(CASE WHEN resultado = 'OK'    THEN 1 ELSE 0 END) AS ok,
            SUM(CASE WHEN resultado = 'ERROR' THEN 1 ELSE 0 END) AS errores
        FROM {SCHEMA}.dqm_validacion_campo
        GROUP BY tabla
        ORDER BY tabla
    """)

    if not df_val.empty:
        df_val_melt = df_val.melt(id_vars="tabla", var_name="estado", value_name="controles")
        fig_val = px.bar(
            df_val_melt, x="tabla", y="controles", color="estado",
            color_discrete_map={"ok": COLOR_SUCCESS, "errores": COLOR_DANGER},
            barmode="group",
            labels={"tabla": "Tabla", "controles": "Controles", "estado": "Resultado"},
            title="Controles de calidad OK vs ERROR por tabla",
        )
        fig_val.update_layout(xaxis_tickangle=-30)
        st.plotly_chart(fig_val, use_container_width=True)
    else:
        st.info("No hay registros en dqm_validacion_campo.")

    st.divider()

    # ── Registros rechazados ───────────────────────────────
    st.subheader("Registros rechazados (dqm_registro_rechazado)")

    df_rech = run_query(f"""
        SELECT
            r.rechazo_id,
            s.script_nombre,
            r.tabla_origen,
            r.clave_registro,
            r.motivo_rechazo,
            r.decision,
            r.fecha_rechazo
        FROM {SCHEMA}.dqm_registro_rechazado r
        LEFT JOIN {SCHEMA}.dqm_execution_log  l ON l.log_id    = r.log_id
        LEFT JOIN {SCHEMA}.dqm_script_inventory s ON s.script_id = l.script_id
        ORDER BY r.rechazo_id
    """)

    if not df_rech.empty:
        st.dataframe(
            df_rech.rename(columns={
                "rechazo_id":    "ID",
                "script_nombre": "Script",
                "tabla_origen":  "Tabla origen",
                "clave_registro":"Clave",
                "motivo_rechazo":"Motivo",
                "decision":      "Decisión",
                "fecha_rechazo": "Fecha",
            }),
            hide_index=True,
            use_container_width=True,
        )
    else:
        st.success("No hay registros rechazados.")

    st.divider()

    # ── Inventario de scripts ──────────────────────────────
    st.subheader("Inventario de scripts del pipeline")

    df_inv = run_query(f"""
        SELECT
            s.script_id,
            s.script_nombre,
            s.etapa,
            s.script_desc,
            COUNT(l.log_id)  AS veces_ejecutado,
            MAX(l.fecha_fin) AS ultima_ejecucion,
            (SELECT resultado FROM {SCHEMA}.dqm_execution_log
             WHERE script_id = s.script_id
             ORDER BY log_id DESC LIMIT 1) AS ultimo_resultado
        FROM {SCHEMA}.dqm_script_inventory s
        LEFT JOIN {SCHEMA}.dqm_execution_log l ON l.script_id = s.script_id
        GROUP BY s.script_id, s.script_nombre, s.etapa, s.script_desc
        ORDER BY s.script_id
    """)

    st.dataframe(
        df_inv.rename(columns={
            "script_id":        "ID",
            "script_nombre":    "Script",
            "etapa":            "Etapa",
            "script_desc":      "Descripción",
            "veces_ejecutado":  "Ejecuciones",
            "ultima_ejecucion": "Última ejecución",
            "ultimo_resultado": "Último resultado",
        }).style.map(colorear_resultado, subset=["Último resultado"]),
        hide_index=True,
        use_container_width=True,
        height=400,
    )
