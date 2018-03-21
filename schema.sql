-- This simply follows the WP MySQL schema, although using Postgres types
DROP TABLE IF EXISTS wikipedia_geo_tags;
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

-- This is now using our own schema conventions
DROP TABLE IF EXISTS wikipedia_anon_revisions;
CREATE TABLE wikipedia_anon_revisions (
      ns integer NOT NULL,
      page integer NOT NULL,
      revision integer NOT NULL,
      ip TEXT NOT NULL,
      iso2 TEXT DEFAULT NULL,
      timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL
);
CREATE UNIQUE INDEX wikipedia_anon_revisions_page_revision ON wikipedia_anon_revisions(page, revision);

