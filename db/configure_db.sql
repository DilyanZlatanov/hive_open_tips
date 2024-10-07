-- Create tables

\c hive_open_tips;

--main table
CREATE TABLE IF NOT EXISTS hive_open_tips (
   hafsql_op_id BIGINT PRIMARY KEY,
   sender VARCHAR(20) NOT NULL,
   receiver VARCHAR(20) NOT NULL,
   amount FLOAT NOT NULL,
   token VARCHAR(20) NOT NULL,
   timestamp TIMESTAMP NOT NULL,
   platform VARCHAR(50),
   author VARCHAR(16),
   permlink TEXT,
   memo TEXT,
   parent_author VARCHAR(16),
   parent_permlink TEXT,
   author_permlink TEXT
   );

CREATE INDEX IF NOT EXISTS idx_sender ON hive_open_tips USING HASH (sender);
CREATE INDEX IF NOT EXISTS idx_receiver ON hive_open_tips USING HASH (receiver);
CREATE INDEX IF NOT EXISTS idx_memo ON hive_open_tips USING HASH (memo);


--unverified transfers from hafsql.op_custom_json
CREATE TABLE IF NOT EXISTS unverified_transfers (
   hafsql_op_id BIGINT PRIMARY KEY,
   sender VARCHAR(20),
   receiver VARCHAR(20),
   amount FLOAT,
   token VARCHAR(20),
   timestamp TIMESTAMP,
   platform VARCHAR(50),
   author VARCHAR(20),
   permlink TEXT,
   memo TEXT,
   parent_author VARCHAR(20),
   parent_permlink TEXT,
   author_permlink TEXT,
   trx_id TEXT
   );


-- This table is defining new start point for fetch_tips() function to avoid fetching same records
CREATE TABLE IF NOT EXISTS dynamic_start_point_table (
   id SERIAL PRIMARY KEY,
   dynamic_start_point BIGINT
);
-- This is the first tip record
INSERT INTO dynamic_start_point_table (dynamic_start_point) VALUES (183067199966029313);


--This table is helping to escape fetching same records in fetch_hive_engine_tips()
CREATE TABLE IF NOT EXISTS last_checked_block_num_table (
    id SERIAL PRIMARY KEY,
    last_checked_block_num BIGINT
);



-- Create functions for fetching the app data and for providing data API
\i /usr/src/app/db/fetch_data.sql
\i /usr/src/app/api/endpoints.sql

-- Add dblink extension to our app's db
DROP EXTENSION IF EXISTS dblink;
CREATE EXTENSION dblink;