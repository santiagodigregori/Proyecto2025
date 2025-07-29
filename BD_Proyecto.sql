-- Crear base de datos
CREATE DATABASE IF NOT EXISTS softrail_db;
USE softrail_db;

-- Tabla Usuario
CREATE TABLE usuario (
    mail VARCHAR(50) PRIMARY KEY,
    contraseña VARCHAR(255) NOT NULL,
    rol ENUM('administrador','cliente','proveedor') NOT NULL,
    documento VARCHAR(20),
    tipo_documento VARCHAR(20)
);

-- Tabla Teléfono
CREATE TABLE telefono (
    mail VARCHAR(50),
    telefono_usuario VARCHAR(15),
    PRIMARY KEY (mail, telefono_usuario),
    FOREIGN KEY (mail) REFERENCES usuario(mail) ON DELETE CASCADE
);

-- Tabla Cliente
CREATE TABLE cliente (
    mail VARCHAR(50) PRIMARY KEY,
    FOREIGN KEY (mail) REFERENCES usuario(mail) ON DELETE CASCADE
);

-- Tabla Proveedor
CREATE TABLE proveedor (
    mail VARCHAR(50) PRIMARY KEY,
    FOREIGN KEY (mail) REFERENCES usuario(mail) ON DELETE CASCADE
);

-- Tabla Administrador
CREATE TABLE administrador (
    mail VARCHAR(50) PRIMARY KEY,
    FOREIGN KEY (mail) REFERENCES usuario(mail) ON DELETE CASCADE
);

-- Tabla Horarios Disponibles Cliente
CREATE TABLE horarios_disp_cliente (
    mail VARCHAR(50),
    fecha_disp DATE,
    hora_ini_disp TIME,
    hora_fin_disp TIME,
    estado BOOLEAN,
    PRIMARY KEY (mail, fecha_disp, hora_ini_disp, hora_fin_disp),
    FOREIGN KEY (mail) REFERENCES cliente(mail) ON DELETE CASCADE
);

-- Tabla Horarios Disponibles Proveedor
CREATE TABLE horarios_disp_prov (
    mail VARCHAR(50),
    fecha_disp DATE,
    hora_ini_disp TIME,
    hora_fin_disp TIME,
    estado BOOLEAN,
    PRIMARY KEY (mail, fecha_disp, hora_ini_disp, hora_fin_disp),
    FOREIGN KEY (mail) REFERENCES proveedor(mail) ON DELETE CASCADE
);

-- Tabla Publicacion
CREATE TABLE publicacion (
    id_pub INT AUTO_INCREMENT PRIMARY KEY,
    categoria VARCHAR(100) NOT NULL
);

-- Tabla Ofrece
CREATE TABLE ofrece (
    id_pub INT,
    mail_proveedor VARCHAR(50),
    descripcion TEXT,
    imagen VARCHAR(255),
    precio DECIMAL(10,2),
    ubicacion VARCHAR(255),
    PRIMARY KEY (id_pub, mail_proveedor),
    FOREIGN KEY (id_pub) REFERENCES publicacion(id_pub) ON DELETE CASCADE,
    FOREIGN KEY (mail_proveedor) REFERENCES proveedor(mail) ON DELETE CASCADE
);

-- Tabla Contrata
CREATE TABLE contrata (
    id_contrata INT AUTO_INCREMENT PRIMARY KEY,
    mail_cliente VARCHAR(50),
    mail_proveedor VARCHAR(50),
    id_pub INT,
    fecha_contrato DATE,
    estado_contrato ENUM('Pendiente','Acordado','Cancelado') DEFAULT 'Pendiente',
    FOREIGN KEY (mail_cliente) REFERENCES cliente(mail) ON DELETE CASCADE,
    FOREIGN KEY (mail_proveedor) REFERENCES proveedor(mail) ON DELETE CASCADE,
    FOREIGN KEY (id_pub) REFERENCES publicacion(id_pub) ON DELETE CASCADE
);

-- Tabla Disponibilidad Contrata
CREATE TABLE disponibilidad_contrata (
    id_contrata INT,
    fecha_solicitada DATE,
    hora_ini_solicitada TIME,
    hora_fin_solicitada TIME,
    estado ENUM('Pendiente','Acordado','Cancelado') DEFAULT 'Pendiente',
    PRIMARY KEY (id_contrata, fecha_solicitada, hora_ini_solicitada, hora_fin_solicitada),
    FOREIGN KEY (id_contrata) REFERENCES contrata(id_contrata) ON DELETE CASCADE
);

-- Tabla Pedido
CREATE TABLE pedido (
    id_ped INT AUTO_INCREMENT PRIMARY KEY,
    id_contrata INT,
    reseña TEXT,
    lugar VARCHAR(255),
    horaPed_ini TIME,
    horaPed_fin TIME,
    fechaPed DATE,
    FOREIGN KEY (id_contrata) REFERENCES contrata(id_contrata) ON DELETE CASCADE
);

-- Tabla Mensaje
CREATE TABLE mensaje (
    id_mensaje INT AUTO_INCREMENT PRIMARY KEY,
    texto TEXT NOT NULL,
    fecha_enviadoM DATETIME NOT NULL,
    mail_emisor VARCHAR(50),
    mail_receptor VARCHAR(50),
    FOREIGN KEY (mail_emisor) REFERENCES usuario(mail) ON DELETE CASCADE,
    FOREIGN KEY (mail_receptor) REFERENCES usuario(mail) ON DELETE CASCADE
);