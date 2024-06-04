-- Unindexed FK -- Missing indexes - For CI

WITH y AS (
SELECT
pg_catalog.format('%I', c1.relname)  AS referencing_tbl,
pg_catalog.quote_ident(a1.attname) AS referencing_column,
(SELECT pg_get_expr(indpred, indrelid) FROM pg_catalog.pg_index WHERE indrelid = t.conrelid AND indkey[0] = t.conkey[1] AND indpred IS NOT NULL LIMIT 1) partial_statement
FROM pg_catalog.pg_constraint t
JOIN pg_catalog.pg_attribute  a1 ON a1.attrelid = t.conrelid AND a1.attnum = t.conkey[1]
JOIN pg_catalog.pg_class  c1 ON c1.oid = t.conrelid
JOIN pg_catalog.pg_namespace  n1 ON n1.oid = c1.relnamespace
JOIN pg_catalog.pg_class  c2 ON c2.oid = t.confrelid
JOIN pg_catalog.pg_namespace  n2 ON n2.oid = c2.relnamespace
JOIN pg_catalog.pg_attribute  a2 ON a2.attrelid = t.confrelid AND a2.attnum = t.confkey[1]
WHERE t.contype = 'f'
AND NOT EXISTS (
SELECT 1
FROM pg_catalog.pg_index i
WHERE i.indrelid = t.conrelid
AND i.indkey[0] = t.conkey[1]
AND indpred IS NULL
)
)
SELECT  referencing_tbl || '.' || referencing_column as "column"
FROM y
WHERE (partial_statement IS NULL OR partial_statement <> ('(' || referencing_column || ' IS NOT NULL)'))
ORDER BY 1;