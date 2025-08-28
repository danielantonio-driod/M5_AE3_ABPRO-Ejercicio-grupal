# RECITRONIC — Gestión de Reciclaje de Electrónicos (MySQL 8.x)

Este README acompaña el script **`recitronic.sql`**, que crea la base de datos, tablas, inserta datos de ejemplo y demuestra operaciones DML y **transacciones ACID** (commit/rollback) para el caso **RECITRONIC**.

---

## ✅ Requerimientos que cumple

* **Tablas**: `clientes`, `articulos`, `citas`, `pagos` (con PK, FK, NOT NULL, CHECK).
* **Secuencias**: uso de `AUTO_INCREMENT` (equivalente a secuencias en MySQL).
* **DML**: `INSERT`, `UPDATE`, `DELETE` para clientes, artículos, citas y pagos.
* **Integridad referencial**: claves foráneas entre tablas, índices previos a FK.
* **Transacciones**: ejemplo exitoso con `COMMIT` y ejemplo con `ROLLBACK` mediante procedimiento con `HANDLER`.
* **Restricciones**: `UNIQUE`, `ENUM`, `CHECK`, `NOT NULL`, y reglas `ON DELETE/UPDATE`.

---

## 🛠 Requisitos

* **MySQL 8.x** (InnoDB).
* Cliente: **MySQL Workbench**, **phpMyAdmin** o **CLI**.
* Usuario con permisos para crear base de datos (si no, usa una BD existente y elimina la sección `CREATE DATABASE`).

---

## ▶️ Cómo ejecutarlo

### MySQL Workbench / phpMyAdmin

1. Abre `recitronic.sql`.
2. Conéctate al servidor MySQL.
3. Ejecuta **todo** el script (Run All).
4. Confirma que la base activa es `recitronic_db`:

   ```sql
   SELECT DATABASE();
   ```

### CLI

```bash
mysql -u <usuario> -p
SOURCE /ruta/a/recitronic.sql;
```

---

## 📦 Estructura de tablas

**clientes**

* `id_cliente` INT UNSIGNED PK AUTO\_INCREMENT
* `nombre` VARCHAR(100) NOT NULL
* `telefono` VARCHAR(20) NOT NULL **UNIQUE**
* `direccion` VARCHAR(150) NOT NULL

**articulos**

* `id_articulo` INT UNSIGNED PK AUTO\_INCREMENT
* `id_cliente` INT UNSIGNED FK → `clientes.id_cliente`
* `tipo_articulo` VARCHAR(100) NOT NULL
* `estado` ENUM('pendiente','reciclado','cancelado') DEFAULT 'pendiente' NOT NULL

**citas**

* `id_cita` INT UNSIGNED PK AUTO\_INCREMENT
* `id_cliente` INT UNSIGNED FK → `clientes.id_cliente`
* `fecha_hora` DATETIME NOT NULL
* **UNIQUE (`id_cliente`, `fecha_hora`)** para evitar citas duplicadas por cliente

**pagos**

* `id_pago` INT UNSIGNED PK AUTO\_INCREMENT
* `id_cliente` INT UNSIGNED FK → `clientes.id_cliente`
* `monto` DECIMAL(10,2) **CHECK (monto ≥ 0)**
* `fecha_pago` DATETIME DEFAULT CURRENT\_TIMESTAMP NOT NULL

---

## 🧪 Qué hace el script (resumen)

1. **Crea** la base `recitronic_db` y la selecciona con `USE`.
2. **Recrea** tablas (drop seguro + creación con FKs/índices).
3. **Inserta** clientes, artículos, citas y pagos de ejemplo.
4. **Actualiza** una cita por conflicto y marca artículos como `reciclado`.
5. **Elimina** un artículo cargado por error y una cita cancelada.
6. **Transacción COMMIT**: agenda cita + marca reciclado + registra pago (todo o nada).
7. **Transacción con ROLLBACK**: procedimiento `sp_registrar_retiro_seguro` que revierte si algo falla (ej.: `monto` negativo o artículo inválido).

---

## 🔎 Verificaciones útiles

* Ver datos:

  ```sql
  SELECT * FROM clientes;
  SELECT * FROM articulos;
  SELECT * FROM citas;
  SELECT * FROM pagos;
  ```
* Probar **COMMIT**: ya incluido en el bloque 6.A (todo queda guardado).
* Probar **ROLLBACK**: ejecutar la segunda llamada del 6.B (con `monto` negativo); no deben persistir cambios.

---

## 🧰 Troubleshooting

* **“Access denied; you need (at least) the CREATE privilege”**
  Tu usuario no puede crear BDs. Elimina el bloque `CREATE DATABASE...; USE recitronic_db;` y reemplázalo por `USE <tu_bd_existente>;`.

* **Error de FK al crear tablas**
  Ejecuta el script completo en orden. No saltes bloques. El script ya hace `DROP` en orden y crea índices antes de FK.

* **Error por `DELIMITER`**
  Si tu cliente no soporta `DELIMITER`, usa MySQL Workbench o CLI. En Workbench/CLI funciona tal cual.

* **Ya no existe el artículo usado en el ejemplo de ROLLBACK**
  Ajusta los IDs en la llamada al procedimiento (`p_id_cliente`, `p_id_articulo`) para usar uno que esté en estado `pendiente` y pertenezca al cliente indicado.



