-- A plpgsql command to create a joint table view across all wiki languages:
-- SELECT create_multiwiki_table_view('all_wikis', 'article_geotags');
-- SELECT * FROM all_wikis.article_geotags WHERE ...;
CREATE OR REPLACE FUNCTION create_multiwiki_table_view(
    global_schema TEXT,
    view_table_name TEXT
) 
RETURNS VOID AS $$
DECLARE
    schema RECORD;
    query TEXT;
    first_table BOOL DEFAULT TRUE;
BEGIN
    EXECUTE 'DROP VIEW IF EXISTS ' ||
        quote_ident(global_schema) || '.' || 
        quote_ident(view_table_name);
    query := 'CREATE VIEW ' || quote_ident(global_schema) || '.' || 
        quote_ident(view_table_name) || ' AS ';
    FOR schema IN 
        SELECT table_schema 
        FROM information_schema.tables 
        WHERE table_schema LIKE '%wiki'
        AND table_name=view_table_name
        ORDER BY table_schema
    LOOP 
        -- RAISE NOTICE '%', schema.table_schema;
        IF first_table THEN
          first_table = FALSE;
        ELSE
          query := query || ' UNION ALL';
        END IF;
        query := query || ' SELECT ' || 
          quote_literal(schema.table_schema) || ' wiki, * FROM ' || 
          quote_ident(schema.table_schema) || '.' || 
          quote_ident(view_table_name);
    END LOOP;
    EXECUTE query;
END;
$$ LANGUAGE plpgsql;
