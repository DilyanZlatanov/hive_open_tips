-- Create scheduled jobs

-- Delete existing jobs before creating new ones
SELECT timetable.delete_job('gain-tips-data');
SELECT timetable.add_job('gain-tips-data','* * * * *','SELECT public.gain_tips()');