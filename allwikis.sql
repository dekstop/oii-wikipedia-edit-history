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
    SELECT t1.wiki, size, num_pages, num_articles, num_gt_articles,
        num_gt_articles * 1.0 / num_articles as share_gt_articles
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
        SELECT wiki, count(distinct(page)) num_pages,
            count(distinct(page)) FILTER (WHERE ns=0) num_articles
        FROM allwikis.page_stats
        GROUP BY wiki
    ) t2 ON (t1.wiki=t2.wiki)
    LEFT OUTER JOIN (-- geotag stats
        SELECT wiki, count(distinct page) num_gt_articles
        FROM allwikis.article_geotag_primary
        GROUP BY wiki
    ) t3 ON (t1.wiki=t3.wiki)
    ORDER BY t1.wiki;
