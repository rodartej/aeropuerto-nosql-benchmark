# Resumen PARTE 1 — Modelado + JSON Jerárquico

## Universo de datos generado
- Rango: **2023-01-01 → 2024-12-31** (731 días, 100% cubiertos).
- Vuelos: **4,376** · Boletos: **263,008** · Tripulación: **9,978**
- JSON: 731 documentos · profundidad 7 niveles · 101.1 MB.
- PL/pgSQL: 10.08 s.

## Decisiones que afectan P2/P3/P4

1. **Mismo universo en relacional y JSON.** El JSON es la desnormalización exacta del relacional (joins implícitos como árbol). P2 (Mongo vs SQL), P3 (BigQuery vs SQL) y P4 (Neo4j vs SQL) deben consumir este mismo dataset.
2. **Fechas como ISO `YYYY-MM-DDTHH:MM:SS`** sin timezone, idénticas al TIMESTAMP de PG. **P3 BigQuery: ingerir tal cual, sin reformatear** (causa raíz del bug original).
3. **`fecha_nacimiento_iso`** en JSON (no `edad` precomputada) → determinismo. Si P3/P4 necesitan edad, calcular contra fecha del vuelo.
4. **`Tripulacion_Vuelo` poblada** (9,978 filas, 2-3 empleados/vuelo de la misma aerolínea). **P4 lo usa** para traversal Empleado→Vuelo→Aerolínea, dando nivel extra de profundidad vs SQL.
5. **Semillas fijas:** `random.seed(42)` Python, `setseed(0.42)` PG.
6. **`Decimal` → `float`** en JSON (función `_json_default`). Mongo y BigQuery deben tolerar floats.

## Artefactos exportados a `parte1/`
- `aeropuerto_jerarquico.json` — 731 docs (P2 Mongo · P3 BigQuery).
- `catalogos.json` — referencia rápida (P2/P4).
- `metricas_parte1.csv` — números para el reporte final.
- `resumen_parte1.md` — este archivo.

## Conteos finales por tabla
| Tabla | Filas |
|---|---:|
| Aerolineas | 8 |
| Aeropuertos | 12 |
| Modelos_Avion | 6 |
| Servicios_Adicionales | 8 |
| Empleados | 71 |
| Pasajeros | 1,500 |
| Aerolinea_Aeropuertos | 44 |
| Vuelos | 4,376 |
| Reservas | 4,376 |
| Pasajeros_Reserva | 257,804 |
| Servicios_Reserva | 4,376 |
| Boletos | 263,008 |
| Tripulacion_Vuelo | 9,978 |
