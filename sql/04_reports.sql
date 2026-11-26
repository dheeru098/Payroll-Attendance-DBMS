BEGIN;
SET search_path TO payroll_app, public;
CREATE VIEW monthly_attendance WITH (security_invoker=true) AS
 SELECT e.employee_id,e.full_name,date_trunc('month',a.work_date::timestamp)::date AS month,
 count(*) AS recorded_days,count(*) FILTER(WHERE a.status='Present') AS present_days,
 count(*) FILTER(WHERE a.status='Absent') AS absent_days,count(*) FILTER(WHERE a.status='Leave') AS leave_days,
 count(*) FILTER(WHERE a.status='Present' AND a.check_in>time '09:15') AS late_days
 FROM employee e JOIN attendance a USING(employee_id) GROUP BY e.employee_id,e.full_name,date_trunc('month',a.work_date::timestamp)::date;
CREATE VIEW salary_slip WITH (security_invoker=true) AS
 SELECT e.employee_id,e.full_name,p.pay_month,p.working_days,p.paid_days,s.basic,s.allowance,p.gross,p.tax,p.net
 FROM payroll p JOIN employee e USING(employee_id) JOIN salary s ON s.employee_id=p.employee_id AND s.effective_month=p.salary_month;
CREATE VIEW late_marks WITH (security_invoker=true) AS
 SELECT e.employee_id,e.full_name,a.work_date,a.check_in FROM attendance a JOIN employee e USING(employee_id)
 WHERE a.status='Present' AND a.check_in>time '09:15';
COMMIT;
