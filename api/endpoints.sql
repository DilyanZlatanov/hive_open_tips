-- Functions creating API endpoints
-- The function name is the endpoint name, accessible under domain.com/rpc/function_name

-- This function provides a list for tips for a specific Hive post.
CREATE OR REPLACE FUNCTION tips_list_for_post(author VARCHAR, permlink TEXT)
RETURNS TABLE (
   tip FLOAT,
   token VARCHAR(20),
   hive_post TEXT,
   from_sender VARCHAR(16),
   to_receiver VARCHAR(16)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
      t.amount,
      t.token,
      t.permlink,
      t.sender,
      t.receiver
    FROM hive_open_tips t
    WHERE t.parent_author = ''
    AND t.author = $1
    AND t.permlink = $2;
END;
$$
LANGUAGE plpgsql;



-- This function provides list for tips for every comment on a specific Hive post.
CREATE OR REPLACE FUNCTION tips_list_for_post_comments(author VARCHAR, permlink TEXT)
RETURNS TABLE (
  tip_for_comment FLOAT,
  token VARCHAR(20),
  comment TEXT,
  parent_post TEXT,
  from_sender VARCHAR(16),
  to_receiver VARCHAR(16)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
      t.amount,
      t.token,
      t.permlink,
      t.parent_permlink,
      t.sender,
      t.receiver
    FROM hive_open_tips t 
    WHERE t.parent_permlink != ''
    AND t.author = $1
    AND t.permlink = $2;
END;
$$
LANGUAGE plpgsql;
  

-- This function accepts POST request. You can pass JSONB array as parameter based on author_permlink column from hive_open_tips table.
CREATE OR REPLACE FUNCTION tips_for_multi_posts_selection(posts JSONB)
RETURNS TABLE(
  hafsql_op_id BIGINT,
  sender VARCHAR(16),
  receiver VARCHAR(16),
  amount FLOAT,
  token VARCHAR(20),
  tip_timestamp TIMESTAMP,
  platform VARCHAR(50),
  author VARCHAR(16),
  permlink TEXT,
  memo TEXT,
  parent_author VARCHAR(50),
  parent_permlink TEXT
)
AS $$
BEGIN
  RETURN QUERY 
  SELECT
  t.hafsql_op_id,
  t.sender,
  t.receiver,
  t.amount,
  t.token,
  t.timestamp,
  t.platform,
  t.author,
  t.permlink,
  t.memo,
  t.parent_author,
  t.parent_permlink
  FROM hive_open_tips t
  WHERE t.author_permlink = ANY(SELECT jsonb_array_elements_text($1));
END;
$$
LANGUAGE plpgsql;
