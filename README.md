# Payroll & Attendance Management System
DBMS capstone | PostgreSQL 15+ and Python 3.10+ | 5 connected phases

This academic application manages employee details, attendance, leave, salary history and payroll. All five phases use the single schema defined in `sql/01_schema.sql`. The schema is proposed for Phase 1 approval; no approval is claimed. Sample data are fictional.

## Setup on Windows (PowerShell, VS Code)
1. Install PostgreSQL 15 or newer with command-line tools (or use your existing local installation), and Python 3.10+. Add PostgreSQL's `bin` folder to PATH if `psql` is not recognized. Open the extracted project folder in VS Code.
2. Use a new local database and a dedicated demo PostgreSQL cluster; the script creates cluster-wide roles and is intended to run once. Replace `postgres` with your administrator if different.

```powershell
psql -U postgres -h localhost -c "CREATE DATABASE payroll_capstone;"
psql -U postgres -h localhost -d payroll_capstone -f setup.sql 2>&1 | Tee-Object docs/setup-output.txt
```

3. Set passwords interactively (choose different strong local passwords; never commit them):

```powershell
psql -U postgres -h localhost -d payroll_capstone
```

At the `psql` prompt:

```text
\password payroll_admin
\password payroll_emp01
\password payroll_emp02
\q
```

4. Start the Python CLI:

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe app.py
```

Use `payroll_admin` for HR, `payroll_emp01` for Aarav, or `payroll_emp02` for Ananya. Enter the password you set. Other seed employees do not have login accounts; the DBA can provision them by creating a new LOGIN role in `payroll_employee` and setting the corresponding `employee.login_name`. The app defaults to localhost:5432/payroll_capstone; override PGHOST, PGPORT, PGDATABASE environment variables if necessary.

## Demo and evidence
* Log in as `payroll_admin`; select 1, 2, or 3, and enter `2026-09-01` for the three reports. HR should see all applicable employees.
* Exit and log in as `payroll_emp01`. Run the same reports. Only employee 1 records should appear, and HR choices must not be available. Try entering `9`; access must be denied.
* Capture screenshots of both logins (never show passwords), report outputs, and the BEFORE / AFTER EXPLAIN output in `docs/setup-output.txt`.
* Run database tests as the setup superuser and keep actual output:

```powershell
psql -U postgres -h localhost -d payroll_capstone -f tests/test_cases.sql 2>&1 | Tee-Object docs/test-output.txt
```

* If the normal plan stays sequential on a small dataset, record that honestly. The script also prints an explicitly labeled diagnostic plan with sequential scans discouraged. Do not pass that off as a natural improvement; explain planner cost or test on a larger isolated dataset.
* The Python file was syntax-checked during preparation. PostgreSQL execution and screenshots have not been verified; capture them locally before final submission.

## Phase map
| Phase | Deliverables |
|---|---|
| 1 | `docs/ER_Diagram.png`, `sql/01_schema.sql`, report normalization explanation |
| 2 | `sql/02_logic.sql`, `sql/03_seed.sql` (10 fictional employees, 650 weekday attendance rows, 30 payroll rows expected) |
| 3 | `sql/04_reports.sql`, `sql/05_indexes.sql`, before/after EXPLAIN and three reports |
| 4 | `sql/06_security.sql`, `tests/test_cases.sql`, Python transaction handling |
| 5 | `app.py`, `setup.sql`, this README, report, and locally generated evidence |

## Rules and limitations
- Monday–Friday workdays; no holiday calendar, overtime, or statutory payroll compliance. Late means strictly after 09:15. Approved leave is paid only when recorded as Leave in attendance. Missing weekdays count as unpaid. Monthly gross = (basic + allowance) × paid days / employed weekdays, rounded to two decimals. Demo tax = 10% of gross above 25,000; not actual Indian tax. Net = gross − tax.
- Payroll snapshots are recalculated only on explicit generation. Salary versions already used by payroll cannot be edited via the salary procedure. HR has all-employee access and writes through procedures for payroll/salary. Employee users have SELECT only with row-level security (RLS) using their actual database login, including in security-invoker views. Admin is an application role, not a PostgreSQL superuser.
- Leave approvals and attendance are cross-validated, with a GiST exclusion constraint for approved leave overlap. Constraints reject duplicate attendance, invalid time pairs and invalid amounts. Advisory locks serialize relevant writes by employee. Production should further constrain employee hire-date amendments, use audit logging and secure managed infrastructure.
- `setup.sql` is not an idempotent migration; use a fresh dedicated database/cluster for a clean rerun. The PostgreSQL `btree_gist` extension must be available. No credentials are in the repository.

## GitHub submission
Create an empty GitHub repository named `Payroll-Attendance-DBMS` (do not initialize it with README if using the following commands). In the extracted project directory:

```powershell
git init
git add .
git commit -m "Build payroll and attendance DBMS capstone"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/Payroll-Attendance-DBMS.git
git push -u origin main
```

Alternatively, use GitHub's web upload feature to upload the extracted folder contents (not just a ZIP). Verify the repo opens and contains the source files, report and actual demo evidence. Submit the repository URL in the GitHub submission field, and the final PDF in Zosima's PDF upload field. No repository has been created by this package.
