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
  