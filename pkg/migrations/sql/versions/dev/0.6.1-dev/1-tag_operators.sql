CALL SCHEMA_CATALOG.execute_everywhere('create_schemas', $ee$ DO $$ BEGIN

    CREATE SCHEMA IF NOT EXISTS SCHEMA_CATALOG; -- catalog tables + internal functions
    GRANT USAGE ON SCHEMA SCHEMA_CATALOG TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_PROM; -- public functions
    GRANT USAGE ON SCHEMA SCHEMA_PROM TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_EXT; -- optimized versions of functions created by the extension
    GRANT USAGE ON SCHEMA SCHEMA_EXT TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_SERIES; -- series views
    GRANT USAGE ON SCHEMA SCHEMA_SERIES TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_METRIC; -- metric views
    GRANT USAGE ON SCHEMA SCHEMA_METRIC TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_DATA;
    GRANT USAGE ON SCHEMA SCHEMA_DATA TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_DATA_SERIES;
    GRANT USAGE ON SCHEMA SCHEMA_DATA_SERIES TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_INFO;
    GRANT USAGE ON SCHEMA SCHEMA_INFO TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_DATA_EXEMPLAR;
    GRANT USAGE ON SCHEMA SCHEMA_DATA_EXEMPLAR TO prom_reader;
    GRANT ALL ON SCHEMA SCHEMA_DATA_EXEMPLAR TO prom_writer;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_TAG;
    GRANT USAGE ON SCHEMA SCHEMA_TAG TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_TRACING;
    GRANT USAGE ON SCHEMA SCHEMA_TRACING TO prom_reader;

    CREATE SCHEMA IF NOT EXISTS SCHEMA_TRACING_PUBLIC;
    GRANT USAGE ON SCHEMA SCHEMA_TRACING_PUBLIC TO prom_reader;
END $$ $ee$);

DO $$
DECLARE
   new_path text;
BEGIN
   new_path := current_setting('search_path') || format(',%L,%L,%L,%L,%L', 'SCHEMA_TAG', 'SCHEMA_EXT', 'SCHEMA_PROM', 'SCHEMA_METRIC', 'SCHEMA_CATALOG');
   execute format('ALTER DATABASE %I SET search_path = %s', current_database(), new_path);
   execute format('SET search_path = %s', new_path);
END
$$;

INSERT INTO public.prom_installation_info(key, value) VALUES
    ('tagging schema',          'SCHEMA_TAG'),
    ('tracing schema',          'SCHEMA_TRACING_PUBLIC'),
    ('tracing schema private',  'SCHEMA_TRACING');

CREATE SCHEMA IF NOT EXISTS SCHEMA_TAG;
GRANT USAGE ON SCHEMA SCHEMA_TAG TO prom_reader;

CREATE SCHEMA IF NOT EXISTS SCHEMA_TRACING;
GRANT USAGE ON SCHEMA SCHEMA_TRACING TO prom_reader;

CREATE SCHEMA IF NOT EXISTS SCHEMA_TRACING_PUBLIC;
GRANT USAGE ON SCHEMA SCHEMA_TRACING_PUBLIC TO prom_reader;

-------------------------------------------------------------------------------
-- jsonb_path_exists
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_jsonb_path_exists AS (tag_key text, value jsonpath);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_jsonb_path_exists(_tag_key text, _value jsonpath)
RETURNS SCHEMA_TAG.tag_op_jsonb_path_exists AS $func$
    SELECT ROW(_tag_key, _value)::SCHEMA_TAG.tag_op_jsonb_path_exists
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_jsonb_path_exists(text, jsonpath) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_jsonb_path_exists IS $$This function supports the @? operator.$$;

CREATE OPERATOR SCHEMA_TAG.@? (
    LEFTARG = text,
    RIGHTARG = jsonpath,
    FUNCTION = SCHEMA_TAG.tag_op_jsonb_path_exists
);

-------------------------------------------------------------------------------
-- regexp_matches
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_regexp_matches AS (tag_key text, value text);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_regexp_matches(_tag_key text, _value text)
RETURNS SCHEMA_TAG.tag_op_regexp_matches AS $func$
    SELECT ROW(_tag_key, _value)::SCHEMA_TAG.tag_op_regexp_matches
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_regexp_matches(text, text) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_regexp_matches IS $$This function supports the ==~ operator.$$;

CREATE OPERATOR SCHEMA_TAG.==~ (
    LEFTARG = text,
    RIGHTARG = text,
    FUNCTION = SCHEMA_TAG.tag_op_regexp_matches
);

-------------------------------------------------------------------------------
-- regexp_not_matches
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_regexp_not_matches AS (tag_key text, value text);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_regexp_not_matches(_tag_key text, _value text)
RETURNS SCHEMA_TAG.tag_op_regexp_not_matches AS $func$
    SELECT ROW(_tag_key, _value)::SCHEMA_TAG.tag_op_regexp_not_matches
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_regexp_not_matches(text, text) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_regexp_not_matches IS $$This function supports the !=~ operator.$$;

CREATE OPERATOR SCHEMA_TAG.!=~ (
    LEFTARG = text,
    RIGHTARG = text,
    FUNCTION = SCHEMA_TAG.tag_op_regexp_not_matches
);

-------------------------------------------------------------------------------
-- equals
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_equals AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_equals_text(_tag_key text, _value text)
RETURNS SCHEMA_TAG.tag_op_equals AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_equals
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_equals_text(text, text) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_equals_text(text, text) IS $$This function supports the == operator.$$;

CREATE OPERATOR SCHEMA_TAG.== (
    LEFTARG = text,
    RIGHTARG = text,
    FUNCTION = SCHEMA_TAG.tag_op_equals_text
);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_equals(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_equals AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_equals
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_equals(text, anyelement) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_equals(text, anyelement) IS $$This function supports the == operator.$$;

CREATE OPERATOR SCHEMA_TAG.== (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_equals
);

-------------------------------------------------------------------------------
-- not_equals
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_not_equals AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_not_equals_text(_tag_key text, _value text)
RETURNS SCHEMA_TAG.tag_op_not_equals AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_not_equals
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_not_equals_text(text, text) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_not_equals_text(text, text) IS $$This function supports the !== operator.$$;

CREATE OPERATOR SCHEMA_TAG.!== (
    LEFTARG = text,
    RIGHTARG = text,
    FUNCTION = SCHEMA_TAG.tag_op_not_equals_text
);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_not_equals(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_not_equals AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_not_equals
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_not_equals(text, anyelement) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_not_equals IS $$This function supports the !== operator.$$;

CREATE OPERATOR SCHEMA_TAG.!== (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_not_equals
);

-------------------------------------------------------------------------------
-- less_than
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_less_than AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_less_than_text(_tag_key text, _value text)
RETURNS SCHEMA_TAG.tag_op_less_than AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_less_than
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_less_than_text(text, text) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_less_than_text(text, text) IS $$This function supports the #< operator.$$;

CREATE OPERATOR SCHEMA_TAG.#< (
    LEFTARG = text,
    RIGHTARG = text,
    FUNCTION = SCHEMA_TAG.tag_op_less_than_text
);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_less_than(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_less_than AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_less_than
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_less_than(text, anyelement) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_less_than IS $$This function supports the #< operator.$$;

CREATE OPERATOR SCHEMA_TAG.#< (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_less_than
);

-------------------------------------------------------------------------------
-- less_than_or_equal
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_less_than_or_equal AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_less_than_or_equal_text(_tag_key text, _value text)
RETURNS SCHEMA_TAG.tag_op_less_than_or_equal AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_less_than_or_equal
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_less_than_or_equal_text(text, text) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_less_than_or_equal_text(text, text) IS $$This function supports the #<= operator.$$;

CREATE OPERATOR SCHEMA_TAG.#<= (
    LEFTARG = text,
    RIGHTARG = text,
    FUNCTION = SCHEMA_TAG.tag_op_less_than_or_equal_text
);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_less_than_or_equal(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_less_than_or_equal AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_less_than_or_equal
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_less_than_or_equal(text, anyelement) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_less_than_or_equal IS $$This function supports the #<= operator.$$;

CREATE OPERATOR SCHEMA_TAG.#<= (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_less_than_or_equal
);

-------------------------------------------------------------------------------
-- greater_than
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_greater_than AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_greater_than_text(_tag_key text, _value text)
RETURNS SCHEMA_TAG.tag_op_greater_than AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_greater_than
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_greater_than_text(text, text) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_greater_than_text(text, text) IS $$This function supports the #> operator.$$;

CREATE OPERATOR SCHEMA_TAG.#> (
    LEFTARG = text,
    RIGHTARG = text,
    FUNCTION = SCHEMA_TAG.tag_op_greater_than_text
);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_greater_than(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_greater_than AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_greater_than
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_greater_than(text, anyelement) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_greater_than IS $$This function supports the #> operator.$$;

CREATE OPERATOR SCHEMA_TAG.#> (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_greater_than
);

-------------------------------------------------------------------------------
-- greater_than_or_equal
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_greater_than_or_equal AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_greater_than_or_equal_text(_tag_key text, _value text)
RETURNS SCHEMA_TAG.tag_op_greater_than_or_equal AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_greater_than_or_equal
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_greater_than_or_equal_text(text, text) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_greater_than_or_equal_text(text, text) IS $$This function supports the #>= operator.$$;

CREATE OPERATOR SCHEMA_TAG.#>= (
    LEFTARG = text,
    RIGHTARG = text,
    FUNCTION = SCHEMA_TAG.tag_op_greater_than_or_equal_text
);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_greater_than_or_equal(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_greater_than_or_equal AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_greater_than_or_equal
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
GRANT EXECUTE ON FUNCTION SCHEMA_TAG.tag_op_greater_than_or_equal(text, anyelement) TO prom_reader;
COMMENT ON FUNCTION SCHEMA_TAG.tag_op_greater_than_or_equal IS $$This function supports the #>= operator.$$;

CREATE OPERATOR SCHEMA_TAG.#>= (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_greater_than_or_equal
);

