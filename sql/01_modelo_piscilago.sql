/* ============================================================
   PRUEBA ANALISTA BI - PISCILAGO
   Archivo: 01_modelo_piscilago.sql

   Objetivo:
   Construir el esquema y las tablas del modelo analítico
   utilizado para el análisis de consumos de Piscilago.

   Fuentes procesadas previamente en Python:
   - dim_afiliados_consistentes.csv
   - piscilago_analitica.csv

   Modelo:
   - dim_afiliados_consistentes: dimensión poblacional
   - fact_consumos_piscilago: tabla analítica de consumos
   ============================================================ */


/* ============================================================
   1. CREACIÓN DEL ESQUEMA BI

   Se utiliza un esquema independiente para separar los objetos
   analíticos de los objetos creados por defecto en PostgreSQL.
   ============================================================ */

CREATE SCHEMA IF NOT EXISTS bi;

SET search_path TO bi;


/* ============================================================
   2. VALIDACIÓN DEL CONTEXTO DE EJECUCIÓN

   Permite comprobar que las consultas se están ejecutando sobre
   la base de datos y el esquema esperados.
   ============================================================ */

SELECT
    current_database() AS base_datos,
    current_schema() AS esquema_actual;


/* ============================================================
   3. DIMENSIÓN POBLACIONAL DE AFILIADOS CONSISTENTES

   Contiene únicamente identificadores para los cuales las
   variables necesarias para la segmentación analítica presentan
   un perfil consistente.

   Grano:
   Una fila por id_normalizado.

   id_normalizado se define como PRIMARY KEY debido a que su
   unicidad fue validada previamente durante el procesamiento
   realizado en Python.
   ============================================================ */

CREATE TABLE IF NOT EXISTS bi.dim_afiliados_consistentes (
    id_normalizado VARCHAR(30) PRIMARY KEY,
    categoria VARCHAR(10) NOT NULL,
    segmento_poblacional VARCHAR(30) NOT NULL,
    piramide1 VARCHAR(50) NOT NULL,
    piramide2 VARCHAR(100) NOT NULL,
    registros_fuente INTEGER NOT NULL,
    calidad_perfil VARCHAR(20) NOT NULL
);


/* ============================================================
   4. VALIDACIÓN INICIAL DE LA DIMENSIÓN

   Antes de la carga, la consulta debe retornar cero registros.
   Posteriormente permitirá realizar controles sobre los datos
   importados.
   ============================================================ */

SELECT *
FROM bi.dim_afiliados_consistentes
LIMIT 5;


/* ============================================================
   5. TABLA ANALÍTICA DE CONSUMOS DE PISCILAGO

   Conserva el grano de la fuente de consumos y agrega las
   variables construidas durante el procesamiento en Python:
   clasificación del vínculo, atributos poblacionales,
   calidad de segmentación y valor neto.

   No se establece una FK obligatoria hacia la dimensión de
   afiliados porque la tabla también contiene compradores
   clasificados como grupo familiar y no afiliados.
   ============================================================ */

CREATE TABLE IF NOT EXISTS bi.fact_consumos_piscilago (
    periodo INTEGER,
    anio INTEGER,
    estado VARCHAR(30),
    fecha_compra DATE,
    desc_producto VARCHAR(100),
    valor_subtotal NUMERIC(14,2),
    seguro INTEGER,
    valor_seguro NUMERIC(14,2),
    valor_neto NUMERIC(14,2),
    identificacion VARCHAR(30),
    nombres VARCHAR(200),
    punto_recaudo VARCHAR(100),
    id_normalizado VARCHAR(30),
    tipo_vinculo VARCHAR(30),
    categoria VARCHAR(10),
    segmento_poblacional VARCHAR(30),
    piramide1 VARCHAR(50),
    piramide2 VARCHAR(100),
    calidad_segmentacion VARCHAR(30),
    mes INTEGER,
    dia_semana VARCHAR(20)
);


/* ============================================================
   6. VALIDACIÓN DE OBJETOS CREADOS

   Comprueba las tablas físicas disponibles dentro del
   esquema analítico bi.
   ============================================================ */

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'bi'
ORDER BY table_name;


/* ============================================================
   DIMENSIÓN DE AFILIADOS CONSISTENTES
   ============================================================

   Objetivo:
   Validar que la dimensión construida en Python fue cargada
   correctamente en PostgreSQL sin modificar su grano.

   Grano esperado:
   1 fila = 1 afiliado único.

   Resultado esperado:
   - 168.866 filas.
   - 168.866 identificadores únicos.
   - 0 duplicados.
   ============================================================ */

SELECT
    COUNT(*) AS total_filas,
    COUNT(DISTINCT id_normalizado) AS ids_unicos,
    COUNT(*) - COUNT(DISTINCT id_normalizado) AS duplicados
FROM bi.dim_afiliados_consistentes;



/* ============================================================
   CONTROL DE INTEGRIDAD
   DIMENSIÓN DE AFILIADOS CONSISTENTES
   ============================================================

   Objetivo:
   Verificar que las variables requeridas para calcular los
   indicadores de penetración y realizar segmentaciones no
   contengan valores nulos.

   Variables evaluadas:
   - categoria
   - segmento_poblacional
   - piramide1
   - piramide2

   Resultado esperado:
   0 valores nulos en todas las variables.
   ============================================================ */

SELECT
    COUNT(*) FILTER (WHERE categoria IS NULL) AS nulos_categoria,
    COUNT(*) FILTER (WHERE segmento_poblacional IS NULL) AS nulos_segmento,
    COUNT(*) FILTER (WHERE piramide1 IS NULL) AS nulos_piramide1,
    COUNT(*) FILTER (WHERE piramide2 IS NULL) AS nulos_piramide2
FROM bi.dim_afiliados_consistentes;



/* ============================================================
   VALIDACIÓN DE DISTRIBUCIÓN POBLACIONAL
   ============================================================

   Objetivo:
   Verificar que las distribuciones de las principales
   dimensiones sean consistentes con los resultados obtenidos
   durante el procesamiento en Python.
   ============================================================ */


/* Afiliados por categoría */

SELECT
    categoria,
    COUNT(*) AS total_afiliados
FROM bi.dim_afiliados_consistentes
GROUP BY categoria
ORDER BY categoria;


/* Afiliados por segmento poblacional */

SELECT
    segmento_poblacional,
    COUNT(*) AS total_afiliados
FROM bi.dim_afiliados_consistentes
GROUP BY segmento_poblacional
ORDER BY total_afiliados DESC;


/* Afiliados por Pirámide 1 */

SELECT
    piramide1,
    COUNT(*) AS total_afiliados
FROM bi.dim_afiliados_consistentes
GROUP BY piramide1
ORDER BY total_afiliados DESC;


/* Afiliados por Pirámide 2 */

SELECT
    piramide2,
    COUNT(*) AS total_afiliados
FROM bi.dim_afiliados_consistentes
GROUP BY piramide2
ORDER BY total_afiliados DESC;



/* ============================================================
   CONTROL DE CARGA
   TABLA DE HECHOS: CONSUMOS PISCILAGO
   ============================================================

   Objetivo:
   Verificar que la tabla analítica construida en Python fue
   cargada completamente en PostgreSQL.

   Grano esperado:
   1 fila = 1 registro de compra de la fuente de consumos.

   Resultado esperado:
   - 145.060 registros.
   ============================================================ */

SELECT
    COUNT(*) AS total_registros
FROM bi.fact_consumos_piscilago;




-- 1. Integridad de la clasificación
-- Afiliado + Grupo familiar + No afiliado = 145.060

-- 2. Reconciliación por tipo de vínculo
-- Esperamos:
-- Afiliado        96.756
-- Grupo familiar   7.358
-- No afiliado     40.946

-- 3. Validación financiera
-- subtotal, seguros descontados y valor neto

-- 4. Calidad de segmentación
-- Consistente / Ambigua / Sin titular localizado / No aplica

-- 5. Validación temporal
-- fechas, meses y días de semana

-- 6. Cruce dimensión ↔ hechos
-- comprobar que los afiliados clasificados como consistentes
-- pueden relacionarse correctamente con la dimensión poblacional




/* ============================================================
   1. INTEGRIDAD Y RECONCILIACIÓN DE LA CLASIFICACIÓN
   ============================================================

   Objetivo:
   Verificar que todos los registros de consumo tengan una
   clasificación de vínculo y que la distribución coincida
   con la tabla analítica construida en Python.

   Resultado esperado:
   - Afiliado:        96.756
   - Grupo familiar:   7.358
   - No afiliado:     40.946
   - Total:          145.060
   ============================================================ */

SELECT
    tipo_vinculo,
    COUNT(*) AS total_registros,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS porcentaje
FROM bi.fact_consumos_piscilago
GROUP BY tipo_vinculo
ORDER BY total_registros DESC;




/* ============================================================
   CONTROL DE COMPLETITUD DE LA CLASIFICACIÓN

   Objetivo:
   Confirmar que los 145.060 registros tienen asignado un
   tipo de vínculo.

   Resultado esperado:
   - registros_totales: 145.060
   - registros_clasificados: 145.060
   - registros_sin_clasificar: 0
   ============================================================ */

SELECT
    COUNT(*) AS registros_totales,
    COUNT(tipo_vinculo) AS registros_clasificados,
    COUNT(*) FILTER (
        WHERE tipo_vinculo IS NULL
           OR TRIM(tipo_vinculo) = ''
    ) AS registros_sin_clasificar
FROM bi.fact_consumos_piscilago;




/* ============================================================
   3. VALIDACIÓN FINANCIERA
   TABLA DE HECHOS: CONSUMOS PISCILAGO
   ============================================================

   Objetivo:
   Validar que el ajuste correspondiente al seguro se haya
   aplicado correctamente y que los resultados financieros
   coincidan con la transformación realizada en Python.

   Regla de negocio:
   - Si seguro = 1, se descuentan $1.200 del valor_subtotal.
   - Si seguro = 0, valor_neto = valor_subtotal.

   Resultado esperado:
   - Registros totales:          145.060
   - Compras con seguro:          35.305
   - Valor subtotal:      $8.586.771.563
   - Valor seguros:          $42.366.000
   - Valor neto:          $8.544.405.563
   ============================================================ */

SELECT
    COUNT(*) AS registros_totales,
    COUNT(*) FILTER (WHERE seguro = 1) AS compras_con_seguro,
    SUM(valor_subtotal) AS valor_subtotal_total,
    SUM(valor_seguro) AS valor_seguros_total,
    SUM(valor_neto) AS valor_neto_total
FROM bi.fact_consumos_piscilago;



/* ============================================================
   CONTROL DE LA REGLA DE NEGOCIO DEL SEGURO

   Objetivo:
   Comprobar registro a registro que:

   seguro = 1 -> valor_seguro = 1.200
                 valor_neto = valor_subtotal - 1.200

   seguro = 0 -> valor_seguro = 0
                 valor_neto = valor_subtotal

   Resultado esperado:
   - registros_con_error: 0
   ============================================================ */

SELECT
    COUNT(*) FILTER (
        WHERE
            (seguro = 1 AND (
                valor_seguro <> 1200
                OR valor_neto <> valor_subtotal - 1200
            ))
            OR
            (seguro = 0 AND (
                valor_seguro <> 0
                OR valor_neto <> valor_subtotal
            ))
    ) AS registros_con_error
FROM bi.fact_consumos_piscilago;




/* ============================================================
   4. CONTROL DE CALIDAD DE LA SEGMENTACIÓN
   TABLA DE HECHOS: CONSUMOS PISCILAGO
   ============================================================

   Objetivo:
   Verificar cómo quedaron clasificados los registros de consumo
   según el tipo de vínculo y la calidad de la segmentación
   poblacional construida previamente en Python.

   Interpretación de calidad_segmentacion:

   - Consistente:
     La persona pudo asociarse a un perfil poblacional único
     y confiable.

   - Ambigua:
     La persona fue identificada como afiliada o integrante de
     grupo familiar, pero presenta más de una caracterización
     poblacional posible en la fuente.

   - Sin titular localizado:
     La persona fue identificada como grupo familiar, pero no
     fue posible recuperar un perfil poblacional confiable del
     afiliado titular.

   - No aplica:
     Corresponde a compradores clasificados como no afiliados,
     por lo que no forman parte de la dimensión poblacional
     de afiliados.

   Este control NO elimina registros.
   Su propósito es identificar qué observaciones pueden utilizarse
   de forma metodológicamente válida para análisis segmentados.
   ============================================================ */

SELECT
    tipo_vinculo,
    calidad_segmentacion,
    COUNT(*) AS total_registros,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS porcentaje_total
FROM bi.fact_consumos_piscilago
GROUP BY
    tipo_vinculo,
    calidad_segmentacion
ORDER BY
    tipo_vinculo,
    total_registros DESC;



/* ============================================================
   CONTROL DE COHERENCIA ENTRE VÍNCULO Y SEGMENTACIÓN

   Objetivo:
   Detectar combinaciones conceptualmente incompatibles entre
   tipo_vinculo y calidad_segmentacion.

   Reglas esperadas:

   Afiliado:
   - Consistente
   - Ambigua

   Grupo familiar:
   - Consistente
   - Ambigua
   - Sin titular localizado

   No afiliado:
   - No aplica

   Resultado esperado:
   - combinaciones_invalidas = 0
   ============================================================ */

SELECT
    COUNT(*) AS combinaciones_invalidas
FROM bi.fact_consumos_piscilago
WHERE NOT (
       (tipo_vinculo = 'Afiliado'
        AND calidad_segmentacion IN ('Consistente', 'Ambigua'))

    OR (tipo_vinculo = 'Grupo familiar'
        AND calidad_segmentacion IN (
            'Consistente',
            'Ambigua',
            'Sin titular localizado'
        ))

    OR (tipo_vinculo = 'No afiliado'
        AND calidad_segmentacion = 'No aplica')
);




/* ============================================================
   5. CONTROL DE RELACIÓN ENTRE DIMENSIÓN Y TABLA DE HECHOS
   ============================================================

   Objetivo:
   Validar que los registros clasificados con segmentación
   consistente puedan relacionarse correctamente con la
   dimensión poblacional de afiliados consistentes.

   Modelo:

   dim_afiliados_consistentes
   --------------------------------
   Grano: 1 fila = 1 afiliado único
   Llave: id_normalizado

                   1
                   |
                   |
                   N

   fact_consumos_piscilago
   --------------------------------
   Grano: 1 fila = 1 registro de compra
   Llave de relación: id_normalizado

   Nota metodológica:
   En el caso de grupo familiar, la caracterización poblacional
   puede provenir del afiliado titular. Por tanto, antes de
   interpretar el cruce es necesario comprobar qué identificador
   fue almacenado en id_normalizado durante la transformación
   realizada en Python.

   No se eliminan registros de la tabla de hechos.
   ============================================================ */


/* ------------------------------------------------------------
   5.1 Afiliados consistentes presentes en la dimensión
   ------------------------------------------------------------

   Para los compradores clasificados como:
   tipo_vinculo = 'Afiliado'
   calidad_segmentacion = 'Consistente'

   verificamos que id_normalizado exista en la dimensión.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS registros_afiliados_consistentes,

    COUNT(d.id_normalizado) AS registros_con_match_dimension,

    COUNT(*) - COUNT(d.id_normalizado)
        AS registros_sin_match_dimension

FROM bi.fact_consumos_piscilago f

LEFT JOIN bi.dim_afiliados_consistentes d
    ON f.id_normalizado = d.id_normalizado

WHERE f.tipo_vinculo = 'Afiliado'
  AND f.calidad_segmentacion = 'Consistente';




/* ------------------------------------------------------------
   5.2 Compradores únicos afiliados consistentes
   ------------------------------------------------------------

   Objetivo:
   Diferenciar registros de compra de compradores únicos.

   Esto será fundamental para los indicadores posteriores,
   especialmente penetración, participación y cobertura.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS registros_compra,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos
FROM bi.fact_consumos_piscilago
WHERE tipo_vinculo = 'Afiliado'
  AND calidad_segmentacion = 'Consistente';



/* ============================================================
   5.3 DIAGNÓSTICO DEL IDENTIFICADOR EN GRUPO FAMILIAR
   ============================================================

   Objetivo:
   Determinar cómo quedó representado id_normalizado para los
   compradores clasificados como Grupo familiar.

   Antes de relacionar estos registros con la dimensión de
   afiliados consistentes debemos establecer si id_normalizado
   corresponde:

   1. al comprador / persona a cargo, o
   2. al afiliado titular utilizado para heredar la segmentación.

   Este diagnóstico evita asumir una relación incorrecta entre
   la tabla de hechos y la dimensión poblacional.
   ============================================================ */

SELECT
    identificacion,
    id_normalizado,
    tipo_vinculo,
    categoria,
    segmento_poblacional,
    piramide1,
    piramide2,
    calidad_segmentacion
FROM bi.fact_consumos_piscilago
WHERE tipo_vinculo = 'Grupo familiar'
ORDER BY calidad_segmentacion
LIMIT 20;



/* ============================================================
   5.4 COMPARACIÓN IDENTIFICACIÓN VS ID NORMALIZADO
   PARA GRUPO FAMILIAR
   ============================================================

   Objetivo:
   Cuantificar si el identificador utilizado en la tabla de
   hechos fue transformado durante la asignación del titular.
   ============================================================ */

SELECT
    COUNT(*) AS registros_grupo_familiar,

    COUNT(*) FILTER (
        WHERE identificacion::text = id_normalizado::text
    ) AS mismo_identificador,

    COUNT(*) FILTER (
        WHERE identificacion::text <> id_normalizado::text
    ) AS identificador_diferente,

    COUNT(DISTINCT id_normalizado)
        AS ids_normalizados_unicos

FROM bi.fact_consumos_piscilago
WHERE tipo_vinculo = 'Grupo familiar';


/* ============================================================
   5.5 REGISTROS VS COMPRADORES ÚNICOS POR TIPO DE VÍNCULO
   ============================================================

   Objetivo:
   Distinguir el número de registros de compra del número de
   compradores únicos en cada población.

   Esta diferencia es fundamental para no utilizar COUNT(*)
   incorrectamente en indicadores cuyo numerador corresponde
   a personas/compradores.
   ============================================================ */

SELECT
    tipo_vinculo,
    COUNT(*) AS registros_compra,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos,
    COUNT(*) - COUNT(DISTINCT id_normalizado)
        AS registros_repetidos
FROM bi.fact_consumos_piscilago
GROUP BY tipo_vinculo
ORDER BY registros_compra DESC;




/* ============================================================
   5.6 INTEGRIDAD DE ATRIBUTOS POBLACIONALES
   SEGÚN CALIDAD DE SEGMENTACIÓN
   ============================================================

   Objetivo:
   Verificar que los registros cuya segmentación fue clasificada
   como "Consistente" tengan completos los atributos requeridos
   para los análisis poblacionales.

   Variables requeridas:
   - categoria
   - segmento_poblacional
   - piramide1
   - piramide2

   Resultado esperado:
   Los registros consistentes deben presentar 0 atributos
   poblacionales faltantes.
   ============================================================ */

SELECT
    tipo_vinculo,
    calidad_segmentacion,
    COUNT(*) AS total_registros,

    COUNT(*) FILTER (
        WHERE categoria IS NULL
           OR TRIM(categoria) = ''
    ) AS sin_categoria,

    COUNT(*) FILTER (
        WHERE segmento_poblacional IS NULL
           OR TRIM(segmento_poblacional) = ''
    ) AS sin_segmento,

    COUNT(*) FILTER (
        WHERE piramide1 IS NULL
           OR TRIM(piramide1) = ''
    ) AS sin_piramide1,

    COUNT(*) FILTER (
        WHERE piramide2 IS NULL
           OR TRIM(piramide2) = ''
    ) AS sin_piramide2

FROM bi.fact_consumos_piscilago

WHERE tipo_vinculo IN ('Afiliado', 'Grupo familiar')

GROUP BY
    tipo_vinculo,
    calidad_segmentacion

ORDER BY
    tipo_vinculo,
    calidad_segmentacion;

/* ============================================================
   RESULTADO DEL CONTROL 5.6

   La validación confirma que todos los registros clasificados
   con calidad_segmentacion = 'Consistente' cuentan con los
   atributos poblacionales requeridos para la segmentación.

   Resultados:

   Afiliado - Consistente:
   - 24.071 registros
   - Sin categoría: 0
   - Sin segmento poblacional: 0
   - Sin pirámide1: 0
   - Sin pirámide2: 0

   Grupo familiar - Consistente:
   - 385 registros
   - Sin categoría: 0
   - Sin segmento poblacional: 0
   - Sin pirámide1: 0
   - Sin pirámide2: 0

   Los perfiles clasificados como 'Ambigua' no cuentan con una
   segmentación poblacional única y, por tanto, sus atributos
   fueron conservados como NULL para evitar asignaciones
   arbitrarias.

   Los 73 registros de Grupo familiar clasificados como
   'Sin titular localizado' tampoco cuentan con atributos
   poblacionales.

   Implicación analítica:
   Para indicadores desagregados por categoría, segmento
   poblacional o pirámide se utilizarán únicamente perfiles
   cuya segmentación pueda sustentarse de manera consistente.

   Los registros ambiguos NO se eliminan de la base:
   permanecen disponibles para indicadores agregados cuando
   la definición del indicador permita incluirlos.
   ============================================================ */