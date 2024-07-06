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
      WHERE (t.memo LIKE %L OR t.memo LIKE %L)
      AND t.op_id >= 2018988205
      AND CASE 
        WHEN %L IS NULL THEN TRUE
        ELSE t.op_id > %L
      END
      ORDER BY t.op_id ASC
      LIMIT 20000
      ) tips
    JOIN hafsql.comments c ON c.permlink = tips.permlink AND c.author = tips.author',
    'app:(\w*)', '(?:!tip|Tip for) @(.*)/', '(?:!tip|Tip for) @.*/([a-z0-9-]*)', '!tip%', 'Tip for @%', fetched_to, fetched_to
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
    parent_permlink,
    author_permlink
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
    row.parent_permlink,
    CONCAT(row.author,'/',row.permlink)
  );
END LOOP;

RETURN 1;

END;
$$
LANGUAGE plpgsql;

-- END of function fetch_tips




-- Fetch tips for verify from Hive Engine
CREATE OR REPLACE FUNCTION fetch_hive_engine_tips()
RETURNS INT
AS $$
DECLARE
  row RECORD;
  is_record_match BOOLEAN;
  current_record BIGINT;
  extracted_platform TEXT;
  extracted_author TEXT;
  extracted_permlink TEXT;
  iteration_count INT := 0;
BEGIN

  SELECT last_saved_record INTO current_record 
  FROM last_saved_record_table 
  WHERE id = 1;

FOR row IN
 SELECT *
 FROM dblink('postgresql://hafsql_public:hafsql_public@hafsql.mahdiyari.info:5432/haf_block_log',
 FORMAT('SELECT tips.*, c.parent_author, c.parent_permlink
 FROM(
    SELECT 
      t.op_id,
      t.timestamp,
      t.required_auths,
      t.json,
      t.json AS author,
      t.json AS permlink
    FROM hafsql.op_custom_json t
    WHERE t.id = %L
    AND t.op_id > %L
    ORDER BY t.op_id ASC
    LIMIT 100000
    ) tips
    JOIN hafsql.comments c ON c.permlink = SUBSTRING(tips.permlink, %L) AND c.author = SUBSTRING(tips.author, %L)',
    'ssc-mainnet-hive',
    current_record,
    '(?:!tip|Tip for) @.*/([a-z0-9-]*)',
    '(?:!tip|Tip for) @(.*)/'
    )
 )
 AS tips(
      op_id BIGINT,
      timestamp TIMESTAMP,
      required_auths VARCHAR,
      json TEXT,
      author VARCHAR,
      permlink TEXT,
      parent_author VARCHAR, 
      parent_permlink TEXT
    )
 
LOOP
  
  iteration_count = iteration_count + 1;

  UPDATE last_saved_record_table 
  SET last_saved_record = row.op_id 
  WHERE id = 1;

  is_record_match := FALSE;

  IF NOT is_record_match THEN
    BEGIN
      -- Attempt to validate JSON and check for the expected structure
      IF row.op_id NOT IN (SELECT hafsql_op_id FROM unverified_transfers)
        AND row.json::jsonb ->> 'contractName' = 'tokens'
        AND row.json::jsonb ->> 'contractAction' = 'transfer'
        AND row.json::jsonb -> 'contractPayload' ? 'to'
        AND row.json::jsonb -> 'contractPayload' ? 'quantity'
        AND (
            row.json::jsonb -> 'contractPayload' ->> 'memo' LIKE '!tip @%'
            OR row.json::jsonb -> 'contractPayload' ->> 'memo' LIKE 'Tip for @%'
        )
      THEN
        is_record_match := TRUE;
      END IF;
      EXCEPTION 
        WHEN OTHERS 
        THEN CONTINUE;
    END;
  END IF;


  IF is_record_match THEN
    BEGIN

      SELECT 
        SUBSTRING(row.json::jsonb -> 'contractPayload' ->> 'memo', 'app:(\w*)'),
        SUBSTRING(row.json::jsonb -> 'contractPayload' ->> 'memo', '(?:!tip|Tip for) @(.*)/'),
        SUBSTRING(row.json::jsonb -> 'contractPayload' ->> 'memo', '(?:!tip|Tip for) @.*/([a-z0-9-]*)')
      INTO
        extracted_platform,
        extracted_author,
        extracted_permlink;


      --Put results into our db
      INSERT INTO unverified_transfers(
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
      parent_permlink,
      author_permlink
      )

      VALUES (
        row.op_id,
        SUBSTRING(row.required_auths FROM 3 FOR LENGTH(row.required_auths) -4),
        row.json::jsonb -> 'contractPayload' ->> 'to',
        CAST(row.json::jsonb -> 'contractPayload' ->> 'quantity' AS FLOAT),
        row.json::jsonb -> 'contractPayload' ->> 'symbol',
        row.timestamp,
        extracted_platform,
        extracted_author,
        extracted_permlink,
        row.json::jsonb -> 'contractPayload' ->> 'memo',
        row.parent_author,
        row.parent_permlink,
        CONCAT(extracted_author,'/',extracted_permlink)
      );
    
    END;

  END IF;

END LOOP;

--Update last_saved_record with +10000 when query is not returning records
IF iteration_count = 0
THEN UPDATE last_saved_record_table 
     SET last_saved_record = (SELECT last_saved_record FROM last_saved_record_table WHERE id = 1) + 10000
     WHERE id = 1;
END IF;

RETURN 1;
END;

$$
LANGUAGE plpgsql;

--END of function fetch_hive_engine_tips
