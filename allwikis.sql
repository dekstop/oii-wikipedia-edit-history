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
