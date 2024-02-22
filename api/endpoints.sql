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


CREATE OR REPLACE FUNCTION tips_sum_for_post(post TEXT)
RETURNS TABLE (
   total_tips FLOAT,
   token VARCHAR(20),
   hive_post VARCHAR(100)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
      t.SUM(amount),
      t.token,
      t.memo
    FROM hive_open_tips t
    WHERE memo = post
    GROUP BY memo, token;
END;
$$
LANGUAGE plpgsql;
