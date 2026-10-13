# Prueba Analista BI

Proyecto desarrollado como solución a la prueba técnica para el cargo de **Analista BI**.

El propósito del proyecto es construir un proceso reproducible de preparación, integración, análisis y visualización de datos utilizando **Python, SQL, PostgreSQL, DBeaver, Power BI, Git y GitHub**.

La solución se organiza en dos ejercicios principales:

1. Análisis de consumos y comportamiento de afiliados en Piscilago.
2. Análisis operativo de atención a partir de la base `T_DIGITURNOS`.

---

# Estado del proyecto

**Versión:** Entrega final de los ejercicios 1 y 2  
**Estado:** Análisis, consultas SQL, tableros Power BI y presentación ejecutiva desarrollados.

**Entregables:**
- Ejercicio 1 — Piscilago: análisis de compradores, penetración, participación, cobertura y tendencias de compra.
- Ejercicio 2 — Digiturnos: análisis de tiempos de espera, demanda horaria, cuellos de botella, utilización estimada de receptores y priorización operativa.
- Dos tableros de Power BI, cada uno con dos páginas de análisis.
- Presentación ejecutiva de 18 diapositivas con resultados, conclusiones y recomendaciones.

**Archivos de presentación:**
- `outputs/Tablero_Piscilago.pdf`
- `outputs/Tablero_Digiturnos.pdf`
- `outputs/Presentacion_Prueba_Tecnica.pdf`

**Nota metodológica:** Los indicadores de utilización de Digiturnos representan estimaciones construidas a partir de la actividad observada. Las prioridades de intervención corresponden a criterios analíticos exploratorios.

---


# Estructura del proyecto

```text
Prueba_Analista_BI/
├── data/
│   ├── raw/                         # Fuentes originales; no publicar
│   └── processed/                   # Bases y dimensiones procesadas
├── notebooks/
│   ├── 01_perfilamiento_piscilago.ipynb
│   └── 02_perfilamiento_digiturnos.ipynb
├── outputs/                         # Exportaciones PDF; revisar antes de publicar
│   ├── Tablero_Piscilago.pdf
│   └── Tablero_Digiturnos.pdf        # Exportar desde Power BI y verificar
├── powerbi/
│   ├── Tablero_Piscilago.pbix
│   └── Tablero_Digiturnos.pbix
├── sql/
│   ├── 01_modelo_piscilago.sql
│   ├── 02_indicadores_piscilago.sql
│   ├── 03_analisis_piscilago.sql
│   ├── 04_modelo_digiturnos.sql
│   └── 05_analisis_digiturnos.sql
├── src/
├── tests/
├── .gitignore
├── README.md
└── requirements.txt
```

La estructura recoge los productos desarrollados y la ruta prevista para el PDF final de Digiturnos; se debe comprobar la existencia y apertura de cada archivo antes del commit. El entorno virtual `.venv/` y las fuentes `data/raw/` permanecen locales.

---


# Arquitectura de trabajo

El proyecto se construye bajo una estructura que separa:

- fuentes originales;
- procesos de transformación;
- productos analíticos;
- consultas SQL;
- visualizaciones;
- documentación.

La lógica general es:

```text
Fuentes raw
    │
    ▼
Perfilamiento y validación
    │
    ▼
Limpieza y estandarización
    │
    ▼
Dimensiones reutilizables
    │
    ▼
Bases analíticas
    │
    ├───────────────┐
    ▼               ▼
   SQL           Power BI
```

---

# Principios metodológicos

## 1. Trazabilidad

Cada transformación relevante queda documentada dentro de los notebooks.

Se registran, entre otros:

- número de registros de entrada;
- número de registros después de cada transformación;
- eliminación controlada de registros;
- validaciones de llaves;
- tratamiento de inconsistencias;
- generación de archivos procesados.

## 2. Reproducibilidad

Las rutas del proyecto se construyen mediante `pathlib`, evitando depender de rutas absolutas específicas del equipo.

Los notebooks están diseñados para ejecutarse a partir de la estructura estándar del proyecto.

## 3. Separación entre raw y processed

Las fuentes originales permanecen en:

```text
data/raw/
```

y no deben modificarse directamente.

Los resultados de transformación se almacenan en:

```text
data/processed/
```

Esto permite conservar la fuente original y reconstruir los productos analíticos cuando sea necesario.

## 4. Dimensiones reutilizables

La clasificación de afiliados y grupo familiar no se reconstruye de manera independiente para cada ejercicio.

Se utilizan dimensiones comunes:

```text
dim_afiliados_consistentes.csv
dim_grupo_familiar.csv
```

Esto permite compartir reglas de negocio entre Piscilago y Digiturnos.

---

# Ejercicio 1 — Piscilago

## Objetivo

Identificar tendencias de compra de los afiliados en Piscilago.

El ejercicio requiere analizar:

- penetración;
- participación;
- cobertura;
- comportamiento de compra;
- segmentación de afiliados;
- tendencias temporales;
- conclusiones y recomendaciones.

También se considera la regla de negocio correspondiente a productos con seguro.

---

## Fuentes utilizadas

```text
BD_CONSUMOS_PISCILAGO.csv
BD_AFILIADOS.csv
AFILIADOS_A_CARGO.xlsx
```

---

## Proceso desarrollado

El flujo incluye:

1. Carga de las fuentes.
2. Perfilamiento inicial.
3. Normalización de identificaciones.
4. Diagnóstico de duplicados.
5. Diagnóstico de valores faltantes.
6. Análisis de consistencia de perfiles.
7. Construcción de una dimensión consistente de afiliados.
8. Cruce jerárquico con las fuentes de afiliación.
9. Clasificación de clientes.
10. Tratamiento de variables monetarias.
11. Generación de una base analítica.
12. Creación de indicadores mediante SQL.
13. Construcción de visualizaciones en Power BI.

---

# Dimensión de afiliados consistentes

Se generó:

```text
data/processed/dim_afiliados_consistentes.csv
```

Esta dimensión contiene una fila analítica por identificación consistente.

Entre sus principales variables se encuentran:

```text
id_normalizado
Categoria
Segmento_poblacional
Piramide1
Piramide2
registros_fuente
calidad_perfil
```

La finalidad de esta dimensión es disponer de una llave confiable para realizar cruces posteriores sin multiplicar artificialmente los registros.

---

# Base analítica de Piscilago

El proceso genera:

```text
data/processed/piscilago_analitica.csv
```

Esta base constituye el principal insumo para:

- análisis SQL;
- construcción de indicadores;
- visualizaciones;
- análisis de tendencias de compra.

---

# Clasificación de clientes

La lógica de clasificación sigue el orden:

```text
Afiliado
   ↓
Grupo familiar
   ↓
No afiliado
```

Primero se busca la identificación en la dimensión de afiliados.

Los registros no encontrados se contrastan con la base de personas a cargo.

Los registros restantes se clasifican como:

```text
No afiliado
```

---

# SQL del ejercicio de Piscilago

La lógica SQL se divide en tres componentes:

```text
sql/
├── 01_modelo_piscilago.sql
├── 02_indicadores_piscilago.sql
└── 03_analisis_piscilago.sql
```

## 01_modelo_piscilago.sql

Contiene la estructura del modelo utilizado para cargar y organizar la información.

## 02_indicadores_piscilago.sql

Contiene las consultas asociadas al cálculo de indicadores.

## 03_analisis_piscilago.sql

Contiene consultas orientadas a exploración y análisis del comportamiento de compra.

---

# Power BI — Piscilago

El tablero se organiza actualmente en dos páginas principales.

## Perfil y alcance

Incluye indicadores relacionados con:

- ventas netas;
- compradores únicos;
- compradores afiliados;
- compradores grupo familiar;
- compradores no afiliados;
- participación de afiliados;
- penetración;
- cobertura.

También incluye visualizaciones por:

- categoría;
- segmento poblacional;
- pirámide.

## Tendencias de compra

Incluye análisis relacionados con:

- top de productos por ventas netas;
- ventas por tipo de vínculo;
- evolución mensual de ventas;
- compradores únicos;
- filtros por tipo de vínculo;
- filtros por producto.

---

# Ejercicio 2 — Digiturnos

## Objetivo

Analizar el proceso de atención registrado en `T_DIGITURNOS`.

Las preguntas principales del ejercicio son:

1. ¿Cuál es el tiempo promedio de espera entre la solicitud y el llamado del servicio por sede y tipo de servicio?
2. ¿Cuáles son los picos de demanda por hora, día de la semana y sede?
3. ¿Dónde se presentan posibles cuellos de botella?
4. ¿Cuál es la tasa de utilización de cada usuario receptor?
5. ¿Qué conclusiones y recomendaciones pueden derivarse del análisis?

---

## Fuente principal

```text
data/raw/T_DIGITURNOS.csv
```

---

# Perfilamiento inicial de T_DIGITURNOS

La fuente contiene inicialmente:

```text
1.016.267 registros
```

Durante el perfilamiento se identificaron:

```text
133.187 filas completamente vacías
```

Estas filas fueron eliminadas de forma controlada.

Después de la limpieza inicial se obtuvieron:

```text
883.080 registros útiles
```

La reconciliación entre registros originales, eliminados y registros analíticos fue validada.

---

# Duplicados

Después de retirar las filas completamente vacías se realizó un control de duplicados exactos.

Resultado:

```text
Duplicados exactos: 0
```

---

# Clientes identificados

En la base útil se identificaron:

```text
60.335 clientes distintos
```

---

# Variables principales de T_DIGITURNOS

La fuente contiene variables como:

```text
Sede
UES
Clasificacion
Usuario_receptor
Tipo_servicio
SUBSERVICIO_HOMOLOGADO
Fecha_Servicio
Hora_solicitud_Servicio
Hora_llamado__Servicio
Hora_finalizado_Servicio
Identificacion_Cliente
Tipo_Oficina
```

---

# Estandarización de variables críticas

Se construyeron variables estandarizadas para:

```text
id_cliente
fecha_servicio
ts_solicitud
ts_llamado
ts_finalizacion
```

La identificación del cliente fue convertida a una llave numérica analítica.

---

# Construcción de tiempos operativos

A partir de las variables temporales se calcularon:

```text
tiempo_espera_min
tiempo_atencion_min
tiempo_total_min
```

Donde:

```text
tiempo_espera_min = llamado - solicitud
tiempo_atencion_min = finalización - llamado
tiempo_total_min = finalización - solicitud
```

---

# Diagnóstico temporal

Durante la validación de coherencia temporal se encontraron:

```text
Registros analizados:      883.080
Registros inconsistentes:        4
```

Porcentaje aproximado:

```text
0,0005 %
```

Los registros presentan situaciones como:

- llamado anterior a la solicitud;
- finalización anterior al llamado.

---

# Tratamiento de inconsistencias temporales

Los cuatro registros identificados:

- se conservan en la base original;
- se documentan para auditoría;
- no se corrigen artificialmente;
- se excluyen únicamente de los indicadores temporales.

La población válida para indicadores de tiempo queda en:

```text
883.076 registros
```

La reconciliación fue validada:

```text
883.080 = 883.076 + 4
```

---

# Dimensión de grupo familiar

Se construyó una dimensión adicional:

```text
data/processed/dim_grupo_familiar.csv
```

La fuente original corresponde a:

```text
AFILIADOS_A_CARGO.xlsx
```

Resultados del procesamiento:

```text
Registros fuente:              39.733
Registros sin persona a cargo:      1
Personas a cargo únicas:       24.554
Duplicados en llave final:          0
Nulos en llave final:               0
```

---

# Relación entre personas a cargo y titulares

Se identificaron:

```text
16.698 personas con titular único
7.856 personas con múltiples titulares
```

Para evitar asignaciones arbitrarias, los casos con más de un titular no reciben automáticamente un afiliado principal.

La dimensión contiene:

```text
id_persona_cargo
n_titulares
id_afiliado_titular
estado_relacion
```

Los valores de `estado_relacion` incluyen:

```text
Titular único
Múltiples titulares
```

---

# Modelo analítico y análisis SQL de Digiturnos

El perfilamiento de `T_DIGITURNOS` parte de **1.016.267 filas**, de las cuales **133.187** estaban completamente vacías. Se conservaron **883.080 solicitudes útiles**. Se identificaron cuatro registros con inconsistencias temporales en el diagnóstico inicial, preservados para auditoría y excluidos según la validez exigida por cada indicador.

La base de PostgreSQL incorpora el esquema `digiturnos` y las tablas analíticas `digiturnos_atenciones` y `digiturnos_franjas`. El desarrollo SQL se organiza en:

- `sql/04_modelo_digiturnos.sql`: preparación/modelado de las estructuras de consulta.
- `sql/05_analisis_digiturnos.sql`: indicadores, controles, ocupación estimada, diagnóstico integrado y priorización.

## Resultados validados de Digiturnos

| Control | Resultado |
|---|---:|
| Sedes | 13 |
| Solicitudes analíticas | 883.080 |
| Solicitudes conciliadas con franjas | 883.080 |
| Combinaciones sede-receptor | 256 |
| Combinaciones principales (30 o más jornadas válidas) | 109 |
| Combinaciones complementarias (1–29 jornadas válidas) | 146 |
| Combinaciones sin jornadas válidas | 1 |
| Jornadas válidas | 17.021 |
| Solicitudes incluidas en jornadas válidas | 882.863 |
| Solicitudes excluidas de ese cálculo | 217 |

La diferencia de **217 solicitudes** corresponde a las reglas específicas del cálculo de ocupación: **103** asociadas a jornadas con duraciones inválidas, **1** a ventana no positiva y **113** a minutos efectivos superiores a la ventana observada. Esta exclusión **no implica borrar solicitudes** de la base ni de los indicadores de demanda.

## Consultas de síntesis y priorización

- **4.5.1 — Síntesis por sede:** demanda, promedio de espera, percentil 90 (P90), esperas mayores a 15 y 30 minutos, y duración de atención.
- **4.5.2 — Ocupación estimada por sede:** proporción entre minutos efectivos de atención y minutos de ventana observada; distingue análisis principal y global.
- **4.5.3 — Diagnóstico integrado:** combina demanda, espera y ocupación; construye perfiles operativos exploratorios.
- **4.5.4 — Priorización de intervenciones:** puntaje relativo de 0 a 100 basado en severidad (40 puntos), magnitud de esperas superiores a 15 minutos (40) y contexto de presión operativa (20).

### Priorización obtenida en 4.5.4

| Sede | P90 espera (min) | Solicitudes con espera >15 min | Ocupación principal | Puntaje | Prioridad |
|---|---:|---:|---:|---:|---|
| Suba | 23,90 | 15.805 | 60,48 % | 87,50 | 1 — Intervención focalizada |
| Soacha | 20,58 | 17.177 | 56,02 % | 82,50 | 1 — Intervención focalizada |
| Calle 26 | 17,67 | 20.203 | 63,27 % | 75,83 | 1 — Intervención focalizada |
| Centro Mayor | 22,95 | 12.785 | 58,99 % | 75,00 | 1 — Intervención focalizada |
| Tintal Plaza | 20,28 | 15.787 | 57,32 % | 65,83 | 2 — Optimización operativa |
| Unicentro de Occidente | 20,30 | 8.559 | 60,12 % | 64,16 | 2 — Optimización operativa |
| Santa Librada | 19,67 | 6.676 | 61,06 % | 54,17 | 2 — Optimización operativa |
| Usaquén | 18,68 | 8.042 | 43,38 % | 46,67 | 3 — Seguimiento preventivo |
| Calle 63 | 16,95 | 5.705 | 40,58 % | 29,17 | 3 — Seguimiento preventivo |
| Fusagasugá | 15,38 | 4.722 | 58,03 % | 26,67 | 3 — Seguimiento preventivo |
| Girardot | 14,80 | 4.396 | 66,63 % | 26,66 | 3 — Seguimiento preventivo |
| Funza | 12,50 | 4.091 | 48,94 % | 11,67 | 3 — Seguimiento preventivo |
| La Mesa | 13,57 | 896 | 55,36 % | 4,17 | 3 — Seguimiento preventivo |

**Interpretación:** Suba y Soacha requieren analizar la severidad de la espera; Calle 26 destaca por la cantidad absoluta de solicitudes afectadas; Centro Mayor presenta un P90 elevado. Estas asociaciones justifican análisis adicionales por servicio, día y franja horaria, pero **no prueban por sí mismas la causa** de las demoras.

**Advertencias metodológicas:**

1. La ocupación calculada es un **indicador proxy**: minutos de atención efectiva divididos entre minutos de ventana observada, no utilización contractual ni capacidad instalada.
2. La ocupación principal se calcula exclusivamente con combinaciones de **30 o más jornadas válidas**; la global incluye todas las combinaciones con jornadas válidas.
3. Los puntajes de prioridad utilizan `PERCENT_RANK` y ponderaciones analíticas; no son una escala oficial ni permiten interpretar diferencias de puntaje como diferencias proporcionales de desempeño.
4. El porcentaje de receptores principales mide combinaciones sede-receptor, **no cobertura de solicitudes**. En Tintal Plaza, Unicentro de Occidente y Santa Librada se recomienda contrastar los resultados con el análisis complementario.
5. Los valores de espera y los filtros de validez corresponden a las definiciones de cada indicador; no debe extrapolarse el universo de jornadas válidas al total de atenciones.

# Power BI — Digiturnos

El archivo `powerbi/Tablero_Digiturnos.pbix` contiene **dos páginas**:

1. **01. Diagnóstico y prioridades:** tarjetas de volumen total, solicitudes con espera superior a 15 minutos y porcentaje correspondiente; barras por sede de solicitudes afectadas y puntaje de priorización; segmentador de nivel de prioridad; tabla de diagnóstico con P90, porcentaje de esperas superiores a 15 minutos, ocupación estimada, acción sugerida e indicador de seguimiento.
2. **02. Análisis horario y patrones de demanda:** distribución de solicitudes por hora; gráfico combinado de volumen y porcentaje de esperas superiores a 15 minutos; matriz de calor de día de la semana (lunes a domingo) y hora; segmentador por sede.

**Cifras de control mostradas en el tablero:** 883.080 solicitudes totales, aproximadamente 125 mil con espera superior a 15 minutos y 14,14 % de incidencia general. La cifra abreviada de 125 mil es una visualización redondeada; no debe utilizarse como valor exacto para conciliaciones.

**Exportación estática:** `outputs/Tablero_Digiturnos.pdf` (dos páginas; exportación y revisión visual requeridas antes de la publicación). El PBIX conserva los filtros y las interacciones. El informe no incorpora una tercera página de conclusiones: los hallazgos y las recomendaciones se desarrollarán en la presentación corporativa.


# Trazabilidad

Los notebooks contienen controles de trazabilidad para registrar las principales transformaciones realizadas.

Entre las etapas documentadas se encuentran:

```text
Carga de fuente
Limpieza inicial
Estandarización
Validación temporal
Construcción de dimensiones
```

Para cada etapa se conservan variables como:

```text
etapa
tabla
registros
columnas
observacion
```

Esto permite reconstruir el flujo de transformación y justificar las decisiones tomadas.

---

# Herramientas utilizadas

## Python

Utilizado para:

- perfilamiento;
- limpieza;
- transformación;
- integración;
- validación;
- generación de archivos procesados.

Principales librerías:

```text
pandas
numpy
openpyxl
pathlib
```

## Jupyter Notebook

Utilizado como componente principal de documentación y ejecución del proceso de preparación de datos.

## PostgreSQL

Utilizado como motor de base de datos para realizar consultas analíticas.

## Docker

Utilizado para ejecutar el entorno de PostgreSQL local.

## DBeaver

Utilizado como cliente SQL para:

- conexión a PostgreSQL;
- ejecución de consultas;
- exploración de tablas;
- validación de resultados.

## Power BI

Utilizado para construir visualizaciones e indicadores de negocio.

## Git

Utilizado para control de versiones.

## GitHub

Utilizado como repositorio remoto del proyecto.

---

# Entorno de desarrollo

El desarrollo se realiza utilizando:

```text
Visual Studio Code
Python 3.12
Jupyter
PostgreSQL
Docker Desktop
DBeaver
Power BI Desktop
```

---

# Configuración del entorno Python

Crear el entorno virtual:

```bash
python -m venv .venv
```

En Windows, activarlo mediante:

```powershell
.venv\Scripts\Activate.ps1
```

Instalar dependencias:

```bash
pip install -r requirements.txt
```

---

# Dependencias principales

El archivo:

```text
requirements.txt
```

contiene actualmente:

```text
pandas
numpy
openpyxl
jupyter
ipykernel
```

---

# Manejo de datos sensibles

Las fuentes originales pueden contener identificaciones personales.

Por esta razón:

```text
data/raw/
```

se encuentra excluida del control de versiones mediante `.gitignore`.

Esto permite:

- mantener las fuentes disponibles localmente;
- evitar publicar información sensible;
- conservar en GitHub únicamente el código y la documentación necesaria.

---

# Reproducibilidad del proyecto

Para reproducir el análisis:

1. Clonar el repositorio.
2. Crear el entorno virtual.
3. Instalar las dependencias.
4. Ubicar las fuentes originales en:

```text
data/raw/
```

5. Ejecutar:

```text
notebooks/01_perfilamiento_piscilago.ipynb
```

6. Ejecutar:

```text
notebooks/02_perfilamiento_digiturnos.ipynb
```

7. Utilizar las bases generadas en:

```text
data/processed/
```

para los análisis posteriores en SQL y Power BI.

---

## Control de versiones y publicación

Antes de publicar, guardar los notebooks, scripts SQL, PBIX y README en sus rutas locales. Ejecutar `git status`, inspeccionar los archivos preparados con `git diff --cached --stat` y confirmar que no haya datos personales, credenciales, fuentes originales ni exportaciones sensibles. Luego realizar commit y push a `origin/main`.

El archivo `.gitignore` excluye `data/raw/`, `.venv/` y `outputs/`. Para publicar **únicamente** los PDF de entrega revisados, utilizar `git add -f outputs/Tablero_Piscilago.pdf outputs/Tablero_Digiturnos.pdf` (si ambos existen), sin habilitar indiscriminadamente otros contenidos de `outputs/`. **Los archivos previamente versionados no dejan de rastrearse automáticamente** al agregarlos a `.gitignore`. Verificar el estado real con `git ls-files`.

La documentación contiene resultados de las ejecuciones SQL realizadas; no sustituye una prueba de ejecución completa desde un entorno limpio.

---


# Autor: Angie Coba

Prueba técnica — Analista BI

Proyecto desarrollado en Python, SQL y Power BI.
