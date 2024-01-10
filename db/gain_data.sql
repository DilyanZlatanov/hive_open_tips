-- Functions for gaining data from a HafSQL database

CREATE OR REPLACE FUNCTION gain_tips()
RETURNS INT
AS $$
DECLARE
  gained_to BIGINT;
  row RECORD;
BEGIN

-- Check which hafsql id we have gained up to
SELECT tips.hafsql_id INTO gained_to FROM tips ORDER BY hafsql_id DESC LIMIT 1;

-- Get new tips and loop over them
RAISE NOTICE 'Gaining tips data...';

-- We use dblink to connect to a remote db. See https://www.postgresql.org/docs/current/contrib-dblink-function.html
-- We use format() with literals to dynamically build the query. See https://www.postgresql.org/docs/current/plpgsql-statements.html#PLPGSQL-QUOTE-LITERAL-EXAMPLE

FOR row IN
  SELECT *
  FROM dblink('postgresql://hafsql_public:hafsql_public@hafsql.mahdiyari.info:5432/haf_block_log',
    FORMAT(
     'SELECT op_id, from, to, amount, timestamp, memo
      FROM hafsql.op_transfer
      WHERE memo LIKE "!tip%"
      ORDER BY timestamp DESC',
    ))
      AS t1(op_id INT, from VARCHAR, to VARCHAR, amount FLOAT, timestamp TIMESTAMP, memo TEXT)
  
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
    row.from,
    row.to,
    row.amount::jsonb->>'amount',
    row.amount::jsonb->>'nai',
    row.timestamp,
    --row.platform,
    row.memo
  );
  END LOOP;

RETURN 1;

END;
$$
LANGUAGE plpgsql;
