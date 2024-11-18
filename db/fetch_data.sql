-- Functions for fetching data from a HafSQL database

CREATE OR REPLACE FUNCTION fetch_tips()
RETURNS INT
AS $$
DECLARE
  start_point BIGINT;
  row RECORD;
BEGIN

-- Update the start point for the next query
SELECT dynamic_start_point INTO start_point 
FROM dynamic_start_point_table 
WHERE id = 1;

-- Get new tips and loop over them
RAISE NOTICE 'fetching tips data...';

-- We use dblink to connect to a remote db. See https://www.postgresql.org/docs/current/contrib-dblink-function.html
-- We use format() with literals to dynamically build the query. See https://www.postgresql.org/docs/current/plpgsql-statements.html#PLPGSQL-QUOTE-LITERAL-EXAMPLE


FOR row IN
  SELECT *
    FROM dblink('postgresql://hafsql_public:hafsql_public@hafsql.mahdiyari.info:5432/haf_block_log',
    FORMAT('SELECT tips.*, c.root_author AS parent_author, c.root_permlink AS parent_permlink
    FROM (
    SELECT t.op_id,
       t."from", 
       t."to",
       t.amount,
       t.symbol,
       t.timestamp,
       SUBSTRING(t.memo from %L) AS platform,
       SUBSTRING(t.memo from %L) AS author,
       SUBSTRING(t.memo from %L) AS permlink,
       t.memo
      FROM hafsql.op_transfer t
      WHERE (t.memo LIKE %L OR t.memo LIKE %L)
      AND t.op_id > %L
      ORDER BY t.op_id ASC
      LIMIT 20000
      ) tips
    JOIN hafsql.comments_table c ON c.permlink = tips.permlink AND c.author = tips.author',
    'app:(\w*)', '(?:!tip|Tip for) @(.*)/', '(?:!tip|Tip for) @.*/([a-z0-9-]*)', '!tip%', 'Tip for @%', start_point
    )

    )
      AS tips(
            op_id BIGINT, 
            "from" VARCHAR, 
            "to" VARCHAR, 
            amount FLOAT,
            symbol VARCHAR, 
            timestamp TIMESTAMP, 
            platform TEXT, 
            author VARCHAR, 
            permlink TEXT,
            memo TEXT,
            parent_author VARCHAR, 
            parent_permlink TEXT
      )
    

  LOOP
  -- Update dynamic_start_point
  UPDATE dynamic_start_point_table 
  SET dynamic_start_point = row.op_id 
  WHERE id = 1;

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
    row.amount,
    row.symbol,
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
  extracted_platform TEXT;
  extracted_author TEXT;
  extracted_permlink TEXT;
  max_block_num INT;
  lower_bound INT;
  upper_bound INT;
  increment INT := 10000;
BEGIN

-- Fetch the maximum block_num to trace when database ends
  SELECT block_num
  INTO max_block_num
  FROM dblink('postgresql://hafsql_public:hafsql_public@hafsql.mahdiyari.info:5432/haf_block_log',
  'SELECT block_num 
   FROM hafsql.op_custom_json
   ORDER BY block_num DESC
   LIMIT 1'
)
AS result(block_num INT);

-- Set bounds for the first fetch
IF (SELECT COUNT(*) FROM last_checked_block_num_table) < 1 THEN
INSERT INTO last_checked_block_num_table (lower_block_num_bound, upper_block_num_bound) VALUES (90789995, 90799995);
END IF;

  RAISE NOTICE 'fetching hive engine tips...';
  
  -- Set bounds for current fetch
  SELECT lower_block_num_bound, upper_block_num_bound INTO lower_bound, upper_bound
  FROM last_checked_block_num_table 
  WHERE id = 1;


FOR row IN
 SELECT *
 FROM dblink('postgresql://hafsql_public:hafsql_public@hafsql.mahdiyari.info:5432/haf_block_log',
 FORMAT('SELECT tips.*, c.root_author AS parent_author, c.root_permlink AS parent_permlink, hafsql.get_trx_id(tips.op_id) AS trx_id
 FROM(
    SELECT
      t.op_id,
      t.timestamp,
      t.required_auths,
      t.json,
      t.json AS author,
      t.json AS permlink,
      t.block_num
    FROM hafsql.op_custom_json t
    WHERE t.id = %L
    AND t.block_num > %L
    AND t.block_num < %L
    GROUP BY t.op_id, t.timestamp, t.required_auths, t.json, t.block_num
    ORDER BY t.op_id ASC
    LIMIT 200000
    ) tips
    JOIN hafsql.comments c ON c.permlink = SUBSTRING(tips.permlink, %L) AND c.author = SUBSTRING(tips.author, %L)
    JOIN hafsql.op_comment opc
    ON  c.author = opc.author
    AND c.permlink = opc.permlink',
    'ssc-mainnet-hive',
    lower_bound,
    upper_bound,
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
      block_num INT,
      parent_author VARCHAR, 
      parent_permlink TEXT,
      trx_id TEXT
    )
 
LOOP

  RAISE NOTICE 'current block number is: %', row.block_num;
  -- Update bounds for next fetch
  UPDATE last_checked_block_num_table 
  SET lower_block_num_bound = row.block_num,
      upper_block_num_bound = (row.block_num + increment)
  WHERE id = 1;
  
  is_record_match := FALSE;

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
      author_permlink,
      trx_id
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
        CONCAT(extracted_author,'/',extracted_permlink),
        row.trx_id
      );
    
    END;

  END IF;

END LOOP;

-- If no records were fetched, increase both bounds by the increment value
IF NOT FOUND THEN
  UPDATE last_checked_block_num_table
  SET lower_block_num_bound = lower_block_num_bound + increment,
      upper_block_num_bound = upper_block_num_bound + increment
  WHERE id = 1;
  RAISE NOTICE 'No records found, advancing bounds to % - %', lower_bound + increment, upper_bound + increment;
END IF;

-- Avoid exceed the database
IF lower_bound > max_block_num THEN
  UPDATE last_checked_block_num_table
  SET lower_block_num_bound = max_block_num - 1,
      upper_block_num_bound = max_block_num + (increment - 1)
  WHERE id = 1;
  RAISE NOTICE 'Avoid exceed database, advancing bounds to % - %', max_block_num - 1, max_block_num + (increment - 1);
END IF;

RETURN 1;
END;

$$
LANGUAGE plpgsql;

--END of function fetch_hive_engine_tips
