-- 04_modelo_digiturnos.sql
-- Modelo inicial basado en inventario de CSV procesados.
-- Ejecutar en PostgreSQL desde DBeaver.
-- No elimina ni modifica tablas de Piscilago.
-- Los CSV se importan con separador ;, encabezado y UTF-8.
-- No se declaran PK/FK antes de validar unicidad y granularidad.

BEGIN;
CREATE SCHEMA IF NOT EXISTS digiturnos;

CREATE TABLE IF NOT EXISTS digiturnos."digiturnos_atenciones" (
    "Sede" TEXT,
    "UES" TEXT,
    "Clasifiacion" TEXT,
    "Usuario_receptor" TEXT,
    "Tipo_servicio" TEXT,
    "SUBSERVICIO_HOMOLOGADO" TEXT,
    "Fecha_Servico" TEXT,
    "Hora_solicitud_Servicio" TEXT,
    "Hora_llamado__Servicio" TEXT,
    "Hora_finalizado_Servicio" TEXT,
    "Identificacion_Cliente" TEXT,
    "Tipo_Oficina" TEXT,
    "id_registro_original" BIGINT,
    "dt_solicitud" TIMESTAMP,
    "dt_llamado" TIMESTAMP,
    "dt_finalizacion" TIMESTAMP,
    "receptor" TEXT,
    "sede" TEXT,
    "fecha_incompleta" TEXT,
    "secuencia_invalida" TEXT,
    "duracion_atencion_min" DOUBLE PRECISION,
    "intervalo_valido" TEXT,
    "espera_min_diag" DOUBLE PRECISION,
    "atencion_min_diag" DOUBLE PRECISION,
    "tiempos_validos_diag" TEXT,
    "alerta_solapamiento" TEXT
);

CREATE TABLE IF NOT EXISTS digiturnos."digiturnos_franjas" (
    "sede" TEXT,
    "fecha_dia" DATE,
    "dia_semana" BIGINT,
    "hora_solicitud" SMALLINT,
    "solicitudes" BIGINT,
    "receptores_observados" TEXT,
    "turnos_validos" BIGINT,
    "espera_promedio_min" DOUBLE PRECISION,
    "espera_mediana_min" DOUBLE PRECISION,
    "espera_p90_min" DOUBLE PRECISION,
    "umbral_p75_demanda" DOUBLE PRECISION,
    "alta_demanda_relativa" TEXT,
    "espera_p90_referencia_sede" DOUBLE PRECISION,
    "espera_elevada_relativa" TEXT,
    "alerta_presion_operativa" TEXT,
    "franja_inicio" TEXT,
    "minutos_servicio" DOUBLE PRECISION,
    "receptores_activos" TEXT,
    "atenciones_en_curso" BIGINT,
    "minutos_por_receptor_activo" TEXT,
    "servicios_iniciados" BIGINT,
    "duracion_media_min" DOUBLE PRECISION,
    "duracion_mediana_min" DOUBLE PRECISION,
    "duracion_p90_min" DOUBLE PRECISION,
    "solicitudes_por_receptor_activo" TEXT,
    "horas_receptor_equivalentes" TEXT,
    "alerta_integrada_preliminar" TEXT,
    "minutos_por_receptor_observado" TEXT,
    "p75_solicitudes" DOUBLE PRECISION,
    "p75_espera_promedio_min" DOUBLE PRECISION,
    "p75_espera_p90_min" DOUBLE PRECISION,
    "p75_minutos_por_receptor_observado" TEXT,
    "senal_demanda" TEXT,
    "senal_espera_promedio" TEXT,
    "senal_espera_p90" TEXT,
    "senal_carga_observada" TEXT,
    "datos_suficientes" TEXT,
    "numero_senales" BIGINT,
    "prioridad_cuello" TEXT,
    "orden_prioridad" BIGINT,
    "prioridad" TEXT,
    "es_critica" TEXT,
    "es_alta" TEXT,
    "es_prioritaria" TEXT,
    "es_seguimiento" TEXT,
    "sin_evidencia" TEXT
);

CREATE TABLE IF NOT EXISTS digiturnos."digiturnos_diagnostico_sedes" (
    "sede" TEXT,
    "franjas_analizadas" BIGINT,
    "solicitudes" BIGINT,
    "franjas_criticas" BIGINT,
    "franjas_altas" BIGINT,
    "franjas_seguimiento" BIGINT,
    "franjas_sin_evidencia" BIGINT,
    "franjas_prioritarias" BIGINT,
    "pct_franjas_prioritarias" DOUBLE PRECISION
);

COMMIT;

-- Comprobación de estructura (ejecutar tras crear las tablas):
SELECT table_name, count(*) AS columnas FROM information_schema.columns WHERE table_schema = 'digiturnos' GROUP BY table_name ORDER BY table_name;

-- Comprobación de registros (ejecutar DESPUÉS de importar los CSV):
SELECT 'digiturnos_atenciones' AS tabla, COUNT(*) AS registros FROM digiturnos."digiturnos_atenciones"
UNION ALL
SELECT 'digiturnos_franjas', COUNT(*) FROM digiturnos."digiturnos_franjas"
UNION ALL
SELECT 'digiturnos_diagnostico_sedes', COUNT(*) FROM digiturnos."digiturnos_diagnostico_sedes";

