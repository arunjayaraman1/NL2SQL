-- =============================================================================
-- HR Database Reset + Complex 100-Employee Dataset (No Duplicates)
-- =============================================================================
-- This script clears and recreates schema hr with deterministic synthetic data.
-- Key guarantees:
--   - Exactly 100 employees
--   - No duplicate employees, emails, or employee codes
--   - One annual bonus row per employee (no duplicate join rows)
--   - Uniqueness constraints on common business keys

DROP SCHEMA IF EXISTS hr CASCADE;
CREATE SCHEMA hr;
SET search_path TO hr, public;

-- =============================================================================
-- CORE MASTER TABLES
-- =============================================================================
CREATE TABLE departments (
    id SERIAL PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    department_code VARCHAR(20) NOT NULL UNIQUE,
    location VARCHAR(100) NOT NULL,
    annual_budget NUMERIC(14, 2) NOT NULL CHECK (annual_budget > 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE jobs (
    id SERIAL PRIMARY KEY,
    job_title VARCHAR(120) NOT NULL,
    job_level VARCHAR(20) NOT NULL CHECK (job_level IN ('L1', 'L2', 'L3', 'L4')),
    department_id INTEGER NOT NULL REFERENCES departments(id),
    min_salary NUMERIC(12, 2) NOT NULL CHECK (min_salary > 0),
    max_salary NUMERIC(12, 2) NOT NULL CHECK (max_salary >= min_salary),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (job_title, job_level, department_id)
);

CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    employee_code VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    hire_date DATE NOT NULL,
    department_id INTEGER NOT NULL REFERENCES departments(id),
    job_id INTEGER NOT NULL REFERENCES jobs(id),
    manager_id INTEGER REFERENCES employees(id),
    salary NUMERIC(12, 2) NOT NULL CHECK (salary > 0),
    bonus_target_pct NUMERIC(5, 2) NOT NULL CHECK (bonus_target_pct >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (first_name, last_name)
);

-- =============================================================================
-- HISTORY / TRANSACTION TABLES
-- =============================================================================
CREATE TABLE employees_history (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    status VARCHAR(20) NOT NULL CHECK (status IN ('active', 'on_leave', 'terminated')),
    effective_date DATE NOT NULL,
    reason TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, status, effective_date)
);

CREATE TABLE salaries (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    effective_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, effective_date)
);

CREATE TABLE bonuses (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    bonus_date DATE NOT NULL,
    bonus_type VARCHAR(20) NOT NULL CHECK (bonus_type IN ('performance', 'retention', 'spot')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, bonus_date, bonus_type)
);

CREATE TABLE leave_requests (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    leave_type VARCHAR(20) NOT NULL CHECK (leave_type IN ('vacation', 'sick', 'personal', 'parental')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL CHECK (end_date >= start_date),
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
    approver_id INTEGER REFERENCES employees(id),
    request_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE leave_balances (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    leave_type VARCHAR(20) NOT NULL CHECK (leave_type IN ('vacation', 'sick')),
    year INTEGER NOT NULL CHECK (year BETWEEN 2020 AND 2030),
    balance_days INTEGER NOT NULL CHECK (balance_days >= 0),
    used_days INTEGER NOT NULL CHECK (used_days >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, leave_type, year)
);

CREATE TABLE attendance_logs (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    work_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('present', 'late', 'absent', 'half_day')),
    clock_in TIME,
    clock_out TIME,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, work_date)
);

CREATE TABLE performance_reviews (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    review_year INTEGER NOT NULL CHECK (review_year BETWEEN 2020 AND 2030),
    score INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
    reviewer_id INTEGER REFERENCES employees(id),
    feedback TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, review_year)
);

CREATE TABLE training_enrollments (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    training_name VARCHAR(120) NOT NULL,
    training_date DATE NOT NULL,
    duration_hours INTEGER NOT NULL CHECK (duration_hours > 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('enrolled', 'completed', 'cancelled')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, training_name, training_date)
);

CREATE TABLE certifications (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    cert_name VARCHAR(120) NOT NULL,
    issued_date DATE NOT NULL,
    expiry_date DATE,
    credential_id VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, cert_name, issued_date)
);

CREATE TABLE promotions (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    old_job_id INTEGER REFERENCES jobs(id),
    new_job_id INTEGER REFERENCES jobs(id),
    old_salary NUMERIC(12, 2),
    new_salary NUMERIC(12, 2),
    promotion_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, promotion_date)
);

CREATE TABLE terminations (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL UNIQUE REFERENCES employees(id),
    termination_date DATE NOT NULL,
    reason VARCHAR(200),
    exit_interview_completed BOOLEAN NOT NULL DEFAULT FALSE,
    final_settlement NUMERIC(12, 2),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE approvals (
    id SERIAL PRIMARY KEY,
    request_type VARCHAR(50) NOT NULL CHECK (request_type IN ('leave', 'expense', 'reimbursement')),
    requester_id INTEGER NOT NULL REFERENCES employees(id),
    approver_id INTEGER REFERENCES employees(id),
    request_date DATE NOT NULL DEFAULT CURRENT_DATE,
    approval_date DATE,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
    comments TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id),
    action VARCHAR(50) NOT NULL CHECK (action IN ('create', 'update', 'delete', 'login')),
    table_affected VARCHAR(50),
    record_id INTEGER,
    old_value TEXT,
    new_value TEXT,
    ip_address VARCHAR(45),
    logged_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE emergency_contacts (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id),
    contact_name VARCHAR(100) NOT NULL,
    relationship VARCHAR(30) NOT NULL CHECK (relationship IN ('spouse', 'parent', 'sibling', 'friend', 'other')),
    phone VARCHAR(20) NOT NULL,
    alternate_phone VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (employee_id, contact_name)
);

-- =============================================================================
-- SEED MASTER DATA
-- =============================================================================
INSERT INTO departments (department_name, department_code, location, annual_budget) VALUES
('Engineering', 'ENG', 'HQ-A3', 1500000),
('Human Resources', 'HR', 'HQ-B1', 400000),
('Finance', 'FIN', 'HQ-B2', 700000),
('Marketing', 'MKT', 'HQ-A2', 900000),
('Sales', 'SLS', 'HQ-A1', 1200000),
('Operations', 'OPS', 'HQ-C1', 800000),
('IT Support', 'ITS', 'HQ-C2', 600000),
('Legal', 'LGL', 'HQ-B3', 450000),
('Product', 'PRD', 'HQ-A4', 1100000),
('Research', 'RND', 'HQ-C3', 1000000);

INSERT INTO jobs (job_title, job_level, department_id, min_salary, max_salary) VALUES
('Software Engineer', 'L1', 1, 65000, 90000),
('Software Engineer', 'L2', 1, 85000, 115000),
('Engineering Manager', 'L3', 1, 110000, 155000),
('HR Specialist', 'L1', 2, 50000, 70000),
('HR Manager', 'L3', 2, 85000, 120000),
('Financial Analyst', 'L1', 3, 60000, 85000),
('Finance Manager', 'L3', 3, 95000, 135000),
('Marketing Analyst', 'L1', 4, 55000, 78000),
('Marketing Manager', 'L3', 4, 90000, 130000),
('Sales Executive', 'L1', 5, 50000, 90000),
('Sales Manager', 'L3', 5, 95000, 145000),
('Operations Analyst', 'L1', 6, 55000, 80000),
('Operations Manager', 'L3', 6, 90000, 130000),
('IT Support Engineer', 'L1', 7, 50000, 76000),
('IT Manager', 'L3', 7, 90000, 125000),
('Legal Counsel', 'L2', 8, 90000, 130000),
('Product Manager', 'L2', 9, 95000, 140000),
('Research Scientist', 'L2', 10, 90000, 145000),
('Data Scientist', 'L2', 10, 95000, 150000),
('Senior Manager', 'L4', 1, 140000, 190000);

-- =============================================================================
-- EXACTLY 100 UNIQUE EMPLOYEES
-- =============================================================================
WITH seed AS (
    SELECT
        gs AS n,
        'EMP' || LPAD(gs::TEXT, 4, '0') AS employee_code,
        'First' || LPAD(gs::TEXT, 3, '0') AS first_name,
        'Last' || LPAD(gs::TEXT, 3, '0') AS last_name,
        LOWER('emp' || LPAD(gs::TEXT, 4, '0') || '@company.com') AS email,
        '+1-555-' || LPAD((2000000 + gs)::TEXT, 7, '0') AS phone,
        (DATE '2017-01-01' + ((gs * 17) % 2500) * INTERVAL '1 day')::DATE AS hire_date,
        ((gs - 1) % 10) + 1 AS department_id,
        ((gs - 1) % 20) + 1 AS job_id,
        CASE WHEN gs <= 10 THEN NULL ELSE ((gs - 1) % 10) + 1 END AS manager_id,
        (55000 + (((gs - 1) % 15) * 4200) + ((((gs - 1) % 10) + 1) * 350))::NUMERIC(12,2) AS salary,
        (6 + ((gs - 1) % 6) * 1.5)::NUMERIC(5,2) AS bonus_target_pct
    FROM generate_series(1, 100) AS gs
)
INSERT INTO employees (
    employee_code,
    first_name,
    last_name,
    email,
    phone,
    hire_date,
    department_id,
    job_id,
    manager_id,
    salary,
    bonus_target_pct
)
SELECT
    employee_code,
    first_name,
    last_name,
    email,
    phone,
    hire_date,
    department_id,
    job_id,
    manager_id,
    salary,
    bonus_target_pct
FROM seed
ORDER BY n;

-- =============================================================================
-- DERIVED / TRANSACTION DATA
-- =============================================================================
INSERT INTO employees_history (employee_id, status, effective_date, reason)
SELECT id, 'active', hire_date, 'Initial hiring record'
FROM employees;

INSERT INTO employees_history (employee_id, status, effective_date, reason)
SELECT id, 'on_leave', DATE '2023-08-01' + (id % 120) * INTERVAL '1 day', 'Annual leave cycle'
FROM employees
WHERE id % 17 = 0;

INSERT INTO salaries (employee_id, amount, effective_date, end_date)
SELECT id, salary - 4500, hire_date, (hire_date + INTERVAL '365 day')::DATE
FROM employees;

INSERT INTO salaries (employee_id, amount, effective_date, end_date)
SELECT id, salary, (hire_date + INTERVAL '366 day')::DATE, NULL
FROM employees;

INSERT INTO bonuses (employee_id, amount, bonus_date, bonus_type)
SELECT
    id,
    ROUND(salary * (bonus_target_pct / 100.0), 2),
    DATE '2024-12-15',
    CASE WHEN id % 7 = 0 THEN 'retention' WHEN id % 5 = 0 THEN 'spot' ELSE 'performance' END
FROM employees;

INSERT INTO leave_requests (employee_id, leave_type, start_date, end_date, status, approver_id)
SELECT
    e.id,
    CASE WHEN e.id % 4 = 0 THEN 'vacation'
         WHEN e.id % 4 = 1 THEN 'sick'
         WHEN e.id % 4 = 2 THEN 'personal'
         ELSE 'parental' END,
    (DATE '2024-01-01' + (e.id % 220) * INTERVAL '1 day')::DATE,
    (DATE '2024-01-02' + (e.id % 220) * INTERVAL '1 day')::DATE,
    CASE WHEN e.id % 6 = 0 THEN 'pending'
         WHEN e.id % 6 = 1 THEN 'rejected'
         ELSE 'approved' END,
    COALESCE(e.manager_id, 1)
FROM employees e
WHERE e.id <= 80;

INSERT INTO leave_balances (employee_id, leave_type, year, balance_days, used_days)
SELECT id, 'vacation', 2024, 18, (id % 9)
FROM employees;

INSERT INTO leave_balances (employee_id, leave_type, year, balance_days, used_days)
SELECT id, 'sick', 2024, 10, (id % 5)
FROM employees;

INSERT INTO attendance_logs (employee_id, work_date, status, clock_in, clock_out)
SELECT
    e.id,
    d::DATE AS work_date,
    CASE
        WHEN (e.id + EXTRACT(DAY FROM d)::INT) % 20 = 0 THEN 'absent'
        WHEN (e.id + EXTRACT(DAY FROM d)::INT) % 9 = 0 THEN 'late'
        WHEN (e.id + EXTRACT(DAY FROM d)::INT) % 13 = 0 THEN 'half_day'
        ELSE 'present'
    END,
    CASE
        WHEN (e.id + EXTRACT(DAY FROM d)::INT) % 20 = 0 THEN NULL
        ELSE TIME '09:00:00' + ((e.id % 3) * INTERVAL '5 minute')
    END,
    CASE
        WHEN (e.id + EXTRACT(DAY FROM d)::INT) % 20 = 0 THEN NULL
        WHEN (e.id + EXTRACT(DAY FROM d)::INT) % 13 = 0 THEN TIME '13:00:00'
        ELSE TIME '18:00:00' + ((e.id % 4) * INTERVAL '5 minute')
    END
FROM employees e
CROSS JOIN generate_series(DATE '2024-06-03', DATE '2024-06-07', INTERVAL '1 day') AS d;

INSERT INTO performance_reviews (employee_id, review_year, score, reviewer_id, feedback)
SELECT
    id,
    2024,
    2 + (id % 4),
    COALESCE(manager_id, 1),
    'Review for employee ' || employee_code
FROM employees;

INSERT INTO training_enrollments (employee_id, training_name, training_date, duration_hours, status)
SELECT
    id,
    CASE
        WHEN id % 5 = 0 THEN 'Leadership Essentials'
        WHEN id % 5 = 1 THEN 'Advanced SQL'
        WHEN id % 5 = 2 THEN 'Product Thinking'
        WHEN id % 5 = 3 THEN 'Cloud Fundamentals'
        ELSE 'Security Awareness'
    END,
    (DATE '2024-02-01' + (id % 140) * INTERVAL '1 day')::DATE,
    8 + ((id % 5) * 4),
    CASE WHEN id % 7 = 0 THEN 'enrolled' ELSE 'completed' END
FROM employees;

INSERT INTO certifications (employee_id, cert_name, issued_date, expiry_date, credential_id)
SELECT
    id,
    CASE
        WHEN id % 4 = 0 THEN 'AWS Associate'
        WHEN id % 4 = 1 THEN 'Scrum Master'
        WHEN id % 4 = 2 THEN 'Data Analyst Pro'
        ELSE 'ITIL Foundation'
    END,
    (DATE '2023-01-01' + (id % 200) * INTERVAL '1 day')::DATE,
    (DATE '2026-01-01' + (id % 200) * INTERVAL '1 day')::DATE,
    'CERT-' || LPAD(id::TEXT, 4, '0')
FROM employees
WHERE id % 2 = 0;

INSERT INTO promotions (employee_id, old_job_id, new_job_id, old_salary, new_salary, promotion_date)
SELECT
    e.id,
    e.job_id,
    CASE WHEN e.job_id = 20 THEN 19 ELSE e.job_id + 1 END,
    e.salary - 6000,
    e.salary,
    (e.hire_date + INTERVAL '730 day')::DATE
FROM employees e
WHERE e.id % 4 = 0;

INSERT INTO terminations (employee_id, termination_date, reason, exit_interview_completed, final_settlement)
SELECT
    e.id,
    DATE '2024-03-01' + (e.id % 20) * INTERVAL '1 day',
    'Role redundancy',
    TRUE,
    e.salary * 1.5
FROM employees e
WHERE e.id IN (96, 97, 98, 99, 100);

UPDATE employees
SET is_active = FALSE
WHERE id IN (96, 97, 98, 99, 100);

INSERT INTO approvals (request_type, requester_id, approver_id, request_date, approval_date, status, comments)
SELECT
    'leave',
    lr.employee_id,
    lr.approver_id,
    lr.request_date,
    CASE WHEN lr.status = 'approved' THEN lr.request_date + INTERVAL '1 day' ELSE NULL END,
    lr.status,
    'Auto-seeded approval workflow'
FROM leave_requests lr;

INSERT INTO audit_logs (employee_id, action, table_affected, record_id, old_value, new_value, ip_address)
SELECT
    e.id,
    CASE WHEN e.id % 4 = 0 THEN 'update' WHEN e.id % 7 = 0 THEN 'delete' ELSE 'create' END,
    'employees',
    e.id,
    NULL,
    'Seeded employee record',
    '10.10.' || ((e.id % 20) + 1)::TEXT || '.' || ((e.id % 200) + 10)::TEXT
FROM employees e;

INSERT INTO emergency_contacts (employee_id, contact_name, relationship, phone, alternate_phone)
SELECT
    e.id,
    'Contact_' || e.employee_code,
    CASE WHEN e.id % 5 = 0 THEN 'spouse'
         WHEN e.id % 5 = 1 THEN 'parent'
         WHEN e.id % 5 = 2 THEN 'sibling'
         WHEN e.id % 5 = 3 THEN 'friend'
         ELSE 'other' END,
    '+1-444-' || LPAD((7000000 + e.id)::TEXT, 7, '0'),
    NULL
FROM employees e;

-- =============================================================================
-- QUICK VALIDATION OUTPUT
-- =============================================================================
SELECT 'Departments: ' || COUNT(*) FROM departments;
SELECT 'Jobs: ' || COUNT(*) FROM jobs;
SELECT 'Employees (expected 100): ' || COUNT(*) FROM employees;
SELECT 'Duplicate employee_code rows: ' || COUNT(*) FROM (
    SELECT employee_code FROM employees GROUP BY employee_code HAVING COUNT(*) > 1
) d;
SELECT 'Duplicate email rows: ' || COUNT(*) FROM (
    SELECT email FROM employees GROUP BY email HAVING COUNT(*) > 1
) d;