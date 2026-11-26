-- Run with psql as the setup superuser. No changes from these tests should persist.
\set ON_ERROR_STOP on
SET search_path TO payroll_app, public;
DO $$ BEGIN
 IF (SELECT count(*) FROM employee)<>10 OR (SELECT count(*) FROM attendance)<>650 OR (SELECT count(*) FROM payroll)<>30 THEN
   RAISE EXCEPTION 'Unexpected seed counts'; END IF;
 IF demo_tax(25000)<>0 OR demo_tax(35000)<>1000 THEN RAISE EXCEPTION 'Tax error'; END IF;
 RAISE NOTICE 'PASS seed counts and tax boundary';
END $$;
BEGIN;
SET SESSION AUTHORIZATION payroll_admin;
DO $$ BEGIN
 BEGIN
   CALL payroll_app.set_salary(1,'2026-11-01',-1,0);
   RAISE EXCEPTION 'FAIL negative salary accepted';
 EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS negative salary rejected'; END;
 BEGIN
   INSERT INTO payroll_app.attendance(employee_id,work_date,status,check_in,check_out) VALUES(1,'2026-08-03','Present','09:00','18:00');
   RAISE EXCEPTION 'FAIL duplicate accepted';
 EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'PASS duplicate attendance rejected'; END;
 BEGIN
   INSERT INTO payroll_app.leave_request(employee_id,start_date,end_date,status,reason) VALUES(1,'2026-08-11','2026-08-12','Approved','Overlap test');
   RAISE EXCEPTION 'FAIL overlap accepted';
 EXCEPTION WHEN raise_exception OR exclusion_violation THEN
   IF SQLERRM='FAIL overlap accepted' THEN RAISE; END IF;
   RAISE NOTICE 'PASS overlapping approved leave rejected'; END;
 BEGIN
   INSERT INTO payroll_app.attendance(employee_id,work_date,status) VALUES(1,'2026-11-07','Absent');
   RAISE EXCEPTION 'FAIL weekend accepted';
 EXCEPTION WHEN raise_exception THEN
   IF SQLERRM='FAIL weekend accepted' THEN RAISE; END IF;
   RAISE NOTICE 'PASS weekend rejected'; END;
 CALL payroll_app.set_salary(1,'2026-11-01',40000,0);
 IF NOT EXISTS(SELECT 1 FROM payroll_app.salary WHERE employee_id=1 AND effective_month='2026-11-01') THEN RAISE EXCEPTION 'Valid salary missing'; END IF;
 RAISE NOTICE 'PASS valid salary write';
END $$;
RESET SESSION AUTHORIZATION;
ROLLBACK;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM salary WHERE employee_id=1 AND effective_month='2026-11-01') THEN RAISE EXCEPTION 'Rollback failed'; END IF;
 RAISE NOTICE 'PASS rollback removed salary write';
END $$;
BEGIN;
SET SESSION AUTHORIZATION payroll_emp01;
DO $$ BEGIN
 IF (SELECT count(*) FROM payroll_app.employee)<>1 OR (SELECT count(*) FROM payroll_app.salary_slip)<>3 OR
 (SELECT count(*) FROM payroll_app.attendance WHERE employee_id<>1)<>0 OR
 (SELECT count(*) FROM payroll_app.salary_slip WHERE employee_id<>1)<>0 THEN RAISE EXCEPTION 'RLS failed'; END IF;
 RAISE NOTICE 'PASS employee sees only own records';
 BEGIN
   UPDATE payroll_app.attendance SET status='Absent' WHERE employee_id=1;
   RAISE EXCEPTION 'FAIL unauthorized update accepted';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS unauthorized write rejected'; END;
 BEGIN
   CALL payroll_app.generate_payroll(2,'2026-10-01');
   RAISE EXCEPTION 'FAIL unauthorized procedure accepted';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS unauthorized payroll procedure rejected'; END;
END $$;
RESET SESSION AUTHORIZATION;
ROLLBACK;
