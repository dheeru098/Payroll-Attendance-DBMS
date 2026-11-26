BEGIN;
SET search_path TO payroll_app, public;
INSERT INTO employee(full_name,department,email,hire_date,login_name) VALUES
 ('Aarav Sharma','Engineering','aarav@example.test','2026-01-05','payroll_emp01'),
 ('Ananya Verma','HR','ananya@example.test','2026-01-05','payroll_emp02'),
 ('Kabir Mehta','Engineering','kabir@example.test','2026-01-05',NULL),
 ('Diya Singh','Finance','diya@example.test','2026-01-05',NULL),
 ('Ishaan Gupta','Support','ishaan@example.test','2026-01-05',NULL),
 ('Meera Joshi','Engineering','meera@example.test','2026-01-05',NULL),
 ('Arjun Rao','Operations','arjun@example.test','2026-01-05',NULL),
 ('Riya Patel','Finance','riya@example.test','2026-01-05',NULL),
 ('Vivaan Das','Support','vivaan@example.test','2026-01-05',NULL),
 ('Sara Khan','Engineering','sara@example.test','2026-01-05',NULL);
INSERT INTO salary(employee_id,effective_month,basic,allowance)
 SELECT employee_id,'2026-08-01',30000+employee_id*2500,5000 FROM employee;
INSERT INTO leave_request(employee_id,start_date,end_date,status,reason) VALUES
 (1,'2026-08-10','2026-08-11','Approved','Personal'),
 (2,'2026-09-14','2026-09-15','Approved','Family'),
 (3,'2026-10-12','2026-10-12','Approved','Medical'),
 (4,'2026-10-19','2026-10-20','Pending','Personal');
WITH days AS (
 SELECT e.employee_id,d::date AS day FROM employee e CROSS JOIN
 generate_series(timestamp '2026-08-01',timestamp '2026-10-31',interval '1 day') d
 WHERE extract(isodow FROM d)<=5
), statuses AS (
 SELECT *, CASE WHEN EXISTS (SELECT 1 FROM leave_request l WHERE l.employee_id=days.employee_id
 AND l.status='Approved' AND day BETWEEN l.start_date AND l.end_date) THEN 'Leave'
 WHEN (extract(day FROM day)::int+employee_id)%19=0 THEN 'Absent' ELSE 'Present' END AS st FROM days
)
INSERT INTO attendance(employee_id,work_date,status,check_in,check_out)
 SELECT employee_id,day,st,CASE WHEN st='Present' THEN CASE WHEN (extract(day FROM day)::int+employee_id)%17=0
 THEN time '09:25' ELSE time '09:00' END END,CASE WHEN st='Present' THEN time '18:00' END FROM statuses;
DO $$ DECLARE e record; m date; BEGIN
 FOR e IN SELECT employee_id FROM payroll_app.employee LOOP
  FOR m IN SELECT generate_series(timestamp '2026-08-01',timestamp '2026-10-01',interval '1 month')::date LOOP
   CALL payroll_app.generate_payroll(e.employee_id,m);
  END LOOP;
 END LOOP;
END $$;
COMMIT;
