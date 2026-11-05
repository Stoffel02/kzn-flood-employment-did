# Data

This repository contains **no data**. The files below are public, but they are
redistributed under their providers' terms, so download them yourself.

## 1. SARS–National Treasury Spatial Tax Panel (local municipalities)

Download the *local municipality* tables and the 2018 municipal boundary shapefile
from the Spatial Tax Panel data portal (National Treasury / SARS, version 5).
Read the panel's metadata document and terms of use before use and cite as required.

Place them so that `$raw` (default `data/raw/`) looks like this:

```
data/raw/
├── Local_Municipal_Data/
│   ├── Municipal_FTE_Monthly.csv
│   ├── Municipal_FTE_Industry5d_Monthly.csv      (≈360 MB)
│   ├── Municipal_Establishments_Import.csv
│   └── Municipal_MedianIncome.csv
└── Local_Municipal_Shapefiles/
    └── MDB_Local_Municipal_Boundary_2018.shp (+ .dbf .shx .prj .cpg)
```

Only these five inputs are used by the pipeline. Cells with fewer than 10
employees/establishments are suppressed (`<10`) in the source data; see the
`FLAG (data)` comments in `code/01_build_industry.do` and `code/02_build_inputs.do`
for how each build handles them.

## 2. Flood events (exploratory scripts only)

`exploratory/` also refers to flood records taken from a global archive of large
flood events (`SA flood data.dta`, `SA_floods_expanded.dta`). These are **not** needed
for the main pipeline, which identifies the treated districts directly.

## Using a different folder

Copy `config_local.example.do` to `config_local.do` (git-ignored) and set `$raw`.
