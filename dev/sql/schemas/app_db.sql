-- app_db: base principal del sistema (estructura de acceso, seguridad y bitácora).
-- Fuente de verdad: dev/specs/control-acceso.md y dev/specs/base-de-datos.md.
-- Convenciones: id BIGINT UNSIGNED AUTO_INCREMENT, columnas estándar y baja lógica,
-- toda tabla calificada como app_db.<tabla> desde los procedimientos.
-- Excepción explícita a las columnas estándar: las tablas de solo-anexado
-- `bitacora`, `usuario_acceso_log` y `opcion_uso_log` (no se actualizan ni eliminan).
--
-- Las claves únicas (login, correo, nombre de módulo/rol) se aplican a todas las
-- filas, incluidas las de baja lógica. La política de reutilización de claves
-- naturales tras una baja queda como decisión abierta (base-de-datos.md §12).
--
-- Nota: este script es el esquema objetivo. El entorno de desarrollo aún usa pr_db;
-- se aplica con `make sql` una vez ajustado el comando a app_db (ver AGENTS.md).

CREATE DATABASE IF NOT EXISTS `app_db`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE `app_db`;

-- ---------------------------------------------------------------------------
-- 4.1 app: configuración de la aplicación.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `app` (
  `idapp`                     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `app_nombre`                VARCHAR(150)    NOT NULL,
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idapp`),
  KEY `idx_app_activo` (`activo`, `eliminado`),
  CONSTRAINT `chk_app_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.2 modulos: unidades funcionales (carpetas de modules/<modulo>/).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `modulos` (
  `idmodulo`                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `modulo_nombre`             VARCHAR(100)    NOT NULL,
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idmodulo`),
  UNIQUE KEY `uq_modulos_nombre` (`modulo_nombre`),
  CONSTRAINT `chk_modulos_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.3 carpetas: agrupación de opciones dentro de un módulo.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `carpetas` (
  `idcarpeta`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idmodulo`                  BIGINT UNSIGNED NOT NULL,
  `carpeta_nombre`            VARCHAR(100)    NOT NULL,
  `carpeta_orden`             VARCHAR(10)     NOT NULL,
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idcarpeta`),
  KEY `idx_carpetas_modulo` (`idmodulo`),
  KEY `idx_carpetas_orden` (`idmodulo`, `carpeta_orden`),
  CONSTRAINT `fk_carpetas_modulo` FOREIGN KEY (`idmodulo`)
    REFERENCES `modulos` (`idmodulo`),
  CONSTRAINT `chk_carpetas_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.4 opciones: pantallas o acciones ejecutables dentro de una carpeta.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `opciones` (
  `idopcion`                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idcarpeta`                 BIGINT UNSIGNED NOT NULL,
  `opcion_nombre`             VARCHAR(100)    NOT NULL,
  `opcion_orden`              VARCHAR(10)     NOT NULL,
  `opcion_call`               VARCHAR(150)    NOT NULL,
  `opcion_parametros`         VARCHAR(500)    NULL,
  `opcion_grupo_accion`       VARCHAR(50)     NULL,
  `opcion_accion`             VARCHAR(50)     NULL,
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idopcion`),
  KEY `idx_opciones_carpeta` (`idcarpeta`),
  KEY `idx_opciones_orden` (`idcarpeta`, `opcion_orden`),
  KEY `idx_opciones_call` (`opcion_call`),
  CONSTRAINT `fk_opciones_carpeta` FOREIGN KEY (`idcarpeta`)
    REFERENCES `carpetas` (`idcarpeta`),
  CONSTRAINT `chk_opciones_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.6 roles: conjunto de opciones concedidas.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `roles` (
  `idrol`                     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `rol_nombre`                VARCHAR(100)    NOT NULL,
  `rol_descripcion`           VARCHAR(255)    NULL,
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idrol`),
  UNIQUE KEY `uq_roles_nombre` (`rol_nombre`),
  CONSTRAINT `chk_roles_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.8 usuarios: personas autenticadas.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuarios` (
  `idusuario`                     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `usuario_nombre`                VARCHAR(150)    NOT NULL,
  `usuario_correo`                VARCHAR(180)    NOT NULL,
  `usuario_login`                 VARCHAR(80)     NOT NULL,
  `usuario_password`              VARCHAR(255)    NULL,
  `usuario_token_acceso`          VARCHAR(255)    NULL,
  `fecha_ultimo_cambio_password`  DATETIME(3)     NULL,
  `fecha_token_acceso`            DATETIME(3)     NULL,
  `intentos_fallidos`             INT             NOT NULL DEFAULT 0,
  `fecha_ultimo_intento`          DATETIME(3)     NULL,
  `bloqueado`                     TINYINT(1)      NOT NULL DEFAULT 0,
  `fecha_bloqueo`                 DATETIME(3)     NULL,
  `doble_factor_habilitado`       TINYINT(1)      NOT NULL DEFAULT 0,
  `fecha_dado_baja`               DATETIME(3)     NULL,
  `motivo_baja`                   VARCHAR(255)    NULL,
  `activo`                        TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                     TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`       BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`         BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`        DATETIME(3)     NULL,
  PRIMARY KEY (`idusuario`),
  UNIQUE KEY `uq_usuarios_login` (`usuario_login`),
  UNIQUE KEY `uq_usuarios_correo` (`usuario_correo`),
  KEY `idx_usuarios_activo` (`activo`, `eliminado`),
  KEY `idx_usuarios_bloqueado` (`bloqueado`),
  CONSTRAINT `chk_usuarios_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.5 rol - opcion: permisos concedidos a un rol.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rol_opcion` (
  `idrol_opcion`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idrol`                     BIGINT UNSIGNED NOT NULL,
  `idopcion`                  BIGINT UNSIGNED NOT NULL,
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idrol_opcion`),
  UNIQUE KEY `uq_rol_opcion` (`idrol`, `idopcion`),
  KEY `idx_rol_opcion_opcion` (`idopcion`),
  CONSTRAINT `fk_rol_opcion_rol` FOREIGN KEY (`idrol`)
    REFERENCES `roles` (`idrol`),
  CONSTRAINT `fk_rol_opcion_opcion` FOREIGN KEY (`idopcion`)
    REFERENCES `opciones` (`idopcion`),
  CONSTRAINT `chk_rol_opcion_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.7 usuario - rol: roles asignados a un usuario.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuario_rol` (
  `idusuario_rol`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idusuario`                 BIGINT UNSIGNED NOT NULL,
  `idrol`                     BIGINT UNSIGNED NOT NULL,
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idusuario_rol`),
  UNIQUE KEY `uq_usuario_rol` (`idusuario`, `idrol`),
  KEY `idx_usuario_rol_rol` (`idrol`),
  CONSTRAINT `fk_usuario_rol_usuario` FOREIGN KEY (`idusuario`)
    REFERENCES `usuarios` (`idusuario`),
  CONSTRAINT `fk_usuario_rol_rol` FOREIGN KEY (`idrol`)
    REFERENCES `roles` (`idrol`),
  CONSTRAINT `chk_usuario_rol_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.9 password_historial: hashes de contraseñas anteriores (no repetición).
-- La poda de registros antiguos es baja lógica (eliminado = 1).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `password_historial` (
  `idpassword_historial`      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idusuario`                 BIGINT UNSIGNED NOT NULL,
  `password_hash`             VARCHAR(255)    NOT NULL,
  `fecha_cambio`              DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idpassword_historial`),
  KEY `idx_password_historial_usuario` (`idusuario`, `fecha_cambio`),
  CONSTRAINT `fk_password_historial_usuario` FOREIGN KEY (`idusuario`)
    REFERENCES `usuarios` (`idusuario`),
  CONSTRAINT `chk_password_historial_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.10 seguridad_parametros: política de contraseñas, tokens y 2FA.
-- Una fila por parámetro (modelo clave/valor) o fila única; aquí, fila única.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `seguridad_parametros` (
  `idseguridad_parametro`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `password_largo_minimo`                 INT             NOT NULL DEFAULT 8,
  `password_largo_maximo`                 INT             NULL,
  `password_duracion_dias`                INT             NOT NULL DEFAULT 0,
  `password_historial`                    INT             NOT NULL DEFAULT 0,
  `intentos_maximos`                      INT             NOT NULL DEFAULT 5,
  `token_vigencia_minutos`                INT             NULL DEFAULT 60,
  `sesion_vigencia_minutos`               INT             NULL DEFAULT 480,
  `doble_factor_exigido`                  TINYINT(1)      NOT NULL DEFAULT 0,
  `doble_factor_codigo_vigencia_segundos` INT             NULL DEFAULT 30,
  `doble_factor_codigos_recuperacion`     INT             NULL DEFAULT 10,
  `activo`                                TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                             TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`               BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`              DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`                 BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`                DATETIME(3)     NULL,
  PRIMARY KEY (`idseguridad_parametro`),
  CONSTRAINT `chk_seguridad_parametros_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.11 usuario_token: tokens de un solo uso (activación/recuperación).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuario_token` (
  `idusuario_token`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idusuario`                 BIGINT UNSIGNED NOT NULL,
  `token_hash`                VARCHAR(255)    NOT NULL,
  `proposito`                 VARCHAR(30)     NOT NULL,
  `fecha_emision`             DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `fecha_expiracion`          DATETIME(3)     NOT NULL,
  `usado`                     TINYINT(1)      NOT NULL DEFAULT 0,
  `fecha_uso`                 DATETIME(3)     NULL,
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idusuario_token`),
  KEY `idx_usuario_token_usuario` (`idusuario`, `proposito`, `usado`),
  CONSTRAINT `fk_usuario_token_usuario` FOREIGN KEY (`idusuario`)
    REFERENCES `usuarios` (`idusuario`),
  CONSTRAINT `chk_usuario_token_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.12 usuario_2fa: configuración del segundo factor (TOTP) por usuario.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuario_2fa` (
  `idusuario_2fa`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idusuario`                 BIGINT UNSIGNED NOT NULL,
  `secreto`                   VARCHAR(255)    NOT NULL,
  `habilitado`                TINYINT(1)      NOT NULL DEFAULT 0,
  `fecha_activacion`          DATETIME(3)     NULL,
  `fecha_desactivacion`       DATETIME(3)     NULL,
  `ultimo_contador`           BIGINT          NULL,
  `activo`                    TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                 TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`   BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`     BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`    DATETIME(3)     NULL,
  PRIMARY KEY (`idusuario_2fa`),
  UNIQUE KEY `uq_usuario_2fa_usuario` (`idusuario`),
  CONSTRAINT `fk_usuario_2fa_usuario` FOREIGN KEY (`idusuario`)
    REFERENCES `usuarios` (`idusuario`),
  CONSTRAINT `chk_usuario_2fa_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.13 usuario_2fa_codigo_recuperacion: códigos de recuperación (hasheados).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuario_2fa_codigo_recuperacion` (
  `idusuario_2fa_codigo_recuperacion` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idusuario`                         BIGINT UNSIGNED NOT NULL,
  `codigo_hash`                       VARCHAR(255)    NOT NULL,
  `usado`                             TINYINT(1)      NOT NULL DEFAULT 0,
  `fecha_uso`                         DATETIME(3)     NULL,
  `activo`                            TINYINT(1)      NOT NULL DEFAULT 1,
  `eliminado`                         TINYINT(1)      NOT NULL DEFAULT 0,
  `idusuario_actualizacion`           BIGINT UNSIGNED NOT NULL,
  `fecha_hora_actualizacion`          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `idusuario_eliminacion`             BIGINT UNSIGNED NULL,
  `fecha_hora_eliminacion`            DATETIME(3)     NULL,
  PRIMARY KEY (`idusuario_2fa_codigo_recuperacion`),
  KEY `idx_usuario_2fa_codigo_usuario` (`idusuario`, `usado`),
  CONSTRAINT `fk_usuario_2fa_codigo_usuario` FOREIGN KEY (`idusuario`)
    REFERENCES `usuarios` (`idusuario`),
  CONSTRAINT `chk_usuario_2fa_codigo_eliminado` CHECK (
    (`eliminado` = 0 AND `idusuario_eliminacion` IS NULL AND `fecha_hora_eliminacion` IS NULL)
    OR
    (`eliminado` = 1 AND `idusuario_eliminacion` IS NOT NULL AND `fecha_hora_eliminacion` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.14 usuario_acceso_log: eventos de acceso (auditoría, solo-anexado).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuario_acceso_log` (
  `idusuario_acceso_log`      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idusuario`                 BIGINT UNSIGNED NULL,
  `usuario_login_intento`     VARCHAR(80)     NULL,
  `evento`                    VARCHAR(40)     NOT NULL,
  `motivo`                    VARCHAR(255)    NULL,
  `ip`                        VARCHAR(45)     NULL,
  `agente`                    VARCHAR(255)    NULL,
  `fecha_hora`                DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`idusuario_acceso_log`),
  KEY `idx_usuario_acceso_log_usuario` (`idusuario`, `fecha_hora`),
  KEY `idx_usuario_acceso_log_evento` (`evento`, `fecha_hora`),
  CONSTRAINT `fk_usuario_acceso_log_usuario` FOREIGN KEY (`idusuario`)
    REFERENCES `usuarios` (`idusuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.15 opcion_uso_log: uso de opciones (auditoría funcional, solo-anexado).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `opcion_uso_log` (
  `idopcion_uso_log`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idusuario`                 BIGINT UNSIGNED NOT NULL,
  `idopcion`                  BIGINT UNSIGNED NOT NULL,
  `metodo`                    VARCHAR(10)     NOT NULL,
  `ruta`                      VARCHAR(255)    NOT NULL,
  `parametros`                VARCHAR(1000)   NULL,
  `resultado`                 VARCHAR(20)     NOT NULL,
  `codigo_http`               INT             NULL,
  `duracion_ms`               INT             NULL,
  `fecha_hora`                DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`idopcion_uso_log`),
  KEY `idx_opcion_uso_log_usuario` (`idusuario`, `fecha_hora`),
  KEY `idx_opcion_uso_log_opcion` (`idopcion`, `fecha_hora`),
  CONSTRAINT `fk_opcion_uso_log_usuario` FOREIGN KEY (`idusuario`)
    REFERENCES `usuarios` (`idusuario`),
  CONSTRAINT `fk_opcion_uso_log_opcion` FOREIGN KEY (`idopcion`)
    REFERENCES `opciones` (`idopcion`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4.7 (base-de-datos) bitacora: cambios de datos (solo-anexado, sin columnas
-- estándar). Centralizada en app_db.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bitacora` (
  `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `idusuario`         BIGINT UNSIGNED NOT NULL,
  `fecha_hora`        DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `tabla_afectada`    VARCHAR(150)    NOT NULL,
  `idregistro`        BIGINT UNSIGNED NULL,
  `tipo_accion`       VARCHAR(10)     NOT NULL,
  `datos_antes`       JSON            NULL,
  `datos_despues`     JSON            NULL,
  PRIMARY KEY (`id`),
  KEY `idx_bitacora_usuario` (`idusuario`),
  KEY `idx_bitacora_fecha` (`fecha_hora`),
  KEY `idx_bitacora_tabla` (`tabla_afectada`, `idregistro`),
  KEY `idx_bitacora_accion` (`tipo_accion`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Datos iniciales mínimos (idempotentes).
-- ---------------------------------------------------------------------------

-- Fila de configuración de seguridad con valores por defecto (usuario sistema id 0).
INSERT INTO `seguridad_parametros` (`idusuario_actualizacion`)
SELECT 0
WHERE NOT EXISTS (SELECT 1 FROM `seguridad_parametros`);

-- Aplicación base.
INSERT INTO `app` (`app_nombre`, `idusuario_actualizacion`)
SELECT 'pr', 0
WHERE NOT EXISTS (SELECT 1 FROM `app`);
