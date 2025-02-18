-- Loads the `conf` var from layerset INI file
require "layerset"

local driver = require('luasql.postgres')
local env = driver.postgres()

local pgosm_conn_env = os.getenv("PGOSM_CONN")
local pgosm_conn = nil

if pgosm_conn_env then
    pgosm_conn = pgosm_conn_env
else
    error('ENV VAR PGOSM_CONN must be set.')
end

layers = {'amenity', 'building', 'indoor', 'infrastructure', 'landuse'
          , 'leisure'
          , 'natural', 'place', 'poi', 'public_transport'
          , 'road', 'road_major', 'shop', 'tags'
          , 'traffic', 'unitable', 'water'}


local function post_processing(layerset)
    print(string.format('Post-processing %s', layerset))
    local filename = string.format('sql/%s.sql', layerset)
    local sql_file = io.open(filename, 'r')
    sql_raw = sql_file:read( '*all' )
    sql_file:close()
    local result = con:execute(sql_raw)
    --print(result) -- Returns 0.0 on success?  nil on error?
end


-- Establish connection to Postgres
con = assert (env:connect(pgosm_conn))

-- simple query to verify connection
cur = con:execute"SELECT version() AS pg_version;"

row = cur:fetch ({}, "a")
while row do
  print(string.format("Postgres version: %s", row.pg_version))
  -- reusing the table of results
  row = cur:fetch (row, "a")
end


post_processing('pgosm-meta')

for ix, layer in ipairs(layers) do
    if conf['layerset'][layer] then
        post_processing(layer)
    end
end


-- close everything
cur:close()
con:close()
env:close()
