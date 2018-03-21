-- This simply follows the WP MySQL schema, although using Postgres types.
-- All subsequent tables will use our own schema conventions.
DROP TABLE IF EXISTS wikipedia_geo_tags CASCADE;
CREATE TABLE wikipedia_geo_tags (
      gt_id serial NOT NULL,
      gt_page_id serial NOT NULL,
      gt_globe TEXT NOT NULL,
      gt_primary bool NOT NULL,
      gt_lat decimal(11,8) DEFAULT NULL,
      gt_lon decimal(11,8) DEFAULT NULL,
      gt_dim integer DEFAULT NULL,
      gt_type TEXT DEFAULT NULL,
      gt_name TEXT DEFAULT NULL,
      gt_country TEXT DEFAULT NULL,
      gt_region TEXT DEFAULT NULL
);
CREATE UNIQUE INDEX wikipedia_geo_tags_id ON wikipedia_geo_tags(gt_id);

DROP TABLE IF EXISTS wikipedia_anon_revisions CASCADE;
CREATE TABLE wikipedia_anon_revisions (
      ns integer NOT NULL,
      page integer NOT NULL,
      revision integer NOT NULL,
      ip TEXT NOT NULL,
      iso2 TEXT DEFAULT NULL,
      timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL
);
CREATE UNIQUE INDEX wikipedia_anon_revisions_page_revision ON wikipedia_anon_revisions(page, revision);

CREATE OR REPLACE VIEW view_page_revisions AS
    SELECT * FROM wikipedia_anon_revisions WHERE ns=0;

CREATE OR REPLACE VIEW view_page_geotags AS
    SELECT
      gt_id as id, gt_page_id as page,
      gt_primary as primary,
      gt_lat as lat, gt_lon as lon, 
      gt_dim as dim, gt_type as type, 
      gt_name as name, 
      gt_country as country, gt_region as region
    FROM wikipedia_geo_tags g
    JOIN (SELECT DISTINCT page FROM view_page_revisions) r ON (g.gt_page_id=r.page)
    WHERE gt_globe='earth'
    ORDER BY page, id;

CREATE OR REPLACE VIEW view_page_geotag_primary AS
    SELECT DISTINCT ON (page) *
    FROM view_page_geotags
    ORDER BY page, "primary" DESC, id ASC;

