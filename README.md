# Termo-Trafo SCADA - Sistema Móvil Offline de Monitoreo Térmico Predictivo

Aplicación móvil nativa en **Flutter (Dart 3)** diseñada para ingeniería de campo, subestaciones eléctricas y patios de transformación. Funciona de manera **100% offline y local** sin dependencias en la nube, garantizando resiliencia operativa en áreas remotas o industriales con cero conectividad.

---

## 1. Arquitectura y Stack Tecnológico

- **Framework:** Flutter 3.x+ / Dart 3.
- **Patrón de Arquitectura:** Feature-First / Clean Architecture con gestión reactiva de estado mediante **Riverpod** (`NotifierProvider`, `FutureProvider`).
- **Base de Datos Local:** SQLite relacional estricto con `sqflite` y `sqflite_common_ffi` (soporte multiplataforma móvil y desktop).
  - Integridad referencial reforzada con `PRAGMA foreign_keys = ON;`.
  - Operaciones multi-tabla atómicas bajo `db.transaction(...)`.
- **Motor Gráfico:** `fl_chart` para trazado interactivo de series temporales térmicas con curvas multicanal, líneas normativas de umbral y tooltip con notas de patio.
- **UI/UX Industrial:** Tema oscuro SCADA de alto contraste (`#0F172A`, `#1E293B`, `#38BDF8`), tipografías monospace numéricas y semáforos cromáticos según criticidad.

---

## 2. Estructura de Módulos del Proyecto

```
lib/
├── main.dart                               # Punto de entrada con ProviderScope y tema SCADA
├── database/
│   ├── database_service.dart              # SQLite con transacciones, FKs e índices
│   └── database_seeder.dart               # Precarga de plantas, activos y lecturas históricas
├── models/
│   ├── plant.dart                         # Entidad Plantas (plants)
│   ├── subarea.dart                       # Entidad Subáreas (subareas)
│   ├── asset.dart                         # Entidad Transformador (assets)
│   ├── measurement_channel.dart           # Entidad Canales de Medición (measurement_channels)
│   ├── temperature_record.dart            # Entidad Lecturas (temperature_records)
│   ├── channel_value.dart                 # Entidad Valores por Canal (channel_values)
│   ├── record_with_values.dart            # DTO de Registro compuesto con canales
│   ├── asset_status.dart                  # Semáforo de salud térmica y alarmas
│   └── asset_detail_dto.dart              # DTO para renderizado en tarjetas y listas
├── services/
│   └── transformer_standards_engine.dart  # Motor de reglas normativas (IEC 60076 / IEEE C57)
├── providers/
│   └── app_providers.dart                 # Notifiers de Riverpod y operaciones de persistencia
└── views/
    ├── plants_overview_screen.dart        # Vista principal: Selector de Planta, Subárea y KPIs
    ├── trend_chart_screen.dart            # Gráficas fl_chart interactivas e historial cronológico
    ├── new_record_screen.dart             # Formulario de captura rápida para patio
    ├── asset_form_screen.dart             # Alta/edición de activo con auto-cálculo normativo
    └── widgets/
        ├── asset_card.dart                # Tarjeta de activo con semáforo y valores multicanal
        ├── kpi_summary_card.dart          # Tarjetas KPI de conteo de alarmas
        └── status_badge.dart              # Badge de estado de alta visibilidad
test/
├── transformer_standards_engine_test.dart # Pruebas unitarias del motor normativo y semáforo
└── widget_test.dart                       # Smoke test de interfaz y arranque
```

---

## 3. Esquema Relacional de Base de Datos (SQLite)

```sql
PRAGMA foreign_keys = ON;

-- 1. Plantas
CREATE TABLE plants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Subáreas
CREATE TABLE subareas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plant_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
);

-- 3. Activos (Transformadores)
CREATE TABLE assets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subarea_id INTEGER NOT NULL,
  tag TEXT NOT NULL,
  secondary_tag TEXT,
  asset_type TEXT NOT NULL,          -- 'DRY_TYPE' | 'OIL_IMMERSED'
  insulation_class TEXT,            -- 'CLASS_B' | 'CLASS_F' | 'CLASS_H' | 'STANDARD_OIL'
  rated_power_kva REAL,
  primary_voltage_kv REAL,
  temp_warning_limit REAL NOT NULL,
  temp_trip_limit REAL NOT NULL,
  FOREIGN KEY (subarea_id) REFERENCES subareas(id) ON DELETE CASCADE
);

-- 4. Canales de Medición
CREATE TABLE measurement_channels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id INTEGER NOT NULL,
  channel_name TEXT NOT NULL,       -- "CH1", "CH2", "CH3"
  probe_type TEXT DEFAULT 'PT100',
  FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- 5. Lecturas de Temperatura
CREATE TABLE temperature_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id INTEGER NOT NULL,
  reading_date DATETIME NOT NULL,
  recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  event_notes TEXT,
  special_status TEXT DEFAULT 'NONE', -- 'NONE' | 'FOC_FAULT' | 'DISPLAY_OFF' | 'RTD_ERROR'
  FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- 6. Valores por Canal
CREATE TABLE channel_values (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id INTEGER NOT NULL,
  channel_id INTEGER NOT NULL,
  temperature_val REAL NULL,
  has_error INTEGER DEFAULT 0,
  FOREIGN KEY (record_id) REFERENCES temperature_records(id) ON DELETE CASCADE,
  FOREIGN KEY (channel_id) REFERENCES measurement_channels(id)
);

CREATE INDEX idx_records_asset_date ON temperature_records(asset_id, reading_date DESC);
```

---

## 4. Motor de Reglas Normativas (`TransformerStandardsEngine`)

Implementa de forma estricta los límites recomendados por normas internacionales:

| Tipo de Transformador | Clase Térmica | Límite Warning | Límite Trip / Alarma | Norma de Referencia |
|---|---|---|---|---|
| **Sumergido en Aceite (`OIL_IMMERSED`)** | Aceite Mineral | **85.0 °C** | **100.0 °C** | IEC 60076-7 / IEEE C57.91 |
| **Tipo Seco (`DRY_TYPE`)** | Clase B (130 °C) | **100.0 °C** | **125.0 °C** | IEC 60076-11 / IEEE C57.96 |
| **Tipo Seco (`DRY_TYPE`)** | Clase F (155 °C) [Default] | **130.0 °C** | **150.0 °C** | IEC 60076-11 / IEEE C57.96 |
| **Tipo Seco (`DRY_TYPE`)** | Clase H (180 °C) | **150.0 °C** | **170.0 °C** | IEC 60076-11 / IEEE C57.96 |

- El formulario permite verificar la norma aplicada y sobreescribir los valores manualmente en caso de que la placa del fabricante estipule umbrales distintos.

---

## 5. Gestión Temporal y Semáforo de Criticidad

- **Ancla Temporal:** `DateTime.now()` es capturado en `systemBaselineTimeProvider` al iniciar la app.
- **Alerta de Desactualización:** Si la última fecha registrada difiere por más de 15 días respecto a la fecha actual, se despliega una advertencia visual destacada: `"Sin lecturas hace X días (> 15d)"`.
- **Semáforo Industrial:**
  - 🟢 **NORMAL:** Temperatura máxima < Límite Warning.
  - 🟡 **ADVERTENCIA:** Límite Warning <= Temperatura máxima < Límite Trip.
  - 🔴 **CRÍTICO / TRIP:** Temperatura máxima >= Límite Trip.
  - ⚪ **FALLA / MONITOR OFF:** Estados especiales (`FOC_FAULT`, `DISPLAY_OFF`, `RTD_ERROR`).

---

## 6. Precarga de Datos Históricos (Seeder)

El `DatabaseSeeder` precarga automáticamente en el primer inicio de SQLite:
- **Planta:** PPL (Planta Principal), con soporte de navegación a M1 y M4.
- **Subárea:** Patio de Transformadores.
- **Transformadores:**
  - `T3-3` (Canales CH1, CH2, CH3) con historial desde 15/01/2025 y fallas FOC en 2026.
  - `T3-4` con 11 lecturas e incidentes de patio ("30S207, 30S107 Bloqueo compuerta").
  - `T3-5` con lecturas y pico de sobretemperatura en 29/04/2026.
  - `T3-6` (Tag secundario `50EN07`) con pico crítico extremo (118°C en CH2) y eventos de patio ("Fuerte ruido contactor 50lv51").
  - `T3-7` con periodos de monitor en `DISPLAY_OFF`.
  - `T3-20` con eventos de sensor `RTD_ERROR` (`has_error = 1`) y monitor apagado.

---

## 7. Ejecución y Validación

### Ejecutar Pruebas Unitarias
```bash
flutter test
```
*Resultado: 10/10 pruebas superadas.*

### Análisis Estático de Código
```bash
flutter analyze
```
*Resultado: 0 errores, 0 advertencias.*

### Ejecutar la Aplicación
```bash
flutter run
```
*(Funciona nativamente en Android, iOS, Windows, macOS y Linux).*
