-------------------------------------------------------------------------------
-- jsonb_path_exists
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_jsonb_path_exists AS (tag_key text, value jsonpath);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_jsonb_path_exists(_tag_key text, _value jsonpath)
RETURNS SCHEMA_TAG.tag_op_jsonb_path_exists AS $func$
    SELECT ROW(_tag_key, _value)::SCHEMA_TAG.tag_op_jsonb_path_exists
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

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

CREATE OPERATOR SCHEMA_TAG.!=~ (
    LEFTARG = text,
    RIGHTARG = text,
    FUNCTION = SCHEMA_TAG.tag_op_regexp_not_matches
);

-------------------------------------------------------------------------------
-- equals
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_equals AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_equals(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_equals AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_equals
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR SCHEMA_TAG.== (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_equals
);

-------------------------------------------------------------------------------
-- not_equals
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_not_equals AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_not_equals(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_not_equals AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_not_equals
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR SCHEMA_TAG.!== (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_not_equals
);

-------------------------------------------------------------------------------
-- less_than
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_less_than AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_less_than(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_less_than AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_less_than
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR SCHEMA_TAG.#< (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_less_than
);

-------------------------------------------------------------------------------
-- less_than_or_equal
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_less_than_or_equal AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_less_than_or_equal(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_less_than_or_equal AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_less_than_or_equal
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR SCHEMA_TAG.#<= (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_less_than_or_equal
);

-------------------------------------------------------------------------------
-- greater_than
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_greater_than AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_greater_than(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_greater_than AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_greater_than
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR SCHEMA_TAG.#> (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_greater_than
);

-------------------------------------------------------------------------------
-- greater_than_or_equal
-------------------------------------------------------------------------------
CREATE TYPE SCHEMA_TAG.tag_op_greater_than_or_equal AS (tag_key text, value jsonb);

CREATE OR REPLACE FUNCTION SCHEMA_TAG.tag_op_greater_than_or_equal(_tag_key text, _value anyelement)
RETURNS SCHEMA_TAG.tag_op_greater_than_or_equal AS $func$
    SELECT ROW(_tag_key, to_jsonb(_value))::SCHEMA_TAG.tag_op_greater_than_or_equal
$func$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR SCHEMA_TAG.#>= (
    LEFTARG = text,
    RIGHTARG = anyelement,
    FUNCTION = SCHEMA_TAG.tag_op_greater_than_or_equal
);

