-- ==========================================================
-- RECITRONIC — Gestión de reciclaje de electrónicos
-- Motor: MySQL 8.x (InnoDB, ACID)
-- Requisitos cubiertos:
--  - Tablas: clientes, articulos, citas, pagos (PK, FK, NOT NULL, CHECK)
--  - "Secuencias": AUTO_INCREMENT para ids (MySQL)
--  - DML: inserts, updates, deletes
--  - Transacciones: COMMIT y ROLLBACK (con procedimiento seguro)
-- ==========================================================

/* 0) Crear y usar la base */
CREATE DATABASE IF NOT EXISTS recitronic_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
USE recitronic_db;

/* 1) Limpiar (orden seguro) */
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS pagos;
DROP TABLE IF EXISTS citas;
DROP TABLE IF EXISTS articulos;
DROP TABLE IF EXISTS clientes;
SET FOREIGN_KEY_CHECKS = 1;

/* 2) Tablas con restricciones e integridad referencial */

/* 2.1) Clientes */
CREATE TABLE clientes (
  id_cliente   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre       VARCHAR(100) NOT NULL,
  telefono     VARCHAR(20)  NOT NULL,
  direccion    VARCHAR(150) NOT NULL,
  PRIMARY KEY (id_cliente),
  UNIQUE KEY uk_clientes_telefono (telefono)
) ENGINE=InnoDB;

/* 2.2) Articulos (cada artículo pertenece a un cliente) */
CREATE TABLE articulos (
  id_articulo  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_cliente   INT UNSIGNED NOT NULL,
  tipo_articulo VARCHAR(100) NOT NULL,
  estado       ENUM('pendiente','reciclado','cancelado') NOT NULL DEFAULT 'pendiente',
  PRIMARY KEY (id_articulo),
  KEY idx_articulos_cliente (id_cliente),
  CONSTRAINT fk_articulos_clientes
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB;

/* 2.3) Citas (una cita se agenda para un cliente en una fecha/hora) */
CREATE TABLE citas (
  id_cita      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_cliente   INT UNSIGNED NOT NULL,
  fecha_hora   DATETIME     NOT NULL,
  PRIMARY KEY (id_cita),
  KEY idx_citas_cliente (id_cliente),
  CONSTRAINT uq_citas_cliente_fecha UNIQUE (id_cliente, fecha_hora), -- evita duplicados
  CONSTRAINT fk_citas_clientes
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB;

/* 2.4) Pagos (asociados al cliente) */
CREATE TABLE pagos (
  id_pago      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_cliente   INT UNSIGNED NOT NULL,
  monto        DECIMAL(10,2) NOT NULL,
  fecha_pago   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_pago),
  KEY idx_pagos_cliente (id_cliente),
  CONSTRAINT ck_pagos_monto CHECK (monto >= 0),
  CONSTRAINT fk_pagos_clientes
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB;

/* 3) DML — INSERTAR INFORMACIÓN */

/* 3.1) Clientes */
INSERT INTO clientes (nombre, telefono, direccion) VALUES
('Ana Rivas',     '911111111', 'Av. Central 123, Santiago'),
('Luis Ortega',   '922222222', 'Calle Norte 456, Valparaíso'),
('María Campos',  '933333333', 'Pasaje Sur 789, Concepción');

/* 3.2) Artículos por cliente */
INSERT INTO articulos (id_cliente, tipo_articulo, estado) VALUES
(1, 'Notebook',           'pendiente'),
(1, 'Impresora',          'pendiente'),
(2, 'Smartphone',         'pendiente'),
(2, 'Monitor',            'pendiente'),
(3, 'Placa Madre',        'pendiente'),
(3, 'Fuente de Poder',    'pendiente');

/* 3.3) Citas (agenda de retiro) */
INSERT INTO citas (id_cliente, fecha_hora) VALUES
(1, '2025-09-01 10:00:00'),
(1, '2025-09-03 09:00:00'),
(2, '2025-09-02 15:30:00'),
(3, '2025-09-04 11:15:00');

/* 3.4) Pagos */
INSERT INTO pagos (id_cliente, monto, fecha_pago) VALUES
(1, 15.00, '2025-09-01 12:00:00'),
(2, 25.50, '2025-09-02 16:00:00'),
(3, 10.00, '2025-09-04 12:00:00');

/* 4) DML — ACTUALIZAR INFORMACIÓN */

/* 4.1) Reagendar una cita (conflicto de horarios) */
-- Cambiamos la cita de Ana del 2025-09-03 09:00 a 2025-09-03 11:00
UPDATE citas
SET fecha_hora = '2025-09-03 11:00:00'
WHERE id_cliente = 1 AND fecha_hora = '2025-09-03 09:00:00';

/* 4.2) Cambiar estado de un artículo de 'pendiente' a 'reciclado' */
-- Marcamos reciclado el smartphone de Luis (id_cliente=2)
UPDATE articulos
SET estado = 'reciclado'
WHERE id_cliente = 2 AND tipo_articulo = 'Smartphone' AND estado = 'pendiente';

/* 5) DML — ELIMINAR INFORMACIÓN */

/* 5.1) Eliminar un artículo ingresado por error (ejemplo: fuente de poder de María) */
DELETE FROM articulos
WHERE id_cliente = 3 AND tipo_articulo = 'Fuente de Poder';

/* 5.2) Eliminar una cita cancelada (ejemplo: la de 2025-09-02 15:30 de Luis) */
DELETE FROM citas
WHERE id_cliente = 2 AND fecha_hora = '2025-09-02 15:30:00';

/* 6) TRANSACCIONES (ACID) */

/* 6.A) Ejemplo de transacción EXITOSA (COMMIT)
   Caso: Registrar un retiro con pago. Todo-o-nada:
   - Insertar nueva cita
   - Cambiar estado de un artículo a 'reciclado'
   - Registrar pago
*/
START TRANSACTION;
  -- Nueva cita para Ana
  INSERT INTO citas (id_cliente, fecha_hora)
  VALUES (1, '2025-09-05 09:30:00');

  -- Marcar su 'Impresora' como reciclada
  UPDATE articulos
  SET estado = 'reciclado'
  WHERE id_cliente = 1 AND tipo_articulo = 'Impresora' AND estado = 'pendiente';

  -- Registrar pago del servicio
  INSERT INTO pagos (id_cliente, monto) VALUES (1, 12.00);
COMMIT;

/* 6.B) Ejemplo de transacción con ROLLBACK controlado
   Implementado con procedimiento y HANDLER para SQLEXCEPTION.
   Si algo falla (p.ej., monto negativo viola CHECK), se revierte todo.
*/

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_registrar_retiro_seguro $$
CREATE PROCEDURE sp_registrar_retiro_seguro(
  IN p_id_cliente INT UNSIGNED,
  IN p_id_articulo INT UNSIGNED,
  IN p_fecha_hora DATETIME,
  IN p_monto DECIMAL(10,2)
)
BEGIN
  DECLARE exit handler FOR SQLEXCEPTION
  BEGIN
    -- Cualquier error: revertimos
    ROLLBACK;
    -- Opcional: SIGNAL para informar (comentado si tu cliente corta la ejecución)
    -- SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transacción revertida por error';
  END;

  START TRANSACTION;

    /* Verificaciones simples (opcionales) */
    -- Asegurar que el artículo pertenezca al cliente y esté pendiente
    UPDATE articulos
    SET estado = 'reciclado'
    WHERE id_articulo = p_id_articulo
      AND id_cliente  = p_id_cliente
      AND estado = 'pendiente';

    -- Debe afectar 1 fila; si no, forzamos error:
    IF ROW_COUNT() = 0 THEN
      -- fuerza error genérico para entrar al HANDLER
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Artículo no válido o ya reciclado';
    END IF;

    -- Insertar la cita (podría fallar por FK o por UNIQUE de (id_cliente, fecha_hora))
    INSERT INTO citas (id_cliente, fecha_hora)
    VALUES (p_id_cliente, p_fecha_hora);

    -- Insertar pago (puede fallar por CHECK monto>=0)
    INSERT INTO pagos (id_cliente, monto)
    VALUES (p_id_cliente, p_monto);

  COMMIT;
END $$
DELIMITER ;

/* Llamada EXITOSA (commit) */
CALL sp_registrar_retiro_seguro(3, /* cliente María */
                                5, /* id_articulo=Placa Madre (pendiente) */
                                '2025-09-06 10:00:00',
                                14.50);

/* Llamada que PROVOCA ROLLBACK (monto negativo → viola CHECK) */
-- Nada debería persistir tras esta llamada.
CALL sp_registrar_retiro_seguro(2, /* cliente Luis */
                                4, /* id_articulo=Monitor */
                                '2025-09-07 15:00:00',
                                -5.00);

/* 7) Consultas de verificación (opcionales) */
SELECT * FROM clientes ORDER BY id_cliente;
SELECT * FROM articulos ORDER BY id_articulo;
SELECT * FROM citas ORDER BY id_cita;
SELECT * FROM pagos ORDER BY id_pago;

-- ======================= FIN =======================
