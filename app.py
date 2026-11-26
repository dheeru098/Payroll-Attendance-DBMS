"""Payroll & Attendance: role-based PostgreSQL CLI. No credentials stored."""
import os
from getpass import getpass
import psycopg

SCHEMA = 'payroll_app.'

def show(conn, sql, params=()):
    with conn.cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
        if not rows:
            print('No records found.'); return
        headers = [c.name for c in cur.description]
        data = [[str(x) if x is not None else '-' for x in r] for r in rows]
        widths = [max(len(h), *(len(r[i]) for r in data)) for i,h in enumerate(headers)]
        def line(row): return ' | '.join(str(x).ljust(w) for x,w in zip(row,widths))
        print(line(headers)); print('-+-'.join('-'*w for w in widths))
        for r in data: print(line(r))
        print(f'{len(rows)} row(s)')

def month():
    return input('Month (YYYY-MM-01): ').strip()

def execute(conn, sql, params):
    # One atomic transaction per write operation. Rolls back automatically on error.
    with conn.transaction():
        conn.execute(sql, params)
    print('Committed successfully.')

def report(conn, choice):
    m = month()
    if choice == '1':
        show(conn, 'SELECT * FROM payroll_app.monthly_attendance WHERE month=%s::date ORDER BY employee_id', (m,))
    elif choice == '2':
        show(conn, 'SELECT * FROM payroll_app.salary_slip WHERE pay_month=%s::date ORDER BY employee_id', (m,))
    else:
        show(conn, "SELECT * FROM payroll_app.late_marks WHERE work_date >= %s::date AND work_date < %s::date + interval '1 month' ORDER BY work_date,employee_id", (m,m))

def hr_action(conn, choice):
    if choice == '4':
        show(conn, 'SELECT * FROM payroll_app.employee ORDER BY employee_id')
    elif choice == '5':
        execute(conn, 'INSERT INTO payroll_app.employee(full_name,department,email,hire_date) VALUES (%s,%s,%s,%s::date)', tuple(input(p) for p in ('Name: ','Department: ','Email: ','Hire date YYYY-MM-DD: ')))
    elif choice == '6':
        eid=int(input('Employee ID: ')); name=input('New name: '); dept=input('Department: ')
        execute(conn,'UPDATE payroll_app.employee SET full_name=%s,department=%s WHERE employee_id=%s',(name,dept,eid))
    elif choice == '7':
        eid=int(input('Employee ID: ')); day=input('Date YYYY-MM-DD: '); status=input('Present / Absent / Leave: ').strip().title()
        start=input('Check-in HH:MM: ') if status=='Present' else None
        end=input('Check-out HH:MM: ') if status=='Present' else None
        execute(conn,'INSERT INTO payroll_app.attendance(employee_id,work_date,status,check_in,check_out) VALUES (%s,%s::date,%s,%s::time,%s::time)',(eid,day,status,start,end))
    elif choice == '8':
        execute(conn,'INSERT INTO payroll_app.leave_request(employee_id,start_date,end_date,status,reason) VALUES (%s,%s::date,%s::date,%s,%s)',(int(input('Employee ID: ')),input('Start YYYY-MM-DD: '),input('End YYYY-MM-DD: '),input('Pending / Approved / Rejected: ').title(),input('Reason: ')))
    elif choice == '9':
        execute(conn,'CALL payroll_app.set_salary(%s,%s::date,%s::numeric,%s::numeric)',(int(input('Employee ID: ')),month(),input('Basic salary: '),input('Allowance: ')))
    elif choice == '10':
        m=month(); eid=input('Employee ID or ALL: ').strip()
        with conn.transaction():
            ids=[r[0] for r in conn.execute('SELECT employee_id FROM payroll_app.employee WHERE hire_date < %s::date + interval \'1 month\' ORDER BY employee_id',(m,))] if eid.upper()=='ALL' else [int(eid)]
            for i in ids: conn.execute('CALL payroll_app.generate_payroll(%s,%s::date)',(i,m))
        print(f'Committed payroll for {len(ids)} employee(s).')
    elif choice == '11':
        show(conn,'SELECT * FROM payroll_app.leave_request ORDER BY leave_id')
    elif choice == '12':
        execute(conn,'UPDATE payroll_app.leave_request SET status=%s WHERE leave_id=%s',(input('New status Pending / Approved / Rejected: ').title(),int(input('Leave ID: '))))
    else: print('Invalid option.')

def main():
    print('=== Payroll & Attendance | DBMS Capstone ===')
    user=input('Database login: ').strip()
    try:
        with psycopg.connect(host=os.getenv('PGHOST','localhost'),port=os.getenv('PGPORT','5432'),dbname=os.getenv('PGDATABASE','payroll_capstone'),user=user,password=getpass('Password: '),autocommit=True) as conn:
            hr,emp=conn.execute("SELECT pg_has_role(session_user,'payroll_hr','member'),pg_has_role(session_user,'payroll_employee','member')").fetchone()
            if not (hr or emp): print('No application role assigned.'); return
            print('Signed in as', 'HR/Admin' if hr else 'Employee (own records only)')
            while True:
                print('\n1 Monthly attendance | 2 Salary slip | 3 Late marks | 0 Exit')
                if hr:
                    print('4 List employees | 5 Add employee | 6 Edit employee | 7 Record attendance')
                    print('8 Add leave | 9 Set salary | 10 Generate payroll | 11 List leave | 12 Change leave status')
                choice=input('Select: ').strip()
                if choice=='0': break
                try:
                    if choice in ('1','2','3'): report(conn,choice)
                    elif hr: hr_action(conn,choice)
                    else: print('Access denied or invalid option.')
                except (psycopg.Error,ValueError) as exc:
                    print('Operation failed; no incomplete write committed:', exc)
    except psycopg.Error as exc: print('Login/connection failed:',exc)

if __name__=='__main__': main()
