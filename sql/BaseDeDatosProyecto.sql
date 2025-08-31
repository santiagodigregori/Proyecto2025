create database if not exists AppProyecto;
use AppProyecto;
SET foreign_key_checks = 1;

create table usuario (
mail varchar (50) primary key not null,
rol varchar(20),
documento INT,
tipoDoc varchar (6)
);


create table pedido (
IdPedido INT not null,
fechaP date,
lugarP varchar (50),
reseña varchar (255),
calificacion INT,
horaPini time,
horaPfin time
);


create table servicio (
id_s int primary key AUTO_INCREMENT,
categoria varchar (70),
fechaS date,
horaSini time,
horaSfin time
);


create table ofrece (
mail varchar (50) primary key not null,
id_s int unique not null,
descripcion varchar (255),
imagenO varchar (255),
precio INT,
ubicacion varchar (255)
);

create table proveedor (
mail varchar (50) primary key not null,
FOREIGN KEY (mail) REFERENCES usuario (mail)
);
    
create table cliente (
mail varchar (50) primary key not null,
FOREIGN KEY (mail) REFERENCES usuario(mail)
);
    
create table administrador (
mail varchar (50) primary key not null,
FOREIGN KEY (mail) REFERENCES usuario(mail)
);

create table mensaje (
    idMensaje INT PRIMARY KEY AUTO_INCREMENT,
    mailEmisor VARCHAR(150),
    mailReceptor VARCHAR(150),
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    leido BOOLEAN DEFAULT FALSE,
    fecha_leido DATETIME DEFAULT NULL,
    texto TEXT,
    FOREIGN KEY (mailEmisor) REFERENCES usuario(mail),
    FOREIGN KEY (mailReceptor) REFERENCES usuario(mail)
);

create table telefonos (
mail varchar (50) primary key not null,
telefono INT,
FOREIGN KEY (mail) REFERENCES usuario(mail)
);
