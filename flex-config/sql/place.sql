COMMENT ON TABLE osm.place_point IS 'OpenStreetMap named places and administrative boundaries. Generated by osm2pgsql Flex output using pgosm-flex/flex-config/place.lua';
COMMENT ON TABLE osm.place_line IS 'OpenStreetMap named places and administrative boundaries. Generated by osm2pgsql Flex output using pgosm-flex/flex-config/place.lua';
COMMENT ON TABLE osm.place_polygon IS 'See view: osm.vplace_polgyon for improved data.  OpenStreetMap named places and administrative boundaries.  Contains relations and the polygon parts making up the relations. Generated by osm2pgsql Flex output using pgosm-flex/flex-config/place.lua';

COMMENT ON COLUMN osm.place_point.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';
COMMENT ON COLUMN osm.place_line.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';
COMMENT ON COLUMN osm.place_polygon.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';

COMMENT ON COLUMN osm.place_point.osm_type IS 'Values from place if a place tag exists.  If no place tag, values boundary or admin_level indicate the source of the feature.';
COMMENT ON COLUMN osm.place_line.osm_type IS 'Values from place if a place tag exists.  If no place tag, values boundary or admin_level indicate the source of the feature.';
COMMENT ON COLUMN osm.place_polygon.osm_type IS 'Values from place if a place tag exists.  If no place tag, values boundary or admin_level indicate the source of the feature.';

COMMENT ON COLUMN osm.place_polygon.member_ids IS 'Member IDs making up the full relation.  NULL if not a relation.  Used to create improved osm.vplace_polygon.';

COMMENT ON COLUMN osm.place_point.name IS 'Best name option determined by helpers.get_name(). Keys with priority are: name, short_name, alt_name and loc_name.  See pgosm-flex/flex-config/helpers.lua for full logic of selection.';
COMMENT ON COLUMN osm.place_line.name IS 'Best name option determined by helpers.get_name(). Keys with priority are: name, short_name, alt_name and loc_name.  See pgosm-flex/flex-config/helpers.lua for full logic of selection.';
COMMENT ON COLUMN osm.place_polygon.name IS 'Best name option determined by helpers.get_name(). Keys with priority are: name, short_name, alt_name and loc_name.  See pgosm-flex/flex-config/helpers.lua for full logic of selection.';

COMMENT ON COLUMN osm.place_point.geom IS 'Geometry loaded by osm2pgsql.';
COMMENT ON COLUMN osm.place_line.geom IS 'Geometry loaded by osm2pgsql.';
COMMENT ON COLUMN osm.place_polygon.geom IS 'Geometry loaded by osm2pgsql.';

COMMENT ON COLUMN osm.place_point.admin_level IS 'Value from admin_level if it exists as integer value. Meaning of admin_level changes by region, see: https://wiki.openstreetmap.org/wiki/Key:admin_level';
COMMENT ON COLUMN osm.place_line.admin_level IS 'Value from admin_level if it exists as integer value. Meaning of admin_level changes by region, see: https://wiki.openstreetmap.org/wiki/Key:admin_level';
COMMENT ON COLUMN osm.place_polygon.admin_level IS 'Value from admin_level if it exists as integer value. Meaning of admin_level changes by region, see: https://wiki.openstreetmap.org/wiki/Key:admin_level';

COMMENT ON COLUMN osm.place_point.boundary IS 'Value from boundary tag.  https://wiki.openstreetmap.org/wiki/Boundaries';
COMMENT ON COLUMN osm.place_line.boundary IS 'Value from boundary tag.  https://wiki.openstreetmap.org/wiki/Boundaries';
COMMENT ON COLUMN osm.place_polygon.boundary IS 'Value from boundary tag.  https://wiki.openstreetmap.org/wiki/Boundaries';


ALTER TABLE osm.place_point
    ADD CONSTRAINT pk_osm_place_point_osm_id
    PRIMARY KEY (osm_id)
;
ALTER TABLE osm.place_line
    ADD CONSTRAINT pk_osm_place_line_osm_id
    PRIMARY KEY (osm_id)
;
ALTER TABLE osm.place_polygon
    ADD CONSTRAINT pk_osm_place_polygon_osm_id
    PRIMARY KEY (osm_id)
;


CREATE INDEX ix_osm_place_point_type ON osm.place_point (osm_type);
CREATE INDEX ix_osm_place_line_type ON osm.place_line (osm_type);
CREATE INDEX ix_osm_place_polygon_type ON osm.place_polygon (osm_type);


CREATE VIEW osm.places_in_relations AS
SELECT p_no_rel.osm_id
    FROM osm.place_polygon p_no_rel
    WHERE osm_id > 0
        AND EXISTS (SELECT * 
            FROM (SELECT i.osm_id AS relation_id, 
                        jsonb_array_elements_text(i.member_ids)::BIGINT AS member_id
                    FROM osm.place_polygon i
                    WHERE i.osm_id < 0
                    ) rel
            WHERE rel.member_id = p_no_rel.osm_id
            ) 
;

COMMENT ON VIEW osm.places_in_relations IS 'Lists all osm_id values included in a relation''s member_ids list.  Technically could contain duplicates, but not a concern with current expected use of this view.';
COMMENT ON COLUMN osm.places_in_relations.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';


CREATE MATERIALIZED VIEW osm.vplace_polygon AS
SELECT p.*
    FROM osm.place_polygon p
    WHERE NOT EXISTS (
        SELECT 1 
            FROM osm.places_in_relations pir 
            WHERE p.osm_id = pir.osm_id)
;

CREATE UNIQUE INDEX uix_osm_vplace_polygon_osm_id
    ON osm.vplace_polygon (osm_id);
CREATE INDEX gix_osm_vplace_polygon
    ON osm.vplace_polygon USING GIST (geom);



COMMENT ON MATERIALIZED VIEW osm.vplace_polygon IS 'Simplified polygon layer removing non-relation geometries when a relation contains it in the member_ids column.';
COMMENT ON COLUMN osm.vplace_polygon.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';
COMMENT ON COLUMN osm.vplace_polygon.member_ids IS 'Member IDs making up the full relation.  NULL if not a relation.  Used to create improved osm.vplace_polygon.';
COMMENT ON COLUMN osm.vplace_polygon.name IS 'Best name option determined by helpers.get_name(). Keys with priority are: name, short_name, alt_name and loc_name.  See pgosm-flex/flex-config/helpers.lua for full logic of selection.';
COMMENT ON COLUMN osm.vplace_polygon.admin_level IS 'Value from admin_level if it exists.';

COMMENT ON COLUMN osm.vplace_polygon.boundary IS 'Value from boundary tag.  https://wiki.openstreetmap.org/wiki/Boundaries';
COMMENT ON COLUMN osm.vplace_polygon.geom IS 'Geometry loaded by osm2pgsql.';


DROP TABLE IF EXISTS osm.place_polygon_nested;
CREATE TABLE osm.place_polygon_nested
(
    osm_id BIGINT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    osm_type TEXT NOT NULL,
    admin_level INT NOT NULL,
    nest_level BIGINT NULL,
    name_path TEXT[] NULL,
    osm_id_path BIGINT[] NULL,
    admin_level_path INT[] NULL,
    row_innermost BOOLEAN NOT NULL GENERATED ALWAYS AS (
        CASE WHEN osm_id_path[array_length(osm_id_path, 1)] = osm_id THEN True
            ELSE False
            END
        ) STORED,
    innermost BOOLEAN NOT NULL DEFAULT False,
    geom GEOMETRY NOT NULL, -- Can't enforce geom type b/c SRID is dynamic project wide. Can't set MULTIPOLYGON w/out SRID too
    CONSTRAINT fk_place_polygon_nested
        FOREIGN KEY (osm_id) REFERENCES osm.place_polygon (osm_id) 
);



CREATE INDEX ix_osm_place_polygon_nested_osm_id
    ON osm.place_polygon_nested (osm_id)
;
CREATE INDEX ix_osm_place_polygon_nested_name_path
    ON osm.place_polygon_nested USING GIN (name_path)
;
CREATE INDEX ix_osm_place_polygon_nested_osm_id_path
    ON osm.place_polygon_nested USING GIN (osm_id_path)
;

COMMENT ON TABLE osm.place_polygon_nested IS 'Provides hierarchy of administrative polygons.  Built on top of osm.vplace_polygon. Artifact of PgOSM-Flex (place.sql).';

COMMENT ON COLUMN osm.place_polygon_nested.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';


COMMENT ON COLUMN osm.place_polygon_nested.admin_level IS 'Value from admin_level if it exists.  Defaults to 99 if not.';
COMMENT ON COLUMN osm.place_polygon_nested.nest_level IS 'How many polygons is the current polygon nested within.  1 indicates polygon with no containing polygon.';
COMMENT ON COLUMN osm.place_polygon_nested.name_path IS 'Array of names of the current polygon (last) and all containing polygons.';
COMMENT ON COLUMN osm.place_polygon_nested.osm_id_path IS 'Array of osm_id for the current polygon (last) and all containing polygons.';
COMMENT ON COLUMN osm.place_polygon_nested.admin_level_path IS 'Array of admin_level values for the current polygon (last) and all containing polygons.';
COMMENT ON COLUMN osm.place_polygon_nested.name IS 'Best name option determined by helpers.get_name(). Keys with priority are: name, short_name, alt_name and loc_name.  See pgosm-flex/flex-config/helpers.lua for full logic of selection.';
COMMENT ON COLUMN osm.place_polygon_nested.row_innermost IS 'Indicates if the osm_id is the most inner ID of the current row.  Used to calculated innermost after all nesting paths have been calculated.';
COMMENT ON COLUMN osm.place_polygon_nested.innermost IS 'Indiciates this row is the innermost admin level of the current data set and does **not** itself contain another admin polygon.  Calculated by procedure osm.build_nested_admin_polygons() defined in pgosm-flex/flex-config/place.sql.';

COMMENT ON COLUMN osm.place_polygon_nested.geom IS 'Geometry loaded by osm2pgsql.';


INSERT INTO osm.place_polygon_nested (osm_id, name, osm_type, admin_level, geom)
SELECT p.osm_id, p.name, p.osm_type,
        COALESCE(p.admin_level::INT, 99) AS admin_level,
        geom
    FROM osm.vplace_polygon p
    WHERE (p.boundary = 'administrative'
            OR p.osm_type IN   ('neighborhood', 'city', 'suburb', 'town', 'admin_level', 'locality')
       )
        AND p.name IS NOT NULL
;



CREATE OR REPLACE PROCEDURE osm.build_nested_admin_polygons(
     batch_row_limit BIGINT = 100
 )
 LANGUAGE plpgsql
 AS $$
 DECLARE
     rows_to_update BIGINT;
 BEGIN

 SELECT  COUNT(*) INTO rows_to_update
     FROM osm.place_polygon_nested r
     WHERE nest_level IS NULL
 ;
 RAISE NOTICE 'Rows to update: %', rows_to_update;
 RAISE NOTICE 'Updating in batches of % rows', $1;

 FOR counter IN 1..rows_to_update by $1 LOOP

    DROP TABLE IF EXISTS places_for_nesting;
    CREATE TEMP TABLE places_for_nesting AS
    SELECT p.osm_id
        FROM osm.place_polygon_nested p
        WHERE p.name IS NOT NULL
            AND (admin_level IS NOT NULL
                OR osm_type IN ('boundary', 'admin_level', 'suburb',
                             'neighbourhood')
                )
    ;

    DROP TABLE IF EXISTS place_batch;
    CREATE TEMP TABLE place_batch AS
    SELECT p.osm_id, t.nest_level, t.name_path, t.osm_id_path, t.admin_level_path
        FROM osm.vplace_polygon p
        INNER JOIN LATERAL (
            SELECT COUNT(i.osm_id) AS nest_level,
                    ARRAY_AGG(i.name ORDER BY COALESCE(i.admin_level::INT, 99::INT) ASC) AS name_path,
                    ARRAY_AGG(i.osm_id ORDER BY COALESCE(i.admin_level::INT, 99::INT) ASC) AS osm_id_path,
                    ARRAY_AGG(COALESCE(i.admin_level::INT, 99::INT) ORDER BY i.admin_level ASC) AS admin_level_path
                FROM osm.vplace_polygon i
                WHERE ST_Within(p.geom, i.geom)
                    AND EXISTS (
                            SELECT 1 FROM places_for_nesting include
                                WHERE i.osm_id = include.osm_id
                        )
                    AND i.name IS NOT NULL
               ) t ON True
        WHERE EXISTS (
                SELECT 1 FROM osm.place_polygon_nested miss
                    WHERE miss.nest_level IS NULL
                    AND p.osm_id = miss.osm_id
        )
        AND EXISTS (
                SELECT 1 FROM places_for_nesting include
                    WHERE p.osm_id = include.osm_id
            )
    LIMIT $1
    ;

    UPDATE osm.place_polygon_nested n 
        SET nest_level = t.nest_level,
            name_path = t.name_path,
            osm_id_path = t.osm_id_path,
            admin_level_path = t.admin_level_path
        FROM place_batch t
        WHERE n.osm_id = t.osm_id
        ;
    COMMIT;
    END LOOP;

    DROP TABLE IF EXISTS place_batch;
    DROP TABLE IF EXISTS places_for_nesting;

    -- With all nested paths calculated the innermost value can be determined.
    WITH calc_inner AS (
    SELECT a.osm_id
        FROM osm.place_polygon_nested a
        WHERE a.row_innermost -- Start with per row check...
            -- If an osm_id is found in any other path, cannot be innermost
            AND NOT EXISTS (
            SELECT 1
                FROM osm.place_polygon_nested i
                WHERE a.osm_id <> i.osm_id
                    AND a.osm_id = ANY(osm_id_path)
        )
    )
    UPDATE osm.place_polygon_nested n
        SET innermost = True
        FROM calc_inner i
        WHERE n.osm_id = i.osm_id
    ;
END $$; 



COMMENT ON PROCEDURE osm.build_nested_admin_polygons IS 'Warning: Expensive procedure!  Use to populate the osm.place_polygon_nested table.  Not ran as part of SQL script automatically due to excessive run time on large regions.';

-- Commented out on purpose -- see comment above
--CALL osm.build_nested_admin_polygons();



CREATE MATERIALIZED VIEW osm.vplace_polygon_subdivide AS
SELECT osm_id, ST_Subdivide(geom) AS geom
    FROM osm.vplace_polygon
;
CREATE INDEX gix_osm_vplace_polygon_subdivide
    ON osm.vplace_polygon_subdivide USING GIST (geom)
;

COMMENT ON MATERIALIZED VIEW osm.vplace_polygon_subdivide IS 'Subdivided geometry from osm.vplace_polygon.  Multiple rows per osm_id, one for each subdivided geometry.';

COMMENT ON COLUMN osm.vplace_polygon_subdivide.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.  Duplicated in this view!';
COMMENT ON COLUMN osm.vplace_polygon_subdivide.geom IS 'Geometry loaded by osm2pgsql.';

