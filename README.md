# Northwind — Data Warehouse Analítico

**Universidad Austral · Introducción a Data Warehousing · Trabajo Final**  
Autores: Sofia Cremydas · Jorge Barbona · Nicolas Caggiano · Diego Carabajal

---

## Descripción

Pipeline ETL completo sobre la base de datos Northwind Traders, implementado en PostgreSQL (Supabase). Incluye cuatro etapas: ingesta y validación, construcción del DWA en esquema estrella, enriquecimiento con fuentes externas, y publicación de Data Products con tablero interactivo en Streamlit.

**Período cubierto:** julio 1996 – mayo 1998  
**Base de datos fuente:** Northwind Traders (pedidos, clientes, productos, empleados)  
**Enriquecimiento externo:** World Data 2023 (datos socioeconómicos por país) + Customer Score

---

## Arquitectura

```
CSV (ingesta1/ingesta2)
        │
        ▼
  [txt_*] tablas raw            ← scripts 01-02 / 16-17
        │  validación + limpieza ← scripts 03-06 / 18-19
        ▼
  [tmp_*] tablas staging        ← scripts 07-09 / 20-21
        │  integridad referencial
        ▼
  [dwa_dim_*] dimensiones       ← scripts 11, 15, 22-23
  [dwa_fact_ventas] hechos      ← scripts 11, 15, 23
  [dwm_*] memoria SCD2          ← scripts 22-23
  [dwa_enr_*] enriquecimiento   ← script 24
        │
        ▼
  [dp_*] Data Products          ← scripts 26-27
        │  pre-agregados planos para visualización
        ▼
  Streamlit Dashboard
```

**DQM transversal:** `dqm_script_inventory` → `dqm_execution_log` → `dqm_carga_dwa` en cada script.

---

## Estructura del repositorio

```
├── scripts/                        # Pipeline SQL (29 scripts)
│   ├── 01_ddl_estructuras.sql      # DDL tablas txt_* (raw)
│   ├── 02_import_csv.sql           # Importación CSV → txt_*
│   ├── 03_validacion_txt.sql       # Validaciones capa raw
│   ├── 04_perfilado_txt.sql        # Perfilado estadístico
│   ├── 05_limpieza_datos_txt.sql   # Limpieza y normalización
│   ├── 06_validacion_post_limpieza.sql
│   ├── 07_migracion_txt_a_tmp.sql  # Migración txt → tmp
│   ├── 08_integridad_referencial_tmp.sql
│   ├── 09_migracion_schema.sql
│   ├── 10_metadata.sql             # Catálogo met_entidades
│   ├── 11_ddl_dwa.sql              # Modelo estrella (DDL)
│   ├── 12_ddl_dqm_dwa.sql         # DQM: tablas de calidad
│   ├── 13_validacion_ingesta_dwa.sql
│   ├── 14_validacion_integracion_dwa.sql
│   ├── 15_carga_dwa.sql            # Carga inicial al DWA
│   ├── 16_ddl_ingesta2.sql         # DDL segunda ingesta
│   ├── 17_import_csv_ingesta2.sql
│   ├── 18_validacion_txt2.sql
│   ├── 19_perfilado_txt2.sql
│   ├── 20_migracion_txt2_a_tmp2.sql
│   ├── 21_integridad_tmp2.sql
│   ├── 22_ddl_dwa_extensiones.sql  # SCD2 + enriquecimiento DDL
│   ├── 23_actualizacion_dwa_ingesta2.sql
│   ├── 24_actualizacion_memoria_enriquecimiento.sql
│   ├── 25_actualizacion_metadata.sql
│   ├── 26_ddl_data_products.sql    # DDL tablas dp_
│   ├── 27_carga_data_products.sql  # Carga dp_ (reejecutable)
│   ├── 28_metadata_publicacion.sql # Catálogo 75 columnas dp_
│   ├── 29_correccion_encoding_pais.sql  # Fix U+FFFD
│   └── correccion_bd.sql           # Correcciones silenciosas
│
├── ingesta1/                       # CSVs primera ingesta (Northwind)
│   ├── categories.csv
│   ├── customers.csv
│   ├── employees.csv
│   ├── order_details.csv
│   ├── orders.csv
│   ├── products.csv
│   └── ...
│
├── ingesta2/                       # CSVs segunda ingesta
│   ├── customers_score.csv         # Score externo de clientes
│   ├── world-data-2023.csv         # Datos socioeconómicos por país
│   └── ...
│
├── streamlit_app/                  # Dashboard interactivo
│   ├── app.py                      # Aplicación principal
│   ├── requirements.txt            # Dependencias Python
│   ├── .gitignore                  # Excluye secrets.toml
│   └── .streamlit/
│       ├── secrets.toml            # ← NO se sube a GitHub
│       └── secrets.toml.example    # Plantilla de credenciales
│
├── .gitignore
└── README.md
```

---

## Tablas del DWA (schema `data_warehouse`)

| Prefijo | Capa | Descripción |
|---------|------|-------------|
| `txt_*` | Raw | Datos importados directamente del CSV, sin transformar |
| `tmp_*` | Staging | Datos validados y normalizados, listos para el DWA |
| `dwa_dim_*` | Dimensiones | Estado actual de cada entidad (sin SCD2) |
| `dwa_fact_ventas` | Hechos | Tabla de hechos (granularidad: línea de pedido) |
| `dwm_*` | Memoria SCD2 | Historial de cambios por dimensión |
| `dwa_enr_*` | Enriquecimiento | KPIs pre-calculados por cliente y producto |
| `dp_*` | Data Products | Tablas planas pre-agregadas para visualización |
| `dqm_*` | Calidad | Inventario de scripts, log de ejecuciones, validaciones |
| `met_entidades` | Metadata | Catálogo de todas las columnas del DWA |

### Data Products (capa dp_)

| Tabla | Filas | Descripción |
|-------|-------|-------------|
| `dp_ventas_por_periodo` | 23 | Revenue y pedidos por año/trimestre/mes |
| `dp_ventas_por_cliente` | 91 | Métricas + segmento PREMIUM/REGULAR/BAJO por cliente |
| `dp_ventas_por_producto` | 77 | Revenue + performance TOP/MID/LOW por producto |
| `dp_ventas_por_empleado` | 9 | Ranking de vendedores |
| `dp_ventas_geografico` | 249 | Ventas por país con datos socioeconómicos |

---

## Dashboard Streamlit

El tablero tiene dos pestañas, cumpliendo ambos requerimientos de explotación:

**Tab 1 — 📈 Métricas de Ventas** (fuente: tablas `dp_`)
- KPIs globales (pedidos, revenue, ticket promedio)
- Evolución mensual de revenue y pedidos
- Top 15 clientes y productos coloreados por segmento/performance
- Distribución en donut charts (segmento de clientes, performance de productos)
- Ranking de vendedores
- Mapa geográfico de ventas (scatter_geo)

**Tab 2 — 🔍 Analítica del DW** (fuente: tablas `dqm_`)
- KPIs del pipeline (ejecuciones, OK/WARNING/ERROR, registros procesados)
- Historial de ejecuciones con colores por resultado
- Registros cargados por tabla destino (barras)
- Controles de calidad OK vs ERROR por tabla
- Detalle de registros rechazados
- Inventario completo de scripts con último resultado

---

## Configuración local

### 1. Clonar el repositorio

```bash
git clone https://github.com/TU-USUARIO/northwind-dwa.git
cd northwind-dwa
```

### 2. Instalar dependencias

```bash
cd streamlit_app
pip install -r requirements.txt
```

### 3. Configurar credenciales

```bash
cp .streamlit/secrets.toml.example .streamlit/secrets.toml
# Editar secrets.toml con la URL de tu base de datos Supabase
```

Contenido de `.streamlit/secrets.toml`:
```toml
[db]
url = "postgresql://postgres:[YOUR-PASSWORD]@db.[TU-PROJECT-REF].supabase.co:5432/postgres"
```

La URL la encontrás en: **Supabase → Settings → Database → Connection string → URI**

### 4. Ejecutar localmente

```bash
streamlit run app.py
```

---

## Deploy en Streamlit Community Cloud

1. Crear cuenta en [share.streamlit.io](https://share.streamlit.io) (gratuito)
2. Conectar tu cuenta de GitHub
3. **New app** → seleccionar este repositorio
4. Configurar:
   - **Main file path:** `streamlit_app/app.py`
   - **Branch:** `main`
5. En **Advanced settings → Secrets**, pegar el contenido del `secrets.toml`:
   ```toml
   [db]
   url = "postgresql://postgres:[YOUR-PASSWORD]@db.[TU-PROJECT-REF].supabase.co:5432/postgres"
   ```
6. Click **Deploy** — en ~2 minutos el tablero queda público con URL propia.

---

## Tecnologías

| Tecnología | Rol |
|-----------|-----|
| PostgreSQL 15 (Supabase) | Base de datos del DWA |
| DBeaver | Ejecución de scripts SQL |
| Python 3.11 | Runtime del dashboard |
| Streamlit 1.35+ | Framework del tablero |
| Plotly 5.20+ | Visualizaciones interactivas |
| SQLAlchemy 2.0+ | Conexión Python → PostgreSQL |
| Streamlit Community Cloud | Hosting gratuito del tablero |

---

## Orden de ejecución de scripts

Ejecutar en DBeaver en orden numérico sobre el schema `data_warehouse`:

```
01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10   (ingesta 1)
11 → 12 → 13 → 14 → 15                               (DWA inicial)
16 → 17 → 18 → 19 → 20 → 21                          (ingesta 2 staging)
22 → 23 → 24 → 25                                     (actualización DWA)
26 → 27 → 28                                          (publicación dp_)
29                                                    (correctivo encoding)
```
