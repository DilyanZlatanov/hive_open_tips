-- Create the database for our app, if it doesn't exist already. Adapted from https://stackoverflow.com/a/18389184
DO
$do$
BEGIN
  DROP EXTENSION IF EXISTS dblink;
  CREATE EXTENSION dblink;
  IF EXISTS (SELECT FROM pg_database WHERE datname = 'hive_open_tips')
  THEN -- do nothing
  ELSE
    PERFORM dblink_exec('dbname=' || current_database(), 
      'CREATE DATABASE hive_open_tips');
  END IF;
END
$do$;