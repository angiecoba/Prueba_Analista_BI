/* ============================================================
   PRUEBA ANALISTA BI - PISCILAGO
   Archivo: 02_indicadores_piscilago.sql

   Objetivo:
   Calcular los indicadores solicitados para el análisis de
   Piscilago a partir del modelo validado en PostgreSQL.

   Indicadores:
   1. Penetración
   2. Participación
   3. Cobertura

   Consideración metodológica:
   Los indicadores segmentados utilizan únicamente perfiles
   poblacionales consistentes cuando la métrica requiere
   categoría, segmento o pirámide.

   Los registros ambiguos se conservan en la base, pero no se
   asignan arbitrariamente a una dimensión poblacional.
   ============================================================ */


SET search_path TO bi;

SELECT
    current_database() AS base_datos,
    current_schema() AS esquema_actual;



/* ============================================================
   1. PENETRACIÓN
   ============================================================

   Definición:
   Proporción de afiliados que realizaron compra en Piscilago
   frente al total de afiliados del universo analítico.

   Numerador:
   Afiliados compradores únicos con perfil consistente.

   Denominador:
   Total de afiliados presentes en
   dim_afiliados_consistentes.
   ============================================================ */


/* ============================================================
   1.1 PENETRACIÓN GLOBAL - UNIVERSO CONSISTENTE
   ============================================================

   Objetivo:
   Estimar qué proporción de los afiliados con perfil
   poblacional consistente realizó compra en Piscilago.

   Numerador:
   Compradores afiliados únicos con segmentación consistente.

   Denominador:
   Total de afiliados únicos de la dimensión consistente.

   Fórmula:
   Penetración = compradores afiliados únicos
                 / total afiliados
                 * 100

   Nota:
   Se utiliza COUNT(DISTINCT id_normalizado) para medir
   personas/compradores y no registros de compra.
   ============================================================ */

WITH compradores AS (
    SELECT
        COUNT(DISTINCT id_normalizado) AS compradores_afiliados
    FROM bi.fact_consumos_piscilago
    WHERE tipo_vinculo = 'Afiliado'
      AND calidad_segmentacion = 'Consistente'
),

poblacion AS (
    SELECT
        COUNT(DISTINCT id_normalizado) AS total_afiliados
    FROM bi.dim_afiliados_consistentes
)

SELECT
    c.compradores_afiliados,
    p.total_afiliados,
    ROUND(
        c.compradores_afiliados * 100.0
        / NULLIF(p.total_afiliados, 0),
        2
    ) AS penetracion_pct
FROM compradores c
CROSS JOIN poblacion p;



/* ============================================================
   1.2 PENETRACIÓN POR CATEGORÍA Y SEGMENTO POBLACIONAL
   ============================================================

   Objetivo:
   Calcular la penetración de compradores afiliados de Piscilago
   para cada combinación de categoría y segmento poblacional.

   Numerador:
   Compradores afiliados únicos con perfil consistente
   pertenecientes a cada categoría y segmento poblacional.

   Denominador:
   Total de afiliados únicos de la misma categoría y segmento
   poblacional presentes en dim_afiliados_consistentes.

   Fórmula:
   Penetración =
       compradores afiliados únicos del grupo
       / total afiliados del grupo
       * 100

   Universo:
   Perfiles poblacionales consistentes.

   Nota metodológica:
   Los perfiles ambiguos no se asignan arbitrariamente a una
   categoría o segmento, por lo que se excluyen del cálculo
   segmentado.
   ============================================================ */

WITH compradores AS (

    SELECT
        categoria,
        segmento_poblacional,
        COUNT(DISTINCT id_normalizado) AS compradores_afiliados

    FROM bi.fact_consumos_piscilago

    WHERE tipo_vinculo = 'Afiliado'
      AND calidad_segmentacion = 'Consistente'

    GROUP BY
        categoria,
        segmento_poblacional
),

poblacion AS (

    SELECT
        categoria,
        segmento_poblacional,
        COUNT(DISTINCT id_normalizado) AS total_afiliados

    FROM bi.dim_afiliados_consistentes

    GROUP BY
        categoria,
        segmento_poblacional
)

SELECT
    p.categoria,
    p.segmento_poblacional,

    COALESCE(c.compradores_afiliados, 0)
        AS compradores_afiliados,

    p.total_afiliados,

    ROUND(
        COALESCE(c.compradores_afiliados, 0) * 100.0
        / NULLIF(p.total_afiliados, 0),
        2
    ) AS penetracion_pct

FROM poblacion p

LEFT JOIN compradores c
    ON p.categoria = c.categoria
   AND p.segmento_poblacional = c.segmento_poblacional

ORDER BY
    penetracion_pct DESC,
    p.categoria,
    p.segmento_poblacional;


/* ============================================================
   1.3 CONTROL DE RECONCILIACIÓN DE PENETRACIÓN
   ============================================================

   Objetivo:
   Verificar que la suma de los universos utilizados en la
   penetración segmentada coincida con el indicador global.

   Resultado esperado:
   - Compradores afiliados consistentes: 24.071
   - Total afiliados consistentes:       168.866
   - Penetración global:                  14,25 %

   Este control garantiza que la segmentación por categoría y
   segmento no pierda ni duplique población.
   ============================================================ */


/* ============================================================
   1.3 CONTROL DE RECONCILIACIÓN DE PENETRACIÓN
   ============================================================

   Objetivo:
   Verificar que la segmentación utilizada para calcular la
   penetración conserve exactamente el universo del indicador
   global, sin pérdida ni duplicación de afiliados.

   Validaciones:
   1. La suma de compradores únicos de los grupos debe ser
      igual a 24.071.
   2. La suma de afiliados de los grupos debe ser igual a
      168.866.
   3. La penetración resultante debe ser igual a 14,25 %.

   Nota:
   Este control es válido porque cada afiliado consistente
   pertenece a una única combinación de categoría y segmento
   poblacional dentro de la dimensión analítica.
   ============================================================ */

WITH compradores_segmentados AS (

    SELECT
        categoria,
        segmento_poblacional,
        COUNT(DISTINCT id_normalizado) AS compradores_afiliados

    FROM bi.fact_consumos_piscilago

    WHERE tipo_vinculo = 'Afiliado'
      AND calidad_segmentacion = 'Consistente'

    GROUP BY
        categoria,
        segmento_poblacional
),

poblacion_segmentada AS (

    SELECT
        categoria,
        segmento_poblacional,
        COUNT(DISTINCT id_normalizado) AS total_afiliados

    FROM bi.dim_afiliados_consistentes

    GROUP BY
        categoria,
        segmento_poblacional
),

reconciliacion AS (

    SELECT
        p.categoria,
        p.segmento_poblacional,
        COALESCE(c.compradores_afiliados, 0)
            AS compradores_afiliados,
        p.total_afiliados

    FROM poblacion_segmentada p

    LEFT JOIN compradores_segmentados c
        ON p.categoria = c.categoria
       AND p.segmento_poblacional = c.segmento_poblacional
)

SELECT
    SUM(compradores_afiliados) AS compradores_segmentados,
    SUM(total_afiliados) AS afiliados_segmentados,

    ROUND(
        SUM(compradores_afiliados) * 100.0
        / NULLIF(SUM(total_afiliados), 0),
        2
    ) AS penetracion_recalculada_pct

FROM reconciliacion;





/* ============================================================
   2. PARTICIPACIÓN GLOBAL
   ============================================================

   Definición:
   Proporción de compradores de Piscilago que corresponden
   a afiliados.

   Numerador:
   Compradores afiliados únicos.

   Denominador:
   Compradores totales únicos de Piscilago.

   Fórmula:
   Participación =
       compradores afiliados únicos
       / compradores totales únicos
       * 100

   Universo:
   Total de compradores registrados en Piscilago.

   Nota:
   A diferencia de la penetración, este indicador no utiliza
   como denominador la población afiliada total, sino el total
   de compradores observados en la tabla de hechos.
   ============================================================ */

WITH afiliados AS (
    SELECT
        COUNT(DISTINCT id_normalizado) AS compradores_afiliados
    FROM bi.fact_consumos_piscilago
    WHERE tipo_vinculo = 'Afiliado'
),

total_compradores AS (
    SELECT
        COUNT(DISTINCT id_normalizado) AS compradores_totales
    FROM bi.fact_consumos_piscilago
)

SELECT
    a.compradores_afiliados,
    t.compradores_totales,
    ROUND(
        a.compradores_afiliados * 100.0
        / NULLIF(t.compradores_totales, 0),
        2
    ) AS participacion_pct
FROM afiliados a
CROSS JOIN total_compradores t;


/* ============================================================
   2.2 PARTICIPACIÓN POR CATEGORÍA Y SEGMENTO POBLACIONAL
   ============================================================

   Objetivo:
   Identificar qué proporción del total de compradores de
   Piscilago corresponde a afiliados de cada combinación de
   categoría y segmento poblacional.

   Numerador:
   Compradores afiliados únicos con segmentación consistente
   pertenecientes a cada categoría y segmento.

   Denominador:
   Total de compradores únicos de Piscilago.

   Fórmula:
   Participación del grupo =
       compradores afiliados del grupo
       / compradores totales
       * 100

   Consideración metodológica:
   Solo se distribuyen por categoría y segmento los afiliados
   cuya calidad de segmentación es 'Consistente'.

   Los afiliados con segmentación ambigua permanecen en el
   cálculo de participación global, pero no se asignan
   arbitrariamente a una categoría o segmento.
   ============================================================ */

WITH total_compradores AS (
    SELECT
        COUNT(DISTINCT id_normalizado) AS compradores_totales
    FROM bi.fact_consumos_piscilago
),

afiliados_segmentados AS (
    SELECT
        categoria,
        segmento_poblacional,
        COUNT(DISTINCT id_normalizado) AS compradores_afiliados
    FROM bi.fact_consumos_piscilago
    WHERE tipo_vinculo = 'Afiliado'
      AND calidad_segmentacion = 'Consistente'
    GROUP BY
        categoria,
        segmento_poblacional
)

SELECT
    a.categoria,
    a.segmento_poblacional,
    a.compradores_afiliados,
    t.compradores_totales,
    ROUND(
        a.compradores_afiliados * 100.0
        / NULLIF(t.compradores_totales, 0),
        2
    ) AS participacion_pct
FROM afiliados_segmentados a
CROSS JOIN total_compradores t
ORDER BY
    participacion_pct DESC,
    a.categoria,
    a.segmento_poblacional;


/* ============================================================
   2.3 CONTROL DE RECONCILIACIÓN DE PARTICIPACIÓN
   ============================================================

   Objetivo:
   Verificar la relación entre la participación global de
   afiliados y la participación que puede distribuirse de
   manera confiable por categoría y segmento poblacional.

   Universo:
   145.060 compradores únicos de Piscilago.

   Resultado esperado:
   - Compradores afiliados totales:       96.756
   - Afiliados con perfil consistente:    24.071
   - Afiliados con perfil ambiguo:        72.685

   Participación global afiliados:
   96.756 / 145.060 = 66,70 %

   Participación segmentable:
   24.071 / 145.060 = 16,59 %

   Participación afiliada no segmentable:
   72.685 / 145.060 = 50,11 %

   Control:
   16,59 % + 50,11 % = 66,70 %

   Nota metodológica:
   Los afiliados con calidad de segmentación 'Ambigua' forman
   parte de la participación global porque su condición de
   afiliado está identificada.

   Sin embargo, no se distribuyen por categoría y segmento,
   debido a que no existe un perfil poblacional único y
   consistente que permita asignarlos sin introducir sesgo.
   ============================================================ */

WITH afiliados AS (
    SELECT
        COUNT(DISTINCT id_normalizado)
            FILTER (WHERE tipo_vinculo = 'Afiliado')
            AS afiliados_totales,

        COUNT(DISTINCT id_normalizado)
            FILTER (
                WHERE tipo_vinculo = 'Afiliado'
                  AND calidad_segmentacion = 'Consistente'
            ) AS afiliados_consistentes,

        COUNT(DISTINCT id_normalizado)
            FILTER (
                WHERE tipo_vinculo = 'Afiliado'
                  AND calidad_segmentacion = 'Ambigua'
            ) AS afiliados_ambiguos,

        COUNT(DISTINCT id_normalizado)
            AS compradores_totales

    FROM bi.fact_consumos_piscilago
)

SELECT
    afiliados_totales,
    afiliados_consistentes,
    afiliados_ambiguos,
    compradores_totales,

    ROUND(
        afiliados_totales * 100.0
        / NULLIF(compradores_totales, 0),
        2
    ) AS participacion_global_pct,

    ROUND(
        afiliados_consistentes * 100.0
        / NULLIF(compradores_totales, 0),
        2
    ) AS participacion_segmentable_pct,

    ROUND(
        afiliados_ambiguos * 100.0
        / NULLIF(compradores_totales, 0),
        2
    ) AS participacion_no_segmentable_pct

FROM afiliados;




/* ============================================================
   3. COBERTURA GLOBAL
   ============================================================

   Definición:
   Proporción de compradores de Piscilago que presentan algún
   vínculo con la Caja, ya sea como afiliados directos o como
   integrantes del grupo familiar.

   Numerador:
   Compradores únicos clasificados como:
   - Afiliado
   - Grupo familiar

   Denominador:
   Total de compradores únicos de Piscilago.

   Fórmula:
   Cobertura =
       (compradores afiliados + compradores grupo familiar)
       / compradores totales
       * 100

   Universo:
   Total de compradores registrados en Piscilago.
   ============================================================ */

WITH cobertura AS (
    SELECT
        COUNT(DISTINCT id_normalizado)
            FILTER (
                WHERE tipo_vinculo IN ('Afiliado', 'Grupo familiar')
            ) AS compradores_cubiertos,

        COUNT(DISTINCT id_normalizado)
            FILTER (
                WHERE tipo_vinculo = 'Afiliado'
            ) AS compradores_afiliados,

        COUNT(DISTINCT id_normalizado)
            FILTER (
                WHERE tipo_vinculo = 'Grupo familiar'
            ) AS compradores_grupo_familiar,

        COUNT(DISTINCT id_normalizado)
            AS compradores_totales

    FROM bi.fact_consumos_piscilago
)

SELECT
    compradores_afiliados,
    compradores_grupo_familiar,
    compradores_cubiertos,
    compradores_totales,

    ROUND(
        compradores_cubiertos * 100.0
        / NULLIF(compradores_totales, 0),
        2
    ) AS cobertura_pct

FROM cobertura;



/* ============================================================
   3.2 COBERTURA POR SEGMENTO POBLACIONAL Y PIRÁMIDE 1
   ============================================================

   Objetivo:
   Analizar la cobertura de compradores vinculados a la Caja
   según segmento poblacional y Pirámide 1.

   Numerador:
   Compradores únicos clasificados como Afiliado o Grupo familiar
   cuya segmentación es consistente.

   Denominador:
   Total de compradores únicos de Piscilago.

   Consideración metodológica:
   La cobertura global incluye todos los compradores identificados
   como Afiliado o Grupo familiar.

   Para la desagregación por segmento y pirámide únicamente se
   utilizan registros con calidad_segmentacion = 'Consistente',
   evitando asignar perfiles poblacionales ambiguos de manera
   arbitraria.

   Por esta razón, la suma de la cobertura segmentada puede ser
   inferior a la cobertura global de 71,77 %.
   ============================================================ */

WITH total_compradores AS (
    SELECT
        COUNT(DISTINCT id_normalizado) AS compradores_totales
    FROM bi.fact_consumos_piscilago
),

cubiertos_segmentados AS (
    SELECT
        segmento_poblacional,
        piramide1,
        COUNT(DISTINCT id_normalizado) AS compradores_cubiertos
    FROM bi.fact_consumos_piscilago
    WHERE tipo_vinculo IN ('Afiliado', 'Grupo familiar')
      AND calidad_segmentacion = 'Consistente'
    GROUP BY
        segmento_poblacional,
        piramide1
)

SELECT
    c.segmento_poblacional,
    c.piramide1,
    c.compradores_cubiertos,
    t.compradores_totales,

    ROUND(
        c.compradores_cubiertos * 100.0
        / NULLIF(t.compradores_totales, 0),
        2
    ) AS cobertura_pct

FROM cubiertos_segmentados c
CROSS JOIN total_compradores t

ORDER BY
    cobertura_pct DESC,
    c.segmento_poblacional,
    c.piramide1;


/* ============================================================
   3.3 CONTROL DE RECONCILIACIÓN DE COBERTURA
   ============================================================

   Objetivo:
   Verificar qué parte de la cobertura global puede desagregarse
   de manera confiable por segmento poblacional y Pirámide 1.

   Cobertura global:
   - Afiliados:                96.756
   - Grupo familiar:            7.358
   - Total cubiertos:          104.114
   - Compradores totales:      145.060
   - Cobertura global:          71,77 %

   Cobertura segmentable:
   Solo considera Afiliados y Grupo familiar cuya
   calidad_segmentacion = 'Consistente'.

   Resultado esperado:
   - Afiliados consistentes:       24.071
   - Grupo familiar consistente:      385
   - Total segmentable:            24.456

   Los compradores cubiertos restantes continúan formando parte
   de la cobertura global, pero no se asignan a segmento o
   pirámide cuando su perfil no es suficientemente confiable.
   ============================================================ */

WITH cobertura AS (
    SELECT
        COUNT(DISTINCT id_normalizado)
            FILTER (
                WHERE tipo_vinculo IN ('Afiliado', 'Grupo familiar')
            ) AS cubiertos_totales,

        COUNT(DISTINCT id_normalizado)
            FILTER (
                WHERE tipo_vinculo = 'Afiliado'
                  AND calidad_segmentacion = 'Consistente'
            ) AS afiliados_consistentes,

        COUNT(DISTINCT id_normalizado)
            FILTER (
                WHERE tipo_vinculo = 'Grupo familiar'
                  AND calidad_segmentacion = 'Consistente'
            ) AS grupo_familiar_consistente,

        COUNT(DISTINCT id_normalizado)
            FILTER (
                WHERE tipo_vinculo IN ('Afiliado', 'Grupo familiar')
                  AND calidad_segmentacion = 'Consistente'
            ) AS cubiertos_segmentables,

        COUNT(DISTINCT id_normalizado) AS compradores_totales

    FROM bi.fact_consumos_piscilago
)

SELECT
    cubiertos_totales,
    afiliados_consistentes,
    grupo_familiar_consistente,
    cubiertos_segmentables,

    cubiertos_totales - cubiertos_segmentables
        AS cubiertos_no_segmentables,

    compradores_totales,

    ROUND(
        cubiertos_totales * 100.0
        / NULLIF(compradores_totales, 0),
        2
    ) AS cobertura_global_pct,

    ROUND(
        cubiertos_segmentables * 100.0
        / NULLIF(compradores_totales, 0),
        2
    ) AS cobertura_segmentable_pct,

    ROUND(
        (cubiertos_totales - cubiertos_segmentables) * 100.0
        / NULLIF(compradores_totales, 0),
        2
    ) AS cobertura_no_segmentable_pct

FROM cobertura;


/* ============================================================
   3.4 CONTROL DE RECONCILIACIÓN DE COBERTURA SEGMENTADA
   ============================================================

   Objetivo:
   Verificar que la suma de compradores únicos distribuidos
   entre las combinaciones de segmento poblacional y Pirámide 1
   coincida con el universo de compradores cubiertos cuya
   segmentación es consistente.

   Resultado esperado:
   - Combinaciones segmento x pirámide: 20
   - Compradores segmentados:          24.456
   - Universo segmentable:             24.456
   - Diferencia:                            0

   Este control confirma que la desagregación no genera pérdida
   ni duplicación de compradores entre los grupos analizados.
   ============================================================ */

WITH cobertura_segmentada AS (
    SELECT
        segmento_poblacional,
        piramide1,
        COUNT(DISTINCT id_normalizado) AS compradores_cubiertos
    FROM bi.fact_consumos_piscilago
    WHERE tipo_vinculo IN ('Afiliado', 'Grupo familiar')
      AND calidad_segmentacion = 'Consistente'
    GROUP BY
        segmento_poblacional,
        piramide1
),

universo_segmentable AS (
    SELECT
        COUNT(DISTINCT id_normalizado) AS compradores_segmentables
    FROM bi.fact_consumos_piscilago
    WHERE tipo_vinculo IN ('Afiliado', 'Grupo familiar')
      AND calidad_segmentacion = 'Consistente'
)

SELECT
    COUNT(*) AS combinaciones_segmento_piramide,
    SUM(c.compradores_cubiertos) AS compradores_segmentados,
    u.compradores_segmentables AS universo_segmentable,
    SUM(c.compradores_cubiertos) - u.compradores_segmentables
        AS diferencia
FROM cobertura_segmentada c
CROSS JOIN universo_segmentable u
GROUP BY
    u.compradores_segmentables;