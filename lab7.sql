CREATE SCHEMA company_data AUTHORIZATION current_user;
ALTER TABLE public.employees SET SCHEMA company_data;

CREATE OR REPLACE VIEW company_data.employee_details AS
SELECT e.emp_id,e.emp_name,e.salary,d.dept_name,d.location
FROM company_data.employees e
JOIN public.departments d ON e.dept_id=d.dept_id;

CREATE OR REPLACE VIEW public.dept_statistics AS
SELECT d.dept_id,d.dept_name,
COALESCE(COUNT(e.emp_id),0) AS employee_count,
ROUND(COALESCE(AVG(e.salary),0)::numeric,2) AS avg_salary,
COALESCE(MAX(e.salary),0) AS max_salary,
COALESCE(MIN(e.salary),0) AS min_salary
FROM public.departments d
LEFT JOIN company_data.employees e ON e.dept_id=d.dept_id
GROUP BY d.dept_id,d.dept_name
ORDER BY employee_count DESC;

CREATE OR REPLACE VIEW public.project_overview AS
SELECT p.project_id,p.project_name,p.budget,
d.dept_name,d.location,
COALESCE(team.team_size,0) AS team_size
FROM public.projects p
LEFT JOIN public.departments d ON p.dept_id=d.dept_id
LEFT JOIN (
  SELECT dept_id,COUNT(emp_id) AS team_size
  FROM company_data.employees
  WHERE dept_id IS NOT NULL
  GROUP BY dept_id
) team ON team.dept_id=p.dept_id;

CREATE OR REPLACE VIEW public.high_earners AS
SELECT e.emp_id,e.emp_name,e.salary,d.dept_name
FROM company_data.employees e
LEFT JOIN public.departments d ON e.dept_id=d.dept_id
WHERE e.salary>55000;

CREATE OR REPLACE VIEW company_data.employee_details AS
SELECT e.emp_id,e.emp_name,e.salary,
d.dept_name,d.location,
CASE
WHEN e.salary>60000 THEN 'High'
WHEN e.salary>50000 THEN 'Medium'
ELSE 'Standard'
END AS salary_grade
FROM company_data.employees e
JOIN public.departments d ON e.dept_id=d.dept_id;

ALTER VIEW public.high_earners RENAME TO public.top_performers;

CREATE TEMP VIEW temp_view AS
SELECT * FROM company_data.employees WHERE salary<50000;
DROP VIEW IF EXISTS temp_view;

CREATE MATERIALIZED VIEW public.avg_salary_by_department AS
SELECT d.dept_id,d.dept_name,ROUND(AVG(e.salary)::numeric,2) AS avg_salary
FROM public.departments d
LEFT JOIN company_data.employees e ON d.dept_id=e.dept_id
GROUP BY d.dept_id,d.dept_name;

REFRESH MATERIALIZED VIEW public.avg_salary_by_department;

DROP MATERIALIZED VIEW IF EXISTS public.avg_salary_by_department;

CREATE OR REPLACE VIEW company_data.employee_info AS
SELECT emp_id,emp_name,salary FROM company_data.employees
WHERE salary>40000
WITH CHECK OPTION;

UPDATE company_data.employee_info SET salary=45000 WHERE emp_id=4;

CREATE ROLE data_viewer LOGIN PASSWORD 'viewer123';
GRANT CONNECT ON DATABASE current_database() TO data_viewer;
GRANT USAGE ON SCHEMA company_data TO data_viewer;
GRANT SELECT ON company_data.employees TO data_viewer;
GRANT SELECT ON public.departments TO data_viewer;
GRANT SELECT ON public.projects TO data_viewer;

CREATE ROLE analyst LOGIN PASSWORD 'analyst123';
GRANT CONNECT ON DATABASE current_database() TO analyst;
GRANT USAGE ON SCHEMA company_data TO analyst;
GRANT SELECT ON company_data.employees TO analyst;
GRANT SELECT ON public.departments TO analyst;
GRANT SELECT ON public.projects TO analyst;
REVOKE SELECT ON public.projects FROM analyst;

CREATE OR REPLACE VIEW company_data.employees_it_department AS
SELECT emp_id,emp_name,salary
FROM company_data.employees e
JOIN public.departments d ON e.dept_id=d.dept_id
WHERE d.dept_name='IT';

CREATE OR REPLACE VIEW public.projects_with_budget AS
SELECT project_id,project_name,budget
FROM public.projects
WHERE budget>70000;

CREATE OR REPLACE VIEW public.combined_overview AS
SELECT e.emp_name,e.salary,p.project_name,p.budget
FROM company_data.employees e
JOIN public.departments d ON e.dept_id=d.dept_id
JOIN public.projects p ON p.dept_id=d.dept_id;