-- Create tables

\c hive_open_tips;

CREATE TABLE hive_open_tips (
   trx_id BIGINT PRIMARY KEY,
   sender VARCHAR(16) NOT NULL,
   receiver VARCHAR(16) NOT NULL,
   amount FLOAT NOT NULL,
   token VARCHAR(20) NOT NULL,
   timestamp TIMESTAMP NOT NULL,
   platform VARCHAR(50),
   memo TEXT
   );

CREATE INDEX idx_sender ON hive_open_tips USING HASH (sender);
CREATE INDEX idx_receiver ON hive_open_tips USING HASH (receiver);
CREATE INDEX idx_memo ON hive_open_tips USING HASH (memo);

-- Create functions for fetching the app data and for providing data API
\i /usr/src/app/db/fetch_data.sql
\i /usr/src/app/api/provide_data_api.sql

-- Add dblink extension to our app's db
DROP EXTENSION IF EXISTS dblink;
CREATE EXTENSION dblink;