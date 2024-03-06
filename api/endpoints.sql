-- Functions creating API endpoints
-- The function name is the endpoint name, accessible under domain.com/rpc/function_name


-- The following function provides data for every tip-like transfer on the blockchain.
CREATE OR REPLACE FUNCTION tips()
RETURNS TABLE (
   trx_id BIGINT,
   sender VARCHAR(16),
   receiver VARCHAR(16),
   amount FLOAT,
   token VARCHAR(20),
   created TIMESTAMP,
   platform VARCHAR,
   memo TEXT
   )
AS $$

BEGIN
RETURN QUERY

SELECT 
  t.trx_id,
  t.sender, 
  t.receiver, 
  t.amount, 
  t.token,
  t.timestamp,
  t.platform,
  t.memo
FROM hive_open_tips t
ORDER BY trx_id ASC;
      
END;
$$
LANGUAGE plpgsql;

-- This function provides the sum of tips for a specific Hive post. - трябва да е списък а не сумата
CREATE OR REPLACE FUNCTION tips_sum_for_post(v_permlink VARCHAR)
RETURNS TABLE (
   total_tips FLOAT,
   token VARCHAR(20),
   hive_post TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
      t.SUM(amount),
      t.token,
      t.permlink,
      t.parent_author
    FROM hive_open_tips t
    WHERE permlink = v_permlink
    AND parent_author = ''
    GROUP BY permlink, token;
END;
$$
LANGUAGE plpgsql;



-- This function provides the sum of tips for every comment on a specific Hive post. - трябва да е списък на бакшишите към всеки пост
CREATE OR REPLACE FUNCTION tips_sum_for_post_comments(v_permlink VARCHAR)
RETURNS TABLE (
  tips_for_comment FLOAT,
  token VARCHAR(20),
  comment TEXT,
  hive_post TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
      t.amount,
      t.token,
      t.permlink,
      t.parent_permlink
    FROM hive_open_tips t 
    WHERE permlink = v_permlink
    AND parent_permlink != '';
END;
$$
LANGUAGE plpgsql;
