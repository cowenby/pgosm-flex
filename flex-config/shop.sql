COMMENT ON TABLE osm.shop_point IS 'OpenStreetMap shop related points.   Generated by osm2pgsql Flex output using pgosm-flex/flex-config/shop.lua';
COMMENT ON TABLE osm.shop_polygon IS 'OpenStreetMap shop related polygons. Generated by osm2pgsql Flex output using pgosm-flex/flex-config/shop.lua';

COMMENT ON COLUMN osm.shop_point.name IS 'Best name option determined by helpers.get_name(). Keys with priority are: name, short_name, alt_name and loc_name.  See pgosm-flex/flex-config/helpers.lua for full logic of selection.';
COMMENT ON COLUMN osm.shop_polygon.name IS 'Best name option determined by helpers.get_name(). Keys with priority are: name, short_name, alt_name and loc_name.  See pgosm-flex/flex-config/helpers.lua for full logic of selection.';

COMMENT ON COLUMN osm.shop_point.geom IS 'Geometry loaded by osm2pgsql.';
COMMENT ON COLUMN osm.shop_polygon.geom IS 'Geometry loaded by osm2pgsql.';


COMMENT ON COLUMN osm.shop_point.wheelchair IS 'Indicates if building is wheelchair accessible.';
COMMENT ON COLUMN osm.shop_point.wheelchair IS 'Indicates if building is wheelchair accessible.';


ALTER TABLE osm.shop_point
    ADD CONSTRAINT pk_osm_shop_point_osm_id
    PRIMARY KEY (osm_id)
;
ALTER TABLE osm.shop_polygon
    ADD CONSTRAINT pk_osm_shop_polygon_osm_id
    PRIMARY KEY (osm_id)
;

ALTER TABLE osm.shop_point 
    ADD address TEXT NOT NULL
    GENERATED ALWAYS AS (
        COALESCE(housenumber, '')
            || COALESCE(' ' || street, '')
            || COALESCE(', ' || city || ' ', '')
            || COALESCE(', ' || state || ' ', '')
        )
    STORED
;

ALTER TABLE osm.shop_polygon
    ADD address TEXT NOT NULL
    GENERATED ALWAYS AS (
        COALESCE(housenumber, '')
            || COALESCE(' ' || street, '')
            || COALESCE(', ' || city || ' ', '')
            || COALESCE(', ' || state || ' ', '')
        )
    STORED
;

COMMENT ON COLUMN osm.shop_point.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';
COMMENT ON COLUMN osm.shop_polygon.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';

COMMENT ON COLUMN osm.shop_point.address IS 'Simple attempt to combine address parts into single column with COALESCE.';
COMMENT ON COLUMN osm.shop_polygon.address IS 'Simple attempt to combine address parts into single column with COALESCE.';

COMMENT ON COLUMN osm.shop_point.housenumber IS 'Value from addr:housenumber tag';
COMMENT ON COLUMN osm.shop_point.street IS 'Value from addr:street tag';
COMMENT ON COLUMN osm.shop_point.city IS 'Value from addr:city tag';
COMMENT ON COLUMN osm.shop_point.state IS 'Value from addr:state tag';

COMMENT ON COLUMN osm.shop_polygon.housenumber IS 'Value from addr:housenumber tag';
COMMENT ON COLUMN osm.shop_polygon.street IS 'Value from addr:street tag';
COMMENT ON COLUMN osm.shop_polygon.city IS 'Value from addr:city tag';
COMMENT ON COLUMN osm.shop_polygon.state IS 'Value from addr:state tag';

COMMENT ON COLUMN osm.shop_polygon.wheelchair IS 'Indicates if building is wheelchair accessible.';

-- osm_type column only has shop/amenity values.
-- Indexing osm_subtype b/c has more selective and seems more likely to be used.
CREATE INDEX ix_osm_shop_point_type ON osm.shop_point (osm_subtype);
CREATE INDEX ix_osm_shop_polygon_type ON osm.shop_polygon (osm_subtype);


CREATE VIEW osm.vshop_all AS
SELECT osm_id, 'N' AS geom_type, osm_type, osm_subtype, name,
        address, phone, wheelchair, operator, brand, website, geom
    FROM osm.shop_point
UNION
SELECT osm_id, 'W' AS geom_type, osm_type, osm_subtype, name,
        address, phone, wheelchair, operator, brand, website, 
        ST_Centroid(geom) AS geom
    FROM osm.shop_polygon
;

COMMENT ON VIEW osm.vshop_all IS 'Converts polygon shops to point with ST_Centroid(), combines with source points using UNION.';
COMMENT ON COLUMN osm.vshop_all.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';
COMMENT ON COLUMN osm.vshop_all.address IS 'Simple attempt to combine address parts into single column with COALESCE.';
COMMENT ON COLUMN osm.vshop_all.name IS 'Best name option determined by helpers.get_name(). Keys with priority are: name, short_name, alt_name and loc_name.  See pgosm-flex/flex-config/helpers.lua for full logic of selection.';
COMMENT ON COLUMN osm.vshop_all.geom IS 'Geometry, mix of points loaded by osm2pgsql and points calculated from the ST_Centroid() of the polygons loaded by osm2pgsql.';

COMMENT ON COLUMN osm.vshop_all.wheelchair IS 'Indicates if building is wheelchair accessible.';
COMMENT ON COLUMN osm.vshop_all.geom_type IS 'Type of geometry. N(ode), W(ay) or R(elation).  Unique along with osm_id';
