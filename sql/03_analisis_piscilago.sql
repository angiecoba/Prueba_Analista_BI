/* ============================================================
   PRUEBA ANALISTA BI - PISCILAGO
   Archivo: 03_analisis_piscilago.sql

   Objetivo:
   Analizar las tendencias de compra de los afiliados en
   Piscilago a partir de la tabla de hechos validada.

   Líneas de análisis:
   1. Tendencia temporal
   2. Comportamiento por tipo de vínculo
   3. Productos
   4. Punto de recaudo
   5. Ticket promedio y valor de compra
   6. Cruces poblacionales complementarios

   Nota metodológica:
   Para análisis por categoría, segmento o pirámide se utilizan
   únicamente perfiles cuya calidad de segmentación sea
   'Consistente'.

   Los registros ambiguos se conservan para análisis agregados
   cuando la dimensión poblacional no sea necesaria.
   ============================================================ */

SET search_path TO bi;


/* ============================================================
   0. VALIDACIÓN DEL CONTEXTO
   ============================================================ */

SELECT
    current_database() AS base_datos,
    current_schema() AS esquema_actual;


/* ============================================================
   1. TENDENCIA MENSUAL DE COMPRAS
   ============================================================

   Objetivo:
   Identificar la evolución mensual del número de compradores,
   las ventas netas y el ticket promedio.

   Indicadores:
   - compradores_unicos
   - ventas_netas
   - ticket_promedio

   Nota:
   En esta base cada registro corresponde a un comprador único,
   pero se mantiene COUNT(DISTINCT id_normalizado) para preservar
   la lógica del indicador.
   ============================================================ */

SELECT
    anio,
    mes,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos,
    ROUND(SUM(valor_neto), 0) AS ventas_netas,
    ROUND(
        AVG(valor_neto),
        2
    ) AS ticket_promedio
FROM bi.fact_consumos_piscilago
GROUP BY
    anio,
    mes
ORDER BY
    anio,
    mes;


/* ============================================================
   2. TENDENCIA MENSUAL POR TIPO DE VÍNCULO
   ============================================================

   Objetivo:
   Comparar el comportamiento mensual de compradores y ventas
   según la relación del comprador con la Caja.
   ============================================================ */

SELECT
    anio,
    mes,
    tipo_vinculo,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos,
    ROUND(SUM(valor_neto), 0) AS ventas_netas,
    ROUND(AVG(valor_neto), 2) AS ticket_promedio
FROM bi.fact_consumos_piscilago
GROUP BY
    anio,
    mes,
    tipo_vinculo
ORDER BY
    anio,
    mes,
    tipo_vinculo;


/* ============================================================
   3. COMPORTAMIENTO POR PRODUCTO
   ============================================================

   Objetivo:
   Identificar qué productos concentran mayor número de
   compradores y mayor valor de venta.
   ============================================================ */

SELECT
    desc_producto,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos,
    ROUND(SUM(valor_neto), 0) AS ventas_netas,
    ROUND(AVG(valor_neto), 2) AS ticket_promedio
FROM bi.fact_consumos_piscilago
GROUP BY
    desc_producto
ORDER BY
    ventas_netas DESC;



/* ============================================================
   3.1 PRODUCTO POR TIPO DE VÍNCULO
   ============================================================ */

SELECT
    tipo_vinculo,
    desc_producto,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos,
    ROUND(SUM(valor_neto), 0) AS ventas_netas
FROM bi.fact_consumos_piscilago
GROUP BY
    tipo_vinculo,
    desc_producto
ORDER BY
    tipo_vinculo,
    ventas_netas DESC;


/* ============================================================
   4. COMPORTAMIENTO POR PUNTO DE RECAUDO
   ============================================================

   Objetivo:
   Identificar los puntos de recaudo con mayor volumen de
   compradores y valor de venta.
   ============================================================ */

SELECT
    punto_recaudo,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos,
    ROUND(SUM(valor_neto), 0) AS ventas_netas,
    ROUND(AVG(valor_neto), 2) AS ticket_promedio
FROM bi.fact_consumos_piscilago
GROUP BY
    punto_recaudo
ORDER BY
    ventas_netas DESC;


/* ============================================================
   5. COMPORTAMIENTO DE AFILIADOS POR SEGMENTO
   ============================================================

   Objetivo:
   Analizar el comportamiento de compra únicamente para
   afiliados con segmentación poblacional consistente.

   Variables:
   - categoria
   - segmento_poblacional
   ============================================================ */

SELECT
    categoria,
    segmento_poblacional,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos,
    ROUND(SUM(valor_neto), 0) AS ventas_netas,
    ROUND(AVG(valor_neto), 2) AS ticket_promedio
FROM bi.fact_consumos_piscilago
WHERE tipo_vinculo = 'Afiliado'
  AND calidad_segmentacion = 'Consistente'
GROUP BY
    categoria,
    segmento_poblacional
ORDER BY
    ventas_netas DESC;


/* ============================================================
   5.1 COMPORTAMIENTO DE AFILIADOS POR PIRÁMIDE 1
   ============================================================ */

SELECT
    piramide1,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos,
    ROUND(SUM(valor_neto), 0) AS ventas_netas,
    ROUND(AVG(valor_neto), 2) AS ticket_promedio
FROM bi.fact_consumos_piscilago
WHERE tipo_vinculo = 'Afiliado'
  AND calidad_segmentacion = 'Consistente'
GROUP BY
    piramide1
ORDER BY
    ventas_netas DESC;


/* ============================================================
   6. COMPORTAMIENTO DE COMPRAS CON Y SIN SEGURO
   ============================================================

   Objetivo:
   Identificar diferencias en volumen y valor de compra entre
   registros con seguro y sin seguro.
   ============================================================ */

SELECT
    seguro,
    COUNT(DISTINCT id_normalizado) AS compradores_unicos,
    ROUND(SUM(valor_subtotal), 0) AS valor_subtotal,
    ROUND(SUM(valor_seguro), 0) AS valor_seguro,
    ROUND(SUM(valor_neto), 0) AS ventas_netas,
    ROUND(AVG(valor_neto), 2) AS ticket_promedio
FROM bi.fact_consumos_piscilago
GROUP BY
    seguro
ORDER BY
    seguro DESC;



/* ============================================================
   7. CONCENTRACIÓN DE VENTAS POR PRODUCTO
   ============================================================

   Objetivo:
   Medir qué proporción de las ventas netas representa cada
   producto dentro del total observado.
   ============================================================ */

WITH productos AS (
    SELECT
        desc_producto,
        COUNT(DISTINCT id_normalizado) AS compradores_unicos,
        SUM(valor_neto) AS ventas_netas
    FROM bi.fact_consumos_piscilago
    GROUP BY desc_producto
),

total AS (
    SELECT
        SUM(valor_neto) AS ventas_totales
    FROM bi.fact_consumos_piscilago
)

SELECT
    p.desc_producto,
    p.compradores_unicos,
    ROUND(p.ventas_netas, 0) AS ventas_netas,
    ROUND(
        p.ventas_netas * 100.0
        / NULLIF(t.ventas_totales, 0),
        2
    ) AS participacion_ventas_pct

FROM productos p
CROSS JOIN total t

ORDER BY
    p.ventas_netas DESC;