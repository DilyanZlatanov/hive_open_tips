-- Script for creating database roles for this HAF app

DO $$
BEGIN

-- If it exists, each role first has all its privileges removed and then it's dropped. See https://stackoverflow.com/a/51257346

-- Role to be used as the postgREST authenticator role
IF EXISTS (SELECT FROM pg_roles WHERE rolname='postgrest_auth') THEN
  DROP OWNED BY postgrest_auth; DROP ROLE postgrest_auth;
END IF;
CREATE ROLE postgrest_auth LOGIN NOINHERIT NOCREATEDB NOCREATEROLE NOSUPERUSER;

-- Role to be used as the postgREST anonymous role
IF EXISTS (SELECT FROM pg_roles WHERE rolname='anonymous') THEN
  DROP OWNED BY anonymous; DROP ROLE anonymous;
END IF;
CREATE ROLE anonymous NOLOGIN;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anonymous;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anonymous;

-- Grant the authenticator role the ability to SET ROLE to the anonymous role
-- See https://postgrest.org/en/stable/references/auth.html#user-impersonation
GRANT anonymous TO postgrest_auth;

-- Role needed by pg_timetable to make cron jobs
IF EXISTS (SELECT FROM pg_roles WHERE rolname='scheduler') THEN
  DROP OWNED BY scheduler; DROP ROLE scheduler;
END IF;
CREATE ROLE scheduler LOGIN NOINHERIT NOCREATEDB NOCREATEROLE NOSUPERUSER;
GRANT USAGE ON SCHEMA timetable TO scheduler;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA timetable TO scheduler;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA timetable TO scheduler;

--ToDo: Find a way to separate the pg_timetable role and the app role into two separate roles that have permission to access only their respective areas
--Currently, the pg_timetable process is run by the scheduler OS user, and it has to be able to access the app's tables
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO scheduler;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO scheduler;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO scheduler;

END 
$$;
