-- Functions creating API endpoints
-- The function name is the endpoint name, accessible under domain.com/rpc/function_name

-- This function provides a list for tips for a specific Hive post.
CREATE OR REPLACE FUNCTION tips_list_for_post(v_author VARCHAR, v_permlink TEXT)
RETURNS TABLE (
  amount FLOAT,
  author VARCHAR(16),
  op_id BIGINT,
  memo TEXT,
  parent_author VARCHAR(16),
  parent_permlink TEXT,
  permlink TEXT,
  platform VARCHAR(50),
  sender VARCHAR(16),
  tip_timestamp TIMESTAMP,
  token VARCHAR(20)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
      t.amount,
      t.author,
      t.hafsql_op_id,
      t.memo,
      t.parent_author,
      t.parent_permlink,
      t.permlink,
      t.platform,
      t.sender,
      t.timestamp,
      t.token
    FROM hive_open_tips t
    WHERE t.parent_author IS NULL
    AND t.author = $1
    AND t.permlink = $2;
END;
$$
LANGUAGE plpgsql;



-- This function provides list for tips for every comment on a specific Hive post.
CREATE OR REPLACE FUNCTION tips_list_for_post_comments(v_author VARCHAR, v_permlink TEXT)
RETURNS TABLE (
  amount FLOAT,
  author VARCHAR(16),
  op_id BIGINT,
  memo TEXT,
  parent_author VARCHAR(16),
  parent_permlink TEXT,
  permlink TEXT,
  platform VARCHAR(50),
  sender VARCHAR(16),
  tip_timestamp TIMESTAMP,
  token VARCHAR(20)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
      t.amount,
      t.author,
      t.hafsql_op_id,
      t.memo,
      t.parent_author,
      t.parent_permlink,
      t.permlink,
      t.platform,
      t.sender,
      t.timestamp,
      t.token
    FROM hive_open_tips t 
    WHERE t.parent_permlink IS NOT NULL
    AND t.author = $1
    AND t.permlink = $2;
END;
$$
LANGUAGE plpgsql;
  

-- This function accepts POST request. You can pass JSONB array as parameter based on author_permlink column from hive_open_tips table.
CREATE OR REPLACE FUNCTION tips_for_multi_posts_selection(posts JSONB)
RETURNS TABLE(
  amount FLOAT,
  author VARCHAR(16),
  op_id BIGINT,
  memo TEXT,
  parent_author VARCHAR(16),
  parent_permlink TEXT,
  permlink TEXT,
  platform VARCHAR(50),
  sender VARCHAR(16),
  tip_timestamp TIMESTAMP,
  token VARCHAR(20)
)
AS $$
BEGIN
  RETURN QUERY 
  SELECT
    t.amount,
    t.author,
    t.hafsql_op_id,
    t.memo,
    t.parent_author,
    t.parent_permlink,
    t.permlink,
    t.platform,
    t.sender,
    t.timestamp,
    t.token
  FROM hive_open_tips t
  WHERE t.author_permlink = ANY(SELECT jsonb_array_elements_text($1));
END;
$$
LANGUAGE plpgsql;
