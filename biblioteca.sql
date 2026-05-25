-- ============================================================
-- SISTEMA DE GESTIÓN DE BIBLIOTECA UNIVERSITARIA
-- Base de Datos en PostgreSQL
-- Normalización: 1FN, 2FN, 3FN
-- ============================================================
-- Autor: Actividad Académica - Bases de Datos
-- Motor: PostgreSQL 15+
-- ============================================================

-- Eliminar base de datos si existe (para reinicio limpio)
-- DROP DATABASE IF EXISTS biblioteca_universitaria;
-- CREATE DATABASE biblioteca_universitaria;

-- ============================================================
-- DDL: DEFINICIÓN DE ESTRUCTURA
-- ============================================================

-- 1. TABLA: categorias
-- Normalización: separa la categoría del libro (evita redundancia en 3FN)
CREATE TABLE IF NOT EXISTS categorias (
    id_categoria    SERIAL PRIMARY KEY,
    nombre          VARCHAR(80)  NOT NULL UNIQUE,
    descripcion     TEXT,
    fecha_creacion  DATE         NOT NULL DEFAULT CURRENT_DATE
);

-- 2. TABLA: editoriales
-- Normalización: datos de editorial desacoplados del libro (2FN/3FN)
CREATE TABLE IF NOT EXISTS editoriales (
    id_editorial    SERIAL PRIMARY KEY,
    nombre          VARCHAR(120) NOT NULL,
    pais_origen     VARCHAR(60)  NOT NULL,
    sitio_web       VARCHAR(200),
    telefono        VARCHAR(20),
    email_contacto  VARCHAR(100)
);

-- 3. TABLA: autores
-- Normalización: entidad propia evita grupos repetitivos (1FN)
CREATE TABLE IF NOT EXISTS autores (
    id_autor        SERIAL PRIMARY KEY,
    nombres         VARCHAR(80)  NOT NULL,
    apellidos       VARCHAR(80)  NOT NULL,
    nacionalidad    VARCHAR(60),
    fecha_nacimiento DATE,
    biografia       TEXT,
    CONSTRAINT uq_autor UNIQUE (nombres, apellidos, fecha_nacimiento)
);

-- 4. TABLA: libros
-- Normalización: atributos solo dependientes de la PK (3FN)
CREATE TABLE IF NOT EXISTS libros (
    id_libro        SERIAL PRIMARY KEY,
    isbn            VARCHAR(17)  NOT NULL UNIQUE,
    titulo          VARCHAR(250) NOT NULL,
    subtitulo       VARCHAR(250),
    anio_publicacion SMALLINT    NOT NULL,
    edicion         SMALLINT     NOT NULL DEFAULT 1,
    num_paginas     SMALLINT,
    idioma          VARCHAR(30)  NOT NULL DEFAULT 'Español',
    id_categoria    INT          NOT NULL,
    id_editorial    INT          NOT NULL,
    CONSTRAINT fk_libro_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    CONSTRAINT fk_libro_editorial FOREIGN KEY (id_editorial) REFERENCES editoriales(id_editorial),
    CONSTRAINT chk_anio CHECK (anio_publicacion BETWEEN 1450 AND EXTRACT(YEAR FROM CURRENT_DATE)),
    CONSTRAINT chk_paginas CHECK (num_paginas > 0)
);

-- 5. TABLA: libro_autores (tabla de unión N:M)
-- Normalización: resuelve relación muchos a muchos entre libros y autores (1FN)
CREATE TABLE IF NOT EXISTS libro_autores (
    id_libro        INT NOT NULL,
    id_autor        INT NOT NULL,
    orden_autor     SMALLINT NOT NULL DEFAULT 1,
    PRIMARY KEY (id_libro, id_autor),
    CONSTRAINT fk_la_libro FOREIGN KEY (id_libro) REFERENCES libros(id_libro) ON DELETE CASCADE,
    CONSTRAINT fk_la_autor FOREIGN KEY (id_autor) REFERENCES autores(id_autor) ON DELETE CASCADE
);

-- 6. TABLA: ejemplares
-- Normalización: estado físico separado del registro bibliográfico (2FN)
CREATE TABLE IF NOT EXISTS ejemplares (
    id_ejemplar     SERIAL PRIMARY KEY,
    id_libro        INT          NOT NULL,
    codigo_barras   VARCHAR(30)  NOT NULL UNIQUE,
    ubicacion       VARCHAR(50)  NOT NULL,  -- ej: "Sala A, Estante 3, Nivel 2"
    estado          VARCHAR(20)  NOT NULL DEFAULT 'disponible',
    fecha_adquisicion DATE       NOT NULL DEFAULT CURRENT_DATE,
    condicion       VARCHAR(20)  NOT NULL DEFAULT 'bueno',
    CONSTRAINT fk_ej_libro FOREIGN KEY (id_libro) REFERENCES libros(id_libro),
    CONSTRAINT chk_estado CHECK (estado IN ('disponible','prestado','reservado','baja','reparacion')),
    CONSTRAINT chk_condicion CHECK (condicion IN ('excelente','bueno','regular','deteriorado'))
);

-- 7. TABLA: facultades
-- Normalización: entidad propia desacoplada de usuarios (3FN)
CREATE TABLE IF NOT EXISTS facultades (
    id_facultad     SERIAL PRIMARY KEY,
    nombre          VARCHAR(120) NOT NULL UNIQUE,
    codigo          VARCHAR(10)  NOT NULL UNIQUE,
    dean            VARCHAR(120),
    fecha_fundacion DATE
);

-- 8. TABLA: usuarios
-- Normalización: datos de usuario sin campos compuestos ni multivaluados (1FN, 3FN)
CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario      SERIAL PRIMARY KEY,
    numero_carnet   VARCHAR(20)  NOT NULL UNIQUE,
    nombres         VARCHAR(80)  NOT NULL,
    apellidos       VARCHAR(80)  NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    telefono        VARCHAR(20),
    tipo_usuario    VARCHAR(20)  NOT NULL DEFAULT 'estudiante',
    id_facultad     INT,
    fecha_registro  DATE         NOT NULL DEFAULT CURRENT_DATE,
    activo          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_usuario_facultad FOREIGN KEY (id_facultad) REFERENCES facultades(id_facultad),
    CONSTRAINT chk_tipo CHECK (tipo_usuario IN ('estudiante','docente','investigador','administrativo')),
    CONSTRAINT chk_email CHECK (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$')
);

-- 9. TABLA: prestamos
-- Normalización: registro transaccional con FK a ejemplar y usuario (3FN)
CREATE TABLE IF NOT EXISTS prestamos (
    id_prestamo     SERIAL PRIMARY KEY,
    id_ejemplar     INT          NOT NULL,
    id_usuario      INT          NOT NULL,
    fecha_prestamo  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_devolucion_prevista DATE NOT NULL,
    fecha_devolucion_real     TIMESTAMP,
    estado_prestamo VARCHAR(20)  NOT NULL DEFAULT 'activo',
    observaciones   TEXT,
    CONSTRAINT fk_prestamo_ejemplar FOREIGN KEY (id_ejemplar) REFERENCES ejemplares(id_ejemplar),
    CONSTRAINT fk_prestamo_usuario  FOREIGN KEY (id_usuario)  REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_estado_prestamo  CHECK (estado_prestamo IN ('activo','devuelto','vencido','renovado')),
    CONSTRAINT chk_fechas CHECK (fecha_devolucion_prevista > fecha_prestamo::date)
);

-- 10. TABLA: multas
-- Normalización: entidad separada, evita dependencia transitiva en préstamos (3FN)
CREATE TABLE IF NOT EXISTS multas (
    id_multa        SERIAL PRIMARY KEY,
    id_prestamo     INT          NOT NULL UNIQUE,
    monto           NUMERIC(8,2) NOT NULL,
    motivo          VARCHAR(60)  NOT NULL,
    fecha_generada  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_pagada    TIMESTAMP,
    estado_multa    VARCHAR(20)  NOT NULL DEFAULT 'pendiente',
    CONSTRAINT fk_multa_prestamo FOREIGN KEY (id_prestamo) REFERENCES prestamos(id_prestamo),
    CONSTRAINT chk_monto CHECK (monto > 0),
    CONSTRAINT chk_motivo CHECK (motivo IN ('devolucion_tardia','dano','perdida','otro')),
    CONSTRAINT chk_estado_multa CHECK (estado_multa IN ('pendiente','pagada','exonerada'))
);

-- 11. TABLA: reservas
-- Normalización: entidad transaccional diferente del préstamo (3FN)
CREATE TABLE IF NOT EXISTS reservas (
    id_reserva      SERIAL PRIMARY KEY,
    id_libro        INT          NOT NULL,
    id_usuario      INT          NOT NULL,
    fecha_reserva   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion DATE        NOT NULL,
    estado_reserva  VARCHAR(20)  NOT NULL DEFAULT 'activa',
    CONSTRAINT fk_reserva_libro    FOREIGN KEY (id_libro)   REFERENCES libros(id_libro),
    CONSTRAINT fk_reserva_usuario  FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_estado_reserva  CHECK (estado_reserva IN ('activa','cumplida','cancelada','expirada')),
    CONSTRAINT chk_exp CHECK (fecha_expiracion > fecha_reserva::date)
);

-- ============================================================
-- ÍNDICES para optimización de consultas frecuentes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_libros_titulo      ON libros(titulo);
CREATE INDEX IF NOT EXISTS idx_libros_isbn        ON libros(isbn);
CREATE INDEX IF NOT EXISTS idx_ejemplares_estado  ON ejemplares(estado);
CREATE INDEX IF NOT EXISTS idx_prestamos_usuario  ON prestamos(id_usuario);
CREATE INDEX IF NOT EXISTS idx_prestamos_estado   ON prestamos(estado_prestamo);
CREATE INDEX IF NOT EXISTS idx_usuarios_carnet    ON usuarios(numero_carnet);
CREATE INDEX IF NOT EXISTS idx_multas_estado      ON multas(estado_multa);

-- ============================================================
-- DML: DATOS INICIALES
-- ============================================================

-- ---- CATEGORÍAS ----
INSERT INTO categorias (nombre, descripcion) VALUES
('Ingeniería de Software',     'Desarrollo, diseño y gestión de sistemas de software'),
('Bases de Datos',             'Modelado, diseño y administración de bases de datos'),
('Redes y Comunicaciones',     'Protocolos, arquitecturas y sistemas de red'),
('Inteligencia Artificial',    'Aprendizaje automático, redes neuronales y IA'),
('Matemáticas Aplicadas',      'Cálculo, álgebra lineal, estadística y probabilidad'),
('Ciencias de la Computación', 'Algoritmos, estructuras de datos y teoría computacional'),
('Administración de Empresas', 'Gestión organizacional, estrategia y finanzas'),
('Derecho',                    'Ciencias jurídicas y legislación'),
('Medicina General',           'Ciencias médicas básicas y clínicas'),
('Literatura Hispanoamericana','Narrativa, poesía y ensayo en lengua española')
ON CONFLICT DO NOTHING;

-- ---- EDITORIALES ----
INSERT INTO editoriales (nombre, pais_origen, sitio_web, email_contacto) VALUES
('McGraw-Hill Education',   'Estados Unidos', 'https://www.mheducation.com',   'info@mheducation.com'),
('Pearson Education',       'Reino Unido',    'https://www.pearson.com',        'info@pearson.com'),
('O''Reilly Media',         'Estados Unidos', 'https://www.oreilly.com',        'orders@oreilly.com'),
('Alfaomega Grupo Editor',  'México',         'https://www.alfaomega.com.mx',   'info@alfaomega.com.mx'),
('Addison-Wesley',          'Estados Unidos', 'https://www.informit.com',       'support@informit.com'),
('Springer Nature',         'Alemania',       'https://www.springer.com',       'info@springer.com'),
('Cambridge University',    'Reino Unido',    'https://www.cambridge.org',      'info@cambridge.org'),
('Editorial Anaya',         'España',         'https://www.anayamultimedia.es', 'info@anaya.es'),
('Packt Publishing',        'Reino Unido',    'https://www.packtpub.com',       'info@packtpub.com'),
('MIT Press',               'Estados Unidos', 'https://mitpress.mit.edu',       'info@mitpress.mit.edu')
ON CONFLICT DO NOTHING;

-- ---- AUTORES ----
INSERT INTO autores (nombres, apellidos, nacionalidad, fecha_nacimiento, biografia) VALUES
('Abraham',   'Silberschatz',  'Estadounidense', '1952-01-01', 'Profesor en Yale, coautor de los libros de SO y BD más usados en universidades.'),
('Henry F.',  'Korth',         'Estadounidense', '1953-03-15', 'Investigador y académico especializado en sistemas de bases de datos.'),
('S.',        'Sudarshan',     'Indio',          '1965-06-20', 'Profesor en IIT Bombay, especialista en bases de datos y consultas.'),
('Robert C.', 'Martin',        'Estadounidense', '1952-12-05', 'Ingeniero de software conocido como "Uncle Bob", creador de los principios SOLID.'),
('Thomas H.', 'Cormen',        'Estadounidense', '1956-09-02', 'Profesor en Dartmouth, coautor del libro de algoritmos más usado en el mundo.'),
('Charles E.','Leiserson',     'Estadounidense', '1953-11-10', 'Científico del MIT, pionero en computación paralela y algoritmos.'),
('Andrew S.', 'Tanenbaum',     'Estadounidense', '1944-03-16', 'Profesor en Vrije Universiteit, autor de textos fundamentales en SO y redes.'),
('Ian',       'Sommerville',   'Británico',      '1951-07-01', 'Investigador en ingeniería de software, autor del libro de texto global más usado.'),
('Jeffrey D.','Ullman',        'Estadounidense', '1942-11-22', 'Pionero en teoría de compiladores y bases de datos en Stanford.'),
('Stuart J.', 'Russell',       'Británico',      '1962-05-01', 'Profesor en UC Berkeley, coautor del libro de IA más utilizado mundialmente.'),
('Peter',     'Norvig',        'Estadounidense', '1956-12-14', 'Director de Investigación en Google, coautor de "Artificial Intelligence: A Modern Approach".'),
('Ramez',     'Elmasri',       'Sirio',          '1950-04-10', 'Profesor en UT Arlington, coautor del libro fundamental de bases de datos.'),
('Wirth',     'Niklaus',       'Suizo',          '1934-02-15', 'Creador del lenguaje Pascal, Premio Turing 1984.'),
('Edsger W.', 'Dijkstra',      'Neerlandés',     '1930-05-11', 'Pionero de CS, creador del algoritmo de caminos más cortos, Premio Turing 1972.'),
('Donald E.', 'Knuth',         'Estadounidense', '1938-01-10', 'Padre del análisis de algoritmos, creador de TeX, Premio Turing 1974.')
ON CONFLICT DO NOTHING;

-- ---- FACULTADES ----
INSERT INTO facultades (nombre, codigo, dean, fecha_fundacion) VALUES
('Ingeniería en Computación e Informática',  'ICI',  'Dr. Carlos Mendoza López',    '1985-03-01'),
('Administración de Empresas',               'ADE',  'Dra. María Fernández Torres',  '1972-09-15'),
('Ciencias Jurídicas y Sociales',            'CJS',  'Dr. Roberto Silva Ramírez',    '1968-04-20'),
('Ciencias de la Salud',                     'CSA',  'Dra. Ana Patricia Cruz Molina', '1990-07-10'),
('Humanidades y Artes',                      'HUA',  'Dr. Jorge Martínez Fuentes',   '1975-02-28')
ON CONFLICT DO NOTHING;

-- ---- LIBROS ----
INSERT INTO libros (isbn, titulo, anio_publicacion, edicion, num_paginas, idioma, id_categoria, id_editorial) VALUES
('978-0-07-352332-3', 'Fundamentos de Bases de Datos',                        2019, 7, 1376, 'Español',  2,  1),
('978-0-13-235088-4', 'Clean Code: A Handbook of Agile Software Craftsmanship',2008, 1,  431, 'Inglés',   1,  2),
('978-0-262-03384-8', 'Introduction to Algorithms',                           2022, 4, 1312, 'Inglés',   6,  10),
('978-607-538-317-3', 'Ingeniería de Software',                                2016, 10, 792, 'Español',  1,  4),
('978-0-13-468599-1', 'Computer Networks',                                     2021, 6,  912, 'Inglés',   3,  2),
('978-0-13-110362-7', 'The C Programming Language',                            1988, 2,  274, 'Inglés',   6,  2),
('978-0-13-235088-5', 'Artificial Intelligence: A Modern Approach',            2020, 4, 1132, 'Inglés',   4,  2),
('978-3-540-43595-7', 'Database System Concepts',                              2020, 7, 1376, 'Inglés',   2,  6),
('978-0-521-68052-8', 'Modern Operating Systems',                              2014, 4, 1080, 'Inglés',   6,  7),
('978-0-201-63361-0', 'Design Patterns: Elements of Reusable Object-Oriented Software', 1994, 1, 395, 'Inglés', 1, 5),
('978-0-13-110362-8', 'Álgebra Lineal con Aplicaciones',                       2018, 9,  644, 'Español',  5,  1),
('978-0-07-476143-7', 'Cálculo: Trascendentes Tempranas',                      2017, 8, 1368, 'Español',  5,  1),
('978-1-449-35768-1', 'Learning Python',                                       2013, 5, 1594, 'Inglés',   6,  3),
('978-1-491-95016-0', 'Python Data Science Handbook',                          2016, 1,  548, 'Inglés',   4,  3),
('978-0-13-374827-7', 'Sistemas Operativos Modernos',                          2015, 4,  1136,'Español',  6,  2)
ON CONFLICT DO NOTHING;

-- ---- LIBRO_AUTORES (relación N:M) ----
INSERT INTO libro_autores (id_libro, id_autor, orden_autor) VALUES
(1, 1, 1), (1, 2, 2), (1, 3, 3),   -- Fundamentos BD: Silberschatz, Korth, Sudarshan
(2, 4, 1),                           -- Clean Code: Robert C. Martin
(3, 5, 1), (3, 6, 2),               -- Algorithms: Cormen, Leiserson
(4, 8, 1),                           -- Ingeniería SW: Sommerville
(5, 7, 1),                           -- Computer Networks: Tanenbaum
(7, 10, 1), (7, 11, 2),             -- AI: Russell, Norvig
(8, 1, 1), (8, 2, 2), (8, 3, 3),   -- Database System Concepts: mismos autores
(9, 7, 1),                           -- Modern OS: Tanenbaum
(10, 14, 1),                         -- Design Patterns: Dijkstra (ficción académica)
(13, 15, 1),                         -- Learning Python: Knuth (ficción académica)
(14, 10, 1),                         -- Python DS: Russell (ficción académica)
(6, 15, 1)                           -- C Language: Knuth (ficción académica)
ON CONFLICT DO NOTHING;

-- ---- EJEMPLARES ----
INSERT INTO ejemplares (id_libro, codigo_barras, ubicacion, estado, fecha_adquisicion, condicion) VALUES
(1,  'LIB-001-A', 'Sala A, Estante 1, Nivel 1', 'disponible', '2021-02-10', 'bueno'),
(1,  'LIB-001-B', 'Sala A, Estante 1, Nivel 2', 'prestado',   '2021-02-10', 'bueno'),
(1,  'LIB-001-C', 'Sala A, Estante 1, Nivel 3', 'disponible', '2022-08-15', 'excelente'),
(2,  'LIB-002-A', 'Sala B, Estante 3, Nivel 1', 'disponible', '2020-05-20', 'bueno'),
(2,  'LIB-002-B', 'Sala B, Estante 3, Nivel 2', 'reservado',  '2020-05-20', 'regular'),
(3,  'LIB-003-A', 'Sala A, Estante 5, Nivel 1', 'disponible', '2023-01-12', 'excelente'),
(3,  'LIB-003-B', 'Sala A, Estante 5, Nivel 2', 'prestado',   '2023-01-12', 'bueno'),
(4,  'LIB-004-A', 'Sala C, Estante 2, Nivel 1', 'disponible', '2019-09-01', 'bueno'),
(4,  'LIB-004-B', 'Sala C, Estante 2, Nivel 2', 'disponible', '2021-03-14', 'excelente'),
(5,  'LIB-005-A', 'Sala B, Estante 7, Nivel 1', 'disponible', '2022-11-30', 'bueno'),
(6,  'LIB-006-A', 'Sala D, Estante 1, Nivel 1', 'disponible', '2015-06-08', 'regular'),
(7,  'LIB-007-A', 'Sala A, Estante 9, Nivel 1', 'prestado',   '2021-07-22', 'bueno'),
(7,  'LIB-007-B', 'Sala A, Estante 9, Nivel 2', 'disponible', '2021-07-22', 'excelente'),
(8,  'LIB-008-A', 'Sala A, Estante 1, Nivel 4', 'disponible', '2022-04-05', 'bueno'),
(9,  'LIB-009-A', 'Sala C, Estante 4, Nivel 1', 'baja',       '2010-01-20', 'deteriorado'),
(10, 'LIB-010-A', 'Sala B, Estante 5, Nivel 1', 'disponible', '2018-11-11', 'bueno'),
(11, 'LIB-011-A', 'Sala D, Estante 2, Nivel 1', 'disponible', '2020-02-28', 'excelente'),
(12, 'LIB-012-A', 'Sala D, Estante 3, Nivel 1', 'disponible', '2019-08-19', 'bueno'),
(13, 'LIB-013-A', 'Sala B, Estante 8, Nivel 1', 'disponible', '2015-03-03', 'regular'),
(14, 'LIB-014-A', 'Sala A, Estante 11, Nivel 1','disponible', '2017-09-07', 'bueno')
ON CONFLICT DO NOTHING;

-- ---- USUARIOS ----
INSERT INTO usuarios (numero_carnet, nombres, apellidos, email, telefono, tipo_usuario, id_facultad) VALUES
('2021-ICI-001', 'Carlos Andrés',  'González Mejía',    'cagonzalez@universidad.edu.sv',  '7777-1111', 'estudiante',    1),
('2020-ICI-045', 'María José',     'Hernández Flores',  'mjhernandez@universidad.edu.sv', '7777-2222', 'estudiante',    1),
('2022-ICI-012', 'Roberto',        'Martínez López',    'rmartinez@universidad.edu.sv',   '7777-3333', 'estudiante',    1),
('2019-ADE-031', 'Ana Lucía',      'Torres Ramos',      'altorres@universidad.edu.sv',    '7777-4444', 'estudiante',    2),
('2021-ADE-018', 'Diego Alejandro','Pérez Díaz',        'daperez@universidad.edu.sv',     '7777-5555', 'estudiante',    2),
('2018-CJS-007', 'Sofía Isabel',   'Ramírez Cruz',      'siramrez@universidad.edu.sv',    '7777-6666', 'estudiante',    3),
('2020-CSA-055', 'Luis Fernando',  'Chávez Portillo',   'lfchavez@universidad.edu.sv',    '7777-7777', 'estudiante',    4),
('2021-HUA-023', 'Valentina',      'Morales Sánchez',   'vmorales@universidad.edu.sv',    '7777-8888', 'estudiante',    5),
('DOC-ICI-001',  'Dr. Jorge',      'Fuentes Andrade',   'jfuentes@universidad.edu.sv',    '2222-1111', 'docente',       1),
('DOC-ICI-002',  'Dra. Patricia',  'Villanueva Herrera', 'pvillanueva@universidad.edu.sv', '2222-2222', 'docente',       1),
('INV-001',      'MSc. Edwin',     'Galindo Marroquín', 'egalindo@universidad.edu.sv',    '2222-3333', 'investigador',  1),
('ADM-001',      'Claudia María',  'Reyes Bonilla',     'creyes@universidad.edu.sv',      '2222-4444', 'administrativo',NULL)
ON CONFLICT DO NOTHING;

-- ---- PRÉSTAMOS ----
INSERT INTO prestamos (id_ejemplar, id_usuario, fecha_prestamo, fecha_devolucion_prevista, fecha_devolucion_real, estado_prestamo, observaciones) VALUES
(2,  1, '2024-10-01 09:00:00', '2024-10-15', '2024-10-14 14:30:00', 'devuelto',   'Devuelto en buen estado'),
(7,  2, '2024-10-05 10:15:00', '2024-10-19', NULL,                  'activo',     'Préstamo vigente'),
(12, 3, '2024-09-20 11:00:00', '2024-10-04', NULL,                  'vencido',    'No se ha devuelto - vencido'),
(2,  4, '2024-10-10 08:30:00', '2024-10-24', '2024-10-23 16:00:00', 'devuelto',   'Renovado una vez antes de devolver'),
(7,  5, '2024-10-12 14:00:00', '2024-10-26', NULL,                  'activo',     NULL),
(3,  9, '2024-10-08 09:30:00', '2024-11-08', NULL,                  'activo',     'Docente - plazo extendido 30 días'),
(4,  10,'2024-09-15 10:00:00', '2024-10-15', '2024-10-20 09:00:00', 'devuelto',   'Devuelto con 5 días de retraso'),
(6,  11,'2024-10-01 11:30:00', '2024-11-01', NULL,                  'activo',     'Investigador en proyecto'),
(8,  1, '2024-10-16 09:00:00', '2024-10-30', NULL,                  'activo',     NULL),
(10, 6, '2024-09-25 15:00:00', '2024-10-09', '2024-10-09 10:00:00', 'devuelto',   'A tiempo'),
(11, 7, '2024-10-03 08:00:00', '2024-10-17', '2024-10-17 12:30:00', 'devuelto',   'A tiempo'),
(16, 8, '2024-10-07 13:00:00', '2024-10-21', '2024-10-25 11:00:00', 'devuelto',   'Devuelto con 4 días de retraso')
ON CONFLICT DO NOTHING;

-- ---- MULTAS ----
INSERT INTO multas (id_prestamo, monto, motivo, fecha_generada, fecha_pagada, estado_multa) VALUES
(3,  15.00, 'devolucion_tardia', '2024-10-05 08:00:00', NULL,                    'pendiente'),
(7,   5.00, 'devolucion_tardia', '2024-10-21 08:00:00', '2024-10-22 10:00:00',   'pagada'),
(12,  8.00, 'devolucion_tardia', '2024-10-26 08:00:00', NULL,                    'pendiente')
ON CONFLICT DO NOTHING;

-- ---- RESERVAS ----
INSERT INTO reservas (id_libro, id_usuario, fecha_reserva, fecha_expiracion, estado_reserva) VALUES
(1,  6, '2024-10-10 09:00:00', '2024-10-17', 'activa'),
(2,  3, '2024-10-11 11:00:00', '2024-10-18', 'activa'),
(7,  4, '2024-10-09 14:30:00', '2024-10-16', 'cumplida'),
(3,  7, '2024-09-28 10:00:00', '2024-10-05', 'expirada'),
(5,  1, '2024-10-13 08:30:00', '2024-10-20', 'activa'),
(10, 2, '2024-10-12 15:00:00', '2024-10-19', 'activa'),
(4,  8, '2024-10-05 09:00:00', '2024-10-12', 'cancelada'),
(8, 11, '2024-10-14 11:30:00', '2024-10-21', 'activa'),
(12, 5, '2024-10-08 10:00:00', '2024-10-15', 'expirada'),
(6,  9, '2024-10-15 16:00:00', '2024-10-22', 'activa')
ON CONFLICT DO NOTHING;

-- ============================================================
-- VISTAS ÚTILES
-- ============================================================

-- Vista: catálogo completo de libros con autores y categoría
CREATE OR REPLACE VIEW v_catalogo_libros AS
SELECT
    l.id_libro,
    l.isbn,
    l.titulo,
    l.anio_publicacion,
    l.edicion,
    l.idioma,
    c.nombre        AS categoria,
    e.nombre        AS editorial,
    STRING_AGG(a.nombres || ' ' || a.apellidos, ', ' ORDER BY la.orden_autor) AS autores,
    COUNT(DISTINCT ej.id_ejemplar) FILTER (WHERE ej.estado = 'disponible') AS ejemplares_disponibles,
    COUNT(DISTINCT ej.id_ejemplar)                                          AS total_ejemplares
FROM libros l
JOIN categorias   c  ON l.id_categoria  = c.id_categoria
JOIN editoriales  e  ON l.id_editorial  = e.id_editorial
LEFT JOIN libro_autores la ON l.id_libro = la.id_libro
LEFT JOIN autores a        ON la.id_autor = a.id_autor
LEFT JOIN ejemplares ej    ON l.id_libro = ej.id_libro
GROUP BY l.id_libro, l.isbn, l.titulo, l.anio_publicacion, l.edicion, l.idioma, c.nombre, e.nombre;

-- Vista: préstamos activos con información de usuario y libro
CREATE OR REPLACE VIEW v_prestamos_activos AS
SELECT
    p.id_prestamo,
    u.numero_carnet,
    u.nombres || ' ' || u.apellidos AS usuario,
    u.tipo_usuario,
    l.titulo                         AS libro,
    ej.codigo_barras,
    p.fecha_prestamo::date,
    p.fecha_devolucion_prevista,
    CASE
        WHEN p.fecha_devolucion_prevista < CURRENT_DATE THEN 'VENCIDO'
        WHEN p.fecha_devolucion_prevista = CURRENT_DATE THEN 'VENCE HOY'
        ELSE 'VIGENTE'
    END AS estado_vencimiento,
    (CURRENT_DATE - p.fecha_devolucion_prevista) AS dias_retraso
FROM prestamos p
JOIN usuarios   u  ON p.id_usuario  = u.id_usuario
JOIN ejemplares ej ON p.id_ejemplar = ej.id_ejemplar
JOIN libros     l  ON ej.id_libro   = l.id_libro
WHERE p.estado_prestamo IN ('activo', 'vencido');

-- Vista: usuarios con multas pendientes
CREATE OR REPLACE VIEW v_usuarios_multas_pendientes AS
SELECT
    u.numero_carnet,
    u.nombres || ' ' || u.apellidos AS usuario,
    u.email,
    COUNT(m.id_multa)   AS cantidad_multas,
    SUM(m.monto)        AS total_deuda
FROM multas m
JOIN prestamos p ON m.id_prestamo = p.id_prestamo
JOIN usuarios  u ON p.id_usuario  = u.id_usuario
WHERE m.estado_multa = 'pendiente'
GROUP BY u.id_usuario, u.numero_carnet, u.nombres, u.apellidos, u.email;

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
