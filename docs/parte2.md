# Resumen PARTE 2 — Benchmark de Ingesta

## Comparativa: PostgreSQL Relacional vs MongoDB

Mismo universo PARTE 1 (731 días, 4,376 vuelos, 263,008 boletos, 9,978 tripulación), cada motor en su forma natural.

| Alcance | PG Relacional (mediana) | MongoDB (mediana) | n SQL (filas) | n Mongo (docs) |
|---|---:|---:|---:|---:|
| Global  | 8.647 s  | 0.368 s  | 543,918 | 731 |
| 2023    | 4.283 s | 0.201 s | 271,689   | 365 |
| 2024    | 4.309 s | 0.203 s | 272,229   | 366 |

Protocolo: 3 corridas por motor por alcance, mediana reportada, `time.perf_counter()` solo alrededor de `execute_values+commit` (SQL) e `insert_many` (Mongo), reset de BD entre corridas.

## Decisión de granularidad
- SQL inserta filas normalizadas (su forma natural: 13 tablas).
- Mongo inserta los 731 documentos jerárquicos (su forma natural: árboles BSON).
- **No se aplana** el JSON a 263k docs planos. Esto preserva el modelo embebido de Mongo y mantiene paridad con P3 (BigQuery RECORD/REPEATED) y P4 (Neo4j).

## Decisiones que afectan P3 y P4
1. **P3 (BigQuery):** usar el mismo `aeropuerto_jerarquico.json` que Mongo. Granularidad = 731 docs anidados. **No re-aplanar.**
2. **P3:** los timestamps ISO sin TZ del JSON deben ingerirse tal cual (causa raíz del bug original mencionado en PARTE 1).
3. **P4 (Neo4j):** la tripulación está poblada (9,978 filas) y forma parte del benchmark SQL aquí. P4 puede usar el traversal Empleado→Tripulacion_Vuelo→Vuelo→Aerolinea para profundidad extra vs SQL.
4. **Protocolo de medición estándar (P3 y P4):** 3 corridas + mediana + reset de BD entre corridas + cronómetro solo alrededor de la operación medida.

## Artefactos exportados a `parte2/`
- `metricas_parte2.csv` — 3 corridas + mediana por motor por alcance.
- `ingesta_global.png` — comparativa global SQL vs Mongo.
- `ingesta_por_anio.png` — comparativa partida 2023 vs 2024.
- `resumen_parte2.md` — este archivo.
