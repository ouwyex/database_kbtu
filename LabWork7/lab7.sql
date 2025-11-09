-- 2.1
CREATE OR REPLACE VIEW employee_details AS
SELECT e.emp_id, e.emp_name, e.salary, d.dept_name, d.location
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id;

-- 2.2
CREATE OR REPLACE VIEW dept_statistics AS
SELECT d.dept_id, d.dept_name,
COALESCE(COUNT(e.emp_id),0) AS employee_count,
ROUND(COALESCE(AVG(e.salary),0)::numeric,2) AS avg_salary,
COALESCE(MAX(e.salary),0) AS max_salary,
COALESCE(MIN(e.salary),0) AS min_salary
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name;

-- 2.3
CREATE OR REPLACE VIEW project_overview AS
SELECT p.project_id, p.project_name, p.budget, d.dept_name, d.location,
COALESCE(team.team_size,0) AS team_size
FROM projects p
LEFT JOIN departments d ON p.dept_id = d.dept_id
LEFT JOIN (
  SELECT dept_id, COUNT(emp_id) AS team_size
  FROM employees
  WHERE dept_id IS NOT NULL
  GROUP BY dept_id
) team ON team.dept_id = p.dept_id;

-- 2.4
CREATE OR REPLACE VIEW high_earners AS
SELECT e.emp_id, e.emp_name, e.salary, d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > 55000;

-- 3.1
CREATE OR REPLACE VIEW employee_details AS
SELECT e.emp_id, e.emp_name, e.salary, d.dept_name, d.location,
CASE
  WHEN e.salary > 60000 THEN 'High'
  WHEN e.salary > 50000 THEN 'Medium'
  ELSE 'Standard'
END AS salary_grade
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id;

-- 3.2
ALTER VIEW IF EXISTS high_earners RENAME TO top_performers;

-- 3.3
CREATE TEMP VIEW temp_view AS
SELECT emp_id, emp_name, dept_id, salary FROM employees WHERE salary < 50000;
DROP VIEW IF EXISTS temp_view;

-- 4.1
CREATE OR REPLACE VIEW employee_salaries AS
SELECT emp_id, emp_name, dept_id, salary FROM employees
WITH LOCAL CHECK OPTION;

-- 4.2
UPDATE employee_salaries SET salary = 52000 WHERE emp_name = 'John Smith';

-- 4.3
INSERT INTO employee_salaries (emp_id, emp_name, dept_id, salary)
VALUES (6, 'Alice Johnson', 102, 58000);

-- 4.4
CREATE OR REPLACE VIEW it_employees AS
SELECT emp_id, emp_name, dept_id, salary FROM employees
WHERE dept_id = 101
WITH LOCAL CHECK OPTION;

-- 5.1
CREATE MATERIALIZED VIEW dept_summary_mv WITH DATA AS
SELECT
  d.dept_id,
  d.dept_name,
  COUNT(e.emp_id) AS total_employees,
  COALESCE(SUM(e.salary),0) AS total_salaries,
  COALESCE(COUNT(p.project_id),0) AS total_projects,
  COALESCE(SUM(p.budget),0) AS total_project_budget
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
LEFT JOIN projects p ON p.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name;

-- 5.2
INSERT INTO employees (emp_id, emp_name, dept_id, salary) VALUES (8, 'Charlie Brown', 101, 54000);
REFRESH MATERIALIZED VIEW dept_summary_mv;

-- 5.3
CREATE UNIQUE INDEX IF NOT EXISTS ux_dept_summary_mv_dept_id ON dept_summary_mv(dept_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY dept_summary_mv;

-- 5.4
CREATE MATERIALIZED VIEW project_stats_mv WITH NO DATA AS
SELECT p.project_id, p.project_name, p.budget, d.dept_name, COUNT(e.emp_id) AS assigned_employees
FROM projects p
LEFT JOIN departments d ON p.dept_id = d.dept_id
LEFT JOIN employees e ON e.dept_id = p.dept_id
GROUP BY p.project_id, p.project_name, p.budget, d.dept_name;
REFRESH MATERIALIZED VIEW project_stats_mv;

-- 6.1
CREATE ROLE analyst NOLOGIN;
CREATE ROLE data_viewer LOGIN PASSWORD 'viewer123';
CREATE ROLE report_user LOGIN PASSWORD 'report456';

-- 6.2
CREATE ROLE db_creator LOGIN PASSWORD 'creator789' CREATEDB;
CREATE ROLE user_manager LOGIN PASSWORD 'manager101' CREATEROLE;
CREATE ROLE admin_user LOGIN PASSWORD 'admin999' SUPERUSER;

-- 6.3
GRANT SELECT ON employees, departments, projects TO analyst;
GRANT ALL PRIVILEGES ON employee_details TO data_viewer;
GRANT SELECT, INSERT ON employees TO report_user;

-- 6.4
CREATE ROLE hr_team;
CREATE ROLE finance_team;
CREATE ROLE it_team;
CREATE ROLE hr_user1 LOGIN PASSWORD 'hr001';
CREATE ROLE hr_user2 LOGIN PASSWORD 'hr002';
CREATE ROLE finance_user1 LOGIN PASSWORD 'fin001';
GRANT hr_team TO hr_user1;
GRANT hr_team TO hr_user2;
GRANT finance_team TO finance_user1;
GRANT SELECT, UPDATE ON employees TO hr_team;
GRANT SELECT ON dept_statistics TO finance_team;

-- 6.5
REVOKE UPDATE ON employees FROM hr_team;
REVOKE hr_team FROM hr_user2;
REVOKE ALL PRIVILEGES ON employee_details FROM data_viewer;

-- 6.6
ALTER ROLE analyst WITH LOGIN PASSWORD 'analyst123';
ALTER ROLE user_manager WITH SUPERUSER;
ALTER ROLE analyst WITH PASSWORD NULL;
ALTER ROLE data_viewer WITH CONNECTION LIMIT 5;

-- 7.1
CREATE ROLE read_only;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_only;
CREATE ROLE junior_analyst LOGIN PASSWORD 'junior123';
CREATE ROLE senior_analyst LOGIN PASSWORD 'senior123';
GRANT read_only TO junior_analyst;
GRANT read_only TO senior_analyst;
GRANT INSERT, UPDATE ON employees TO senior_analyst;

-- 7.2
CREATE ROLE project_manager LOGIN PASSWORD 'pm123';
ALTER VIEW dept_statistics OWNER TO project_manager;
ALTER TABLE projects OWNER TO project_manager;

-- 7.3
CREATE ROLE temp_owner LOGIN;
CREATE TABLE temp_table (id INT);
ALTER TABLE temp_table OWNER TO temp_owner;
REASSIGN OWNED BY temp_owner TO postgres;
DROP OWNED BY temp_owner;
DROP ROLE IF EXISTS temp_owner;

-- 7.4
CREATE OR REPLACE VIEW hr_employee_view AS
SELECT emp_id, emp_name, dept_id, salary FROM employees WHERE dept_id = 102;
GRANT SELECT ON hr_employee_view TO hr_team;
CREATE OR REPLACE VIEW finance_employee_view AS
SELECT emp_id, emp_name, salary FROM employees;
GRANT SELECT ON finance_employee_view TO finance_team;

-- 8.1
CREATE OR REPLACE VIEW dept_dashboard AS
SELECT
  d.dept_id,
  d.dept_name,
  d.location,
  COUNT(e.emp_id) AS employee_count,
  ROUND(COALESCE(AVG(e.salary),0)::numeric,2) AS avg_salary,
  COALESCE(COUNT(p.project_id),0) AS active_projects,
  COALESCE(SUM(p.budget),0) AS total_project_budget,
  CASE WHEN COUNT(e.emp_id)=0 THEN 0 ELSE ROUND((COALESCE(SUM(p.budget),0)/COUNT(e.emp_id))::numeric,2) END AS budget_per_employee
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
LEFT JOIN projects p ON p.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name, d.location;

-- 8.2
ALTER TABLE projects ADD COLUMN IF NOT EXISTS created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE VIEW high_budget_projects AS
SELECT p.project_id, p.project_name, p.budget, d.dept_name, p.created_date,
CASE
  WHEN p.budget > 150000 THEN 'Critical Review Required'
  WHEN p.budget > 100000 THEN 'Management Approval Needed'
  ELSE 'Standard Process'
END AS approval_status
FROM projects p
LEFT JOIN departments d ON p.dept_id = d.dept_id
WHERE p.budget > 75000;

-- 8.3
CREATE ROLE viewer_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO viewer_role;
CREATE ROLE entry_role;
GRANT viewer_role TO entry_role;
GRANT INSERT ON employees, projects TO entry_role;
CREATE ROLE analyst_role;
GRANT entry_role TO analyst_role;
GRANT UPDATE ON employees, projects TO analyst_role;
CREATE ROLE manager_role;
GRANT analyst_role TO manager_role;
GRANT DELETE ON employees, projects TO manager_role;
CREATE ROLE alice LOGIN PASSWORD 'alice123';
CREATE ROLE bob LOGIN PASSWORD 'bob123';
CREATE ROLE charlie LOGIN PASSWORD 'charlie123';
GRANT viewer_role TO alice;
GRANT analyst_role TO bob;
GRANT manager_role TO charlie;
