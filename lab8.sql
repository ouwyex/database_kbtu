-- Task 1.1
CREATE TABLE departments (
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location VARCHAR(50)
);
CREATE TABLE employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(100),
    dept_id INT,
    salary DECIMAL(10,2),
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);
CREATE TABLE projects (
    proj_id INT PRIMARY KEY,
    proj_name VARCHAR(100),
    budget DECIMAL(12,2),
    dept_id INT,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- Task 1.2
INSERT INTO departments VALUES
(101, 'IT', 'Building A'),
(102, 'HR', 'Building B'),
(103, 'Operations', 'Building C');
INSERT INTO employees VALUES
(1, 'John Smith', 101, 50000),
(2, 'Jane Doe', 101, 55000),
(3, 'Mike Johnson', 102, 48000),
(4, 'Sarah Williams', 102, 52000),
(5, 'Tom Brown', 103, 60000);
INSERT INTO projects VALUES
(201, 'Website Redesign', 75000, 101),
(202, 'Database Migration', 120000, 101),
(203, 'HR System Upgrade', 50000, 102);

-- Task 2.1
CREATE INDEX emp_salary_idx ON employees(salary);

-- Task 2.2
CREATE INDEX emp_dept_idx ON employees(dept_id);

-- Task 2.3
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'employees';

-- Task 3.1
CREATE INDEX emp_dept_salary_idx ON employees(dept_id, salary);

-- Task 3.2
CREATE INDEX emp_salary_dept_idx ON employees(salary, dept_id);

-- Task 4.1
ALTER TABLE employees ADD COLUMN email VARCHAR(100);
CREATE UNIQUE INDEX emp_email_unique_idx ON employees(email);

-- Task 4.2
ALTER TABLE employees ADD COLUMN phone VARCHAR(20) UNIQUE;

-- Task 5.1
CREATE INDEX emp_salary_desc_idx ON employees(salary DESC);

-- Task 5.2
CREATE INDEX proj_budget_nulls_first_idx ON projects(budget NULLS FIRST);

-- Task 6.1
CREATE INDEX emp_name_lower_idx ON employees(LOWER(emp_name));

-- Task 6.2
ALTER TABLE employees ADD COLUMN hire_date DATE;
UPDATE employees SET hire_date = '2020-01-15' WHERE emp_id = 1;
UPDATE employees SET hire_date = '2019-06-20' WHERE emp_id = 2;
UPDATE employees SET hire_date = '2021-03-10' WHERE emp_id = 3;
UPDATE employees SET hire_date = '2020-11-05' WHERE emp_id = 4;
UPDATE employees SET hire_date = '2018-08-25' WHERE emp_id = 5;
CREATE INDEX emp_hire_year_idx ON employees((EXTRACT(YEAR FROM hire_date)));

-- Task 7.1
ALTER INDEX emp_salary_idx RENAME TO employees_salary_index;

-- Task 7.2
DROP INDEX IF EXISTS emp_salary_dept_idx;

-- Task 7.3
REINDEX INDEX employees_salary_index;

-- Task 8.1
CREATE INDEX emp_salary_filter_idx ON employees(salary) WHERE salary > 50000;

-- Task 8.2
CREATE INDEX proj_high_budget_idx ON projects(budget) WHERE budget > 80000;

-- Task 8.3
EXPLAIN ANALYZE SELECT * FROM employees WHERE salary > 52000;

-- Task 9.1
CREATE INDEX dept_name_hash_idx ON departments USING HASH (dept_name);

-- Task 9.2
CREATE INDEX proj_name_btree_idx ON projects(proj_name);
CREATE INDEX proj_name_hash_idx ON projects USING HASH (proj_name);

-- Task 10.1
SELECT
    schemaname, tablename, indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Task 10.2
DROP INDEX IF EXISTS proj_name_hash_idx;

-- Task 10.3
CREATE OR REPLACE VIEW index_documentation AS
SELECT tablename, indexname, indexdef, 'Improves salary-based queries' AS purpose
FROM pg_indexes
WHERE schemaname='public' AND indexname LIKE '%salary%';
SELECT * FROM index_documentation;



