-- ======================================================
-- 1. CREACIÓN DE LA BASE DE DATOS
-- ======================================================

-- DROP DATABASE GestionAeropuerto;

-- DROP DATABASE GestionAeropuerto;
CREATE DATABASE IF NOT EXISTS GestionAeropuerto;
USE GestionAeropuerto;

-- ======================================================
-- 2. TABLAS CATÁLOGO (ENTIDADES MAESTRAS)
-- ======================================================

-- Aerolíneas
CREATE TABLE IF NOT EXISTS Aerolineas (
    Codigo_IATA_Aerolinea CHAR(2) NOT NULL,
    Nombre_Comercial VARCHAR(100) NOT NULL,
    Pais_Origen VARCHAR(50) NOT NULL,
    PRIMARY KEY (Codigo_IATA_Aerolinea)
) ENGINE=InnoDB;

-- Aeropuertos
CREATE TABLE IF NOT EXISTS Aeropuertos (
    Codigo_IATA_Aeropuerto CHAR(3) NOT NULL,
    Nombre_Oficial VARCHAR(150) NOT NULL,
    Ciudad VARCHAR(100) NOT NULL,
    Pais VARCHAR(50) NOT NULL,
    PRIMARY KEY (Codigo_IATA_Aeropuerto)
) ENGINE=InnoDB;

-- Modelos de Avión
CREATE TABLE IF NOT EXISTS Modelos_Avion (
    Codigo_Modelo VARCHAR(15) NOT NULL,
    Fabricante VARCHAR(50) NOT NULL,
    Capacidad_Pasajeros INT NOT NULL,
    Alcance_Km INT,
    PRIMARY KEY (Codigo_Modelo)
) ENGINE=InnoDB;

-- Empleados
CREATE TABLE IF NOT EXISTS Empleados (
    Numero_Licencia VARCHAR(20) NOT NULL,
    Codigo_IATA_Aerolinea CHAR(2) NOT NULL,
    Nombre_Completo VARCHAR(150) NOT NULL,
    Rol VARCHAR(50) NOT NULL,
    PRIMARY KEY (Numero_Licencia),
    FOREIGN KEY (Codigo_IATA_Aerolinea) REFERENCES Aerolineas(Codigo_IATA_Aerolinea) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Pasajeros
CREATE TABLE IF NOT EXISTS Pasajeros (
    Numero_Pasaporte VARCHAR(20) NOT NULL,
    Nombre_Completo VARCHAR(150) NOT NULL,
    Fecha_Nacimiento DATE NOT NULL,
    Nacionalidad VARCHAR(50) NOT NULL,
    PRIMARY KEY (Numero_Pasaporte)
) ENGINE=InnoDB;

-- Servicios Adicionales
CREATE TABLE IF NOT EXISTS Servicios_Adicionales (
    Codigo_Servicio VARCHAR(10) NOT NULL,
    Descripcion VARCHAR(150) NOT NULL,
    Precio_Base DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (Codigo_Servicio)
) ENGINE=InnoDB;

-- ======================================================
-- 3. TABLAS TRANSACCIONALES
-- ======================================================

-- Vuelos
CREATE TABLE IF NOT EXISTS Vuelos (
    ID_Vuelo_Operacion VARCHAR(20) NOT NULL,
    Codigo_IATA_Aerolinea CHAR(2) NOT NULL,
    Origen_IATA CHAR(3) NOT NULL,
    Destino_IATA CHAR(3) NOT NULL,
    Codigo_Modelo VARCHAR(15) NOT NULL,
    Fecha_Hora_Salida DATETIME NOT NULL,
    Fecha_Hora_Llegada DATETIME NOT NULL,
    Estado_Vuelo VARCHAR(20) NOT NULL,
    PRIMARY KEY (ID_Vuelo_Operacion),
    FOREIGN KEY (Codigo_IATA_Aerolinea) REFERENCES Aerolineas(Codigo_IATA_Aerolinea),
    FOREIGN KEY (Origen_IATA) REFERENCES Aeropuertos(Codigo_IATA_Aeropuerto),
    FOREIGN KEY (Destino_IATA) REFERENCES Aeropuertos(Codigo_IATA_Aeropuerto),
    FOREIGN KEY (Codigo_Modelo) REFERENCES Modelos_Avion(Codigo_Modelo)
) ENGINE=InnoDB;

-- Reservas
CREATE TABLE IF NOT EXISTS Reservas (
    PNR_Localizador CHAR(6) NOT NULL,
    ID_Vuelo_Operacion VARCHAR(20) NOT NULL,
    Fecha_Emision DATETIME NOT NULL,
    Estado_Pago VARCHAR(20) NOT NULL,
    Monto_Total DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (PNR_Localizador),
    FOREIGN KEY (ID_Vuelo_Operacion) REFERENCES Vuelos(ID_Vuelo_Operacion) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ======================================================
-- 4. TABLAS DE RELACIÓN (N:M)
-- ======================================================

CREATE TABLE IF NOT EXISTS Aerolinea_Aeropuertos (
    Codigo_IATA_Aerolinea CHAR(2) NOT NULL,
    Codigo_IATA_Aeropuerto CHAR(3) NOT NULL,
    Es_Hub_Principal BOOLEAN NOT NULL,
    Terminal_Asignada VARCHAR(10),
    PRIMARY KEY (Codigo_IATA_Aerolinea, Codigo_IATA_Aeropuerto),
    FOREIGN KEY (Codigo_IATA_Aerolinea) REFERENCES Aerolineas(Codigo_IATA_Aerolinea) ON DELETE CASCADE,
    FOREIGN KEY (Codigo_IATA_Aeropuerto) REFERENCES Aeropuertos(Codigo_IATA_Aeropuerto) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Tripulacion_Vuelo (
    ID_Vuelo_Operacion VARCHAR(20) NOT NULL,
    Numero_Licencia VARCHAR(20) NOT NULL,
    Rol_En_Vuelo VARCHAR(50) NOT NULL,
    PRIMARY KEY (ID_Vuelo_Operacion, Numero_Licencia),
    FOREIGN KEY (ID_Vuelo_Operacion) REFERENCES Vuelos(ID_Vuelo_Operacion) ON DELETE CASCADE,
    FOREIGN KEY (Numero_Licencia) REFERENCES Empleados(Numero_Licencia) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Pasajeros_Reserva (
    PNR_Localizador CHAR(6) NOT NULL,
    Numero_Pasaporte VARCHAR(20) NOT NULL,
    Asiento_Asignado VARCHAR(5),
    Clase_Tarifa VARCHAR(30) NOT NULL,
    PRIMARY KEY (PNR_Localizador, Numero_Pasaporte),
    FOREIGN KEY (PNR_Localizador) REFERENCES Reservas(PNR_Localizador) ON DELETE CASCADE,
    FOREIGN KEY (Numero_Pasaporte) REFERENCES Pasajeros(Numero_Pasaporte) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Servicios_Reserva (
    PNR_Localizador CHAR(6) NOT NULL,
    Codigo_Servicio VARCHAR(10) NOT NULL,
    Cantidad INT NOT NULL,
    Costo_Final_Aplicado DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (PNR_Localizador, Codigo_Servicio),
    FOREIGN KEY (PNR_Localizador) REFERENCES Reservas(PNR_Localizador) ON DELETE CASCADE,
    FOREIGN KEY (Codigo_Servicio) REFERENCES Servicios_Adicionales(Codigo_Servicio) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Boletos (
    Numero_Boleto VARCHAR(13) NOT NULL, -- Estándar IATA
    PNR_Localizador CHAR(6) NOT NULL,
    Numero_Pasaporte VARCHAR(20) NOT NULL,
    ID_Vuelo_Operacion VARCHAR(20) NOT NULL,
    Fecha_Emision DATETIME NOT NULL,
    Asiento_Asignado VARCHAR(5),
    Clase_Tarifa VARCHAR(30) NOT NULL,
    Estado_Boleto VARCHAR(20) NOT NULL, -- 'Emitido', 'Check-in', 'Abordado', 'Cancelado'
    PRIMARY KEY (Numero_Boleto),
    FOREIGN KEY (PNR_Localizador) REFERENCES Reservas(PNR_Localizador) ON DELETE CASCADE,
    FOREIGN KEY (Numero_Pasaporte) REFERENCES Pasajeros(Numero_Pasaporte),
    FOREIGN KEY (ID_Vuelo_Operacion) REFERENCES Vuelos(ID_Vuelo_Operacion)
) ENGINE=InnoDB;