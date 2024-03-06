-- Functions for fetching data from a HafSQL database

CREATE OR REPLACE FUNCTION fetch_tips()
RETURNS INT
AS $$
DECLARE
 fetched_to BIGINT;
 row RECORD;
BEGIN

-- Check the last trx_id we have added into hive_open_tips
SELECT MAX(hive_open_tips.hafsql_op_id) INTO fetched_to FROM hive_open_tips;

-- Get new tips and loop over them
RAISE NOTICE 'fetching tips data...';

-- We use dblink to connect to a remote db. See https://www.postgresql.org/docs/current/contrib-dblink-function.html
-- We use format() with literals to dynamically build the query. See https://www.postgresql.org/docs/current/plpgsql-statements.html#PLPGSQL-QUOTE-LITERAL-EXAMPLE


FOR row IN
  SELECT *
    FROM dblink('postgresql://hafsql_public:hafsql_public@hafsql.mahdiyari.info:5432/haf_block_log',
    FORMAT('select tips.*, c.parent_author,
       c.parent_permlink
    FROM (
    SELECT t.op_id, 
       t."from", 
       t."to",
       t.amount,
       t.timestamp,
       SUBSTRING(t.memo from %L) AS platform,
       SUBSTRING(t.memo from %L) AS author,
       SUBSTRING(t.memo from %L) AS permlink,
       t.memo
      FROM hafsql.op_transfer t
      WHERE t.memo LIKE %L
      AND t.op_id >= 2018988205
      AND CASE 
        WHEN %L IS NULL THEN TRUE
        ELSE t.op_id > %L
      END
      ORDER BY t.op_id ASC
      limit 10
) tips
join hafsql.op_comment c ON c.permlink = tips.permlink and c.author = tips.author',
'app:(\w*)', '!tip @(.*)/', '!tip @.*/([a-z0-9-]*) ', '!tip%', 2018988205, 2018988205
    )

    )
      AS tips(
            op_id BIGINT, 
            "from" VARCHAR, 
            "to" VARCHAR, 
            amount TEXT, 
            timestamp TIMESTAMP, 
            platform TEXT, 
            author VARCHAR, 
            permlink TEXT,
            memo TEXT,
            parent_author VARCHAR, 
            parent_permlink TEXT
      )
    

  LOOP
  -- Put row results into our db  
  INSERT INTO hive_open_tips(
    hafsql_op_id,
    sender,
    receiver,
    amount,
    token,
    timestamp,
    platform,
    author,
    permlink,
    memo,
    parent_author,
    parent_permlink
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
    row.memo,
    row.parent_author,
    row.parent_permlink
  );
END LOOP;

RETURN 1;

END;
$$
LANGUAGE plpgsql;
