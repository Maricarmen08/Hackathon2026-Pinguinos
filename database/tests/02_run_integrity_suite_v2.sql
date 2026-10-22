-- SOLO EJECUCION: sin DDL, sin COMMIT y sin reinstalar rutinas.
-- Seleccionar hackathon_pinguinos_dev en HeidiSQL. Conexion dedicada, sin
-- transacciones pendientes; ejecutar 00_preflight_integrity_v2.sql primero.
-- NO usar CALL de la rutina V1. El nombre y token identifican release 2.0.0.
CALL hackathon_pinguinos_dev.dbv1_test_integridad_v2_0_0(
  'pinguinos-integrity:2.0.0',
  DATABASE(),
  @@SESSION.sql_mode
);
