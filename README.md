# Prueba Analista BI

Proyecto desarrollado como solución a la prueba técnica para el cargo de **Analista BI**.

El propósito del proyecto es construir un proceso reproducible de preparación, integración, análisis y visualización de datos utilizando **Python, SQL, PostgreSQL, DBeaver, Power BI, Git y GitHub**.

La solución se organiza en dos ejercicios principales:

1. Análisis de consumos y comportamiento de afiliados en Piscilago.
2. Análisis operativo de atención a partir de la base `T_DIGITURNOS`.

---

# Estado del proyecto

**Versión actual:** Entrega preliminar  
**Estado:** Desarrollo en curso

A la fecha se ha avanzado en:

- Perfilamiento de las fuentes del ejercicio de Piscilago.
- Limpieza y normalización de identificadores.
- Construcción de una dimensión consistente de afiliados.
- Construcción de una dimensión de grupo familiar.
- Generación de una base analítica de Piscilago.
- Desarrollo de consultas SQL para el ejercicio de Piscilago.
- Construcción inicial de visualizaciones en Power BI.
- Perfilamiento y preparación de `T_DIGITURNOS`.
- Validación de fechas y tiempos operativos.
- Construcción de indicadores temporales.
- Identificación y tratamiento de inconsistencias temporales.
- Construcción de dimensiones reutilizables para ambos ejercicios.
- Documentación de controles de calidad y trazabilidad.

---

# Estructura del proyecto

```text
Prueba_Analista_BI/
│
├── .venv/
│
├── data/
│   ├── raw/
│   │   ├── AFILIADOS_A_CARGO.xlsx
│   │   ├── BD_AFILIADOS.csv
│   │   ├── BD_CONSUMOS_PISCILAGO.csv
│   │   └── T_DIGITURNOS.csv
│   │
│   └── processed/
│       ├── dim_afiliados_consistentes.csv
│       ├── dim_grupo_familiar.csv
│       └── piscilago_analitica.csv
│
├── notebooks/
│   ├── 01_perfilamiento_piscilago.ipynb
│   └── 02_perfilamiento_digiturnos.ipynb
│
├── outputs/
│
├── powerbi/
│
├── sql/
│   ├── 01_modelo_piscilago.sql
│   ├── 02_indicadores_piscilago.sql
│   └── 03_analisis_piscilago.sql
│
├── src/
│
├── tests/
│
├── .gitignore
├── README.md
└── requirements.txt
```

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

# Modelo analítico esperado para Digiturnos

La arquitectura prevista es:

```text
dim_afiliados_consistentes
           │
           │ many to one
           ▼
       T_DIGITURNOS
           ▲
           │ many to one
           │
dim_grupo_familiar
```

La clasificación final seguirá la prioridad:

```text
1. Afiliado
2. Grupo familiar
3. No afiliado
```

---

# Punto de corte de la entrega preliminar

La entrega se detiene de manera intencional antes del `merge` definitivo de Digiturnos con las dimensiones maestras.

Actualmente ya se encuentran construidos:

```text
dim_afiliados_consistentes.csv
dim_grupo_familiar.csv
piscilago_analitica.csv
```

Durante la última ejecución del notebook se detectó una discrepancia en la variable `dim_afiliados` cargada en memoria:

```text
Duplicados observados: 9
Nulos observados:      10
```

Sin embargo, una validación previa del archivo procesado había reportado una dimensión sin duplicados ni nulos.

Por esta razón, antes de continuar se realizará una validación completa mediante:

```text
Restart Kernel
+
Run All
```

El objetivo será identificar si la discrepancia proviene del orden de ejecución de las celdas o de una sobrescritura accidental de la variable dentro del notebook.

---

# Próximos pasos — Digiturnos

Los siguientes pasos serán:

1. Reiniciar el kernel.
2. Ejecutar el notebook completo desde el inicio.
3. Validar nuevamente `dim_afiliados_consistentes.csv`.
4. Confirmar:
   - 0 duplicados;
   - 0 nulos en la llave.
5. Integrar Digiturnos con la dimensión de afiliados.
6. Integrar Digiturnos con la dimensión de grupo familiar.
7. Clasificar clientes.
8. Generar:

```text
data/processed/digiturnos_analitica.csv
```

9. Construir indicadores de espera.
10. Analizar picos de demanda.
11. Identificar cuellos de botella.
12. Calcular utilización de usuarios receptores.
13. Construir consultas SQL.
14. Diseñar el tablero de Power BI.
15. Elaborar conclusiones y recomendaciones.

---

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

# Estado de madurez

## Ejercicio 1 — Piscilago

```text
Estado: Avanzado

Perfilamiento:             completado
Dimensión afiliados:       completada
Base analítica:            completada
SQL:                       avanzado
Power BI:                  avanzado
Documentación:             en consolidación
```

## Ejercicio 2 — Digiturnos

```text
Estado: En desarrollo

Perfilamiento:              completado
Limpieza inicial:           completada
Variables temporales:       completadas
Validación temporal:        completada
Dimensión grupo familiar:   completada
Integración final:          pendiente
Indicadores:                pendiente
SQL:                        pendiente
Power BI:                   pendiente
Conclusiones:               pendiente
```

---

# Entrega preliminar

Esta versión corresponde a un primer punto estable del proyecto.

El objetivo de esta entrega preliminar es centralizar:

- estructura;
- código;
- notebooks;
- SQL;
- documentación;
- dimensiones procesadas;
- avances de visualización.

El desarrollo continuará sobre esta versión utilizando Git para controlar los cambios posteriores.

---

# Autor

Prueba técnica — Analista BI

Proyecto desarrollado en Python, SQL y Power BI.
