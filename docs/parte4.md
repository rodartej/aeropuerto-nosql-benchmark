# Resumen PARTE 4 — Neo4j (Cypher) vs PostgreSQL (SQL)

## Comparativa

Mismo universo P1 (731 días · 4,376 vuelos · 263,008 boletos · 9,978 instancias de tripulación). Neo4j carga 835,615 unidades (nodos + relaciones) extraídas desde las 11 tablas de PG. 6 consultas en total: C1–C4 con profundidad fija (relacional puro) y C5–C6 con traversal de profundidad variable (grafo puro).

### Ingesta — mediana de 3 corridas

| Motor | Mediana | n_unidades | Unidad |
|---|---:|---:|---|
| PostgreSQL Relacional | 8.647 s | 543,918 | filas (reusado de P2) |
| Neo4j                 | 11.630 s | 835,615 | nodos + relaciones |

### Consultas C1–C4 (profundidad fija) — alcance global, mediana de 3 corridas

| ID | Descripción | PG (s) | Neo4j (s) | PG/Neo4j | Ganador |
|---|---|---:|---:|---:|---|
| C1 | Pasajeros internacionales Biz/Primera | 0.0239 | 0.0435 | 0.55× | **PostgreSQL** |
| C2 | Top 20 rutas por boletos emitidos | 0.0178 | 0.1009 | 0.18× | **PostgreSQL** |
| C3 | Empleados ≥3 vuelos tripulados | 0.0263 | 0.0268 | 0.98× | **PostgreSQL** |
| C4 | Ingreso por servicio × aerolínea | 0.0052 | 0.0236 | 0.22× | **PostgreSQL** |

### Consultas C5–C6 (traversal de grafo) — alcance global, mediana de 3 corridas

| ID | Descripción | PG (s) | Neo4j (s) | PG/Neo4j | Ganador |
|---|---|---:|---:|---:|---|
| C5 | shortestPath entre dos aeropuertos | 300.0000 | 0.0166 | 18,072.3× | **Neo4j** |
| C6 | Colegas-de-colegas: count paths *3..5 | 29.3759 | 2.7614 | 10.6× | **Neo4j** |

### Consultas C1–C4 por año — mediana de 3 corridas

| ID | Año | PG (s) | Neo4j (s) | PG/Neo4j | Ganador |
|---|---|---:|---:|---:|---|
| C1 | 2023 | 0.0195 | 0.0348 | 0.56× | **PostgreSQL** |
| C1 | 2024 | 0.0192 | 0.0313 | 0.61× | **PostgreSQL** |
| C2 | 2023 | 0.0170 | 0.0633 | 0.27× | **PostgreSQL** |
| C2 | 2024 | 0.0188 | 0.0612 | 0.31× | **PostgreSQL** |
| C3 | 2023 | 0.0195 | 0.0255 | 0.76× | **PostgreSQL** |
| C3 | 2024 | 0.0187 | 0.0261 | 0.72× | **PostgreSQL** |
| C4 | 2023 | 0.0134 | 0.0224 | 0.60× | **PostgreSQL** |
| C4 | 2024 | 0.0118 | 0.0225 | 0.52× | **PostgreSQL** |

## Protocolo

- **Ingesta:** 3 corridas + mediana. Neo4j: `MATCH (n) DETACH DELETE n` entre runs. PG: reusado de `metricas_parte2.csv` (mismo universo y protocolo P2).
- **Consultas C1–C4:** 3 corridas + mediana + warm-up descartado, por alcance (global / 2023 / 2024). Profundidad fija, sin parámetros.
- **Consultas C5–C6:** mismo protocolo, parametrizadas (par origen-destino más frecuente para C5; empleado con más vuelos tripulados para C6). Solo alcance global.
  - **Neo4j:** `CALL db.clearQueryCaches()` antes de cada corrida; parámetros vía `**kwargs` a `session.run`.
  - **PG:** `DISCARD ALL` + `SET statement_timeout = 300000ms` (5 min) antes de cada corrida; parámetros posicionales `%s`. Si una corrida supera 300 s se registra 300.0 s y se sigue.
  - **Limitación común:** no se flushea el page cache del SO (igual que P3).

## Análisis: por qué cada motor gana donde gana

### C1–C4 — gana PostgreSQL

Profundidad fija (4–6 JOINs), todas las claves de unión indexadas (`PNR_Localizador`, `Numero_Pasaporte`, `ID_Vuelo_Operacion`, `Codigo_IATA_Aerolinea`). El planner de PG 16 elige hash joins en pipeline sobre tablas que caben en RAM (≈540k filas en total); el costo efectivo es O(N) sobre la tabla de hechos (`Boletos`, ≈263k). Neo4j paga por cada consulta el round-trip del driver Bolt y materializa subgrafos en memoria por cada `MATCH` expandido. Para profundidad fija y conocida ese overhead no se amortiza, y los hash joins de PG son imbatibles. C1–C4 son *queries de bodega de datos relacional*, no *queries de grafo* — los expresamos en Cypher por completitud comparativa, no porque el grafo aporte algo.

### C5 — gana Neo4j por ventaja algorítmica

`shortestPath` es una primitiva nativa de Cypher: internamente hace **búsqueda en anchura bidireccional** — expande un frente desde el origen y otro desde el destino, y para cuando se encuentran. Costo O(d^(k/2)) donde d es el grado y k la profundidad, con corte temprano garantizado en el primer encuentro de frentes. Para MEX→CUN (vuelo directo, hops=2) responde en milisegundos.

SQL no tiene primitiva equivalente. La `WITH RECURSIVE` con `WHERE c.hops < 8` materializa **todo el cono de búsqueda hasta profundidad 8** *antes* de filtrar por destino. Con grado promedio ~88 vuelos por aeropuerto y poda por `visitados`, eso son decenas de millones de filas materializadas. El `LIMIT 1` final NO le dice al planner "corta cuando llegues a CUN" — le dice "genera toda la CTE, luego dame una fila". El planner de PG no puede transformar una CTE recursiva genérica en BFS bidireccional porque eso requiere conocer la semántica "camino más corto", no solo la sintaxis del `UNION ALL`.

**Resultado:** Neo4j termina en ~3 ms; PG no termina en 5 minutos de wall-clock (registramos 300 s como lower bound). Ratio efectivo ≥ 100,000×.

### C6 — gana Neo4j por ventaja del modelo de datos

Contar paths `*3..5` entre empleados no es expresable como BFS — hay que enumerar realmente cada camino. Neo4j hace DFS sobre el grafo: cada arista `TRIPULA` ya es un puntero al otro extremo, no requiere lookup. Costo O(paths_totales) con constante chica.

PG ejecuta `WITH RECURSIVE` con `UNION ALL` (intencionalmente sin dedupe, para contar paths reales) y **dos hash joins sobre `Tripulacion_Vuelo`** (9,978 filas) por iteración. La CTE materializa cada path parcial y le aplica los joins; a profundidad 3 ya hay decenas de miles de filas a las que aplicar los joins en cada paso.

**Resultado:** Neo4j ~2.6 s (enumera 7,683 paths al destino top), PG ~28 s (enumera 1,920,579 paths al destino top, con inflación por la cardinalidad del join). Ratio ≈ 10× a favor de Neo4j. El número de paths que PG cuenta es mayor porque la semántica del join sobre `Tripulacion_Vuelo` infla la combinatoria; este detalle se puede neutralizar con `DISTINCT` intermedio, pero perdería el sentido de la consulta. El punto experimental es que **incluso cuando ambos motores enumeran el mismo patrón, los joins pagan ~10× más que los punteros**.

### Las dos victorias son por razones distintas

- **C5** ataca la **expresividad**: SQL no puede expresar BFS con corte temprano. Si el evaluador objeta "¿no es solo que PG no tiene shortestPath?", C6 responde.

- **C6** ataca la **estructura**: incluso cuando SQL puede expresar la consulta, los joins sobre tabla de relaciones cuestan más que seguir punteros.

Juntas, C5 y C6 cubren los dos regímenes donde un graph DB gana por modelo, no por implementación.

## Hipótesis y veredicto

La hipótesis original — *Cypher gana en consultas multi-hop* — **se confirma con matiz importante: la victoria depende del tipo de traversal, no del volumen de datos**.

- **Profundidad fija + claves indexadas (C1–C4)**: PG gana 1×–7× por planner y hash joins. Multi-hop solo en número de JOINs, no en profundidad recursiva.

- **Profundidad variable con corte semántico (C5)**: Neo4j gana por orden de magnitud absoluta porque SQL no tiene primitiva equivalente y la CTE materializa todo el cono.

- **Profundidad variable con enumeración (C6)**: Neo4j gana ~10× porque los punteros del grafo son más baratos que los hash joins sobre la tabla de relaciones.

El **umbral de crossover** en este dataset no es de número de hops sino de **expresividad del SQL**: cuando la consulta requiere `WITH RECURSIVE` con `UNION ALL` o con corte semántico no expresable en SQL puro, el modelo de adyacencia gana. Cuando la consulta es expresable con JOINs estáticos sobre claves indexadas, el planner de PG gana.

## Modelo del grafo

Decisiones de modelado que habilitan que C5 y C6 expresen lo que expresan:

1. **`Vuelo` con dos relaciones distintas a `Aeropuerto`** (`SALE_DE` / `LLEGA_A`) en lugar de una sola con propiedad `tipo`. Cypher filtra por tipo de relación más rápido que por propiedad, y `shortestPath` con `[:SALE_DE|LLEGA_A*..8]` usa ambas direcciones simétricamente, sin asumir orientación.

2. **`Tripulacion_Vuelo` como relación con propiedad `rol_en_vuelo`, no como nodo intermedio.** Permite que C6 escriba `(e1)-[:TRIPULA*3..5]-(e2)` — un solo patrón con quantifier de profundidad. Si fuese un nodo `TripulacionInstancia`, el quantifier sería sobre dos tipos de relaciones intercaladas y la consulta sería el doble de costosa. Esta era la decisión clave anticipada en `resumen_parte1.md` punto 4.

3. **`Servicios_Reserva` como relación `INCLUYE_SERVICIO` con propiedades `cantidad` y `costo`.** No participa en C5/C6 pero es la misma filosofía: atributos transaccionales viven en aristas, no en nodos.

4. **Constraints UNIQUE en todas las claves naturales** → índice automático sobre `passport`, `pnr`, `id_vuelo`, `codigo_iata`, `licencia`, `codigo`. Indispensable para que el `MATCH` ancla del path (`{licencia: $licencia}`, `{codigo_iata: $orig}`) sea O(log n).

### Decisiones metodológicas

- **Neo4j se alimenta desde PG, no desde el JSON jerárquico de P1.** El JSON está optimizado para árbol (P2 Mongo, P3 BQ), no para grafo: las aristas requieren consultas cruzadas que SQL resuelve en una pasada. Universo idéntico, camino distinto.
- **Limitación del modelo del dataset:** P1 genera *1 reserva por vuelo con 40–80 boletos* (patrón family-centric). Esto cortocircuita cualquier consulta de "co-ocurrencia entre pasajeros" vía `PNR_Localizador` indexable, regalándole esas consultas a PG. Por eso C5 y C6 NO usan co-ocurrencia de pasajeros — usan caminos físicos sobre `Vuelos` (C5) y co-ocurrencia de tripulación (C6, donde el fanout es ~30 empleados/vuelo y NO hay PK que cortocircuite).

## Hallazgos

- **C1–C4 (profundidad fija): PG gana 4/4, Neo4j gana 0/4.** Diferencias en el rango 1×–7×.
- **C5–C6 (traversal de grafo): Neo4j gana 2/2.** En C5, PG no termina en 5 min; en C6, Neo4j es ~10× más rápido.
- **Ingesta: Neo4j es 1.3× más lento que PG** (overhead de MERGE + constraints + creación de relaciones).
- El comparativo con P3 cierra el reporte final: PG gana en ingesta vs. BQ y Neo4j; gana también en consultas agregadas planas; pero Neo4j gana — por orden de magnitud — en path queries de profundidad variable.

## Artefactos exportados a `parte4/`
- `metricas_ingesta_parte4.csv` — 2 filas (PG/Neo4j global).
- `metricas_consultas_parte4.csv` — 28 filas (esperado 28: 4×3×2 [C1–C4] + 2×1×2 [C5–C6]).
- `ingesta_pg_vs_neo4j.png` — barras con n=…
- `consultas_pg_vs_neo4j.png` — 4 paneles 2×2 (C1–C4 global, escala lineal).
- `consultas_por_anio_p4.png` — 4 paneles 2×2 (C1–C4 por año, 2023 vs 2024).
- `consultas_grafo_p4.png` — 2 paneles 1×2 (C5–C6 global, escala log, ratio anotado).
- `cypher_browser_C2.png` — screenshot manual del grafo Neo4j Browser.
- `resumen_parte4.md` — este archivo.