COMMENT ON TABLE osm.place_point IS 'OpenStreetMap named places and administrative boundaries. Generated by osm2pgsql Flex output using pgosm-flex/flex-config/place.lua';
COMMENT ON TABLE osm.place_line IS 'OpenStreetMap named places and administrative boundaries. Generated by osm2pgsql Flex output using pgosm-flex/flex-config/place.lua';
COMMENT ON TABLE osm.place_polygon IS 'See view: osm.vplace_polgyon for improved data.  OpenStreetMap named places and administrative boundaries.  Contains relations and the polygon parts making up the relations. Generated by osm2pgsql Flex output using pgosm-flex/flex-config/place.lua';


COMMENT ON COLUMN osm.place_point.osm_type IS 'Values from place if a place tag exists.  If no place tag, values boundary or admin_level indicate the source of the feature.';
COMMENT ON COLUMN osm.place_line.osm_type IS 'Values from place if a place tag exists.  If no place tag, values boundary or admin_level indicate the source of the feature.';
COMMENT ON COLUMN osm.place_polygon.osm_type IS 'Values from place if a place tag exists.  If no place tag, values boundary or admin_level indicate the source of the feature.';


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
