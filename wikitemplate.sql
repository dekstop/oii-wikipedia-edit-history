DROP SCHEMA IF EXISTS wikitemplate CASCADE;
CREATE SCHEMA wikitemplate;

-- This simply follows the WP MySQL schema, although using Postgres types.
-- All subsequent tables will use our own schema conventions.
CREATE TABLE wikitemplate.wikipedia_geo_tags (
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
CREATE UNIQUE INDEX ON wikitemplate.wikipedia_geo_tags(gt_id);

CREATE TABLE wikitemplate.wikipedia_revisions (
      ns integer NOT NULL,
      page integer NOT NULL,
      revision integer NOT NULL,
      contributor INTEGER DEFAULT NULL,
      iso2 TEXT DEFAULT NULL,
      timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
      sha1_is_known bool NOT NULL
);
CREATE UNIQUE INDEX ON wikitemplate.wikipedia_revisions(page, revision);

CREATE MATERIALIZED VIEW wikitemplate.wikipedia_page_stats AS 
  SELECT ns, page, 
    count(*) num_revisions, 
    sum(sha1_is_known::integer) as num_reverts 
  FROM wikitemplate.wikipedia_revisions 
  GROUP BY ns, page;


CREATE VIEW wikitemplate.view_article_revisions AS
    SELECT page, revision, contributor, iso2, timestamp FROM wikitemplate.wikipedia_revisions WHERE ns=0;

CREATE MATERIALIZED VIEW wikitemplate.article_geotags AS
    SELECT
      gt_id as id, gt_page_id as page,
      gt_primary as primary,
      gt_lat as lat, gt_lon as lon, 
      gt_dim as dim, gt_type as type, 
      gt_name as name, 
      gt_country as country, gt_region as region
    FROM wikitemplate.wikipedia_geo_tags g
    JOIN (SELECT DISTINCT page FROM wikitemplate.view_article_revisions) r ON (g.gt_page_id=r.page)
    WHERE gt_globe='earth'
    ORDER BY page, id;

CREATE MATERIALIZED VIEW wikitemplate.article_geotag_primary AS
    SELECT DISTINCT ON (page) *
    FROM wikitemplate.article_geotags
    WHERE page NOT IN (
      SELECT page 
      FROM wikitemplate.article_geotags 
      GROUP BY page 
      HAVING count(*)>4
    )
    ORDER BY page, "primary" DESC, id ASC;

CREATE MATERIALIZED VIEW wikitemplate.article_country AS
    SELECT page, gid
    FROM wikitemplate.article_geotag_primary g
    JOIN countries ON ST_Contains(geom, ST_Point(lon, lat));

CREATE MATERIALIZED VIEW wikitemplate.article_province AS
    SELECT page, gid
    FROM wikitemplate.article_geotag_primary g
    JOIN provinces ON ST_Contains(geom, ST_Point(lon, lat));
