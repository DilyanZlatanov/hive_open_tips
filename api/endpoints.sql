-- Functions creating API endpoints
-- The function name is the endpoint name, accessible under domain.com/rpc/function_name

-- This function provides a list for tips for a specific Hive post.
CREATE OR REPLACE FUNCTION tips_list_for_post(v_author VARCHAR, v_permlink TEXT)
RETURNS TABLE (
  op_id VARCHAR(18),
  "timestamp" TIMESTAMP,
  amount FLOAT,
  token VARCHAR(20),
  sender VARCHAR(16),
  author VARCHAR(16),
  permlink TEXT,
  parent_author VARCHAR(16),
  parent_permlink TEXT,
  memo TEXT,
  platform VARCHAR(50)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
    CAST(t.hafsql_op_id AS VARCHAR),
    t.timestamp,
    t.amount,
    t.token,
    t.sender,
    t.author,
    t.permlink,
    t.parent_author,
    t.parent_permlink,
    t.memo,
    t.platform
    FROM hive_open_tips t
    WHERE t.parent_author = '' 
    AND t.author_permlink = $1 || '/' || $2;
END;
$$
LANGUAGE plpgsql;



-- This function provides list for tips for every comment on a specific Hive post.
CREATE OR REPLACE FUNCTION tips_list_for_post_comments(v_author VARCHAR, v_permlink TEXT)
RETURNS TABLE (
  op_id VARCHAR(18),
  "timestamp" TIMESTAMP,
  amount FLOAT,
  token VARCHAR(20),
  sender VARCHAR(16),
  author VARCHAR(16),
  permlink TEXT,
  parent_author VARCHAR(16),
  parent_permlink TEXT,
  memo TEXT,
  platform VARCHAR(50)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
    CAST(t.hafsql_op_id AS VARCHAR),
    t.timestamp,
    t.amount,
    t.token,
    t.sender,
    t.author,
    t.permlink,
    t.parent_author,
    t.parent_permlink,
    t.memo,
    t.platform
    FROM hive_open_tips t 
    WHERE t.parent_author != ''
    AND t.parent_author = $1
    AND t.parent_permlink = $2;
END;
$$
LANGUAGE plpgsql;
  

-- This function accepts POST request. You can pass JSONB array as parameter based on author_permlink column from hive_open_tips table.
CREATE OR REPLACE FUNCTION tips_for_multi_posts_selection(posts JSONB)
RETURNS TABLE(
  op_id VARCHAR(18),
  "timestamp" TIMESTAMP,
  amount FLOAT,
  token VARCHAR(20),
  sender VARCHAR(16),
  author VARCHAR(16),
  permlink TEXT,
  parent_author VARCHAR(16),
  parent_permlink TEXT,
  memo TEXT,
  platform VARCHAR(50)
)
AS $$
BEGIN
  RETURN QUERY 
  SELECT
  CAST(t.hafsql_op_id AS VARCHAR),
  t.timestamp,
  t.amount,
  t.token,
  t.sender,
  t.author,
  t.permlink,
  t.parent_author,
  t.parent_permlink,
  t.memo,
  t.platform
  FROM hive_open_tips t
  WHERE t.author_permlink = ANY(SELECT jsonb_array_elements_text($1));
END;
$$
LANGUAGE plpgsql;
