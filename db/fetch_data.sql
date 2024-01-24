-- Functions for fetching data from a HafSQL database

CREATE OR REPLACE FUNCTION fetch_tips()
RETURNS INT
AS $$
DECLARE
 -- dynamic_trx_id INT;
  row RECORD;
BEGIN

-- Check which hafsql id we have fetched up to
--SELECT hive_open_tips.trx_id INTO dynamic_trx_id FROM hive_open_tips;

-- Get new tips and loop over them
RAISE NOTICE 'fetching tips data...';

-- We use dblink to connect to a remote db. See https://www.postgresql.org/docs/current/contrib-dblink-function.html
-- We use format() with literals to dynamically build the query. See https://www.postgresql.org/docs/current/plpgsql-statements.html#PLPGSQL-QUOTE-LITERAL-EXAMPLE

FOR row IN
  SELECT *
  FROM dblink('postgresql://hafsql_public:hafsql_public@hafsql.mahdiyari.info:5432/haf_block_log',
    FORMAT(
     'SELECT op_id, ''from'', ''to'', amount, timestamp, memo
      FROM hafsql.op_transfer
      WHERE memo LIKE %L
      ORDER BY timestamp DESC
      LIMIT 10',
      '!tip%'
    ))
      AS t1(op_id BIGINT, "from" VARCHAR, "to" VARCHAR, amount TEXT, timestamp TIMESTAMP, memo TEXT)
  
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
    permalink
  )
  VALUES (
    row.op_id,
    row."from",
    row."to",
    CAST(row.amount::jsonb->>'amount' AS FLOAT),
    row.amount::jsonb->>'nai'::TEXT,
    row.timestamp,
    (SELECT SUBSTRING(row.memo FROM POSITION('Tip sent through ' IN row.memo))FROM hafsql.op_transfer WHERE hafsql.op_transfer.memo LIKE '%Tip sent through%'),
    row.memo
  );
  END LOOP;

RETURN 1;

END;
$$
LANGUAGE plpgsql;
