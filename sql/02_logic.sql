BEGIN;
SET search_path TO payroll_app, public;
CREATE FUNCTION validate_attendance() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE hired date; on_leave boolean;
BEGIN
 PERFORM pg_advisory_xact_lock(NEW.employee_id::bigint);
 SELECT hire_date INTO hired FROM payroll_app.employee WHERE employee_id=NEW.employee_id;
 IF NEW.work_date < hired OR extract(isodow FROM NEW.work_date)>5 THEN
   RAISE EXCEPTION 'Attendance must be on an employed weekday';
 END IF;
 SELECT EXISTS(SELECT 1 FROM payroll_app.leave_request l WHERE l.employee_id=NEW.employee_id
   AND l.status='Approved' AND NEW.work_date BETWEEN l.start_date AND l.end_date) INTO on_leave;
 IF (NEW.status='Leave') <> on_leave THEN RAISE EXCEPTION 'Attendance must match approved leave'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER trg_attendance BEFORE INSERT OR UPDATE ON attendance
 FOR EACH ROW EXECUTE FUNCTION validate_attendance();
CREATE FUNCTION validate_leave() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE hired date;
BEGIN
 IF TG_OP='DELETE' THEN
   PERFORM pg_advisory_xact_lock(OLD.employee_id::bigint);
   IF OLD.status='Approved' AND EXISTS(SELECT 1 FROM payroll_app.attendance a WHERE a.employee_id=OLD.employee_id
     AND a.status='Leave' AND a.work_date BETWEEN OLD.start_date AND OLD.end_date) THEN
     RAISE EXCEPTION 'Remove recorded leave attendance before deleting approval'; END IF;
   RETURN OLD;
 END IF;
 IF TG_OP='UPDATE' AND NEW.employee_id<>OLD.employee_id THEN RAISE EXCEPTION 'Cannot change leave employee'; END IF;
 PERFORM pg_advisory_xact_lock(NEW.employee_id::bigint);
 SELECT hire_date INTO hired FROM payroll_app.employee WHERE employee_id=NEW.employee_id;
 IF NEW.start_date<hired THEN RAISE EXCEPTION 'Leave cannot precede hire date'; END IF;
 IF NEW.status='Approved' THEN
   IF EXISTS(SELECT 1 FROM payroll_app.leave_request l WHERE l.employee_id=NEW.employee_id
     AND l.status='Approved' AND l.leave_id IS DISTINCT FROM NEW.leave_id
     AND l.start_date<=NEW.end_date AND l.end_date>=NEW.start_date) THEN
     RAISE EXCEPTION 'Overlapping approved leave'; END IF;
   IF EXISTS(SELECT 1 FROM payroll_app.attendance a WHERE a.employee_id=NEW.employee_id
     AND a.work_date BETWEEN NEW.start_date AND NEW.end_date AND a.status<>'Leave') THEN
     RAISE EXCEPTION 'Conflicting attendance: correct existing records first'; END IF;
 END IF;
 IF TG_OP='UPDATE' AND OLD.status='Approved' AND EXISTS(SELECT 1 FROM payroll_app.attendance a
   WHERE a.employee_id=OLD.employee_id AND a.status='Leave' AND a.work_date BETWEEN OLD.start_date AND OLD.end_date
   AND (NEW.status<>'Approved' OR a.work_date NOT BETWEEN NEW.start_date AND NEW.end_date)) THEN
   RAISE EXCEPTION 'Change would invalidate recorded leave attendance'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER trg_leave BEFORE INSERT OR UPDATE OR DELETE ON leave_request
 FOR EACH ROW EXECUTE FUNCTION validate_leave();
-- Academic demonstration only, not statutory Indian income tax.
CREATE FUNCTION demo_tax(amount numeric) RETURNS numeric LANGUAGE sql IMMUTABLE STRICT
 AS $$ SELECT round(greatest(amount-25000,0)*0.10,2) $$;
CREATE PROCEDURE set_salary(p_employee integer,p_month date,p_basic numeric,p_allowance numeric)
 LANGUAGE plpgsql AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(p_employee::bigint);
 IF EXISTS(SELECT 1 FROM payroll_app.payroll WHERE employee_id=p_employee AND salary_month=p_month) THEN
   RAISE EXCEPTION 'Salary version already used in payroll; create a new effective month'; END IF;
 INSERT INTO payroll_app.salary VALUES(p_employee,p_month,p_basic,p_allowance)
 ON CONFLICT(employee_id,effective_month) DO UPDATE SET basic=EXCLUDED.basic,allowance=EXCLUDED.allowance;
END $$;
CREATE PROCEDURE generate_payroll(p_employee integer,p_month date) LANGUAGE plpgsql AS $$
DECLARE hired date; sal payroll_app.salary%ROWTYPE; days integer; paid integer; g numeric(12,2);
BEGIN
 IF p_month IS NULL OR extract(day FROM p_month)<>1 THEN RAISE EXCEPTION 'Use first day of month'; END IF;
 PERFORM pg_advisory_xact_lock(p_employee::bigint);
 SELECT hire_date INTO STRICT hired FROM payroll_app.employee WHERE employee_id=p_employee;
 SELECT * INTO STRICT sal FROM payroll_app.salary WHERE employee_id=p_employee AND effective_month<=p_month
 ORDER BY effective_month DESC LIMIT 1;
 SELECT count(*) INTO days FROM generate_series(p_month::timestamp,(p_month+interval '1 month - 1 day')::timestamp,interval '1 day') d
 WHERE extract(isodow FROM d)<=5 AND d::date>=hired;
 IF days=0 THEN RAISE EXCEPTION 'No employed working days in month'; END IF;
 SELECT count(*) INTO paid FROM payroll_app.attendance WHERE employee_id=p_employee AND work_date>=greatest(hired,p_month)
 AND work_date<p_month+interval '1 month' AND status IN ('Present','Leave');
 g:=round((sal.basic+sal.allowance)*paid/days,2);
 INSERT INTO payroll_app.payroll(employee_id,pay_month,salary_month,working_days,paid_days,gross,tax)
 VALUES(p_employee,p_month,sal.effective_month,days,paid,g,payroll_app.demo_tax(g))
 ON CONFLICT(employee_id,pay_month) DO UPDATE SET salary_month=EXCLUDED.salary_month,
 working_days=EXCLUDED.working_days,paid_days=EXCLUDED.paid_days,gross=EXCLUDED.gross,tax=EXCLUDED.tax,calculated_at=now();
END $$;
COMMIT;
