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
     'SELECT
       t.op_id, 
       t."from", 
       t."to",
       t.amount,
       t.timestamp,
       SUBSTRING(t.memo from ''app:(\w*)'') AS platform,
       SUBSTRING(t.memo from ''!tip @(.*)/'') AS author,
       SUBSTRING(t.memo from ''!tip @.*/([a-z0-9-]*) '') AS permlink,
       c.parent_author,
       c.parent_permlink,
       t.memo
      FROM hafsql.op_transfer t
      JOIN hafsql.op_comment c
       ON c.permlink = permlink AND c.author = author
       WHERE t.memo LIKE %L
       AND t.op_id >= 2018988205
       AND CASE
         WHEN %L IS NULL THEN TRUE
         ELSE t.op_id > %L
       END
      ORDER BY t.op_id ASC
      LIMIT 10',
      '!tip%', dynamic_trx_id, dynamic_trx_id
      
    )) 
      AS t1(op_id BIGINT, "from" VARCHAR, "to" VARCHAR, amount TEXT, timestamp TIMESTAMP, platform TEXT, author VARCHAR, permlink TEXT, parent_author VARCHAR, parent_permlink TEXT, memo TEXT)
  
  LOOP
  -- Check if row.op_id already exists in hive_open_tips.trx_id
  PERFORM 1 FROM hive_open_tips WHERE trx_id = row.op_id;
  IF NOT FOUND THEN
  -- Put row results into our db  
  INSERT INTO hive_open_tips(
    trx_id,
    sender,
    receiver,
    amount,
    token,
    timestamp,
    platform,
    author,
    permlink,
    parent_author,
    parent_permlink,
    memo
  )
  VALUES (
    row.op_id,
    row."from",
    row."to",
    CAST(row.amount::jsonb->>'amount' AS FLOAT),
    CASE
      WHEN row.amount::jsonb->>'nai' = '@@000000021' THEN 'HIVE'::TEXT
      WHEN row.amount::jsonb->>'nai' = '@@000000013' THEN 'HBD'::TEXT
      ELSE row.amount::jsonb->>'nai'::TEXT
    END,
    row.timestamp,
    row.platform,
    row.author,
    row.permlink,
    row.parent_author,
    row.parent_permlink,
    row.memo
  );
  END IF;
  END LOOP;

RETURN 1;

END;
$$
LANGUAGE plpgsql;
