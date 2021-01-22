# PgOSM Flex

The goal of PgOSM Flex is to provide high quality OpenStreetMap datasets in PostGIS
using the
[osm2pgsql Flex output](https://osm2pgsql.org/doc/manual.html#the-flex-output).
This project provides a curated set of Lua and SQL scripts to clean and organize
the most commonly used OpenStreetMap data, such as roads, buildings, and points of interest (POIs).

The overall approach is to do as much processing in the `<name>.lua` script
with post-processing steps creating indexes, constraints and comments in a companion `<name>.sql` script.
For more details on using this project see [Hands on with osm2pgsql's new Flex output](https://blog.rustprooflabs.com/2020/12/osm2gpsql-flex-output-to-postgis).

> Warning - The PgOSM Flex output is currently marked as experimental!  All testing done with osm2pgsql v1.4.0 or later.


## Project decisions

A few decisions made in this project:

* ID column is `osm_id`
* Geometry stored in SRID 3857
* Geometry column named `geom`
* Default to same units as OpenStreetMap (e.g. km/hr, meters)
* Data not deemed worthy of a dedicated column goes in side table `osm.tags`. Raw key/value data stored in `JSONB` column
* Points, Lines, and Polygons are not mixed in a single table

## Versions Supported

Minimum versions supported:

* Postgres 12
* PostGIS 3.0
* osm2pgsql 1.4.0


## Standard Import

### Prepare

Download the file, this example uses the Washington D.C. extract from Geofabrik.
It's always a good idea to check the MD5 hash of the file to verify integrity.

```bash
mkdir ~/tmp
cd ~/tmp
wget https://download.geofabrik.de/north-america/us/district-of-columbia-latest.osm.pbf
wget https://download.geofabrik.de/north-america/us/district-of-columbia-latest.osm.pbf.md5

cat ~/tmp/district-of-columbia-latest.osm.pbf.md5
md5sum ~/tmp/district-of-columbia-latest.osm.pbf
```

Prepare the `pgosm` database in Postgres.
Need the PostGIS extension and the `osm` schema.

```bash
psql -c "CREATE DATABASE pgosm;"
psql -d pgosm -c "CREATE EXTENSION postgis; CREATE SCHEMA osm;"
```


### Run osm2pgsql w/ PgOSM-Flex

The PgOSM-Flex styles are required to run, clone the repo and change into the directory
with the `.lua` and `.sql` scripts.
The `run-all.lua` script provides the most complete set of OpenStreetMap
data.  The list of main tables in PgOSM-Flex will continue to grow and evolve.


```bash
mkdir ~/git
cd ~/git
git clone https://github.com/rustprooflabs/pgosm-flex.git
cd pgosm-flex/flex-config

osm2pgsql --slim --drop \
    --output=flex --style=./run-all.lua \
    -d pgosm \
    ~/tmp/district-of-columbia-latest.osm.pbf
```

After osm2pgsql completes the main load, run the matching SQL scripts. 
Each `.lua` has a matching `.sql` to create primary keys, indexes, comments,
views and more.

```bash
psql -d pgosm -f ./run-all.sql
```

> Note: The `run-all` scripts exclude `unitable` and `road_major`.

A peek at some of the tables loaded. 

```sql
SELECT s_name, t_name, rows, size_plus_indexes 
    FROM dd.tables 
    WHERE s_name = 'osm' 
    ORDER BY t_name LIMIT 10;
```

```bash
    ┌────────┬──────────────────────┬────────┬───────────────────┐
    │ s_name │        t_name        │  rows  │ size_plus_indexes │
    ╞════════╪══════════════════════╪════════╪═══════════════════╡
    │ osm    │ amenity_line         │      7 │ 56 kB             │
    │ osm    │ amenity_point        │   5796 │ 1136 kB           │
    │ osm    │ amenity_polygon      │   7593 │ 3704 kB           │
    │ osm    │ building_point       │    525 │ 128 kB            │
    │ osm    │ building_polygon     │ 161256 │ 55 MB             │
    │ osm    │ indoor_line          │      1 │ 40 kB             │
    │ osm    │ indoor_point         │      5 │ 40 kB             │
    │ osm    │ indoor_polygon       │    288 │ 136 kB            │
    │ osm    │ infrastructure_point │    884 │ 216 kB            │
    │ osm    │ landuse_point        │     18 │ 56 kB             │
    └────────┴──────────────────────┴────────┴───────────────────┘
```


> Query available via the [PostgreSQL Data Dictionary (PgDD) extension](https://github.com/rustprooflabs/pgdd).


## Meta table

PgOSM-Flex tracks basic metadata in table ``osm.pgosm_flex``.
The `ts` is set by the post-processing script.  It does not necessarily
indicate the date of the data loaded, though in general it should be close
depending on your processing pipeline.


```sql
SELECT pgosm_flex_version, srid, project_url, ts
    FROM osm.pgosm_flex;
```

```bash
┌────────────────────┬──────┬──────────────────────────────────────┬───────────────────────────────┐
│ pgosm_flex_version │ srid │             project_url              │              ts               │
╞════════════════════╪══════╪══════════════════════════════════════╪═══════════════════════════════╡
│ 0.0.6              │ 3857 │ https://github.com/rustprooflabs/pgo…│ 2021-01-20 01:25:17.555204+00 │
│                    │      │…sm-flex                              │                               │
└────────────────────┴──────┴──────────────────────────────────────┴───────────────────────────────┘
```

For more example queries with data loaded by PgOSM-Flex see [QUERY.md](QUERY.md).



## Additional Styles

Loading the full data set results in a lot of data, see
[the LOAD-DATA.md instructions](LOAD-DATA.md)
for more load options using PgOSM-Flex.



## Nested admin polygons

This is defined in `flex-config/place.sql` but not ran.  Can run quickly on
small areas (Colorado), takes significantly longer on larger areas (North America).

```sql
CALL osm.build_nested_admin_polygons();
```

The above can take a long time.  Monitor progress with this query.

```sql
SELECT COUNT(*) AS row_count,
        COUNT(*) FILTER (WHERE nest_level IS NOT NULL) AS nesting_set
    FROM osm.place_polygon_nested
;
```



## Dump and reload data

To move data loaded on one Postgres instance to another, use `pg_dump`.

Create a directory to export.  Using `-Fd` for directory format to allow using
`pg_dump`/`pg_restore` with multiple processes (`-j 4`).  For the small data set for
Washington D.C. used here this isn't necessary, though can seriously speed up with larger areas, e.g. Europe or North America.

```bash
mkdir -p ~/tmp/osm_dc
pg_dump --schema=osm \
    -d pgosm \
    -Fd -j 4 \
    -f ~/tmp/osm_dc
tar -cvf osm_dc.tar -C ~/tmp osm_dc
```

Move the `.tar`.  Untar and restore.

```bash
tar -xvf osm_eu.tar
pg_restore -j 4 -d pgosm_eu -Fd osm_eu/
```


# Extras


## Additional structure and helper data

**Optional**

Deploying the additional table structure is done via [sqitch](https://sqitch.org/).

Assumes this repo is cloned under `~/git/pgosm-flex/` and a local Postgres
DB named `pgosm` has been created with the `postgis` extension installed.

```bash
cd ~/git/pgosm-flex/db
sqitch deploy db:pg:pgosm
```

- Load helper road data.

```bash
cd ~/git/pgosm-flex/db
psql -d pgosm -f data/roads-us.sql
```


Currently only U.S. region drafted, more regions with local `maxspeed` are welcome via PR!

## QGIS Styles

**Optional**

See [the README documenting using the QGIS styles](https://github.com/rustprooflabs/pgosm-flex/blob/main/db/qgis-style/README.md).



## PgOSM via Docker


PgOSM-Flex can be deployed using the Docker image from [Docker Hub](https://hub.docker.com/r/rustprooflabs/pgosm-flex). 


Create folder for the output (``~/pgosm-data``),
this stores the generated SQL file used to perform the PgOSM transformations and the
output file from ``pg_dump`` containing the ``osm`` schema to load into a production database.
The ``.osm.pbf`` file and associated ``md5``are saved here.  Custom templates, and custom OSM file inputs can be stored here.


```
mkdir ~/pgosm-data
```

Start the `pgosm` container to make PostgreSQL/PostGIS available.  This command exposes Postgres inside Docker on port 5433 and establishes links to local directories.

```
docker run --name pgosm -d \
    -v ~/pgosm-data:/app/output \
    -e POSTGRES_PASSWORD=mysecretpassword \
    -p 5433:5432 -d rustprooflabs/pgosm-flex
```


Run the PgOSM-flex processing.  Using the Washington D.C. sub-region is great
for testing, it runs fast even on the smallest hardware.

```
docker exec -it \
    -e POSTGRES_PASSWORD=mysecretpassword -e POSTGRES_USER=postgres \
    pgosm bash docker/run_pgosm_flex.sh \
    north-america/us \
    district-of-columbia \
    400 \
    run-all
```


## Always download

To force the processing to remove existing files and re-download the latest PBF and MD5 files from Geofabrik, set the `PGOSM_ALWAYS_DOWNLOAD` env var when running the Docker
container.

```
docker run --name pgosm -d \
    -v ~/pgosm-data:/app/output \
    -e POSTGRES_PASSWORD=mysecretpassword \
    -e PGOSM_ALWAYS_DOWNLOAD=1 \
    -p 5433:5432 -d rustprooflabs/pgosm
```

----