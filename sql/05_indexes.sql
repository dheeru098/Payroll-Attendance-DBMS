-- Run once after seeding; capture actual output with psql -f or \o.
SET search_path TO payroll_app, public;
ANALYZE attendance;
\echo BEFORE: late-marks report for September
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM late_marks WHERE work_date >= DATE '2026-09-01' AND work_date < DATE '2026-10-01';
CREATE INDEX idx_attendance_late_date ON attendance(work_date,employee_id)
 WHERE status='Present' AND check_in>time '09:15';
CREATE INDEX idx_attendance_work_date ON attendance(work_date);
CREATE INDEX idx_payroll_month ON payroll(pay_month);
ANALYZE attendance;
\echo AFTER: identical report
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM late_marks WHERE work_date >= DATE '2026-09-01' AND work_date < DATE '2026-10-01';
\echo DIAGNOSTIC ONLY: eligible indexed plan if the small dataset favors sequential scan
BEGIN;
SET LOCAL enable_seqscan=off;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM late_marks WHERE work_date >= DATE '2026-09-01' AND work_date < DATE '2026-10-01';
ROLLBACK;
