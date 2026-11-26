-- Run as a superuser. Group roles are cluster-wide; use a dedicated local demo cluster.
BEGIN;
CREATE ROLE payroll_hr NOLOGIN;
CREATE ROLE payroll_employee NOLOGIN;
CREATE ROLE payroll_admin LOGIN IN ROLE payroll_hr;
CREATE ROLE payroll_emp01 LOGIN IN ROLE payroll_employee;
CREATE ROLE payroll_emp02 LOGIN IN ROLE payroll_employee;
-- Passwords are deliberately not stored here. Set them using psql \password.
SET search_path TO payroll_app, public;
REVOKE ALL ON SCHEMA payroll_app FROM PUBLIC;
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA payroll_app FROM PUBLIC;
GRANT USAGE ON SCHEMA payroll_app TO payroll_hr,payroll_employee;
GRANT SELECT,INSERT,UPDATE,DELETE ON employee,attendance,leave_request TO payroll_hr;
-- Payroll and salary writes use vetted SECURITY DEFINER procedures, not arbitrary DML.
GRANT SELECT ON salary,payroll TO payroll_hr;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA payroll_app TO payroll_hr;
ALTER PROCEDURE set_salary(integer,date,numeric,numeric) SECURITY DEFINER;
ALTER PROCEDURE set_salary(integer,date,numeric,numeric) SET search_path TO pg_catalog,payroll_app,pg_temp;
ALTER PROCEDURE generate_payroll(integer,date) SECURITY DEFINER;
ALTER PROCEDURE generate_payroll(integer,date) SET search_path TO pg_catalog,payroll_app,pg_temp;
GRANT EXECUTE ON PROCEDURE set_salary(integer,date,numeric,numeric),generate_payroll(integer,date) TO payroll_hr;
GRANT EXECUTE ON FUNCTION validate_attendance(),validate_leave() TO payroll_hr;
GRANT SELECT ON employee,attendance,leave_request,salary,payroll TO payroll_employee;
GRANT SELECT ON monthly_attendance,salary_slip,late_marks TO payroll_hr,payroll_employee;
ALTER TABLE employee ENABLE ROW LEVEL SECURITY;
CREATE POLICY hr_all ON employee TO payroll_hr USING (true) WITH CHECK (true);
CREATE POLICY employee_own ON employee FOR SELECT TO payroll_employee USING (login_name=session_user::text);
DO $$ DECLARE t text; BEGIN
 FOR t IN SELECT unnest(ARRAY['attendance','leave_request','salary','payroll']) LOOP
   EXECUTE format('ALTER TABLE payroll_app.%I ENABLE ROW LEVEL SECURITY',t);
   EXECUTE format('CREATE POLICY hr_all ON payroll_app.%I TO payroll_hr USING (true) WITH CHECK (true)',t);
   EXECUTE format('CREATE POLICY employee_own ON payroll_app.%I FOR SELECT TO payroll_employee USING (employee_id IN (SELECT employee_id FROM payroll_app.employee WHERE login_name=session_user::text))',t);
 END LOOP;
END $$;
COMMIT;
