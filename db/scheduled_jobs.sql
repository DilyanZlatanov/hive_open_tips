-- Create scheduled jobs

-- Delete existing jobs before creating new ones
SELECT timetable.delete_job('fetch-tips-data');
SELECT timetable.add_job('fetch-tips-data','* * * * *','SELECT public.fetch_tips()');

SELECT timetable.delete_job('fetch-tips-data-engine-tips');
SELECT timetable.add_job('fetch-tips-data-engine-tips','* * * * *','SELECT public.fetch_hive_engine_tips()');
