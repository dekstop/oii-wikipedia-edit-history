DROP SCHEMA IF EXISTS allwikis CASCADE;
CREATE SCHEMA allwikis;

SELECT create_wiki_enum_type();
SELECT create_multiwiki_table_view('allwikis', 'view_article_revisions');
SELECT create_multiwiki_table_view('allwikis', 'page_stats');
SELECT create_multiwiki_table_view('allwikis', 'page_controversy');
SELECT create_multiwiki_table_view('allwikis', 'article_geotags');
SELECT create_multiwiki_table_view('allwikis', 'article_geotag_primary');
SELECT create_multiwiki_table_view('allwikis', 'article_country');
SELECT create_multiwiki_table_view('allwikis', 'article_province');

CREATE MATERIALIZED VIEW allwikis.article_editorloc AS
    SELECT wiki, page, iso2, count(*) num_revisions 
    FROM allwikis.view_article_revisions
    GROUP BY wiki, page, iso2;

CREATE MATERIALIZED VIEW allwikis.country_editorloc AS
    SELECT ae.wiki, 
        ac.gid as country_gid, 
        ae.iso2 as editor_iso2, 
        count(distinct ae.page) num_articles,
        sum(ae.num_revisions) num_revisions
    FROM allwikis.article_editorloc ae
    JOIN allwikis.article_country ac ON (ae.wiki=ac.wiki AND ae.page=ac.page)
    GROUP BY ae.wiki, ac.gid, ae.iso2;

CREATE MATERIALIZED VIEW allwikis.wiki_stats AS
    SELECT t1.wiki, size, num_pages, num_articles, 
        num_gt_articles, num_gt_articles * 1.0 / num_articles as share_gt_articles,
        num_controv_articles, num_controv_articles * 1.0 / num_articles as share_controv_articles
    FROM (-- namespace sizes
        SELECT n.nspname::wiki as wiki, pg_catalog.pg_size_pretty(sum(pg_total_relation_size(pg_class.oid::regclass))) as size 
        FROM pg_class 
        JOIN pg_catalog.pg_namespace n ON n.oid=pg_class.relnamespace 
        WHERE n.nspname IN (-- namespace name matches a wiki enum
            SELECT e.enumlabel
            FROM pg_enum e
            JOIN pg_type t ON e.enumtypid = t.oid
            WHERE t.typname = 'wiki')
        GROUP BY wiki
    ) t1
    JOIN (-- page/article stats
        SELECT wiki, count(distinct page) num_pages,
            count(distinct page) FILTER (WHERE ns=0) num_articles
        FROM allwikis.page_stats
        GROUP BY wiki
    ) t2 ON (t1.wiki=t2.wiki)
    LEFT OUTER JOIN (-- geotag stats
        SELECT wiki, count(distinct page) num_gt_articles
        FROM allwikis.article_geotag_primary
        GROUP BY wiki
    ) t3 ON (t1.wiki=t3.wiki)
    LEFT OUTER JOIN (-- controversy stats
        SELECT wiki, count(distinct page) num_controv_articles
        FROM allwikis.page_controversy
        WHERE ns=0 AND controversy_score>=1000
        GROUP BY wiki
    ) t4 ON (t1.wiki=t4.wiki)
    ORDER BY t1.wiki;

-- A helper join table to track annual page activity. For every page, a row for 
-- every year of its existence, with a flag for the initial year of page creation.
CREATE MATERIALIZED VIEW allwikis.page_years AS
    WITH all_years AS (
        SELECT first_year + generate_series(0,last_year-first_year) as year
        FROM (
            SELECT 
                date_part('year', min(created_at))::int first_year, 
                date_part('year', max(created_at))::int last_year
            FROM allwikis.page_stats
        )t1)
    SELECT year, page, (date_part('year', created_at)::int=year) as is_first_year
    FROM allwikis.page_stats
    JOIN all_years ON date_part('year', created_at)::int<=year;
