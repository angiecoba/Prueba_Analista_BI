/*
==========================================================
PRUEBA TÉCNICA - ANALISTA BI
EJERCICIO 2 - DIGITURNOS
PREGUNTA A: TIEMPOS DE ESPERA POR SEDE Y TIPO DE SERVICIO
==========================================================

OBJETIVO
Calcular el tiempo promedio transcurrido entre la
solicitud del servicio y la llamada al usuario,
desagregado por sede y tipo de servicio.

FUENTE
Esquema: digiturnos
Tabla: digiturnos_atenciones

UNIDAD DE ANÁLISIS
Una solicitud de atención identificada mediante
id_registro_original.

CAMPO DE MEDICIÓN
espera_min_diag: tiempo de espera calculado previamente,
expresado en minutos.

REGLAS METODOLÓGICAS
1. Se conserva el total de solicitudes para establecer
   el volumen de demanda de cada grupo.
2. Se excluyen los valores negativos del cálculo
   de indicadores de espera.
3. Se conservan las esperas iguales a cero, dado que
   pueden representar atenciones inmediatas.
4. Se reporta la cobertura de esperas válidas.
5. Se calculan promedio, mediana y percentil 90.
6. No se aplica un umbral máximo arbitrario.
7. La validez definitiva debe contrastarse con las
   banderas de calidad del modelo de preparación.

LIMITACIONES
La existencia de un tiempo numérico no garantiza,
por sí sola, que la secuencia de eventos sea válida.

==========================================================
*/

WITH base AS (

    -- Normalización de dimensiones y validación básica.
    SELECT
        id_registro_original,

        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        COALESCE(
            NULLIF(TRIM("Tipo_servicio"), ''),
            'Sin clasificación'
        ) AS tipo_servicio,

        espera_min_diag,

        CASE
            WHEN espera_min_diag IS NULL THEN FALSE
            WHEN espera_min_diag < 0 THEN FALSE
            ELSE TRUE
        END AS espera_valida

    FROM digiturnos.digiturnos_atenciones

),

indicadores AS (

    -- Agregación por sede y tipo de servicio.
    SELECT
        sede,
        tipo_servicio,

        COUNT(*) AS total_solicitudes,

        COUNT(*) FILTER (
            WHERE espera_valida
        ) AS solicitudes_validas,

        COUNT(*) FILTER (
            WHERE NOT espera_valida
        ) AS solicitudes_excluidas,

        COUNT(*) FILTER (
            WHERE espera_valida
              AND espera_min_diag = 0
        ) AS solicitudes_espera_cero,

        AVG(espera_min_diag)
            FILTER (WHERE espera_valida)
            AS promedio,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY espera_min_diag)
            FILTER (WHERE espera_valida)
            AS mediana,

        PERCENTILE_CONT(0.9)
            WITHIN GROUP (ORDER BY espera_min_diag)
            FILTER (WHERE espera_valida)
            AS p90

    FROM base

    GROUP BY
        sede,
        tipo_servicio

)

-- Presentación final de los indicadores.
SELECT
    sede,
    tipo_servicio,

    total_solicitudes,
    solicitudes_validas,
    solicitudes_excluidas,
    solicitudes_espera_cero,

    ROUND(
        100.0 * solicitudes_validas
        / NULLIF(total_solicitudes, 0),
        2
    ) AS pct_esperas_validas,

    ROUND(promedio::numeric, 2)
        AS espera_promedio_min,

    ROUND(mediana::numeric, 2)
        AS espera_mediana_min,

    ROUND(p90::numeric, 2)
        AS espera_p90_min

FROM indicadores

ORDER BY
    espera_promedio_min DESC NULLS LAST,
    total_solicitudes DESC;



/*
CONTROL DE CALIDAD COMPLEMENTARIO
Distribución de esperas iguales a cero por tipo de servicio.

Propósito:
Identificar si las esperas inmediatas están distribuidas
de forma homogénea o concentradas en una categoría.
*/

SELECT
    "Tipo_servicio" AS tipo_servicio,

    COUNT(*) AS total_solicitudes,

    COUNT(*) FILTER (
        WHERE espera_min_diag = 0
    ) AS esperas_cero,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE espera_min_diag = 0
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pct_esperas_cero,

    COUNT(*) FILTER (
        WHERE espera_min_diag < 0
    ) AS esperas_negativas,

    ROUND(
        AVG(espera_min_diag)
            FILTER (WHERE espera_min_diag > 0)::numeric,
        2
    ) AS promedio_solo_esperas_positivas

FROM digiturnos.digiturnos_atenciones

GROUP BY "Tipo_servicio"

ORDER BY total_solicitudes DESC;


/*
==========================================================
3. PREGUNTA B - PICOS DE DEMANDA
==========================================================

OBJETIVO
Identificar los periodos de mayor demanda de servicios
según sede, día de la semana y hora de solicitud.

FUENTE
digiturnos.digiturnos_franjas

GRANULARIDAD
Cada registro representa una combinación de:
- Sede
- Fecha calendario
- Hora de solicitud

METODOLOGÍA
1. Agrupar las solicitudes por sede, día y hora.
2. Calcular el volumen acumulado de solicitudes.
3. Calcular el promedio por franja observada.
4. Identificar las horas con mayor demanda en cada sede.
5. Conservar el número de franjas para evaluar la
   comparabilidad entre periodos.

CONSIDERACIONES
- La columna dia_semana utiliza la codificación
  de la fuente; verificamos su correspondencia
  antes de asignar nombres a los días.
- No se deben sumar promedios ya calculados.
- El promedio por franja es una medida descriptiva
  de la demanda, no de la capacidad de atención.
==========================================================
*/


-- -------------------------------------------------------
-- 3.1. VALIDACIÓN DE LA CODIFICACIÓN DEL DÍA DE SEMANA
-- -------------------------------------------------------
-- Compara el código de origen con el día calendario.
-- PostgreSQL: ISODOW devuelve lunes=1 y domingo=7.

SELECT
    dia_semana AS codigo_origen,
    EXTRACT(ISODOW FROM fecha_dia)::integer
        AS codigo_calendario,
    COUNT(*) AS franjas,

    SUM(solicitudes) AS solicitudes

FROM digiturnos.digiturnos_franjas

GROUP BY
    dia_semana,
    EXTRACT(ISODOW FROM fecha_dia)

ORDER BY
    codigo_origen,
    codigo_calendario;


-- -------------------------------------------------------
-- 3.2. DEMANDA POR SEDE, DÍA DE SEMANA Y HORA
-- -------------------------------------------------------
-- Indicadores:
-- total_solicitudes: volumen acumulado.
-- franjas_observadas: cantidad de registros de franja.
-- promedio_solicitudes_franja: intensidad promedio.
-- max_solicitudes_franja: máximo diario observado.
--
-- Se calcula el día desde la fecha para garantizar
-- que el nombre corresponda al calendario.

WITH demanda AS (

    SELECT
        sede,

        EXTRACT(ISODOW FROM fecha_dia)::integer
            AS dia_semana,

        hora_solicitud,

        COUNT(*) AS franjas_observadas,

        SUM(solicitudes) AS total_solicitudes,

        AVG(solicitudes::numeric)
            AS promedio_solicitudes_franja,

        MAX(solicitudes)
            AS max_solicitudes_franja

    FROM digiturnos.digiturnos_franjas

    WHERE fecha_dia IS NOT NULL
      AND hora_solicitud BETWEEN 0 AND 23
      AND solicitudes IS NOT NULL

    GROUP BY
        sede,
        EXTRACT(ISODOW FROM fecha_dia),
        hora_solicitud

)

SELECT
    sede,

    dia_semana,

    CASE dia_semana
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
    END AS nombre_dia,

    hora_solicitud,

    franjas_observadas,

    total_solicitudes,

    ROUND(
        promedio_solicitudes_franja,
        2
    ) AS promedio_solicitudes_franja,

    max_solicitudes_franja

FROM demanda

ORDER BY
    sede,
    dia_semana,
    hora_solicitud;


-- -------------------------------------------------------
-- 3.3. TOP 3 DE PICOS DE DEMANDA POR SEDE
-- -------------------------------------------------------
-- Se ordenan las combinaciones día-hora según
-- la demanda promedio, no solo el volumen acumulado.
--
-- El ranking es descriptivo. Las franjas con pocas
-- observaciones requieren interpretación cautelosa.

WITH demanda AS (

    SELECT
        sede,

        EXTRACT(ISODOW FROM fecha_dia)::integer
            AS dia_semana,

        hora_solicitud,

        COUNT(*) AS franjas_observadas,

        SUM(solicitudes) AS total_solicitudes,

        AVG(solicitudes::numeric)
            AS promedio_solicitudes

    FROM digiturnos.digiturnos_franjas

    WHERE fecha_dia IS NOT NULL
      AND hora_solicitud BETWEEN 0 AND 23
      AND solicitudes IS NOT NULL

    GROUP BY
        sede,
        EXTRACT(ISODOW FROM fecha_dia),
        hora_solicitud

),

ranking AS (

    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY sede
            ORDER BY
                promedio_solicitudes DESC,
                total_solicitudes DESC,
                dia_semana,
                hora_solicitud
        ) AS posicion

    FROM demanda

)

SELECT
    sede,
    posicion AS ranking_pico,

    dia_semana,

    CASE dia_semana
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
    END AS nombre_dia,

    hora_solicitud,

    franjas_observadas,

    total_solicitudes,

    ROUND(
        promedio_solicitudes,
        2
    ) AS promedio_solicitudes_franja

FROM ranking

WHERE posicion <= 3

ORDER BY
    sede,
    ranking_pico;



/*
==========================================================
3.4. CONTROL DE CALIDAD DE LAS FRANJAS HORARIAS
==========================================================

OBJETIVO
Verificar la integridad de la tabla agregada utilizada
para identificar los picos de demanda.

VALIDACIONES
1. Total de solicitudes.
2. Número de franjas registradas.
3. Número de combinaciones únicas sede-fecha-hora.
4. Existencia de franjas con solicitudes negativas.
5. Existencia de valores nulos en campos clave.

CRITERIO DE ACEPTACIÓN
- El total de solicitudes debe coincidir con la tabla
  de atenciones: 883.080 registros.
- La diferencia entre filas y combinaciones únicas
  debe ser cero, si el modelo tiene una fila por franja.

NOTA
Este control no modifica ni elimina registros.
==========================================================
*/

SELECT
    COUNT(*) AS total_franjas,

    SUM(solicitudes) AS total_solicitudes,

    COUNT(DISTINCT (
        sede,
        fecha_dia,
        hora_solicitud
    )) AS combinaciones_unicas,

    COUNT(*) -
    COUNT(DISTINCT (
        sede,
        fecha_dia,
        hora_solicitud
    )) AS posibles_duplicados,

    COUNT(*) FILTER (
        WHERE solicitudes < 0
    ) AS franjas_negativas,

    COUNT(*) FILTER (
        WHERE sede IS NULL
           OR fecha_dia IS NULL
           OR hora_solicitud IS NULL
           OR solicitudes IS NULL
    ) AS franjas_con_nulos

FROM digiturnos.digiturnos_franjas;




/*
============================================================
SECCION 4. IDENTIFICACION DE CUELLOS DE BOTELLA
EJERCICIO 2 - PREGUNTA C
============================================================

OBJETIVO
Identificar sedes y tipos de servicio con mayores
dificultades en la oportunidad de atencion.

METODOLOGIA
Se analizan:
1. Volumen de solicitudes.
2. Espera promedio y mediana.
3. Percentil 90 de espera.
4. Porcentaje de esperas superiores a 15 minutos.
5. Porcentaje de esperas superiores a 30 minutos.

CRITERIOS DE INTERPRETACION
- El promedio mide la espera general.
- La mediana representa la espera habitual.
- El percentil 90 identifica la cola de esperas.
- Los umbrales de 15 y 30 minutos se utilizan
  como referencias exploratorias, no como metas
  institucionales oficialmente establecidas.

CONTROL DE CALIDAD
Se excluyen del calculo de tiempos las esperas
negativas, por representar inconsistencias
cronologicas.

Las esperas iguales a cero se conservan porque
pueden representar atencion inmediata.

Las solicitudes excluidas del calculo de tiempos
siguen contabilizadas en el volumen total.

FUENTE
digiturnos.digiturnos_atenciones

NOTA
Consulta de solo lectura. No modifica datos.
============================================================
*/

WITH base AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        COALESCE(
            NULLIF(TRIM("Tipo_servicio"), ''),
            'Sin clasificacion'
        ) AS tipo_servicio,

        espera_min_diag

    FROM digiturnos.digiturnos_atenciones
),

indicadores AS (
    SELECT
        sede,
        tipo_servicio,

        COUNT(*) AS total_solicitudes,

        COUNT(*) FILTER (
            WHERE espera_min_diag >= 0
        ) AS solicitudes_validas,

        COUNT(*) FILTER (
            WHERE espera_min_diag < 0
               OR espera_min_diag IS NULL
        ) AS solicitudes_invalidas,

        ROUND(
            AVG(espera_min_diag)
                FILTER (
                    WHERE espera_min_diag >= 0
                )::numeric,
            2
        ) AS espera_promedio_min,

        ROUND(
            PERCENTILE_CONT(0.5)
                WITHIN GROUP (
                    ORDER BY espera_min_diag
                )
                FILTER (
                    WHERE espera_min_diag >= 0
                )::numeric,
            2
        ) AS espera_mediana_min,

        ROUND(
            PERCENTILE_CONT(0.9)
                WITHIN GROUP (
                    ORDER BY espera_min_diag
                )
                FILTER (
                    WHERE espera_min_diag >= 0
                )::numeric,
            2
        ) AS espera_p90_min,

        COUNT(*) FILTER (
            WHERE espera_min_diag > 15
        ) AS solicitudes_mas_15_min,

        COUNT(*) FILTER (
            WHERE espera_min_diag > 30
        ) AS solicitudes_mas_30_min

    FROM base

    GROUP BY
        sede,
        tipo_servicio
)

SELECT
    sede,
    tipo_servicio,
    total_solicitudes,
    solicitudes_validas,
    solicitudes_invalidas,
    espera_promedio_min,
    espera_mediana_min,
    espera_p90_min,
    solicitudes_mas_15_min,

    ROUND(
        100.0 * solicitudes_mas_15_min
        / NULLIF(solicitudes_validas, 0),
        2
    ) AS pct_mas_15_min,

    solicitudes_mas_30_min,

    ROUND(
        100.0 * solicitudes_mas_30_min
        / NULLIF(solicitudes_validas, 0),
        2
    ) AS pct_mas_30_min

FROM indicadores

ORDER BY
    espera_p90_min DESC NULLS LAST,
    total_solicitudes DESC;


/*
============================================================
4.2. DIAGNOSTICO DE PRESION OPERATIVA POR SEDE
EJERCICIO 2 - PREGUNTA C
============================================================

OBJETIVO
Identificar las sedes con mayor coincidencia entre
alta demanda y esperas elevadas.

FUENTE
digiturnos.digiturnos_franjas

UNIDAD DE ANALISIS
Una fila por sede, fecha y hora de solicitud.

METODOLOGIA
Se calcula por sede:
1. Total de franjas observadas.
2. Volumen de solicitudes.
3. Demanda promedio por franja.
4. Espera promedio ponderada por solicitudes.
5. Percentil 90 de espera entre franjas.
6. Franjas con alta demanda relativa.
7. Franjas con espera elevada relativa.
8. Franjas donde coinciden ambas condiciones.
9. Promedio de receptores activos.

ADVERTENCIAS
- Los indicadores relativos dependen de los
  criterios definidos en la preparacion de datos.
- Los receptores activos no equivalen
  necesariamente a la dotacion programada.
- La coincidencia de alertas permite priorizar
  investigaciones, pero no demuestra causalidad.
- El promedio ponderado utiliza el volumen
  de solicitudes de cada franja.

CONTROL
Consulta de solo lectura. No altera registros.
============================================================
*/

WITH base AS (
    SELECT
        sede,
        solicitudes,
        espera_promedio_min,
        receptores_activos,

        CASE
            WHEN LOWER(TRIM(alta_demanda_relativa))
                 IN ('true', 't', '1', 'si', 'sí')
            THEN 1 ELSE 0
        END AS indicador_alta_demanda,

        CASE
            WHEN LOWER(TRIM(espera_elevada_relativa))
                 IN ('true', 't', '1', 'si', 'sí')
            THEN 1 ELSE 0
        END AS indicador_espera_elevada

    FROM digiturnos.digiturnos_franjas
),

indicadores AS (
    SELECT
        sede,

        COUNT(*) AS total_franjas,

        SUM(solicitudes) AS total_solicitudes,

        ROUND(
            AVG(solicitudes)::numeric, 2
        ) AS solicitudes_promedio_franja,

        ROUND(
            (
                SUM(
                    espera_promedio_min * solicitudes
                ) FILTER (
                    WHERE espera_promedio_min >= 0
                )
                /
                NULLIF(
                    SUM(solicitudes) FILTER (
                        WHERE espera_promedio_min >= 0
                    ), 0
                )
            )::numeric,
            2
        ) AS espera_ponderada_min,

        ROUND(
            PERCENTILE_CONT(0.9)
            WITHIN GROUP (
                ORDER BY espera_promedio_min
            )
            FILTER (
                WHERE espera_promedio_min >= 0
            )::numeric,
            2
        ) AS p90_espera_franjas_min,

        SUM(indicador_alta_demanda)
            AS franjas_alta_demanda,

        SUM(indicador_espera_elevada)
            AS franjas_espera_elevada,

        COUNT(*) FILTER (
            WHERE indicador_alta_demanda = 1
              AND indicador_espera_elevada = 1
        ) AS franjas_criticas_coincidentes,

        ROUND(
            AVG(
                NULLIF(
                    receptores_activos::numeric,
                    0
                )
            ),
            2
        ) AS receptores_activos_promedio

    FROM base

    GROUP BY sede
)

SELECT
    sede,
    total_franjas,
    total_solicitudes,
    solicitudes_promedio_franja,
    espera_ponderada_min,
    p90_espera_franjas_min,
    franjas_alta_demanda,
    franjas_espera_elevada,
    franjas_criticas_coincidentes,

    ROUND(
        100.0 * franjas_criticas_coincidentes
        / NULLIF(total_franjas, 0),
        2
    ) AS pct_franjas_criticas,

    receptores_activos_promedio

FROM indicadores

ORDER BY
    pct_franjas_criticas DESC NULLS LAST,
    total_solicitudes DESC;


/*
============================================================
4.3. FRANJAS HORARIAS CON MAYOR PRESION OPERATIVA
EJERCICIO 2 - PREGUNTA C
============================================================

OBJETIVO
Identificar, para cada sede, los dias y horas con
mayor recurrencia de franjas criticas.

FUENTE
digiturnos.digiturnos_franjas

UNIDAD DE ANALISIS
Sede + dia de semana + hora de solicitud.

METODOLOGIA
1. Identificar franjas con alta demanda relativa.
2. Identificar franjas con espera elevada relativa.
3. Detectar la coincidencia de ambas condiciones.
4. Agrupar por sede, dia de semana y hora.
5. Calcular la frecuencia y proporcion de
   franjas criticas.
6. Priorizar las tres combinaciones horarias con
   mayor proporcion de franjas criticas por sede.

ADVERTENCIAS
- Se utiliza el dia calendario derivado de la fecha.
- Se requiere una cantidad minima de observaciones
  para evitar priorizar horarios aislados.
- Se fija un minimo exploratorio de 10 franjas
  observadas por combinacion.
- La clasificacion no establece causalidad.
- La consulta no modifica registros.
============================================================
*/

WITH base AS (
    SELECT
        sede,
        EXTRACT(
            ISODOW FROM fecha_dia
        )::integer AS dia_semana,

        hora_solicitud,
        solicitudes,
        espera_promedio_min,
        receptores_activos,

        CASE
            WHEN LOWER(TRIM(alta_demanda_relativa))
                 IN ('true', 't', '1', 'si', 'sí')
            THEN 1 ELSE 0
        END AS alta_demanda,

        CASE
            WHEN LOWER(TRIM(espera_elevada_relativa))
                 IN ('true', 't', '1', 'si', 'sí')
            THEN 1 ELSE 0
        END AS espera_elevada

    FROM digiturnos.digiturnos_franjas
),

agrupado AS (
    SELECT
        sede,
        dia_semana,
        hora_solicitud,

        COUNT(*) AS franjas_observadas,

        SUM(solicitudes) AS solicitudes,

        ROUND(
            AVG(solicitudes)::numeric, 2
        ) AS solicitudes_promedio_franja,

        ROUND(
            (
                SUM(
                    espera_promedio_min * solicitudes
                ) FILTER (
                    WHERE espera_promedio_min >= 0
                )
                /
                NULLIF(
                    SUM(solicitudes) FILTER (
                        WHERE espera_promedio_min >= 0
                    ), 0
                )
            )::numeric,
            2
        ) AS espera_ponderada_min,

        ROUND(
            AVG(
                NULLIF(
                    receptores_activos::numeric,
                    0
                )
            ),
            2
        ) AS receptores_activos_promedio,

        COUNT(*) FILTER (
            WHERE alta_demanda = 1
              AND espera_elevada = 1
        ) AS franjas_criticas

    FROM base

    GROUP BY
        sede,
        dia_semana,
        hora_solicitud
),

indicadores AS (
    SELECT
        *,

        ROUND(
            100.0 * franjas_criticas
            / NULLIF(franjas_observadas, 0),
            2
        ) AS pct_franjas_criticas

    FROM agrupado

    WHERE franjas_observadas >= 10
),

priorizacion AS (
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY sede
            ORDER BY
                pct_franjas_criticas DESC,
                franjas_criticas DESC,
                solicitudes DESC,
                dia_semana,
                hora_solicitud
        ) AS prioridad

    FROM indicadores
)

SELECT
    sede,
    prioridad,
    dia_semana,

    CASE dia_semana
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miercoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sabado'
        WHEN 7 THEN 'Domingo'
    END AS nombre_dia,

    hora_solicitud,
    franjas_observadas,
    solicitudes,
    solicitudes_promedio_franja,
    espera_ponderada_min,
    receptores_activos_promedio,
    franjas_criticas,
    pct_franjas_criticas

FROM priorizacion

WHERE prioridad <= 3

ORDER BY
    sede,
    prioridad;



/*
============================================================
SECCION 5. UTILIZACION DE USUARIOS RECEPTORES
EJERCICIO 2 - PREGUNTA D

5.1. CONTROL DE CALIDAD DE TIEMPOS DE ATENCION
============================================================

OBJETIVO
Verificar la disponibilidad y consistencia de los
datos necesarios para calcular la carga operativa
de los usuarios receptores.

FUENTE
digiturnos.digiturnos_atenciones

DEFINICIONES
- Atencion: intervalo entre llamada y finalizacion.
- Duracion valida: intervalo no negativo.
- Receptor identificado: registro con identificador
  de receptor no nulo ni vacio.

ADVERTENCIA METODOLOGICA
El tiempo efectivo de atencion puede calcularse
a partir de las marcas temporales.

La utilizacion laboral real requiere conocer
tambien el tiempo disponible o programado.
Sin ese dato solo es posible estimar indicadores
de ocupacion bajo supuestos documentados.

CONTROL
Consulta de solo lectura. No modifica registros.
============================================================
*/

WITH base AS (
    SELECT
        sede,
        NULLIF(TRIM(receptor), '') AS receptor,
        dt_llamado,
        dt_finalizacion,

        EXTRACT(
            EPOCH FROM (
                dt_finalizacion - dt_llamado
            )
        ) / 60.0 AS duracion_calculada_min

    FROM digiturnos.digiturnos_atenciones
)

SELECT
    COUNT(*) AS total_solicitudes,

    COUNT(DISTINCT receptor)
        AS receptores_identificados,

    COUNT(*) FILTER (
        WHERE receptor IS NULL
    ) AS solicitudes_sin_receptor,

    COUNT(*) FILTER (
        WHERE dt_llamado IS NULL
           OR dt_finalizacion IS NULL
    ) AS solicitudes_sin_marcas_completas,

    COUNT(*) FILTER (
        WHERE duracion_calculada_min < 0
    ) AS duraciones_negativas,

    COUNT(*) FILTER (
        WHERE duracion_calculada_min = 0
    ) AS duraciones_cero,

    COUNT(*) FILTER (
        WHERE duracion_calculada_min > 0
    ) AS duraciones_positivas,

    ROUND(
        AVG(duracion_calculada_min)
            FILTER (
                WHERE duracion_calculada_min >= 0
            )::numeric,
        2
    ) AS duracion_promedio_min,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY duracion_calculada_min
        )
        FILTER (
            WHERE duracion_calculada_min >= 0
        )::numeric,
        2
    ) AS duracion_mediana_min,

    ROUND(
        PERCENTILE_CONT(0.9)
        WITHIN GROUP (
            ORDER BY duracion_calculada_min
        )
        FILTER (
            WHERE duracion_calculada_min >= 0
        )::numeric,
        2
    ) AS duracion_p90_min

FROM base;



/*
============================================================
EJERCICIO 2D - UTILIZACION DE USUARIOS RECEPTORES
============================================================

CONSULTA 4.1
Productividad y carga operativa por sede y receptor.

OBJETIVO
Identificar el volumen de atenciones, los minutos efectivos
de servicio y la distribucion de tiempos de cada receptor.

FUENTE
digiturnos.digiturnos_atenciones

CRITERIOS METODOLOGICOS
1. Cada registro representa una solicitud.
2. Se utiliza la duracion calculada a partir de las
   marcas temporales de inicio y finalizacion.
3. Se excluyen duraciones negativas y cero del tiempo
   efectivo, pero se reportan como incidencias.
4. La consulta NO calcula todavia la tasa de utilizacion,
   porque falta definir el tiempo disponible del receptor.
5. Se agrupa por sede y receptor para evitar combinar
   actividades de un mismo codigo en distintas sedes.

TRAZABILIDAD
Consulta de solo lectura. No modifica la base de datos.
============================================================
*/

WITH base AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        COALESCE(
            NULLIF(TRIM("Usuario_receptor"), ''),
            'Sin receptor'
        ) AS receptor,

        id_registro_original,

        EXTRACT(
            EPOCH FROM (dt_finalizacion - dt_llamado)
        ) / 60.0 AS duracion_min

    FROM digiturnos.digiturnos_atenciones
)

SELECT
    sede,
    receptor,

    COUNT(*) AS total_solicitudes,

    COUNT(*) FILTER (
        WHERE duracion_min > 0
    ) AS atenciones_validas,

    COUNT(*) FILTER (
        WHERE duracion_min <= 0
           OR duracion_min IS NULL
    ) AS atenciones_con_incidencia,

    ROUND(
        SUM(duracion_min)
        FILTER (WHERE duracion_min > 0)::numeric,
        2
    ) AS minutos_efectivos,

    ROUND(
        AVG(duracion_min)
        FILTER (WHERE duracion_min > 0)::numeric,
        2
    ) AS duracion_promedio_min,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY duracion_min)
        FILTER (WHERE duracion_min > 0)::numeric,
        2
    ) AS duracion_mediana_min,

    ROUND(
        PERCENTILE_CONT(0.9)
        WITHIN GROUP (ORDER BY duracion_min)
        FILTER (WHERE duracion_min > 0)::numeric,
        2
    ) AS duracion_p90_min

FROM base

GROUP BY
    sede,
    receptor

ORDER BY
    minutos_efectivos DESC NULLS LAST,
    total_solicitudes DESC;


/*
============================================================
EJERCICIO 2D - CONSULTA 4.2
VALIDACION DE VENTANAS DIARIAS POR RECEPTOR
============================================================

OBJETIVO
Construir una unidad de analisis por sede, receptor y dia
para evaluar la viabilidad de una tasa estimada de ocupacion.

METODOLOGIA
1. Se agrupan las atenciones por sede, receptor y fecha.
2. Se identifica la primera llamada del dia.
3. Se identifica la ultima finalizacion del dia.
4. Se suman los minutos efectivos de atencion.
5. Se calcula la ventana observada de actividad.
6. Se identifican posibles inconsistencias temporales.

ADVERTENCIAS
- La ventana observada no equivale a jornada contratada.
- Atenciones simultaneas pueden inflar los minutos sumados.
- No se calcula todavia la tasa definitiva.
- No se modifica ninguna tabla.

FUENTE
digiturnos.digiturnos_atenciones
============================================================
*/

WITH base AS (
    SELECT
        sede,

        NULLIF(
            TRIM("Usuario_receptor"),
            ''
        ) AS receptor,

        dt_llamado::date AS fecha,

        dt_llamado,
        dt_finalizacion,

        EXTRACT(
            EPOCH FROM (
                dt_finalizacion - dt_llamado
            )
        ) / 60.0 AS duracion_min

    FROM digiturnos.digiturnos_atenciones

    WHERE dt_llamado IS NOT NULL
      AND dt_finalizacion IS NOT NULL
),

receptor_dia AS (
    SELECT
        sede,
        receptor,
        fecha,

        COUNT(*) AS total_atenciones,

        COUNT(*) FILTER (
            WHERE duracion_min > 0
        ) AS atenciones_validas,

        MIN(dt_llamado) AS primera_llamada,

        MAX(dt_finalizacion) AS ultima_finalizacion,

        SUM(duracion_min) FILTER (
            WHERE duracion_min > 0
        ) AS minutos_efectivos

    FROM base

    GROUP BY
        sede,
        receptor,
        fecha
),

ventanas AS (
    SELECT
        *,

        EXTRACT(
            EPOCH FROM (
                ultima_finalizacion - primera_llamada
            )
        ) / 60.0 AS minutos_ventana

    FROM receptor_dia
)

SELECT
    COUNT(*) AS total_receptor_dias,

    COUNT(DISTINCT receptor)
        AS receptores_identificados,

    COUNT(*) FILTER (
        WHERE minutos_ventana > 0
    ) AS ventanas_positivas,

    COUNT(*) FILTER (
        WHERE minutos_ventana <= 0
           OR minutos_ventana IS NULL
    ) AS ventanas_invalidas,

    COUNT(*) FILTER (
        WHERE minutos_efectivos > minutos_ventana
    ) AS ventanas_con_exceso_de_tiempo,

    ROUND(
        AVG(minutos_ventana)
        FILTER (
            WHERE minutos_ventana > 0
        )::numeric,
        2
    ) AS ventana_promedio_min,

    ROUND(
        AVG(minutos_efectivos)
        FILTER (
            WHERE minutos_efectivos > 0
        )::numeric,
        2
    ) AS atencion_promedio_diaria_min,

    ROUND(
        MAX(minutos_ventana)::numeric,
        2
    ) AS ventana_maxima_min

FROM ventanas;


/*
============================================================
EJERCICIO 2D - CONSULTA 4.3
OCUPACION OPERATIVA ESTIMADA POR RECEPTOR
============================================================

OBJETIVO
Estimar la proporcion de tiempo observado que cada
receptor dedica a la atencion efectiva de solicitudes.

UNIDAD DE ANALISIS
Sede + receptor + fecha.

DEFINICIONES
- Minutos efectivos: suma de duraciones positivas.
- Ventana observada: intervalo entre primera llamada
  y ultima finalizacion del receptor en el dia.
- Ocupacion estimada: minutos efectivos / ventana.

CRITERIOS DE CALIDAD
1. Se excluyen duraciones no positivas del numerador.
2. Se excluyen jornadas con ventana no positiva.
3. Se excluyen del indicador las jornadas donde los
   minutos efectivos superan la ventana observada.
4. Las jornadas excluidas se contabilizan por separado.
5. Se pondera por minutos, no por promedio simple
   de porcentajes diarios.

LIMITACION
No equivale a la utilizacion contractual real porque
no se dispone de horarios laborales programados.

TRAZABILIDAD
Consulta de solo lectura. No modifica registros.
============================================================
*/

WITH base AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        COALESCE(
            NULLIF(TRIM("Usuario_receptor"), ''),
            'Sin receptor'
        ) AS receptor,

        dt_llamado::date AS fecha,
        dt_llamado,
        dt_finalizacion,

        EXTRACT(
            EPOCH FROM (dt_finalizacion - dt_llamado)
        ) / 60.0 AS duracion_min

    FROM digiturnos.digiturnos_atenciones

    WHERE dt_llamado IS NOT NULL
      AND dt_finalizacion IS NOT NULL
),

receptor_dia AS (
    SELECT
        sede,
        receptor,
        fecha,

        COUNT(*) AS solicitudes,

        COUNT(*) FILTER (
            WHERE duracion_min > 0
        ) AS atenciones_validas,

        MIN(dt_llamado) AS primera_llamada,
        MAX(dt_finalizacion) AS ultima_finalizacion,

        COALESCE(
            SUM(duracion_min) FILTER (
                WHERE duracion_min > 0
            ),
            0
        ) AS minutos_efectivos

    FROM base

    GROUP BY
        sede,
        receptor,
        fecha
),

ventanas AS (
    SELECT
        *,

        EXTRACT(
            EPOCH FROM (
                ultima_finalizacion - primera_llamada
            )
        ) / 60.0 AS minutos_ventana

    FROM receptor_dia
),

clasificacion AS (
    SELECT
        *,

        CASE
            WHEN minutos_ventana <= 0
              OR minutos_ventana IS NULL
                THEN 'Ventana invalida'

            WHEN minutos_efectivos > minutos_ventana
                THEN 'Exceso de tiempo'

            ELSE 'Valida'
        END AS estado_ventana

    FROM ventanas
)

SELECT
    sede,
    receptor,

    COUNT(*) AS dias_observados,

    COUNT(*) FILTER (
        WHERE estado_ventana = 'Valida'
    ) AS dias_validos,

    COUNT(*) FILTER (
        WHERE estado_ventana <> 'Valida'
    ) AS dias_excluidos,

    SUM(solicitudes) AS solicitudes_totales,

    SUM(atenciones_validas) AS atenciones_validas,

    ROUND(
        SUM(minutos_efectivos)
        FILTER (
            WHERE estado_ventana = 'Valida'
        )::numeric,
        2
    ) AS minutos_atencion_validos,

    ROUND(
        SUM(minutos_ventana)
        FILTER (
            WHERE estado_ventana = 'Valida'
        )::numeric,
        2
    ) AS minutos_ventana_validos,

    ROUND(
        (
            100.0 *
            SUM(minutos_efectivos) FILTER (
                WHERE estado_ventana = 'Valida'
            )
            /
            NULLIF(
                SUM(minutos_ventana) FILTER (
                    WHERE estado_ventana = 'Valida'
                ),
                0
            )
        )::numeric,
        2
    ) AS ocupacion_estimada_pct

FROM clasificacion

GROUP BY
    sede,
    receptor

ORDER BY
    ocupacion_estimada_pct DESC NULLS LAST,
    minutos_atencion_validos DESC NULLS LAST;


/*
=========================================================
CONTROL DE ESTRUCTURA - TABLA DIGITURNOS_ATENCIONES
=========================================================

OBJETIVO:
Identificar los nombres y tipos de datos disponibles
para corregir la consulta 4.4 sin modificar la tabla.

Esta consulta es de solo lectura.
=========================================================
*/

SELECT
    ordinal_position AS posicion,
    column_name AS nombre_columna,
    data_type AS tipo_dato

FROM information_schema.columns

WHERE table_schema = 'digiturnos'
  AND table_name = 'digiturnos_atenciones'

ORDER BY ordinal_position;



/*
====================================================================
EJERCICIO 2D - CONSULTA 4.4
DISTRIBUCION DE LA OCUPACION OPERATIVA ESTIMADA POR RECEPTOR
====================================================================

OBJETIVO
Identificar como se distribuye la ocupacion operativa entre
las combinaciones sede-receptor, diferenciando los resultados
segun la cantidad de jornadas observadas.

FUENTE
digiturnos.digiturnos_atenciones

UNIDAD DE ANALISIS
Combinacion sede + receptor.

CRITERIO DE REPRESENTATIVIDAD
- Principal: 30 o mas jornadas validas observadas.
- Complementario: menos de 30 jornadas validas.

Los registros del analisis complementario permanecen
en el resultado y no se eliminan de la base de datos.

DEFINICION DEL INDICADOR
Ocupacion operativa estimada (%) =
    SUM(minutos efectivos de atencion)
    / SUM(minutos de ventana observada) * 100

La ventana diaria se calcula entre la primera llamada
y la ultima finalizacion de una misma jornada.

ADVERTENCIAS METODOLOGICAS
1. No representa la utilizacion contractual real.
2. No incorpora turnos programados ni descansos.
3. Los rangos son descriptivos, no metas institucionales.
4. Las jornadas invalidas se excluyen del indicador,
   pero se conservan en la tabla original.
5. Las atenciones superpuestas pueden sobreestimar
   los minutos efectivos y requieren control adicional.

====================================================================
*/

WITH base AS (

    /*
    PASO 1. PREPARACION DE LOS REGISTROS

    Se utilizan las columnas reales verificadas
    mediante information_schema.columns.

    La fecha de jornada se deriva de dt_llamado.

    Se conservan los identificadores originales
    sin modificar la informacion de origen.
    */

    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        NULLIF(TRIM(receptor), '') AS receptor,

        dt_llamado::date AS fecha_jornada,

        dt_llamado,

        dt_finalizacion,

        duracion_atencion_min

    FROM digiturnos.digiturnos_atenciones

),

jornadas AS (

    /*
    PASO 2. CONSOLIDACION DIARIA

    Se agrupan las atenciones por:
    - sede
    - receptor
    - fecha de jornada

    Se calcula:
    - cantidad de solicitudes;
    - minutos efectivos de atencion;
    - ventana temporal observada;
    - cantidad de duraciones invalidas.

    Las duraciones negativas o nulas no aportan
    minutos efectivos.

    IMPORTANTE:
    Una jornada con duraciones invalidas no se
    considera valida para el calculo posterior.
    */

    SELECT
        sede,
        receptor,
        fecha_jornada,

        COUNT(*) AS solicitudes_dia,

        COUNT(*) FILTER (
            WHERE duracion_atencion_min IS NULL
               OR duracion_atencion_min < 0
        ) AS duraciones_invalidas,

        SUM(
            CASE
                WHEN duracion_atencion_min >= 0
                THEN duracion_atencion_min
                ELSE 0
            END
        ) AS minutos_efectivos,

        EXTRACT(
            EPOCH FROM (
                MAX(dt_finalizacion)
                - MIN(dt_llamado)
            )
        ) / 60.0 AS minutos_ventana

    FROM base

    WHERE receptor IS NOT NULL
      AND fecha_jornada IS NOT NULL

    GROUP BY
        sede,
        receptor,
        fecha_jornada

),

jornadas_validas AS (

    /*
    PASO 3. VALIDACION DE JORNADAS

    Se consideran validas las jornadas que:
    1. No tienen duraciones invalidas.
    2. Tienen una ventana temporal positiva.
    3. Tienen minutos efectivos no negativos.
    4. No superan la ventana observada.

    Este ultimo control ayuda a detectar posibles
    inconsistencias por atenciones superpuestas.

    NOTA:
    Se trata de una regla conservadora.
    Si existen atenciones simultaneas legitimas,
    sera necesario revisar este supuesto.
    */

    SELECT
        *

    FROM jornadas

    WHERE duraciones_invalidas = 0
      AND minutos_ventana > 0
      AND minutos_efectivos >= 0
      AND minutos_efectivos <= minutos_ventana

),

receptores AS (

    /*
    PASO 4. CONSOLIDACION POR SEDE Y RECEPTOR

    La ocupacion se calcula como razon de sumas,
    no como promedio de porcentajes diarios.

    Esto permite ponderar correctamente jornadas
    con diferentes duraciones observadas.
    */

    SELECT
        sede,
        receptor,

        COUNT(*) AS jornadas_observadas,

        SUM(solicitudes_dia) AS solicitudes,

        SUM(minutos_efectivos)
            AS minutos_atencion,

        SUM(minutos_ventana)
            AS minutos_ventana,

        ROUND(
            (
                100.0 * SUM(minutos_efectivos)
                / NULLIF(SUM(minutos_ventana), 0)
            )::numeric,
            2
        ) AS ocupacion_estimada_pct

    FROM jornadas_validas

    GROUP BY
        sede,
        receptor

),

clasificacion AS (

    /*
    PASO 5. CLASIFICACION DE LOS RECEPTORES

    A. Representatividad:
       Principal o complementario.

    B. Rango de ocupacion:
       Intervalos descriptivos de 20 puntos.

    No se excluyen receptores por tener menos
    de 30 jornadas.
    */

    SELECT
        *,

        CASE
            WHEN jornadas_observadas >= 30
                THEN 'Principal: 30 o mas jornadas'
            ELSE
                'Complementario: menos de 30 jornadas'
        END AS nivel_analisis,

        CASE
            WHEN ocupacion_estimada_pct < 20
                THEN '01. Menos de 20%'

            WHEN ocupacion_estimada_pct < 40
                THEN '02. 20% a menos de 40%'

            WHEN ocupacion_estimada_pct < 60
                THEN '03. 40% a menos de 60%'

            WHEN ocupacion_estimada_pct < 80
                THEN '04. 60% a menos de 80%'

            ELSE '05. 80% a 100%'

        END AS rango_ocupacion

    FROM receptores

),

resumen AS (

    /*
    PASO 6. RESUMEN POR NIVEL Y RANGO

    Se calculan:
    - combinaciones sede-receptor;
    - receptores distintos dentro del grupo;
    - jornadas observadas;
    - solicitudes;
    - minutos efectivos y de ventana;
    - ocupacion ponderada.

    IMPORTANTE:
    Un mismo receptor puede aparecer en varias
    sedes o rangos. Por tanto, los receptores
    distintos no son necesariamente aditivos.
    */

    SELECT
        nivel_analisis,
        rango_ocupacion,

        COUNT(*) AS combinaciones_sede_receptor,

        COUNT(DISTINCT receptor)
            AS receptores_distintos,

        SUM(jornadas_observadas)
            AS jornadas_observadas,

        SUM(solicitudes)
            AS solicitudes,

        SUM(minutos_atencion)
            AS minutos_atencion,

        SUM(minutos_ventana)
            AS minutos_ventana

    FROM clasificacion

    GROUP BY
        nivel_analisis,
        rango_ocupacion

)

/*
PASO 7. RESULTADO FINAL

Los porcentajes se calculan dentro de cada
nivel de analisis.

Esto permite comparar la distribucion interna
del grupo principal y del complementario.

La ocupacion ponderada se obtiene mediante
la razon de los minutos agregados.
*/

SELECT
    nivel_analisis,

    rango_ocupacion,

    combinaciones_sede_receptor,

    receptores_distintos,

    jornadas_observadas,

    solicitudes,

    ROUND(
        (
            100.0 * combinaciones_sede_receptor
            / NULLIF(
                SUM(combinaciones_sede_receptor)
                    OVER (PARTITION BY nivel_analisis),
                0
            )
        )::numeric,
        2
    ) AS pct_combinaciones,

    ROUND(
        (
            100.0 * solicitudes
            / NULLIF(
                SUM(solicitudes)
                    OVER (PARTITION BY nivel_analisis),
                0
            )
        )::numeric,
        2
    ) AS pct_solicitudes,

    ROUND(
        (
            100.0 * minutos_atencion
            / NULLIF(minutos_ventana, 0)
        )::numeric,
        2
    ) AS ocupacion_ponderada_pct

FROM resumen

ORDER BY
    CASE
        WHEN nivel_analisis =
            'Principal: 30 o mas jornadas'
        THEN 1
        ELSE 2
    END,
    rango_ocupacion;


/*
====================================================================
EJERCICIO 2D - CONSULTA 4.4.1
CONTROL FINAL DE RECONCILIACION DE COMBINACIONES SEDE-RECEPTOR
====================================================================

OBJETIVO
Reconciliar el universo de combinaciones sede-receptor con las
combinaciones incluidas en el analisis de ocupacion operativa.

FUENTE
digiturnos.digiturnos_atenciones

TRAZABILIDAD
- Consulta 4.3: ocupacion estimada por sede-receptor.
- Consulta 4.4: distribucion por rango de ocupacion.
- Consulta 4.4.1: control independiente de reconciliacion.

UNIDAD DE ANALISIS
Combinacion sede + receptor.

CRITERIOS DE JORNADA VALIDA
Se replican los criterios de la consulta 4.4:

1. Ninguna duracion de atencion nula o negativa.
2. Ventana temporal observada mayor que cero.
3. Minutos efectivos de atencion no negativos.
4. Minutos efectivos menores o iguales a la ventana.

CLASIFICACION
- Principal: 30 o mas jornadas validas.
- Complementario: entre 1 y 29 jornadas validas.
- Sin jornadas validas: ocupacion no calculable.

IMPORTANTE
Esta consulta:
- No modifica ni elimina registros.
- No crea ni actualiza tablas.
- Conserva todas las combinaciones del universo.
- No asigna ocupacion igual a cero a registros sin
  jornadas validas.
- Permite verificar la conciliacion de cantidades.

RESULTADOS PREVIOS DE REFERENCIA
Universo: 256 combinaciones.
Consulta 4.4: 255 combinaciones con jornadas validas.
Diferencia identificada: Soacha - Sin Usuario.

Estos resultados deben confirmarse al ejecutar el control.
====================================================================
*/

WITH base AS (

    /*
    PASO 1. NORMALIZACION DE IDENTIFICADORES

    Se utilizan las columnas normalizadas del modelo
    de atenciones, igual que en la consulta 4.4.
    */

    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        NULLIF(
            TRIM(receptor),
            ''
        ) AS receptor,

        dt_llamado::date AS fecha_jornada,

        dt_llamado,
        dt_finalizacion,
        duracion_atencion_min

    FROM digiturnos.digiturnos_atenciones
),

universo AS (

    /*
    PASO 2. UNIVERSO COMPLETO

    Se conservan todas las combinaciones originales.
    Los identificadores nulos se mantienen mediante
    una clave de presentacion para no perder registros.
    */

    SELECT DISTINCT
        sede,
        COALESCE(receptor, 'Sin receptor') AS receptor

    FROM base
),

jornadas AS (

    /*
    PASO 3. CONSOLIDACION DIARIA

    Replica la logica de agrupacion de la consulta 4.4.
    */

    SELECT
        sede,
        receptor,
        fecha_jornada,

        COUNT(*) AS solicitudes_dia,

        COUNT(*) FILTER (
            WHERE duracion_atencion_min IS NULL
               OR duracion_atencion_min < 0
        ) AS duraciones_invalidas,

        SUM(
            CASE
                WHEN duracion_atencion_min >= 0
                    THEN duracion_atencion_min
                ELSE 0
            END
        ) AS minutos_efectivos,

        EXTRACT(
            EPOCH FROM (
                MAX(dt_finalizacion)
                - MIN(dt_llamado)
            )
        ) / 60.0 AS minutos_ventana

    FROM base

    WHERE receptor IS NOT NULL
      AND fecha_jornada IS NOT NULL

    GROUP BY
        sede,
        receptor,
        fecha_jornada
),

jornadas_validas AS (

    /*
    PASO 4. VALIDACION DE JORNADAS

    Filtros identicos a los de la consulta 4.4.
    */

    SELECT *
    FROM jornadas

    WHERE duraciones_invalidas = 0
      AND minutos_ventana > 0
      AND minutos_efectivos >= 0
      AND minutos_efectivos <= minutos_ventana
),

receptores AS (

    /*
    PASO 5. CONSOLIDACION DE JORNADAS VALIDAS

    Se calcula la ocupacion como razon de sumas.
    */

    SELECT
        sede,
        receptor,

        COUNT(*) AS jornadas_validas,

        SUM(solicitudes_dia) AS solicitudes_validas,

        SUM(minutos_efectivos) AS minutos_atencion,

        SUM(minutos_ventana) AS minutos_ventana,

        ROUND(
            (
                100.0 * SUM(minutos_efectivos)
                / NULLIF(SUM(minutos_ventana), 0)
            )::numeric,
            2
        ) AS ocupacion_estimada_pct

    FROM jornadas_validas

    GROUP BY
        sede,
        receptor
),

reconciliacion AS (

    /*
    PASO 6. REINCORPORACION DEL UNIVERSO COMPLETO

    LEFT JOIN permite conservar las combinaciones
    que no tienen jornadas validas.

    La ocupacion permanece NULL cuando no puede
    calcularse.
    */

    SELECT
        u.sede,
        u.receptor,

        COALESCE(
            r.jornadas_validas,
            0
        ) AS jornadas_validas,

        COALESCE(
            r.solicitudes_validas,
            0
        ) AS solicitudes_validas,

        r.minutos_atencion,
        r.minutos_ventana,
        r.ocupacion_estimada_pct,

        CASE
            WHEN COALESCE(r.jornadas_validas, 0) = 0
                THEN '03. Sin jornadas validas'

            WHEN r.jornadas_validas >= 30
                THEN '01. Principal: 30 o mas jornadas'

            ELSE
                '02. Complementario: menos de 30 jornadas'
        END AS nivel_analisis

    FROM universo u

    LEFT JOIN receptores r
        ON u.sede = r.sede
       AND u.receptor = r.receptor
),

resumen AS (

    /*
    PASO 7. RESUMEN DE COMBINACIONES

    Se contabilizan las combinaciones por nivel.
    */

    SELECT
        nivel_analisis,

        COUNT(*) AS combinaciones_sede_receptor,

        COUNT(*) FILTER (
            WHERE ocupacion_estimada_pct IS NOT NULL
        ) AS combinaciones_con_ocupacion,

        COUNT(*) FILTER (
            WHERE ocupacion_estimada_pct IS NULL
        ) AS combinaciones_sin_ocupacion,

        SUM(jornadas_validas) AS jornadas_validas,

        SUM(solicitudes_validas) AS solicitudes_validas

    FROM reconciliacion

    GROUP BY nivel_analisis
)

/*
PASO 8. RESULTADO FINAL

Se incluye una fila TOTAL para facilitar
la reconciliacion con las consultas anteriores.
*/

SELECT
    nivel_analisis,

    combinaciones_sede_receptor,

    combinaciones_con_ocupacion,

    combinaciones_sin_ocupacion,

    jornadas_validas,

    solicitudes_validas

FROM resumen

UNION ALL

SELECT
    'TOTAL GENERAL' AS nivel_analisis,

    SUM(combinaciones_sede_receptor),

    SUM(combinaciones_con_ocupacion),

    SUM(combinaciones_sin_ocupacion),

    SUM(jornadas_validas),

    SUM(solicitudes_validas)

FROM resumen

ORDER BY nivel_analisis;



/*
============================================================
CONTROL DE RECONCILIACION - CONSULTAS 4.3 Y 4.4
PASO 1. Combinaciones sede-receptor de la tabla base
============================================================

OBJETIVO
Verificar cuantas combinaciones sede-receptor existen
antes de aplicar filtros sobre jornadas observadas.

FUENTE
digiturnos.digiturnos_atenciones

CRITERIO
Se normalizan espacios y valores vacios.
No se excluyen registros por duracion ni por jornada.

IMPORTANTE
Este resultado debe compararse con el universo utilizado
en la consulta 4.3. No necesariamente sera identico si
esa consulta aplica otros filtros.
============================================================
*/

WITH base AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        COALESCE(
            NULLIF(TRIM("Usuario_receptor"), ''),
            'Sin receptor'
        ) AS receptor

    FROM digiturnos.digiturnos_atenciones
)

SELECT
    COUNT(*) AS combinaciones_sede_receptor,

    COUNT(*) FILTER (
        WHERE receptor = 'Sin receptor'
    ) AS combinaciones_sin_receptor,

    COUNT(*) FILTER (
        WHERE sede = 'Sin sede'
    ) AS combinaciones_sin_sede

FROM (
    SELECT DISTINCT sede, receptor
    FROM base
) AS combinaciones;


/*
============================================================
CONTROL DE RECONCILIACION - PASO 2
Identificacion de combinaciones sin jornadas validas
============================================================

OBJETIVO
Identificar combinaciones sede-receptor que existen
en la tabla de atenciones pero no tienen jornadas
con una ventana temporal positiva.

DEFINICIONES
- Jornada observada: combinacion sede-receptor-fecha.
- Ventana diaria: tiempo entre el primer llamado y
  la ultima finalizacion del dia.
- Jornada valida: ventana mayor que cero minutos.

ADVERTENCIA
Esta es una reconstruccion diagnostica.
Para la reconciliacion definitiva debe utilizarse
exactamente la misma definicion de ventana que en 4.4.
============================================================
*/

WITH base AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        COALESCE(
            NULLIF(TRIM("Usuario_receptor"), ''),
            'Sin receptor'
        ) AS receptor,

        dt_llamado,
        dt_finalizacion

    FROM digiturnos.digiturnos_atenciones
),

universo AS (
    SELECT DISTINCT sede, receptor
    FROM base
),

jornadas AS (
    SELECT
        sede,
        receptor,
        dt_llamado::date AS fecha_jornada,

        EXTRACT(
            EPOCH FROM (
                MAX(dt_finalizacion) - MIN(dt_llamado)
            )
        ) / 60.0 AS ventana_min

    FROM base

    WHERE dt_llamado IS NOT NULL
      AND dt_finalizacion IS NOT NULL
      AND dt_finalizacion >= dt_llamado

    GROUP BY
        sede,
        receptor,
        dt_llamado::date
),

resumen AS (
    SELECT
        sede,
        receptor,

        COUNT(*) AS jornadas_observadas,

        COUNT(*) FILTER (
            WHERE ventana_min > 0
        ) AS jornadas_validas

    FROM jornadas

    GROUP BY sede, receptor
)

SELECT
    u.sede,
    u.receptor,

    COALESCE(
        r.jornadas_observadas, 0
    ) AS jornadas_observadas,

    COALESCE(
        r.jornadas_validas, 0
    ) AS jornadas_validas,

    CASE
        WHEN COALESCE(r.jornadas_validas, 0) = 0
            THEN 'Sin jornadas validas'

        WHEN r.jornadas_validas < 30
            THEN 'Complementario: menos de 30 jornadas'

        ELSE 'Principal: 30 o mas jornadas'
    END AS nivel_analisis

FROM universo u

LEFT JOIN resumen r
    ON u.sede = r.sede
   AND u.receptor = r.receptor

WHERE COALESCE(r.jornadas_validas, 0) = 0

ORDER BY
    u.sede,
    u.receptor;



/*
============================================================
RECONCILIACION DE COMBINACIONES - CONSULTAS 4.3 Y 4.4
============================================================

OBJETIVO
Explicar la diferencia entre el universo de combinaciones
sede-receptor y las combinaciones con jornadas validas
utilizadas para estimar la ocupacion operativa.

RESULTADOS DE LOS CONTROLES

1. Universo de combinaciones sede-receptor: 256.

2. Combinaciones sin sede: 0.

3. Combinaciones sin receptor por ausencia de valor: 0.

4. Combinaciones con al menos una jornada valida: 255.

5. Combinaciones sin jornadas validas: 1.

REGISTRO IDENTIFICADO
Sede: Soacha
Receptor: Sin Usuario
Jornadas observadas: 1
Jornadas validas: 0

INTERPRETACION
La combinacion existe en los datos originales,
pero no dispone de una jornada valida para calcular
una tasa de ocupacion operativa.

DECISION METODOLOGICA

- Conservar las 256 combinaciones en la trazabilidad.
- Utilizar las 255 combinaciones con jornadas validas
  para la estimacion de ocupacion.
- Mantener el umbral de 30 jornadas validas para
  distinguir el analisis principal del complementario.
- No asignar ocupacion igual a cero cuando la ventana
  operativa no es calculable.
- Mantener el registro identificado como incidencia
  de calidad de datos.

ESTADO
Reconciliacion de cantidades: completada.
Equivalencia exacta de filtros: pendiente de contrastar
con las definiciones originales de las consultas.
============================================================
*/


/*
=========================================================
EJERCICIO 2D - CONSULTA 4.4.2
TRAZABILIDAD DE SOLICITUDES FUERA DE JORNADAS VALIDAS
=========================================================

OBJETIVO
Conciliar las solicitudes originales con las incluidas
en jornadas validas para el calculo de ocupacion.

Se replican los criterios de la consulta 4.4.
No se eliminan ni modifican registros.
=========================================================
*/

WITH base AS (
    SELECT
        id_registro_original,

        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        NULLIF(TRIM(receptor), '') AS receptor,

        dt_llamado::date AS fecha_jornada,
        dt_llamado,
        dt_finalizacion,
        duracion_atencion_min

    FROM digiturnos.digiturnos_atenciones
),

jornadas AS (
    SELECT
        sede,
        receptor,
        fecha_jornada,

        COUNT(*) AS solicitudes_dia,

        COUNT(*) FILTER (
            WHERE duracion_atencion_min IS NULL
               OR duracion_atencion_min < 0
        ) AS duraciones_invalidas,

        SUM(
            CASE
                WHEN duracion_atencion_min >= 0
                THEN duracion_atencion_min
                ELSE 0
            END
        ) AS minutos_efectivos,

        EXTRACT(
            EPOCH FROM (
                MAX(dt_finalizacion) - MIN(dt_llamado)
            )
        ) / 60.0 AS minutos_ventana

    FROM base

    WHERE receptor IS NOT NULL
      AND fecha_jornada IS NOT NULL

    GROUP BY
        sede,
        receptor,
        fecha_jornada
),

clasificacion_jornadas AS (
    SELECT
        *,

        CASE
            WHEN duraciones_invalidas > 0
                THEN '03. Duraciones invalidas'

            WHEN minutos_ventana IS NULL
              OR minutos_ventana <= 0
                THEN '04. Ventana no positiva'

            WHEN minutos_efectivos < 0
                THEN '05. Minutos efectivos negativos'

            WHEN minutos_efectivos > minutos_ventana
                THEN '06. Exceso de tiempo'

            ELSE '01. Jornada valida'
        END AS estado_jornada

    FROM jornadas
),

trazabilidad AS (
    SELECT
        b.id_registro_original,
        b.sede,
        b.receptor,
        b.fecha_jornada,

        CASE
            WHEN b.receptor IS NULL
                THEN '02. Sin receptor'

            WHEN b.fecha_jornada IS NULL
                THEN '07. Sin fecha de llamada'

            WHEN j.estado_jornada IS NULL
                THEN '08. Sin jornada asociada'

            ELSE j.estado_jornada
        END AS motivo_clasificacion

    FROM base b

    LEFT JOIN clasificacion_jornadas j
        ON b.sede = j.sede
       AND b.receptor = j.receptor
       AND b.fecha_jornada = j.fecha_jornada
),

resumen AS (
    SELECT
        motivo_clasificacion,

        COUNT(*) AS solicitudes

    FROM trazabilidad

    GROUP BY motivo_clasificacion
)

SELECT
    motivo_clasificacion,
    solicitudes,

    ROUND(
        100.0 * solicitudes
        / NULLIF(SUM(solicitudes) OVER (), 0),
        4
    ) AS pct_universo,

    SUM(solicitudes) OVER ()
        AS total_universo,

    SUM(solicitudes) FILTER (
        WHERE motivo_clasificacion <> '01. Jornada valida'
    ) OVER () AS total_no_incluidas

FROM resumen

ORDER BY motivo_clasificacion;


/*
=====================================================================
EJERCICIO 2D - CONSULTA 4.4.3
VALIDACION FINAL DE CONSISTENCIA DEL MODELO DE OCUPACION
=====================================================================

OBJETIVO
Verificar la conciliacion entre:
1. Universo original de solicitudes.
2. Solicitudes asociadas a jornadas validas.
3. Solicitudes excluidas.
4. Jornadas validas.
5. Combinaciones sede-receptor.
6. Combinaciones con y sin ocupacion calculable.

FUENTE
digiturnos.digiturnos_atenciones

TRAZABILIDAD
Se reconstruyen las jornadas con las condiciones de
validez utilizadas en la consulta 4.4.2.

No se modifican datos ni consultas anteriores.

IMPORTANTE
La ocupacion calculada es una estimacion basada en
la ventana observada, no en el horario contractual.
=====================================================================
*/

WITH base AS (

    /*
    PASO 1. Normalizacion de identificadores.

    Se conserva cada solicitud del universo original.
    */

    SELECT
        id_registro_original,

        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        NULLIF(TRIM(receptor), '') AS receptor,

        dt_llamado::date AS fecha_jornada,

        dt_llamado,
        dt_finalizacion,
        duracion_atencion_min

    FROM digiturnos.digiturnos_atenciones

),

universo_combinaciones AS (

    /*
    PASO 2. Identificar todas las combinaciones
    sede-receptor, incluso si no tienen jornadas validas.
    */

    SELECT DISTINCT
        sede,
        COALESCE(receptor, 'Sin receptor') AS receptor

    FROM base

),

jornadas AS (

    /*
    PASO 3. Reconstruir las jornadas observadas.

    Unidad de analisis:
    sede + receptor + fecha de llamada.
    */

    SELECT
        sede,
        receptor,
        fecha_jornada,

        COUNT(*) AS solicitudes_dia,

        COUNT(*) FILTER (
            WHERE duracion_atencion_min IS NULL
               OR duracion_atencion_min < 0
        ) AS duraciones_invalidas,

        SUM(
            CASE
                WHEN duracion_atencion_min >= 0
                THEN duracion_atencion_min
                ELSE 0
            END
        ) AS minutos_efectivos,

        EXTRACT(
            EPOCH FROM (
                MAX(dt_finalizacion) - MIN(dt_llamado)
            )
        ) / 60.0 AS minutos_ventana

    FROM base

    WHERE receptor IS NOT NULL
      AND fecha_jornada IS NOT NULL

    GROUP BY
        sede,
        receptor,
        fecha_jornada

),

jornadas_clasificadas AS (

    /*
    PASO 4. Aplicar los criterios de validez.

    Una jornada es valida cuando:
    - No tiene duraciones invalidas.
    - Su ventana es positiva.
    - Los minutos efectivos son no negativos.
    - Los minutos efectivos no superan la ventana.
    */

    SELECT
        *,

        CASE
            WHEN duraciones_invalidas > 0
                THEN FALSE

            WHEN minutos_ventana IS NULL
              OR minutos_ventana <= 0
                THEN FALSE

            WHEN minutos_efectivos < 0
                THEN FALSE

            WHEN minutos_efectivos > minutos_ventana
                THEN FALSE

            ELSE TRUE
        END AS jornada_valida

    FROM jornadas

),

solicitudes_clasificadas AS (

    /*
    PASO 5. Vincular cada solicitud con su jornada.

    El LEFT JOIN conserva todas las solicitudes.
    */

    SELECT
        b.id_registro_original,

        COALESCE(
            j.jornada_valida,
            FALSE
        ) AS solicitud_en_jornada_valida

    FROM base b

    LEFT JOIN jornadas_clasificadas j
        ON b.sede = j.sede
       AND b.receptor = j.receptor
       AND b.fecha_jornada = j.fecha_jornada

),

resumen_solicitudes AS (

    /*
    PASO 6. Conciliacion de solicitudes.
    */

    SELECT
        COUNT(*) AS total_solicitudes,

        COUNT(*) FILTER (
            WHERE solicitud_en_jornada_valida
        ) AS solicitudes_validas,

        COUNT(*) FILTER (
            WHERE NOT solicitud_en_jornada_valida
        ) AS solicitudes_excluidas

    FROM solicitudes_clasificadas

),

resumen_jornadas AS (

    /*
    PASO 7. Conciliacion de jornadas.
    */

    SELECT
        COUNT(*) AS jornadas_observadas,

        COUNT(*) FILTER (
            WHERE jornada_valida
        ) AS jornadas_validas,

        COUNT(*) FILTER (
            WHERE NOT jornada_valida
        ) AS jornadas_invalidas,

        COALESCE(
            SUM(solicitudes_dia) FILTER (
                WHERE jornada_valida
            ),
            0
        ) AS solicitudes_desde_jornadas

    FROM jornadas_clasificadas

),

resumen_receptores AS (

    /*
    PASO 8. Determinar si cada combinacion
    sede-receptor tiene ocupacion calculable.

    No se eliminan combinaciones sin jornadas validas.
    */

    SELECT
        u.sede,
        u.receptor,

        COUNT(j.fecha_jornada) FILTER (
            WHERE j.jornada_valida
        ) AS jornadas_validas,

        CASE
            WHEN COUNT(j.fecha_jornada) FILTER (
                WHERE j.jornada_valida
            ) > 0
            THEN TRUE
            ELSE FALSE
        END AS ocupacion_calculable

    FROM universo_combinaciones u

    LEFT JOIN jornadas_clasificadas j
        ON u.sede = j.sede
       AND u.receptor = j.receptor

    GROUP BY
        u.sede,
        u.receptor

),

resumen_combinaciones AS (

    /*
    PASO 9. Conciliacion de combinaciones.
    */

    SELECT
        COUNT(*) AS combinaciones_totales,

        COUNT(*) FILTER (
            WHERE ocupacion_calculable
        ) AS combinaciones_calculables,

        COUNT(*) FILTER (
            WHERE NOT ocupacion_calculable
        ) AS combinaciones_no_calculables,

        SUM(jornadas_validas)
            AS jornadas_desde_receptores

    FROM resumen_receptores

),

indicadores AS (

    /*
    PASO 10. Consolidar controles independientes.

    Cada indicador se contrasta con el valor observado
    previamente en las consultas 4.4.1 y 4.4.2.
    */

    SELECT
        '01. Solicitudes originales' AS indicador,
        s.total_solicitudes::bigint AS valor_obtenido,
        883080::bigint AS valor_referencia

    FROM resumen_solicitudes s

    UNION ALL

    SELECT
        '02. Solicitudes en jornadas validas',
        s.solicitudes_validas::bigint,
        882863::bigint

    FROM resumen_solicitudes s

    UNION ALL

    SELECT
        '03. Solicitudes excluidas',
        s.solicitudes_excluidas::bigint,
        217::bigint

    FROM resumen_solicitudes s

    UNION ALL

    SELECT
        '04. Jornadas validas',
        j.jornadas_validas::bigint,
        17021::bigint

    FROM resumen_jornadas j

    UNION ALL

    SELECT
        '05. Combinaciones sede-receptor',
        r.combinaciones_totales::bigint,
        256::bigint

    FROM resumen_combinaciones r

    UNION ALL

    SELECT
        '06. Combinaciones calculables',
        r.combinaciones_calculables::bigint,
        255::bigint

    FROM resumen_combinaciones r

    UNION ALL

    SELECT
        '07. Combinaciones no calculables',
        r.combinaciones_no_calculables::bigint,
        1::bigint

    FROM resumen_combinaciones r

    UNION ALL

    /*
    Control interno A:
    solicitudes validas por dos caminos independientes.
    */

    SELECT
        '08. Conciliacion de solicitudes validas',
        s.solicitudes_validas::bigint,
        j.solicitudes_desde_jornadas::bigint

    FROM resumen_solicitudes s
    CROSS JOIN resumen_jornadas j

    UNION ALL

    /*
    Control interno B:
    jornadas validas por dos caminos independientes.
    */

    SELECT
        '09. Conciliacion de jornadas validas',
        j.jornadas_validas::bigint,
        r.jornadas_desde_receptores::bigint

    FROM resumen_jornadas j
    CROSS JOIN resumen_combinaciones r

    UNION ALL

    /*
    Control interno C:
    el universo original debe coincidir con
    la suma de solicitudes incluidas y excluidas.
    */

    SELECT
        '10. Conciliacion del universo',
        s.total_solicitudes::bigint,
        (
            s.solicitudes_validas
            + s.solicitudes_excluidas
        )::bigint

    FROM resumen_solicitudes s

)

SELECT
    indicador,

    valor_obtenido,
    valor_referencia,

    valor_obtenido - valor_referencia
        AS diferencia,

    CASE
        WHEN valor_obtenido = valor_referencia
            THEN 'OK - Conciliado'
        ELSE 'REVISAR - Diferencia'
    END AS resultado_control

FROM indicadores

ORDER BY indicador;



/*
============================================================
EJERCICIO 2 - CONSULTA 4.5.1
SINTESIS OPERATIVA POR SEDE
============================================================

OBJETIVO
Consolidar los indicadores de demanda, espera y atencion
para identificar diferencias operativas entre sedes.

FUENTE PRINCIPAL
digiturnos.digiturnos_atenciones

FUENTE DE DEMANDA
digiturnos.digiturnos_franjas

METODOLOGIA
1. Se conserva el universo original de solicitudes.
2. Se calculan los indicadores sobre tiempos validos.
3. Se identifican esperas mayores a 15 y 30 minutos.
4. Se utiliza el percentil 90 para analizar las esperas
   prolongadas que el promedio puede ocultar.
5. Se incorpora el volumen promedio por franja observada.

ADVERTENCIAS
- Los umbrales de 15 y 30 minutos son criterios
  exploratorios, no metas oficiales de servicio.
- La demanda se calcula desde una tabla agregada.
- No se duplican solicitudes al integrar las fuentes.
- No se interpreta la demanda como ocupacion.
============================================================
*/

WITH
/* ---------------------------------------------------------
PASO 1. Normalizar los registros de atencion.
--------------------------------------------------------- */

/* ---------------------------------------------------------
PASO 1. Normalizar los registros de atencion.

TRAZABILIDAD
- espera_min_diag: tiempo de espera calculado en el modelo.
- duracion_atencion_min: duracion de la atencion
  almacenada en la tabla.
- duracion_calculada_min: alias utilizado en esta consulta
  para mantener consistencia con los pasos siguientes.

No se modifican registros ni tablas originales.
--------------------------------------------------------- */
base_atenciones AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        espera_min_diag,

        duracion_atencion_min
            AS duracion_calculada_min

    FROM digiturnos.digiturnos_atenciones
),

/* ---------------------------------------------------------
PASO 2. Calcular indicadores de oportunidad y atencion.

Se excluyen los valores negativos de los promedios
y percentiles, sin eliminar los registros originales.
--------------------------------------------------------- */
indicadores_atencion AS (
    SELECT
        sede,

        COUNT(*) AS total_solicitudes,

        COUNT(*) FILTER (
            WHERE espera_min_diag >= 0
        ) AS esperas_validas,

        ROUND(
            AVG(espera_min_diag)
            FILTER (WHERE espera_min_diag >= 0)::numeric,
            2
        ) AS espera_promedio_min,

        ROUND(
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY espera_min_diag)
            FILTER (WHERE espera_min_diag >= 0)::numeric,
            2
        ) AS espera_mediana_min,

        ROUND(
            PERCENTILE_CONT(0.9)
            WITHIN GROUP (ORDER BY espera_min_diag)
            FILTER (WHERE espera_min_diag >= 0)::numeric,
            2
        ) AS espera_p90_min,

        COUNT(*) FILTER (
            WHERE espera_min_diag > 15
        ) AS esperas_mayores_15,

        COUNT(*) FILTER (
            WHERE espera_min_diag > 30
        ) AS esperas_mayores_30,

        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE espera_min_diag > 15
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE espera_min_diag >= 0
                ), 0
            ),
            2
        ) AS pct_esperas_mayores_15,

        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE espera_min_diag > 30
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE espera_min_diag >= 0
                ), 0
            ),
            2
        ) AS pct_esperas_mayores_30,

        COUNT(*) FILTER (
            WHERE duracion_calculada_min >= 0
        ) AS duraciones_validas,

        ROUND(
            AVG(duracion_calculada_min)
            FILTER (
                WHERE duracion_calculada_min >= 0
            )::numeric,
            2
        ) AS duracion_promedio_min,

        ROUND(
            PERCENTILE_CONT(0.9)
            WITHIN GROUP (
                ORDER BY duracion_calculada_min
            )
            FILTER (
                WHERE duracion_calculada_min >= 0
            )::numeric,
            2
        ) AS duracion_p90_min

    FROM base_atenciones
    GROUP BY sede
),

/* ---------------------------------------------------------
PASO 3. Consolidar la demanda por sede.

Cada registro de la tabla de franjas representa una
combinacion de sede, fecha y hora.

La intensidad promedio corresponde a:
total solicitudes / numero de franjas observadas.
--------------------------------------------------------- */
indicadores_demanda AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        SUM(solicitudes) AS solicitudes_demanda,

        COUNT(*) AS franjas_observadas,

        ROUND(
            SUM(solicitudes)::numeric
            / NULLIF(COUNT(*), 0),
            2
        ) AS solicitudes_promedio_franja

    FROM digiturnos.digiturnos_franjas
    GROUP BY
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        )
)

/* ---------------------------------------------------------
PASO 4. Integrar los indicadores.

LEFT JOIN:
Se conservan todas las sedes presentes en la tabla
principal de atenciones.
--------------------------------------------------------- */
SELECT
    a.sede,

    a.total_solicitudes,

    d.solicitudes_demanda,

    a.total_solicitudes
        - COALESCE(d.solicitudes_demanda, 0)
        AS diferencia_demanda,

    d.franjas_observadas,
    d.solicitudes_promedio_franja,

    a.esperas_validas,
    a.espera_promedio_min,
    a.espera_mediana_min,
    a.espera_p90_min,

    a.esperas_mayores_15,
    a.pct_esperas_mayores_15,

    a.esperas_mayores_30,
    a.pct_esperas_mayores_30,

    a.duraciones_validas,
    a.duracion_promedio_min,
    a.duracion_p90_min

FROM indicadores_atencion a

LEFT JOIN indicadores_demanda d
    ON a.sede = d.sede

ORDER BY
    a.espera_p90_min DESC NULLS LAST,
    a.total_solicitudes DESC;


/*
============================================================
EJERCICIO 2D - CONSULTA 4.5.2
SINTESIS DE OCUPACION OPERATIVA ESTIMADA POR SEDE
============================================================

OBJETIVO
Consolidar la ocupacion operativa estimada por sede,
diferenciando receptores segun representatividad.

METODOLOGIA
1. Reconstruir jornadas por sede, receptor y fecha.
2. Aplicar los criterios de validez de la consulta 4.4.
3. Clasificar combinaciones sede-receptor:
   - Principal: 30 o mas jornadas validas.
   - Complementario: 1 a 29 jornadas validas.
   - Sin jornadas validas.
4. Calcular ocupacion como razon de minutos agregados.
5. Conservar las combinaciones sin ocupacion calculable.

LIMITACION
No representa utilizacion contractual real.
No se dispone de horarios laborales programados.

CONTROL
Consulta de solo lectura.
============================================================
*/

WITH base AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        COALESCE(
            NULLIF(TRIM(receptor), ''),
            'Sin receptor'
        ) AS receptor,

        dt_llamado::date AS fecha_jornada,
        dt_llamado,
        dt_finalizacion,
        duracion_atencion_min

    FROM digiturnos.digiturnos_atenciones
),

universo AS (
    SELECT DISTINCT
        sede,
        receptor
    FROM base
),

jornadas AS (
    SELECT
        sede,
        receptor,
        fecha_jornada,

        COUNT(*) AS solicitudes_dia,

        COUNT(*) FILTER (
            WHERE duracion_atencion_min IS NULL
               OR duracion_atencion_min < 0
        ) AS duraciones_invalidas,

        SUM(
            CASE
                WHEN duracion_atencion_min >= 0
                    THEN duracion_atencion_min
                ELSE 0
            END
        ) AS minutos_efectivos,

        EXTRACT(
            EPOCH FROM (
                MAX(dt_finalizacion)
                - MIN(dt_llamado)
            )
        ) / 60.0 AS minutos_ventana

    FROM base

    WHERE receptor <> 'Sin receptor'
      AND fecha_jornada IS NOT NULL

    GROUP BY
        sede,
        receptor,
        fecha_jornada
),

jornadas_validas AS (
    SELECT *
    FROM jornadas

    WHERE duraciones_invalidas = 0
      AND minutos_ventana > 0
      AND minutos_efectivos >= 0
      AND minutos_efectivos <= minutos_ventana
),

receptores AS (
    SELECT
        sede,
        receptor,

        COUNT(*) AS jornadas_validas,

        SUM(solicitudes_dia) AS solicitudes_validas,

        SUM(minutos_efectivos) AS minutos_atencion,

        SUM(minutos_ventana) AS minutos_ventana

    FROM jornadas_validas

    GROUP BY
        sede,
        receptor
),

clasificacion AS (
    SELECT
        u.sede,
        u.receptor,

        COALESCE(r.jornadas_validas, 0)
            AS jornadas_validas,

        COALESCE(r.solicitudes_validas, 0)
            AS solicitudes_validas,

        r.minutos_atencion,
        r.minutos_ventana,

        CASE
            WHEN COALESCE(r.jornadas_validas, 0) = 0
                THEN '03. Sin jornadas validas'

            WHEN r.jornadas_validas >= 30
                THEN '01. Principal'

            ELSE '02. Complementario'
        END AS nivel_analisis

    FROM universo u

    LEFT JOIN receptores r
        ON u.sede = r.sede
       AND u.receptor = r.receptor
),

resumen AS (
    SELECT
        sede,

        COUNT(*) AS combinaciones_totales,

        COUNT(*) FILTER (
            WHERE nivel_analisis = '01. Principal'
        ) AS receptores_principal,

        COUNT(*) FILTER (
            WHERE nivel_analisis = '02. Complementario'
        ) AS receptores_complementario,

        COUNT(*) FILTER (
            WHERE nivel_analisis = '03. Sin jornadas validas'
        ) AS combinaciones_no_calculables,

        SUM(jornadas_validas) AS jornadas_validas,

        SUM(solicitudes_validas) AS solicitudes_validas,

        SUM(minutos_atencion) FILTER (
            WHERE nivel_analisis = '01. Principal'
        ) AS minutos_atencion_principal,

        SUM(minutos_ventana) FILTER (
            WHERE nivel_analisis = '01. Principal'
        ) AS minutos_ventana_principal,

        SUM(minutos_atencion) AS minutos_atencion_total,

        SUM(minutos_ventana) AS minutos_ventana_total

    FROM clasificacion

    GROUP BY sede
)

SELECT
    sede,

    combinaciones_totales,
    receptores_principal,
    receptores_complementario,
    combinaciones_no_calculables,

    jornadas_validas,
    solicitudes_validas,

    ROUND(
        minutos_atencion_principal::numeric,
        2
    ) AS minutos_atencion_principal,

    ROUND(
        minutos_ventana_principal::numeric,
        2
    ) AS minutos_ventana_principal,

    ROUND(
        (
            100.0 * minutos_atencion_principal
            / NULLIF(minutos_ventana_principal, 0)
        )::numeric,
        2
    ) AS ocupacion_principal_pct,

    ROUND(
        minutos_atencion_total::numeric,
        2
    ) AS minutos_atencion_total,

    ROUND(
        minutos_ventana_total::numeric,
        2
    ) AS minutos_ventana_total,

    ROUND(
        (
            100.0 * minutos_atencion_total
            / NULLIF(minutos_ventana_total, 0)
        )::numeric,
        2
    ) AS ocupacion_global_pct

FROM resumen

ORDER BY
    ocupacion_principal_pct DESC NULLS LAST,
    solicitudes_validas DESC;


/*
============================================================
EJERCICIO 2 - CONSULTA 4.5.3
DIAGNOSTICO INTEGRADO DE PRESION OPERATIVA POR SEDE
============================================================

OBJETIVO
Integrar demanda, oportunidad y ocupacion estimada
para identificar prioridades de analisis operativo.

FUENTES
- digiturnos.digiturnos_atenciones
- digiturnos.digiturnos_franjas

CRITERIOS
1. No se eliminan registros originales.
2. Los tiempos negativos se excluyen de promedios.
3. La ocupacion se calcula con jornadas validas.
4. Analisis principal: 30 o mas jornadas validas.
5. Analisis complementario: menos de 30 jornadas.
6. Los umbrales de priorizacion son exploratorios.

LIMITACION
La ocupacion no equivale a utilizacion contractual.

CONSULTA DE SOLO LECTURA.
============================================================
*/

WITH demanda AS (

    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        SUM(solicitudes) AS solicitudes_demanda,

        COUNT(*) AS franjas_observadas,

        ROUND(
            AVG(solicitudes)::numeric,
            2
        ) AS promedio_solicitudes_franja,

        MAX(solicitudes) AS pico_solicitudes_franja

    FROM digiturnos.digiturnos_franjas

    GROUP BY 1
),

oportunidad_base AS (

    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        espera_min_diag

    FROM digiturnos.digiturnos_atenciones
),

oportunidad AS (

    SELECT
        sede,

        COUNT(*) AS solicitudes_totales,

        COUNT(*) FILTER (
            WHERE espera_min_diag >= 0
        ) AS esperas_validas,

        ROUND(
            AVG(espera_min_diag)
            FILTER (
                WHERE espera_min_diag >= 0
            )::numeric,
            2
        ) AS espera_promedio_min,

        ROUND(
            PERCENTILE_CONT(0.9)
            WITHIN GROUP (
                ORDER BY espera_min_diag
            )
            FILTER (
                WHERE espera_min_diag >= 0
            )::numeric,
            2
        ) AS espera_p90_min,

        COUNT(*) FILTER (
            WHERE espera_min_diag > 15
        ) AS esperas_mayores_15,

        ROUND(
            (
                100.0 *
                COUNT(*) FILTER (
                    WHERE espera_min_diag > 15
                )
                /
                NULLIF(
                    COUNT(*) FILTER (
                        WHERE espera_min_diag >= 0
                    ),
                    0
                )
            )::numeric,
            2
        ) AS pct_esperas_mayores_15

    FROM oportunidad_base

    GROUP BY sede
),

ocupacion_base AS (

    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        COALESCE(
            NULLIF(TRIM(receptor), ''),
            'Sin receptor'
        ) AS receptor,

        dt_llamado::date AS fecha_jornada,

        dt_llamado,
        dt_finalizacion,
        duracion_atencion_min

    FROM digiturnos.digiturnos_atenciones
),

universo_receptores AS (

    SELECT DISTINCT
        sede,
        receptor

    FROM ocupacion_base
),

jornadas AS (

    SELECT
        sede,
        receptor,
        fecha_jornada,

        COUNT(*) AS solicitudes_dia,

        COUNT(*) FILTER (
            WHERE duracion_atencion_min IS NULL
               OR duracion_atencion_min < 0
        ) AS duraciones_invalidas,

        SUM(
            CASE
                WHEN duracion_atencion_min >= 0
                    THEN duracion_atencion_min
                ELSE 0
            END
        ) AS minutos_efectivos,

        EXTRACT(
            EPOCH FROM (
                MAX(dt_finalizacion)
                - MIN(dt_llamado)
            )
        ) / 60.0 AS minutos_ventana

    FROM ocupacion_base

    WHERE receptor <> 'Sin receptor'
      AND fecha_jornada IS NOT NULL

    GROUP BY
        sede,
        receptor,
        fecha_jornada
),

jornadas_validas AS (

    SELECT *
    FROM jornadas

    WHERE duraciones_invalidas = 0
      AND minutos_ventana > 0
      AND minutos_efectivos >= 0
      AND minutos_efectivos <= minutos_ventana
),

receptores AS (

    SELECT
        sede,
        receptor,

        COUNT(*) AS jornadas_validas,

        SUM(solicitudes_dia) AS solicitudes_validas,

        SUM(minutos_efectivos) AS minutos_atencion,

        SUM(minutos_ventana) AS minutos_ventana

    FROM jornadas_validas

    GROUP BY
        sede,
        receptor
),

receptores_clasificados AS (

    SELECT
        u.sede,
        u.receptor,

        COALESCE(
            r.jornadas_validas,
            0
        ) AS jornadas_validas,

        COALESCE(
            r.solicitudes_validas,
            0
        ) AS solicitudes_validas,

        r.minutos_atencion,
        r.minutos_ventana,

        CASE
            WHEN COALESCE(r.jornadas_validas, 0) = 0
                THEN 'Sin jornadas validas'

            WHEN r.jornadas_validas >= 30
                THEN 'Principal'

            ELSE 'Complementario'
        END AS nivel_analisis

    FROM universo_receptores u

    LEFT JOIN receptores r
        ON u.sede = r.sede
       AND u.receptor = r.receptor
),

ocupacion AS (

    SELECT
        sede,

        COUNT(*) AS combinaciones_receptor,

        COUNT(*) FILTER (
            WHERE nivel_analisis = 'Principal'
        ) AS receptores_principales,

        COUNT(*) FILTER (
            WHERE nivel_analisis = 'Complementario'
        ) AS receptores_complementarios,

        COUNT(*) FILTER (
            WHERE nivel_analisis = 'Sin jornadas validas'
        ) AS receptores_no_calculables,

        SUM(jornadas_validas) AS jornadas_validas,

        SUM(solicitudes_validas) AS solicitudes_validas,

        ROUND(
            (
                100.0 *
                SUM(minutos_atencion) FILTER (
                    WHERE nivel_analisis = 'Principal'
                )
                /
                NULLIF(
                    SUM(minutos_ventana) FILTER (
                        WHERE nivel_analisis = 'Principal'
                    ),
                    0
                )
            )::numeric,
            2
        ) AS ocupacion_principal_pct,

        ROUND(
            (
                100.0 *
                SUM(minutos_atencion)
                /
                NULLIF(
                    SUM(minutos_ventana),
                    0
                )
            )::numeric,
            2
        ) AS ocupacion_global_pct

    FROM receptores_clasificados

    GROUP BY sede
),

integracion AS (

    SELECT
        o.sede,

        o.solicitudes_totales,

        d.solicitudes_demanda,
        d.franjas_observadas,
        d.promedio_solicitudes_franja,
        d.pico_solicitudes_franja,

        o.esperas_validas,
        o.espera_promedio_min,
        o.espera_p90_min,
        o.esperas_mayores_15,
        o.pct_esperas_mayores_15,

        c.combinaciones_receptor,
        c.receptores_principales,
        c.receptores_complementarios,
        c.receptores_no_calculables,

        c.jornadas_validas,
        c.solicitudes_validas,

        c.ocupacion_principal_pct,
        c.ocupacion_global_pct

    FROM oportunidad o

    LEFT JOIN demanda d
        ON o.sede = d.sede

    LEFT JOIN ocupacion c
        ON o.sede = c.sede
),

diagnostico AS (

    SELECT
        *,

        CASE
            WHEN espera_p90_min >= 20
             AND ocupacion_principal_pct >= 60
                THEN '01. Presion alta'

            WHEN espera_p90_min >= 20
             AND ocupacion_principal_pct < 60
                THEN '02. Espera alta con ocupacion moderada'

            WHEN espera_p90_min < 20
             AND ocupacion_principal_pct >= 60
                THEN '03. Ocupacion alta con espera controlada'

            WHEN espera_p90_min IS NULL
              OR ocupacion_principal_pct IS NULL
                THEN '05. Informacion insuficiente'

            ELSE '04. Seguimiento ordinario'
        END AS perfil_operativo

    FROM integracion
)

SELECT
    sede,

    solicitudes_totales,

    solicitudes_demanda,

    solicitudes_totales
      - solicitudes_demanda
        AS diferencia_demanda,

    franjas_observadas,

    promedio_solicitudes_franja,
    pico_solicitudes_franja,

    espera_promedio_min,
    espera_p90_min,
    pct_esperas_mayores_15,

    combinaciones_receptor,
    receptores_principales,
    receptores_complementarios,
    receptores_no_calculables,

    jornadas_validas,
    solicitudes_validas,

    ocupacion_principal_pct,
    ocupacion_global_pct,

    perfil_operativo,

    CASE
        WHEN perfil_operativo = '01. Presion alta'
            THEN 'Revisar capacidad y distribucion horaria'

        WHEN perfil_operativo =
             '02. Espera alta con ocupacion moderada'
            THEN 'Revisar asignacion de turnos y picos'

        WHEN perfil_operativo =
             '03. Ocupacion alta con espera controlada'
            THEN 'Monitorear sostenibilidad operativa'

        WHEN perfil_operativo =
             '05. Informacion insuficiente'
            THEN 'Fortalecer calidad y cobertura del dato'

        ELSE 'Mantener seguimiento y mejora continua'
    END AS orientacion_analisis

FROM diagnostico

ORDER BY
    perfil_operativo,
    espera_p90_min DESC NULLS LAST,
    solicitudes_totales DESC;



/*
====================================================================
EJERCICIO 2 - CONSULTA 4.5.4
PRIORIZACION DE INTERVENCIONES OPERATIVAS POR SEDE
====================================================================

OBJETIVO
Construir una matriz de priorizacion basada en:
1. Severidad de los tiempos de espera.
2. Magnitud de solicitudes afectadas.
3. Presion operativa estimada.

FUENTES
- digiturnos.digiturnos_atenciones
- digiturnos.digiturnos_franjas

METODOLOGIA
Puntaje maximo: 100 puntos.

A. Severidad: 40 puntos.
   - P90 de espera: hasta 20.
   - Porcentaje de esperas >15 min: hasta 20.

B. Magnitud: 40 puntos.
   - Solicitudes con espera >15 min: hasta 40.

C. Presion operativa: 20 puntos.
   - Ocupacion principal: hasta 10.
   - Intensidad de demanda por franja: hasta 10.

Los puntajes se calculan mediante posiciones relativas
entre las 13 sedes, usando PERCENT_RANK.

LIMITACIONES
- Los umbrales son exploratorios.
- La ocupacion no representa utilizacion contractual.
- El puntaje no demuestra relaciones causales.
- Los receptores con menos de 30 jornadas se conservan
  en el analisis complementario.

TRAZABILIDAD
Consulta de solo lectura. No modifica registros.
====================================================================
*/

WITH
/* ================================================================
PASO 1. INDICADORES DE OPORTUNIDAD
================================================================ */
oportunidad AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        COUNT(*) AS solicitudes_totales,

        COUNT(*) FILTER (
            WHERE espera_min_diag >= 0
        ) AS esperas_validas,

        COUNT(*) FILTER (
            WHERE espera_min_diag > 15
        ) AS solicitudes_espera_15,

        ROUND(
            AVG(espera_min_diag)
            FILTER (
                WHERE espera_min_diag >= 0
            )::numeric,
            2
        ) AS espera_promedio_min,

        ROUND(
            PERCENTILE_CONT(0.9)
            WITHIN GROUP (
                ORDER BY espera_min_diag
            )
            FILTER (
                WHERE espera_min_diag >= 0
            )::numeric,
            2
        ) AS espera_p90_min,

        ROUND(
            (
                100.0 *
                COUNT(*) FILTER (
                    WHERE espera_min_diag > 15
                )
                /
                NULLIF(
                    COUNT(*) FILTER (
                        WHERE espera_min_diag >= 0
                    ),
                    0
                )
            )::numeric,
            2
        ) AS pct_espera_15

    FROM digiturnos.digiturnos_atenciones

    GROUP BY 1
),

/* ================================================================
PASO 2. DEMANDA POR FRANJA

Se calcula la intensidad promedio observada.
No se interpreta como ocupacion.
================================================================ */
demanda AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        SUM(solicitudes) AS solicitudes_demanda,

        COUNT(*) AS franjas_observadas,

        ROUND(
            AVG(solicitudes)::numeric,
            2
        ) AS promedio_solicitudes_franja

    FROM digiturnos.digiturnos_franjas

    GROUP BY 1
),

/* ================================================================
PASO 3. NORMALIZAR INFORMACION DE RECEPTOR
================================================================ */
base_ocupacion AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        NULLIF(TRIM(receptor), '') AS receptor,

        dt_llamado::date AS fecha_jornada,

        dt_llamado,
        dt_finalizacion,
        duracion_atencion_min

    FROM digiturnos.digiturnos_atenciones
),

universo_receptores AS (
    SELECT DISTINCT
        sede,
        COALESCE(receptor, 'Sin receptor') AS receptor

    FROM base_ocupacion
),

/* ================================================================
PASO 4. RECONSTRUIR JORNADAS
================================================================ */
jornadas AS (
    SELECT
        sede,
        receptor,
        fecha_jornada,

        COUNT(*) AS solicitudes_dia,

        COUNT(*) FILTER (
            WHERE duracion_atencion_min IS NULL
               OR duracion_atencion_min < 0
        ) AS duraciones_invalidas,

        SUM(
            CASE
                WHEN duracion_atencion_min >= 0
                    THEN duracion_atencion_min
                ELSE 0
            END
        ) AS minutos_efectivos,

        EXTRACT(
            EPOCH FROM (
                MAX(dt_finalizacion)
                - MIN(dt_llamado)
            )
        ) / 60.0 AS minutos_ventana

    FROM base_ocupacion

    WHERE receptor IS NOT NULL
      AND fecha_jornada IS NOT NULL

    GROUP BY
        sede,
        receptor,
        fecha_jornada
),

/* ================================================================
PASO 5. FILTRAR JORNADAS VALIDAS
================================================================ */
jornadas_validas AS (
    SELECT *
    FROM jornadas

    WHERE duraciones_invalidas = 0
      AND minutos_ventana > 0
      AND minutos_efectivos >= 0
      AND minutos_efectivos <= minutos_ventana
),

/* ================================================================
PASO 6. CONSOLIDAR POR RECEPTOR
================================================================ */
receptores AS (
    SELECT
        sede,
        receptor,

        COUNT(*) AS jornadas_validas,

        SUM(solicitudes_dia) AS solicitudes_validas,

        SUM(minutos_efectivos) AS minutos_atencion,

        SUM(minutos_ventana) AS minutos_ventana

    FROM jornadas_validas

    GROUP BY
        sede,
        receptor
),

clasificacion_receptores AS (
    SELECT
        u.sede,
        u.receptor,

        COALESCE(r.jornadas_validas, 0)
            AS jornadas_validas,

        r.minutos_atencion,
        r.minutos_ventana,

        CASE
            WHEN COALESCE(r.jornadas_validas, 0) = 0
                THEN 'Sin jornadas validas'

            WHEN r.jornadas_validas >= 30
                THEN 'Principal'

            ELSE 'Complementario'
        END AS nivel_analisis

    FROM universo_receptores u

    LEFT JOIN receptores r
        ON u.sede = r.sede
       AND u.receptor = r.receptor
),

/* ================================================================
PASO 7. CALCULAR OCUPACION POR SEDE
================================================================ */
ocupacion AS (
    SELECT
        sede,

        COUNT(*) AS combinaciones_receptor,

        COUNT(*) FILTER (
            WHERE nivel_analisis = 'Principal'
        ) AS receptores_principales,

        COUNT(*) FILTER (
            WHERE nivel_analisis = 'Complementario'
        ) AS receptores_complementarios,

        COUNT(*) FILTER (
            WHERE nivel_analisis = 'Sin jornadas validas'
        ) AS receptores_no_calculables,

        ROUND(
            (
                100.0 *
                SUM(minutos_atencion) FILTER (
                    WHERE nivel_analisis = 'Principal'
                )
                /
                NULLIF(
                    SUM(minutos_ventana) FILTER (
                        WHERE nivel_analisis = 'Principal'
                    ),
                    0
                )
            )::numeric,
            2
        ) AS ocupacion_principal_pct

    FROM clasificacion_receptores

    GROUP BY sede
),

/* ================================================================
PASO 8. INTEGRAR INDICADORES
================================================================ */
integracion AS (
    SELECT
        o.sede,

        o.solicitudes_totales,
        o.esperas_validas,
        o.solicitudes_espera_15,
        o.espera_promedio_min,
        o.espera_p90_min,
        o.pct_espera_15,

        d.solicitudes_demanda,
        d.franjas_observadas,
        d.promedio_solicitudes_franja,

        c.combinaciones_receptor,
        c.receptores_principales,
        c.receptores_complementarios,
        c.receptores_no_calculables,
        c.ocupacion_principal_pct,

        ROUND(
            (
                100.0 * c.receptores_principales
                / NULLIF(
                    c.combinaciones_receptor, 0
                )
            )::numeric,
            2
        ) AS pct_receptores_principales

    FROM oportunidad o

    LEFT JOIN demanda d
        ON o.sede = d.sede

    LEFT JOIN ocupacion c
        ON o.sede = c.sede
),

/* ================================================================
PASO 9. CALCULAR PUNTAJES RELATIVOS

PERCENT_RANK:
0 = menor valor observado.
1 = mayor valor observado.

Se multiplica por el peso de cada indicador.
================================================================ */
puntajes AS (
    SELECT
        *,

        ROUND(
            (
                20.0 *
                PERCENT_RANK() OVER (
                    ORDER BY espera_p90_min
                )
            )::numeric,
            2
        ) AS puntos_p90,

        ROUND(
            (
                20.0 *
                PERCENT_RANK() OVER (
                    ORDER BY pct_espera_15
                )
            )::numeric,
            2
        ) AS puntos_pct_espera,

        ROUND(
            (
                40.0 *
                PERCENT_RANK() OVER (
                    ORDER BY solicitudes_espera_15
                )
            )::numeric,
            2
        ) AS puntos_magnitud,

        ROUND(
            (
                10.0 *
                PERCENT_RANK() OVER (
                    ORDER BY ocupacion_principal_pct
                )
            )::numeric,
            2
        ) AS puntos_ocupacion,

        ROUND(
            (
                10.0 *
                PERCENT_RANK() OVER (
                    ORDER BY promedio_solicitudes_franja
                )
            )::numeric,
            2
        ) AS puntos_demanda

    FROM integracion
),

/* ================================================================
PASO 10. CONSTRUIR PUNTAJE TOTAL
================================================================ */
priorizacion AS (
    SELECT
        *,

        ROUND(
            (
                puntos_p90
                + puntos_pct_espera
                + puntos_magnitud
                + puntos_ocupacion
                + puntos_demanda
            )::numeric,
            2
        ) AS puntaje_total

    FROM puntajes
),

/* ================================================================
PASO 11. CLASIFICAR PRIORIDAD
================================================================ */
clasificacion_final AS (
    SELECT
        *,

        CASE
            WHEN puntaje_total >= 70
                THEN '01. Prioridad 1 - Intervencion focalizada'

            WHEN puntaje_total >= 50
                THEN '02. Prioridad 2 - Optimizacion operativa'

            ELSE '03. Prioridad 3 - Seguimiento preventivo'
        END AS prioridad,

        CASE
            WHEN pct_receptores_principales < 40
                THEN 'Representatividad limitada'

            ELSE 'Representatividad suficiente'
        END AS alerta_representatividad

    FROM priorizacion
)

/* ================================================================
PASO 12. RESULTADO EJECUTIVO
================================================================ */
SELECT
    sede,

    solicitudes_totales,
    solicitudes_espera_15,

    espera_promedio_min,
    espera_p90_min,
    pct_espera_15,

    promedio_solicitudes_franja,

    ocupacion_principal_pct,

    receptores_principales,
    receptores_complementarios,
    pct_receptores_principales,

    puntos_p90,
    puntos_pct_espera,
    puntos_magnitud,
    puntos_ocupacion,
    puntos_demanda,

    puntaje_total,
    prioridad,
    alerta_representatividad,

    CASE
        WHEN prioridad LIKE '01.%'
            THEN 'Intervenir horarios criticos y revisar asignacion'

        WHEN prioridad LIKE '02.%'
            THEN 'Optimizar turnos y monitorear esperas'

        ELSE 'Seguimiento preventivo y buenas practicas'
    END AS accion_recomendada,

    CASE
        WHEN prioridad LIKE '01.%'
            THEN 'Reducir P90 y esperas mayores a 15 minutos'

        WHEN prioridad LIKE '02.%'
            THEN 'Mejorar oportunidad en franjas de mayor demanda'

        ELSE 'Mantener indicadores y monitorear variaciones'
    END AS indicador_seguimiento

FROM clasificacion_final

ORDER BY
    puntaje_total DESC,
    solicitudes_espera_15 DESC;



/*
============================================================
PRUEBA TECNICA - ANALISTA BI
EJERCICIO 2 - DIGITURNOS

CONSULTA 4.6
TABLA ANALITICA OPERATIVA PARA POWER BI
============================================================

OBJETIVO
Analizar la demanda y los tiempos de espera por sede,
fecha, hora de solicitud y tipo de servicio.

GRANULARIDAD
Una fila por:
sede + fecha + hora + tipo_servicio.

REGLAS METODOLOGICAS
1. Se conserva el total de solicitudes.
2. Los indicadores de espera utilizan valores >= 0.
3. Se incluyen esperas iguales a cero.
4. Se excluyen esperas nulas y negativas del promedio,
   mediana y P90.
5. El umbral de 15 minutos es exploratorio.
6. Los porcentajes se calculan sobre esperas validas.
7. Los percentiles no deben promediarse en Power BI.
8. La consulta es de solo lectura.

VALIDACION PENDIENTE
Contrastar las reglas de espera con la consulta 4.5.4
antes de utilizar ambos archivos en el mismo tablero.
============================================================
*/

WITH base AS (

    SELECT
        id_registro_original,

        COALESCE(
            NULLIF(TRIM(sede), ''),
            'Sin sede'
        ) AS sede,

        dt_solicitud::date AS fecha_servicio,

        EXTRACT(
            HOUR FROM dt_solicitud
        )::integer AS hora_solicitud,

        EXTRACT(
            ISODOW FROM dt_solicitud
        )::integer AS dia_semana_iso,

        COALESCE(
            NULLIF(TRIM("Tipo_servicio"), ''),
            'Sin clasificacion'
        ) AS tipo_servicio,

        espera_min_diag,

        CASE
            WHEN espera_min_diag IS NOT NULL
             AND espera_min_diag >= 0
            THEN TRUE
            ELSE FALSE
        END AS espera_valida

    FROM digiturnos.digiturnos_atenciones

),

indicadores AS (

    SELECT
        sede,
        fecha_servicio,
        hora_solicitud,
        dia_semana_iso,
        tipo_servicio,

        COUNT(*) AS total_solicitudes,

        COUNT(*) FILTER (
            WHERE espera_valida
        ) AS solicitudes_espera_validas,

        COUNT(*) FILTER (
            WHERE NOT espera_valida
        ) AS solicitudes_espera_invalidas,

        COUNT(*) FILTER (
            WHERE espera_valida
              AND espera_min_diag > 15
        ) AS solicitudes_espera_15,

        AVG(espera_min_diag)
            FILTER (WHERE espera_valida)
            AS espera_promedio,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY espera_min_diag)
            FILTER (WHERE espera_valida)
            AS espera_mediana,

        PERCENTILE_CONT(0.9)
            WITHIN GROUP (ORDER BY espera_min_diag)
            FILTER (WHERE espera_valida)
            AS espera_p90

    FROM base

    GROUP BY
        sede,
        fecha_servicio,
        hora_solicitud,
        dia_semana_iso,
        tipo_servicio

)

SELECT
    sede,
    fecha_servicio,
    hora_solicitud,
    dia_semana_iso,
    tipo_servicio,

    total_solicitudes,
    solicitudes_espera_validas,
    solicitudes_espera_invalidas,
    solicitudes_espera_15,

    ROUND(
        (
            100.0 * solicitudes_espera_validas
            / NULLIF(total_solicitudes, 0)
        )::numeric,
        2
    ) AS cobertura_espera_pct,

    ROUND(
        (
            100.0 * solicitudes_espera_15
            / NULLIF(solicitudes_espera_validas, 0)
        )::numeric,
        2
    ) AS pct_espera_15,

    ROUND(
        espera_promedio::numeric, 2
    ) AS espera_promedio_min,

    ROUND(
        espera_mediana::numeric, 2
    ) AS espera_mediana_min,

    ROUND(
        espera_p90::numeric, 2
    ) AS espera_p90_min

FROM indicadores

ORDER BY
    fecha_servicio,
    sede,
    hora_solicitud,
    tipo_servicio;


/*
====================================================
VALIDACION DE LA CONSULTA 4.6
Control de volumen y consistencia de esperas
====================================================
*/

SELECT
    COUNT(*) AS total_solicitudes,

    COUNT(*) FILTER (
        WHERE dt_solicitud IS NULL
    ) AS solicitudes_sin_fecha,

    COUNT(*) FILTER (
        WHERE espera_min_diag IS NOT NULL
          AND espera_min_diag >= 0
    ) AS solicitudes_espera_validas,

    COUNT(*) FILTER (
        WHERE espera_min_diag IS NULL
           OR espera_min_diag < 0
    ) AS solicitudes_espera_invalidas,

    COUNT(*) FILTER (
        WHERE espera_min_diag > 15
    ) AS solicitudes_espera_15,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE espera_min_diag > 15
        ) / NULLIF(
            COUNT(*) FILTER (
                WHERE espera_min_diag IS NOT NULL
                  AND espera_min_diag >= 0
            ), 0
        ),
        2
    ) AS pct_espera_15

FROM digiturnos.digiturnos_atenciones;


/*
====================================================
CONTROL DE DIMENSIONES PARA POWER BI
====================================================
*/

SELECT
    COUNT(*) AS total_registros,

    COUNT(DISTINCT sede) AS total_sedes,

    COUNT(DISTINCT "Tipo_servicio") AS total_tipos_servicio,

    COUNT(DISTINCT dt_solicitud::date)
        AS total_fechas,

    MIN(dt_solicitud::date) AS primera_fecha,

    MAX(dt_solicitud::date) AS ultima_fecha,

    COUNT(*) FILTER (
        WHERE sede IS NULL
           OR TRIM(sede) = ''
    ) AS solicitudes_sin_sede,

    COUNT(*) FILTER (
        WHERE "Tipo_servicio" IS NULL
           OR TRIM("Tipo_servicio") = ''
    ) AS solicitudes_sin_tipo_servicio

FROM digiturnos.digiturnos_atenciones;
