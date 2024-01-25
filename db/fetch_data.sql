-- Functions for fetching data from a HafSQL database

CREATE OR REPLACE FUNCTION fetch_tips()
RETURNS INT
AS $$
DECLARE
 dynamic_trx_id BIGINT;
 row RECORD;
BEGIN

-- Check the last trx_id we have added into hive_open_tips
SELECT MAX(hive_open_tips.trx_id) INTO dynamic_trx_id FROM hive_open_tips;

-- Get new tips and loop over them
RAISE NOTICE 'fetching tips data...';

-- We use dblink to connect to a remote db. See https://www.postgresql.org/docs/current/contrib-dblink-function.html
-- We use format() with literals to dynamically build the query. See https://www.postgresql.org/docs/current/plpgsql-statements.html#PLPGSQL-QUOTE-LITERAL-EXAMPLE

FOR row IN
  SELECT *
  FROM dblink('postgresql://hafsql_public:hafsql_public@hafsql.mahdiyari.info:5432/haf_block_log',
    FORMAT(
     'SELECT op_id, "from", "to", amount, timestamp, memo, SUBSTRING(memo from ''app:(\w*)'')
      FROM hafsql.op_transfer
      WHERE memo LIKE %L
      AND CASE
        WHEN %L IS NULL THEN TRUE
        ELSE op_id > %L
      END
      ORDER BY timestamp ASC',
      '!tip%', dynamic_trx_id, dynamic_trx_id
    ))
      AS t1(op_id BIGINT, "from" VARCHAR, "to" VARCHAR, amount TEXT, timestamp TIMESTAMP, memo TEXT, platform TEXT)
  
  LOOP
  -- Put row results into our db  
  INSERT INTO hive_open_tips(
    trx_id,
    sender,
    receiver,
    amount,
    token,
    timestamp,
    platform,
    memo
  )
  VALUES (
    row.op_id,
    row."from",
    row."to",
    CAST(row.amount::jsonb->>'amount' AS FLOAT),
    row.amount::jsonb->>'nai'::TEXT,
    row.timestamp,
    row.platform,
    row.memo
  );
  END LOOP;

RETURN 1;

END;
$$
LANGUAGE plpgsql;
