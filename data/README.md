# Datos

Datasets de gran tamaño (~108 MB) no versionados. Solo se incluye una muestra demo.

## Estructura

```
data/
├── README.md                       # este archivo
├── sample/                         # versionado — muestra chica para tests
│   ├── aeropuerto_demo.json
│   ├── catalogos.json
│   └── dataset_manifest.json
└── full/                           # no versionado — generado por notebook 01
    ├── aeropuerto_jerarquico.json    # ~101 MB
    └── transacciones_jerarquico.json # ~7 MB
```

## Generación del dataset completo

```bash
jupyter nbconvert --execute notebooks/01_modelado_y_json.ipynb
```

Genera los JSONs jerárquicos en `data/full/`. El notebook simula tráfico aéreo sintético sobre el modelo definido en `sql/schema.sql`.

## Muestra demo

`data/sample/` contiene una versión reducida. Notebooks 02-04 pueden usarla activando `USE_DEMO=True` en su primera celda (ver código de cada notebook).

## Notas

- Datos 100% sintéticos (no info real de aerolíneas).
- Schema relacional en [`sql/schema.sql`](../sql/schema.sql).
- Catálogos de referencia en `sample/catalogos.json`.
