-- Fixture de desarrollo para probar DataTables con server-side processing.
-- Bórralo cuando tengas tus propios esquemas en dev/sql/schemas.

CREATE TABLE IF NOT EXISTS `demo_usuarios` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nombre`     VARCHAR(120) NOT NULL,
  `email`      VARCHAR(180) NOT NULL,
  `rol`        VARCHAR(40)  NOT NULL DEFAULT 'user',
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_demo_usuarios_email` (`email`),
  KEY `idx_demo_usuarios_rol` (`rol`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `demo_usuarios` (`nombre`, `email`, `rol`)
VALUES
  ('Ana Soto',      'ana@example.com',    'admin'),
  ('Bruno Diaz',    'bruno@example.com',  'user'),
  ('Carla Nunez',   'carla@example.com',  'user'),
  ('Diego Rojas',   'diego@example.com',  'editor'),
  ('Elena Vargas',  'elena@example.com',  'user'),
  ('Felipe Munoz',  'felipe@example.com', 'editor'),
  ('Gabriela Paz',  'gabriela@example.com','user'),
  ('Hector Lara',   'hector@example.com', 'user');
