-- Get the names of all namespaces that follow the naming convention "%wiki".
-- Returns a table with a single text column, "name".
CREATE OR REPLACE FUNCTION get_wiki_namespaces()
RETURNS TABLE(name TEXT) AS $$
DECLARE
    schema RECORD;
BEGIN
    FOR schema IN
        SELECT nspname AS name
        FROM pg_catalog.pg_namespace
        WHERE nspname LIKE '%wiki'
        ORDER BY name
    LOOP
        -- RAISE NOTICE '%', schema.name;
        name := schema.name;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Creates an enum type "wiki", with one entry per wiki namespace.
CREATE OR REPLACE FUNCTION create_wiki_enum_type()
RETURNS VOID AS $$
DECLARE
    wiki RECORD;
    query TEXT;
    first_table BOOL DEFAULT TRUE;
BEGIN
    EXECUTE 'DROP TYPE IF EXISTS wiki';
    query := 'CREATE TYPE wiki AS ENUM (';
    FOR wiki IN SELECT get_wiki_namespaces()
    LOOP
        -- RAISE NOTICE '%', wiki.name;
        IF first_table THEN
          first_table = FALSE;
        ELSE
          query := query || ', ';
        END IF;
        query := query || quote_literal(wiki.name);
    END LOOP;
    query := query || ')';
    EXECUTE query;
END;
$$ LANGUAGE plpgsql;

-- A plpgsql command to create a joint table view across all wiki languages.
-- Depends on the "wiki" enum type to be already defined (see above).
-- SELECT create_multiwiki_table_view('all_wikis', 'article_geotags');
-- SELECT all_wikis.article_geotags WHERE ...;
CREATE OR REPLACE FUNCTION create_multiwiki_table_view(
    global_schema TEXT,
    view_table_name TEXT
) 
RETURNS VOID AS $$
DECLARE
    wiki RECORD;
    query TEXT;
    first_table BOOL DEFAULT TRUE;
BEGIN
    EXECUTE 'DROP VIEW IF EXISTS ' ||
        quote_ident(global_schema) || '.' || 
        quote_ident(view_table_name);
    query := 'CREATE VIEW ' || quote_ident(global_schema) || '.' || 
        quote_ident(view_table_name) || ' AS ';
    FOR wiki IN SELECT get_wiki_namespaces()
    LOOP 
        -- RAISE NOTICE '%', wiki.name;
        IF first_table THEN
          first_table = FALSE;
        ELSE
          query := query || ' UNION ALL';
        END IF;
        query := query || ' SELECT ' || 
          quote_literal(wiki.name) || '::wiki wiki, * FROM ' || 
          quote_ident(wiki.name) || '.' || 
          quote_ident(view_table_name);
    END LOOP;
    EXECUTE query;
END;
$$ LANGUAGE plpgsql;
