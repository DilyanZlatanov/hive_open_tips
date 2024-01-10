#! /bin/bash

echo "Starting up Postgres..."
service postgresql start

echo "Creating database..."
sudo -u postgres psql -f /usr/src/app/db/create_db.sql

# Name of the app's database
db_name=hive_open_tips

echo "Setting up pg_timetable..."
# Use peer auth method. See https://github.com/cybertec-postgresql/pg_timetable/discussions/618
sudo -u postgres pg_timetable --clientname=hive_open_tips postgres:///hive_open_tips?host=/var/run/postgresql --init

echo "Configuring database..."
sudo -u postgres psql -d $db_name -f /usr/src/app/db/configure_db.sql

echo "Creating roles..."
sudo -u postgres psql -d $db_name -f /usr/src/app/db/create_roles.sql

echo "Starting pg_timetable..."
# Start it from the scheduler user
sudo -u scheduler pg_timetable --clientname=hive_open_tips postgres:///hive_open_tips?host=/var/run/postgresql &
# Wait until the above process started in the background is complete. This way pg_timetable can create its functions and we can reference them afterwards.
sleep 3

echo "Adding scheduled jobs..."
sudo -u postgres psql -d $db_name -f /usr/src/app/db/scheduled_jobs.sql &
sleep 3

echo "Starting postgREST..."
# Start the postgREST server from the postgrest_auth user
sudo -u postgrest_auth postgrest postgrest.conf
