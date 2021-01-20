COMMENT ON TABLE osm.infrastructure_point IS 'OpenStreetMap infrastructure layer.  Generated by osm2pgsql Flex output using pgosm-flex/flex-config/infrasturcture.lua';
COMMENT ON COLUMN osm.infrastructure_point.osm_type IS '.';


ALTER TABLE osm.infrastructure_point
	ADD CONSTRAINT pk_osm_infrastructure_point_osm_id
    PRIMARY KEY (osm_id)
;

CREATE INDEX ix_osm_infrastructure_point_highway ON osm.infrastructure_point (osm_type);

COMMENT ON COLUMN osm.infrastructure_point.osm_id IS 'OpenStreetMap ID. Unique along with geometry type.';
COMMENT ON COLUMN osm.infrastructure_point.ele IS 'Elevation in meters';

COMMENT ON COLUMN osm.infrastructure_point.name IS 'Best name option determined by helpers.get_name(). Keys with priority are: name, short_name, alt_name and loc_name.  See pgosm-flex/flex-config/helpers.lua for full logic of selection.';

COMMENT ON COLUMN osm.infrastructure_point.height IS 'Object height.  Should be in meters (m) but is not enforced.  Please fix data in OpenStreetMap.org if incorrect values are discovered.';

