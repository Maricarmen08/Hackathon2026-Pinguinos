-- SOLO LECTURA; ejecutar DESPUES de las migraciones.
USE hackathon_pinguinos_dev;
SELECT VERSION() AS version_servidor,DATABASE() AS base_actual,@@session.time_zone AS zona_sesion;
SELECT '23 tablas base y 5 vistas' AS esperado,table_type,COUNT(*) AS cantidad
FROM information_schema.tables WHERE table_schema=DATABASE() GROUP BY table_type;
SELECT * FROM schema_migraciones ORDER BY version;
SELECT constraint_type,COUNT(*) AS cantidad
FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() GROUP BY constraint_type;
SELECT table_name,column_name,column_type,character_set_name,collation_name,is_nullable
FROM information_schema.columns WHERE table_schema=DATABASE()
 AND (column_name='id' OR column_name='negocio_id' OR column_name LIKE '%minor') ORDER BY table_name,ordinal_position;
SELECT table_name,constraint_name,column_name,referenced_table_name,referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema=DATABASE() AND referenced_table_name IS NOT NULL ORDER BY table_name,constraint_name,ordinal_position;
SELECT table_name,index_name,non_unique,GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columnas
FROM information_schema.statistics WHERE table_schema=DATABASE() GROUP BY table_name,index_name,non_unique ORDER BY table_name,index_name;
SELECT constraint_name,check_clause FROM information_schema.check_constraints WHERE constraint_schema=DATABASE();
-- Esperado: CERO filas.
SELECT table_name,column_name FROM information_schema.columns
WHERE table_schema=DATABASE() AND data_type IN ('float','double');
SELECT table_name,engine FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_type='BASE TABLE' AND engine<>'InnoDB';
