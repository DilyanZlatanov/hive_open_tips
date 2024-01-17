-- Create scheduled jobs

-- Delete existing jobs before creating new ones
SELECT timetable.delete_job('fetch-tips-data');
SELECT timetable.add_job('fetch-tips-data','* * * * *','SELECT public.fetch_tips()');
