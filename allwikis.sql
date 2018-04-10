DROP SCHEMA IF EXISTS allwikis CASCADE;
CREATE SCHEMA allwikis;

SELECT create_multiwiki_table_view('allwikis', 'article_revisions');
SELECT create_multiwiki_table_view('allwikis', 'wikipedia_page_stats');
SELECT create_multiwiki_table_view('allwikis', 'article_geotags');
SELECT create_multiwiki_table_view('allwikis', 'article_geotag_primary');
SELECT create_multiwiki_table_view('allwikis', 'article_country');
SELECT create_multiwiki_table_view('allwikis', 'article_province');

CREATE MATERIALIZED VIEW allwikis.article_editorloc AS
    SELECT wiki, page, iso2, count(*) num_revisions 
    FROM allwikis.article_revisions
    GROUP BY wiki, page, iso2;

CREATE MATERIALIZED VIEW allwikis.country_editorloc AS
    SELECT ae.wiki, 
        c.iso_a2 as place_iso2, 
        ae.iso2 as editor_iso2, 
        count(distinct ae.page) num_articles,
        sum(ae.num_revisions) num_revisions
    FROM allwikis.article_editorloc ae
    JOIN allwikis.article_country ac ON (ae.wiki=ac.wiki AND ae.page=ac.page)
    JOIN countries c ON (ac.gid=c.gid)
    GROUP BY ae.wiki, c.iso_a2, ae.iso2;

CREATE MATERIALIZED VIEW allwikis.wikistats AS
    SELECT *, num_gt_articles * 1.0 / num_articles as share_gt_articles 
    FROM (
        SELECT t1.wiki, max(size) size, 
            count(distinct(p.ns, p.page)) num_pages,
            count(distinct(p.ns, p.page)) FILTER (WHERE p.ns=0) num_articles,
            count(distinct g.page) num_gt_articles
        FROM (
            SELECT n.nspname as wiki, pg_catalog.pg_size_pretty(sum(pg_total_relation_size(pg_class.oid::regclass))) as size 
            FROM pg_class 
            JOIN pg_catalog.pg_namespace n ON n.oid=pg_class.relnamespace 
            WHERE pg_class.relkind = 'r'::"char" 
            AND n.nspname LIKE '%wiki'
            GROUP BY wiki
            ORDER BY wiki) t1
        LEFT OUTER JOIN allpages.wikipedia_page_stats p ON (t1.wiki=p.wiki)
        LEFT OUTER JOIN allpages.article_geotag_primary g ON (t1.wiki=g.wiki)
        GROUP BY t1.wiki
    ) t2;
