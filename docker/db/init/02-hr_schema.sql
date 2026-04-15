-- =============================================================================
-- HR Management System Database Schema and Synthetic Data
-- 
-- 17 tables with realistic data including:
-- - Missing values (NULL)
-- - Complex joins
-- - Historical records
-- - Self-referential relationships
-- =============================================================================

-- Drop tables if they exist (in correct order due to foreign keys)
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS emergency_contacts;
DROP TABLE IF EXISTS approvals;
DROP TABLE IF EXISTS terminations;
DROP TABLE IF EXISTS promotions;
DROP TABLE IF EXISTS certifications;
DROP TABLE IF EXISTS training_enrollments;
DROP TABLE IF EXISTS performance_reviews;
DROP TABLE IF EXISTS attendance_logs;
DROP TABLE IF EXISTS leave_balances;
DROP TABLE IF EXISTS leave_requests;
DROP TABLE IF EXISTS bonuses;
DROP TABLE IF EXISTS salaries;
DROP TABLE IF EXISTS employees_history;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS jobs;
DROP TABLE IF EXISTS departments;

-- =============================================================================
-- TABLE 1: DEPARTMENTS
-- =============================================================================
CREATE TABLE departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) UNIQUE NOT NULL,
    manager_id INTEGER,
    parent_department_id INTEGER REFERENCES departments(id),
    location VARCHAR(100),
    budget NUMERIC(15, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 2: JOBS
-- =============================================================================
CREATE TABLE jobs (
    id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    min_salary NUMERIC(12, 2),
    max_salary NUMERIC(12, 2),
    department_id INTEGER REFERENCES departments(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 3: EMPLOYEES
-- =============================================================================
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    hire_date DATE NOT NULL,
    job_id INTEGER REFERENCES jobs(id),
    department_id INTEGER REFERENCES departments(id),
    manager_id INTEGER REFERENCES employees(id),
    salary NUMERIC(12, 2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 4: EMPLOYEES_HISTORY
-- =============================================================================
CREATE TABLE employees_history (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id),
    status VARCHAR(20) NOT NULL, -- 'active', 'on_leave', 'terminated'
    effective_date DATE NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 5: SALARIES
-- =============================================================================
CREATE TABLE salaries (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    effective_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 6: BONUSES
-- =============================================================================
CREATE TABLE bonuses (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    year INTEGER NOT NULL,
    bonus_type VARCHAR(20), -- 'performance', 'referral', 'signing'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 7: LEAVE_REQUESTS
-- =============================================================================
CREATE TABLE leave_requests (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    leave_type VARCHAR(20) NOT NULL, -- 'sick', 'vacation', 'personal', 'maternity'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    approver_id INTEGER REFERENCES employees(id),
    request_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 8: LEAVE_BALANCES
-- =============================================================================
CREATE TABLE leave_balances (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    leave_type VARCHAR(20) NOT NULL,
    year INTEGER NOT NULL,
    balance_days INTEGER NOT NULL DEFAULT 0,
    used_days INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 9: ATTENDANCE_LOGS
-- =============================================================================
CREATE TABLE attendance_logs (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    date DATE NOT NULL,
    status VARCHAR(20) NOT NULL, -- 'present', 'absent', 'late', 'half_day'
    clock_in TIME,
    clock_out TIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 10: PERFORMANCE_REVIEWS
-- =============================================================================
CREATE TABLE performance_reviews (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    review_date DATE NOT NULL,
    score INTEGER CHECK (score >= 1 AND score <= 5), -- 1-5 rating
    feedback TEXT,
    reviewer_id INTEGER REFERENCES employees(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 11: TRAINING_ENROLLMENTS
-- =============================================================================
CREATE TABLE training_enrollments (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    training_name VARCHAR(100) NOT NULL,
    training_date DATE NOT NULL,
    duration_hours INTEGER,
    enrollment_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(20) DEFAULT 'enrolled', -- 'enrolled', 'completed', 'cancelled'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 12: CERTIFICATIONS
-- =============================================================================
CREATE TABLE certifications (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    cert_name VARCHAR(100) NOT NULL,
    issued_date DATE NOT NULL,
    expiry_date DATE,
    credential_id VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 13: PROMOTIONS
-- =============================================================================
CREATE TABLE promotions (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    old_job_id INTEGER REFERENCES jobs(id),
    new_job_id INTEGER REFERENCES jobs(id),
    old_salary NUMERIC(12, 2),
    new_salary NUMERIC(12, 2),
    promotion_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 14: TERMINATIONS
-- =============================================================================
CREATE TABLE terminations (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    termination_date DATE NOT NULL,
    reason VARCHAR(200),
    exit_interview_completed BOOLEAN DEFAULT FALSE,
    final_settlement NUMERIC(12, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 15: APPROVALS
-- =============================================================================
CREATE TABLE approvals (
    id SERIAL PRIMARY KEY,
    request_type VARCHAR(50) NOT NULL, -- 'leave', 'expense', ' reimbursement'
    requester_id INTEGER REFERENCES employees(id),
    approver_id INTEGER REFERENCES employees(id),
    request_date DATE DEFAULT CURRENT_DATE,
    approval_date DATE,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 16: AUDIT_LOGS
-- =============================================================================
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id),
    action VARCHAR(50) NOT NULL, -- 'create', 'update', 'delete', 'login'
    table_affected VARCHAR(50),
    record_id INTEGER,
    old_value TEXT,
    new_value TEXT,
    ip_address VARCHAR(45),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE 17: EMERGENCY_CONTACTS
-- =============================================================================
CREATE TABLE emergency_contacts (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id) NOT NULL,
    name VARCHAR(100) NOT NULL,
    relationship VARCHAR(30), -- 'spouse', 'parent', 'sibling', 'other'
    phone VARCHAR(20) NOT NULL,
    alternate_phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- INSERT SYNTHETIC DATA
-- =============================================================================

-- Departments (12 rows)
INSERT INTO departments (name, code, manager_id, parent_department_id, location, budget) VALUES
('Engineering', 'ENG', NULL, NULL, 'Building A, Floor 3', 500000),
('Human Resources', 'HR', NULL, NULL, 'Building B, Floor 1', 150000),
('Finance', 'FIN', NULL, NULL, 'Building B, Floor 2', 200000),
('Marketing', 'MKT', NULL, NULL, 'Building A, Floor 2', 300000),
('Sales', 'SLS', NULL, NULL, 'Building A, Floor 1', 400000),
('IT Support', 'IT', NULL, 1, 'Building A, Floor 4', 250000),
('Operations', 'OPS', NULL, NULL, 'Building C, Floor 1', 350000),
('Legal', 'LGL', NULL, 3, 'Building B, Floor 3', 100000),
('Customer Success', 'CS', NULL, 5, 'Building A, Floor 1', 180000),
('Product', 'PROD', NULL, 1, 'Building A, Floor 3', 220000),
('Research', 'R&D', NULL, 1, 'Building C, Floor 2', 280000),
('Administration', 'ADMIN', NULL, 2, 'Building B, Floor 1', 80000);

-- Jobs (15 rows)
INSERT INTO jobs (title, description, min_salary, max_salary, department_id) VALUES
('Software Engineer', 'Develops software applications', 60000, 120000, 1),
('Senior Software Engineer', 'Leads software development', 90000, 150000, 1),
('HR Manager', 'Manages HR operations', 55000, 85000, 2),
('Finance Analyst', 'Analyzes financial data', 50000, 75000, 3),
('Marketing Coordinator', 'Coordinates marketing activities', 45000, 65000, 4),
('Sales Representative', 'Handles sales inquiries', 40000, 60000, 5),
('IT Support Specialist', 'Provides IT support', 45000, 70000, 6),
('Operations Manager', 'Manages operations', 55000, 85000, 7),
('Legal Counsel', 'Provides legal advice', 70000, 120000, 8),
('Customer Success Manager', 'Manages customer relations', 50000, 75000, 9),
('Product Manager', 'Manages product development', 70000, 110000, 10),
('Research Scientist', 'Conducts research', 65000, 100000, 11),
('Administrative Assistant', 'Provides administrative support', 35000, 50000, 12),
('Tech Lead', 'Leads technical team', 100000, 160000, 1),
('Financial Controller', 'Controllers financial operations', 80000, 130000, 3);

-- Update department managers
UPDATE departments SET manager_id = 1 WHERE id = 1;
UPDATE departments SET manager_id = 5 WHERE id = 2;
UPDATE departments SET manager_id = 9 WHERE id = 3;
UPDATE departments SET manager_id = 13 WHERE id = 4;
UPDATE departments SET manager_id = 17 WHERE id = 5;

-- Employees (25 rows)
INSERT INTO employees (first_name, last_name, email, phone, hire_date, job_id, department_id, manager_id, salary) VALUES
('John', 'Smith', 'john.smith@company.com', '555-0101', '2020-01-15', 14, 1, NULL, 125000),
('Sarah', 'Johnson', 'sarah.johnson@company.com', '555-0102', '2019-03-20', 1, 1, 1, 85000),
('Michael', 'Brown', 'michael.brown@company.com', '555-0103', '2021-06-10', 1, 1, 1, 72000),
('Emily', 'Davis', 'emily.davis@company.com', '555-0104', '2018-11-05', 2, 1, 1, 105000),
('David', 'Wilson', 'david.wilson@company.com', '555-0105', '2020-08-15', 3, 2, 5, 68000),
('Jessica', 'Taylor', 'jessica.taylor@company.com', NULL, '2017-02-28', 3, 2, 5, 72000),
('James', 'Anderson', 'james.anderson@company.com', '555-0107', '2019-09-12', 4, 3, 9, 62000),
('Jennifer', 'Thomas', 'jennifer.thomas@company.com', '555-0108', '2021-01-05', 4, 3, 9, 58000),
('Robert', 'Garcia', 'robert.garcia@company.com', '555-0109', '2020-04-20', 5, 4, 13, 52000),
('Lisa', 'Martinez', 'lisa.martinez@company.com', '555-0110', '2022-02-14', 5, 4, 13, 48000),
('William', 'Rodriguez', 'william.rodriguez@company.com', '555-0111', '2018-07-01', 6, 5, 17, 55000),
('Ashley', 'Lee', 'ashley.lee@company.com', NULL, '2019-12-10', 6, 5, 17, 58000),
('Christopher', 'Gonzalez', 'christopher.gonzalez@company.com', '555-0113', '2021-03-25', 7, 6, 1, 55000),
('Amanda', 'Walker', 'amanda.walker@company.com', '555-0114', '2020-11-30', 7, 6, 1, 52000),
('Daniel', 'Hall', 'daniel.hall@company.com', '555-0115', '2017-06-15', 8, 7, 5, 72000),
('Michelle', 'Allen', 'michelle.allen@company.com', '555-0116', '2022-07-20', 8, 7, 5, 65000),
('Matthew', 'Young', 'matthew.young@company.com', '555-0117', '2019-04-08', 9, 8, 9, 95000),
('Stephanie', 'King', 'stephanie.king@company.com', NULL, '2020-09-15', 9, 8, 9, 82000),
('Andrew', 'Wright', 'andrew.wright@company.com', '555-0119', '2021-08-01', 10, 9, 17, 62000),
('Nicole', 'Lopez', 'nicole.lopez@company.com', '555-0120', '2018-12-20', 10, 9, 17, 58000),
('Joshua', 'Hill', 'joshua.hill@company.com', '555-0121', '2022-01-10', 11, 10, 1, 78000),
('Rachel', 'Scott', 'rachel.scott@company.com', '555-0122', '2019-07-25', 11, 10, 1, 88000),
('Kevin', 'Green', 'kevin.green@company.com', '555-0123', '2020-05-15', 12, 11, 1, 82000),
('Samantha', 'Adams', 'samantha.adams@company.com', NULL, '2021-10-01', 12, 11, 1, 75000),
('Brian', 'Baker', 'brian.baker@company.com', '555-0125', '2017-03-10', 13, 12, 5, 42000);

-- Employees History (30 rows - some employees have multiple entries)
INSERT INTO employees_history (employee_id, status, effective_date, reason) VALUES
(1, 'active', '2020-01-15', 'Hired as Tech Lead'),
(2, 'active', '2021-06-10', 'New hire'),
(3, 'active', '2021-06-10', 'Promoted to Senior Engineer'),
(3, 'active', '2023-01-15', 'Completed probation'),
(4, 'active', '2018-11-05', 'Hired as Senior Engineer'),
(5, 'active', '2020-08-15', 'Hired as HR Manager'),
(6, 'on_leave', '2017-02-28', 'Maternity leave'),
(6, 'active', '2017-06-28', 'Returned from maternity leave'),
(7, 'active', '2019-09-12', 'Hired as Finance Analyst'),
(8, 'active', '2021-01-05', 'Hired'),
(9, 'active', '2020-04-20', 'Hired as Marketing Coordinator'),
(10, 'active', '2022-02-14', 'Hired'),
(11, 'active', '2018-07-01', 'Hired as Sales Rep'),
(12, 'active', '2019-12-10', 'Hired'),
(13, 'active', '2021-03-25', 'Hired as IT Support'),
(14, 'on_leave', '2020-11-30', 'Sick leave'),
(14, 'active', '2020-12-15', 'Returned'),
(15, 'active', '2017-06-15', 'Hired as Operations Manager'),
(16, 'active', '2022-07-20', 'New hire'),
(17, 'active', '2019-04-08', 'Hired as Legal Counsel'),
(18, 'active', '2020-09-15', 'Hired'),
(19, 'active', '2021-08-01', 'Hired'),
(20, 'active', '2018-12-20', 'Hired'),
(21, 'active', '2022-01-10', 'Hired as Research Scientist'),
(22, 'active', '2019-07-25', 'Senior hire'),
(23, 'active', '2020-05-15', 'Research Scientist'),
(24, 'active', '2021-10-01', 'Research Scientist'),
(25, 'active', '2017-03-10', 'Administrative Assistant'),
(5, 'active', '2023-01-01', 'Promotion to HR Director'),
(1, 'active', '2023-06-01', 'Promotion to Engineering Director');

-- Salaries (25 rows)
INSERT INTO salaries (employee_id, amount, effective_date, end_date) VALUES
(1, 125000, '2020-01-15', '2023-05-31'),
(1, 140000, '2023-06-01', NULL),
(2, 85000, '2021-06-10', NULL),
(3, 72000, '2021-06-10', '2023-01-14'),
(3, 78000, '2023-01-15', NULL),
(4, 105000, '2018-11-05', NULL),
(5, 68000, '2020-08-15', '2022-12-31'),
(5, 75000, '2023-01-01', NULL),
(6, 72000, '2017-02-28', NULL),
(7, 62000, '2019-09-12', NULL),
(8, 58000, '2021-01-05', NULL),
(9, 52000, '2020-04-20', NULL),
(10, 48000, '2022-02-14', NULL),
(11, 55000, '2018-07-01', NULL),
(12, 58000, '2019-12-10', NULL),
(13, 55000, '2021-03-25', NULL),
(14, 52000, '2020-11-30', '2020-12-14'),
(14, 52000, '2020-12-15', NULL),
(15, 72000, '2017-06-15', NULL),
(16, 65000, '2022-07-20', NULL),
(17, 95000, '2019-04-08', NULL),
(18, 82000, '2020-09-15', NULL),
(19, 62000, '2021-08-01', NULL),
(20, 58000, '2018-12-20', NULL),
(21, 78000, '2022-01-10', NULL);

-- Bonuses (15 rows)
INSERT INTO bonuses (employee_id, amount, year, bonus_type) VALUES
(1, 15000, 2023, 'performance'),
(4, 12000, 2023, 'performance'),
(2, 8000, 2023, 'performance'),
(5, 7500, 2023, 'referral'),
(7, 6000, 2023, 'performance'),
(9, 5000, 2023, 'performance'),
(11, 5500, 2022, 'performance'),
(13, 5000, 2023, 'signing'),
(15, 7000, 2023, 'performance'),
(17, 9000, 2023, 'performance'),
(19, 6000, 2023, 'performance'),
(21, 7500, 2023, 'performance'),
(1, 12000, 2022, 'performance'),
(4, 10000, 2022, 'performance'),
(8, 5500, 2022, 'performance');

-- Leave Requests (20 rows)
INSERT INTO leave_requests (employee_id, leave_type, start_date, end_date, status, approver_id) VALUES
(6, 'maternity', '2023-11-01', '2023-12-31', 'approved', 5),
(14, 'sick', '2023-10-15', '2023-10-17', 'approved', 1),
(2, 'vacation', '2023-12-20', '2023-12-27', 'approved', 1),
(3, 'personal', '2023-11-10', '2023-11-10', 'approved', 1),
(8, 'vacation', '2024-01-05', '2024-01-12', 'pending', 5),
(12, 'sick', '2023-09-01', '2023-09-02', 'approved', 1),
(16, 'vacation', '2023-12-25', '2023-12-30', 'approved', 5),
(21, 'personal', '2023-11-15', '2023-11-15', 'rejected', 5),
(24, 'vacation', '2024-02-01', '2024-02-14', 'pending', 1),
(5, 'sick', '2023-10-05', '2023-10-06', 'approved', 5),
(9, 'vacation', '2023-12-15', '2023-12-22', 'approved', 13),
(18, 'maternity', '2024-01-15', '2024-03-15', 'approved', 5),
(22, 'personal', '2023-11-20', '2023-11-20', 'approved', 1),
(10, 'vacation', '2024-01-20', '2024-01-27', 'pending', 13),
(25, 'vacation', '2023-12-18', '2023-12-24', 'approved', 5),
(1, 'vacation', '2024-03-01', '2024-03-10', 'pending', NULL),
(7, 'sick', '2023-10-20', '2023-10-21', 'approved', 9),
(15, 'personal', '2023-11-25', '2023-11-25', 'approved', 5),
(19, 'vacation', '2024-02-15', '2024-02-21', 'pending', 1),
(23, 'vacation', '2023-12-28', '2024-01-03', 'approved', 1);

-- Leave Balances (40 rows)
INSERT INTO leave_balances (employee_id, leave_type, year, balance_days, used_days) VALUES
(1, 'vacation', 2024, 15, 0),
(1, 'sick', 2024, 10, 0),
(2, 'vacation', 2024, 12, 0),
(2, 'sick', 2024, 8, 0),
(3, 'vacation', 2024, 10, 2),
(3, 'sick', 2024, 8, 0),
(4, 'vacation', 2024, 18, 0),
(4, 'sick', 2024, 10, 0),
(5, 'vacation', 2024, 15, 0),
(5, 'sick', 2024, 10, 2),
(6, 'vacation', 2024, 15, 5),
(6, 'sick', 2024, 10, 0),
(7, 'vacation', 2024, 12, 0),
(7, 'sick', 2024, 8, 0),
(8, 'vacation', 2024, 10, 0),
(8, 'sick', 2024, 8, 0),
(9, 'vacation', 2024, 12, 3),
(9, 'sick', 2024, 8, 0),
(10, 'vacation', 2024, 8, 0),
(10, 'sick', 2024, 8, 0),
(11, 'vacation', 2024, 15, 0),
(11, 'sick', 2024, 10, 0),
(12, 'vacation', 2024, 10, 0),
(12, 'sick', 2024, 8, 0),
(13, 'vacation', 2024, 12, 0),
(13, 'sick', 2024, 8, 0),
(14, 'vacation', 2024, 12, 2),
(14, 'sick', 2024, 8, 2),
(15, 'vacation', 2024, 18, 0),
(15, 'sick', 2024, 10, 0),
(16, 'vacation', 2024, 10, 0),
(16, 'sick', 2024, 8, 0),
(17, 'vacation', 2024, 15, 0),
(17, 'sick', 2024, 10, 0),
(18, 'vacation', 2024, 12, 0),
(18, 'sick', 2024, 8, 0),
(19, 'vacation', 2024, 10, 0),
(19, 'sick', 2024, 8, 0),
(20, 'vacation', 2024, 15, 0),
(20, 'sick', 2024, 10, 0);

-- Attendance Logs (50 rows)
INSERT INTO attendance_logs (employee_id, date, status, clock_in, clock_out) VALUES
(2, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(2, '2023-10-24', 'present', '09:00:00', '18:05:00'),
(2, '2023-10-25', 'present', '08:55:00', '17:55:00'),
(3, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(3, '2023-10-24', 'late', '09:15:00', '18:00:00'),
(3, '2023-10-25', 'present', '09:00:00', '18:10:00'),
(4, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(4, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(4, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(5, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(5, '2023-10-24', 'absent', NULL, NULL),
(5, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(7, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(7, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(7, '2023-10-25', 'present', '09:00:00', '17:45:00'),
(8, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(8, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(8, '2023-10-25', 'half_day', '09:00:00', '13:00:00'),
(9, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(9, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(9, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(10, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(10, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(10, '2023-10-25', 'present', '09:10:00', '18:00:00'),
(11, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(11, '2023-10-24', 'present', '08:45:00', '18:00:00'),
(11, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(12, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(12, '2023-10-24', 'absent', NULL, NULL),
(12, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(13, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(13, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(13, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(14, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(14, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(14, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(15, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(15, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(15, '2023-10-25', 'present', '09:00:00', '17:30:00'),
(16, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(16, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(16, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(17, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(17, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(17, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(18, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(18, '2023-10-24', 'present', '09:00:00', '18:00:00'),
(18, '2023-10-25', 'present', '09:00:00', '18:00:00'),
(19, '2023-10-23', 'present', '09:00:00', '18:00:00'),
(19, '2023-10-24', 'late', '09:20:00', '18:00:00');

-- Performance Reviews (20 rows)
INSERT INTO performance_reviews (employee_id, review_date, score, feedback, reviewer_id) VALUES
(2, '2023-06-15', 4, 'Strong technical skills, good teamwork', 1),
(3, '2023-06-15', 4, 'Consistent performer, needs leadership development', 1),
(4, '2023-06-15', 5, 'Exceptional performer, ready for promotion', 1),
(5, '2023-06-15', 3, 'Meets expectations, communication could improve', 5),
(7, '2023-06-15', 4, 'Good analytical skills, detailed oriented', 9),
(8, '2023-06-15', 4, 'Solid performance, consistent', 9),
(9, '2023-06-15', 3, 'Meets expectations, needs more proactive approach', 13),
(10, '2023-06-15', 3, 'Developing skills, good potential', 13),
(11, '2023-06-15', 4, 'Consistent performer, good client relations', 17),
(12, '2023-06-15', 4, 'Strong sales performance', 17),
(13, '2023-06-15', 4, 'Reliable IT support, quick problem resolution', 1),
(14, '2023-06-15', 3, 'Meets basic expectations', 1),
(15, '2023-06-15', 4, 'Good operational management', 5),
(16, '2023-06-15', 4, 'Strong performer, take initiative', 5),
(17, '2023-06-15', 5, 'Outstanding performance, exceptional legal work', 9),
(18, '2023-06-15', 4, 'Good performance, consistent', 9),
(19, '2023-06-15', 3, 'Developing, needs more product knowledge', 17),
(20, '2023-06-15', 4, 'Good customer engagement', 17),
(21, '2023-06-15', 4, 'Strong research capabilities', 1),
(22, '2023-06-15', 5, 'Exceptional research output, industry recognized', 1);

-- Training Enrollments (15 rows)
INSERT INTO training_enrollments (employee_id, training_name, training_date, duration_hours, status) VALUES
(2, 'Advanced Python Programming', '2023-09-15', 40, 'completed'),
(3, 'Leadership Skills', '2023-10-01', 16, 'completed'),
(4, 'Cloud Architecture', '2023-11-15', 32, 'completed'),
(5, 'HR Management Certification', '2023-08-20', 24, 'completed'),
(7, 'Financial Modeling', '2023-09-10', 20, 'completed'),
(9, 'Digital Marketing Strategy', '2023-10-15', 16, 'completed'),
(11, 'Sales Excellence', '2023-08-05', 24, 'completed'),
(13, 'ITIL Certification', '2023-09-25', 32, 'completed'),
(15, 'Project Management Professional', '2023-10-20', 40, 'completed'),
(17, 'Corporate Law Fundamentals', '2023-11-01', 24, 'completed'),
(19, 'Customer Success Mastery', '2023-09-05', 16, 'completed'),
(21, 'Agile Development', '2023-10-10', 24, 'completed'),
(23, 'Data Science with Python', '2023-11-20', 40, 'enrolled'),
(24, 'Machine Learning Fundamentals', '2023-12-01', 32, 'enrolled'),
(1, 'Executive Leadership', '2024-01-15', 24, 'enrolled');

-- Certifications (15 rows)
INSERT INTO certifications (employee_id, cert_name, issued_date, expiry_date, credential_id) VALUES
(2, 'AWS Solutions Architect', '2023-03-01', '2026-03-01', 'AWS-SAA-2023-001'),
(3, 'PMP Certification', '2022-11-15', '2025-11-15', 'PMP-2022-455'),
(4, 'AWS Developer Associate', '2023-06-20', '2026-06-20', 'AWS-DEV-2023-089'),
(7, 'CPA', '2021-05-10', '2025-05-10', 'CPA-2021-223'),
(9, 'Google Analytics Certified', '2023-01-15', '2024-01-15', 'GA-2023-112'),
(11, 'HubSpot Sales Certified', '2023-04-01', '2024-04-01', 'HS-SC-2023-445'),
(13, 'CompTIA A+', '2022-08-20', '2025-08-20', 'CompTIA-A-2022-667'),
(15, 'PMP', '2022-03-01', '2025-03-01', 'PMP-2022-889'),
(17, 'Juris Doctor', '2020-06-15', NULL, 'JD-2020-112'),
(19, 'CSM Certified', '2023-02-01', '2024-02-01', 'CSM-2023-223'),
(21, 'Scrum Master', '2023-07-01', '2024-07-01', 'SM-2023-334'),
(22, 'PhD in Computer Science', '2018-05-01', NULL, 'PHD-CS-2018-112'),
(23, 'Machine Learning Specialization', '2023-08-15', '2025-08-15', 'ML-2023-556'),
(1, 'MBA', '2019-12-01', NULL, 'MBA-2019-889'),
(4, 'System Design Certificate', '2023-09-01', '2024-09-01', 'SD-2023-667');

-- Promotions (8 rows)
INSERT INTO promotions (employee_id, old_job_id, new_job_id, old_salary, new_salary, promotion_date) VALUES
(1, 1, 14, 100000, 125000, '2020-01-15'),
(3, 1, 2, 65000, 78000, '2023-01-15'),
(5, 3, 3, 60000, 68000, '2023-01-01'),
(4, 1, 2, 90000, 105000, '2020-06-01'),
(15, 8, 8, 65000, 72000, '2022-06-15'),
(17, 9, 9, 85000, 95000, '2021-06-01'),
(21, 11, 11, 70000, 78000, '2023-06-01'),
(22, 11, 11, 80000, 88000, '2022-01-01');

-- Approvals (15 rows)
INSERT INTO approvals (request_type, requester_id, approver_id, request_date, approval_date, status) VALUES
('leave', 6, 5, '2023-10-20', '2023-10-21', 'approved'),
('leave', 14, 1, '2023-10-22', '2023-10-22', 'approved'),
('expense', 2, 1, '2023-10-15', '2023-10-16', 'approved'),
('expense', 9, 13, '2023-10-18', '2023-10-19', 'approved'),
('reimbursement', 18, 5, '2023-10-25', NULL, 'pending'),
('leave', 8, 5, '2023-10-28', '2023-10-28', 'approved'),
('expense', 13, 1, '2023-10-10', '2023-10-11', 'approved'),
('leave', 24, 1, '2023-10-30', NULL, 'pending'),
('leave', 10, 13, '2023-11-01', '2023-11-01', 'approved'),
('expense', 21, 1, '2023-10-12', '2023-10-13', 'approved'),
('leave', 25, 5, '2023-11-05', '2023-11-05', 'approved'),
('reimbursement', 7, 9, '2023-10-22', '2023-10-23', 'approved'),
('leave', 19, 1, '2023-11-08', NULL, 'pending'),
('expense', 15, 5, '2023-10-28', '2023-10-29', 'approved'),
('leave', 1, NULL, '2023-11-10', NULL, 'pending');

-- Audit Logs (20 rows)
INSERT INTO audit_logs (employee_id, action, table_affected, record_id, new_value, ip_address) VALUES
(1, 'login', 'employees', 1, 'User logged in', '192.168.1.100'),
(2, 'create', 'employees', 3, 'New employee record created', '192.168.1.105'),
(2, 'update', 'employees', 3, 'Updated salary information', '192.168.1.105'),
(5, 'create', 'leave_requests', 1, 'New leave request submitted', '192.168.1.110'),
(5, 'approve', 'leave_requests', 1, 'Leave request approved', '192.168.1.110'),
(1, 'update', 'employees', 1, 'Promotion processed', '192.168.1.100'),
(2, 'create', 'performance_reviews', 1, 'Performance review created', '192.168.1.105'),
(2, 'update', 'employees', 3, 'Performance score updated', '192.168.1.105'),
(3, 'create', 'bonuses', 1, 'Bonus record created', '192.168.1.108'),
(5, 'create', 'leave_requests', 2, 'Leave request submitted', '192.168.1.110'),
(5, 'approve', 'leave_requests', 2, 'Leave request approved', '192.168.1.110'),
(1, 'create', 'promotions', 1, 'Promotion record created', '192.168.1.100'),
(2, 'create', 'training_enrollments', 1, 'Training enrollment created', '192.168.1.105'),
(3, 'update', 'employees', 4, 'Updated job title', '192.168.1.108'),
(4, 'create', 'certifications', 1, 'Certification record created', '192.168.1.109'),
(5, 'create', 'approvals', 3, 'Expense approval request', '192.168.1.110'),
(5, 'update', 'approvals', 3, 'Expense approved', '192.168.1.110'),
(1, 'login', 'employees', 1, 'User logged in', '192.168.1.100'),
(2, 'create', 'attendance_logs', 1, 'Attendance marked', '192.168.1.105'),
(3, 'update', 'employees', 5, 'Updated department', '192.168.1.108');

-- Emergency Contacts (20 rows)
INSERT INTO emergency_contacts (employee_id, name, relationship, phone, alternate_phone) VALUES
(1, 'Mary Smith', 'spouse', '555-1001', '555-1002'),
(2, 'Tom Johnson', 'father', '555-1003', NULL),
(3, 'Linda Wilson', 'mother', '555-1004', '555-1005'),
(4, 'Robert Brown', 'spouse', '555-1006', NULL),
(5, 'Patricia Davis', 'mother', '555-1007', '555-1008'),
(6, 'James Taylor', 'spouse', '555-1009', NULL),
(7, 'Jennifer Martinez', 'sister', '555-1010', '555-1011'),
(8, 'David Anderson', 'father', '555-1012', NULL),
(9, 'Lisa Thomas', 'mother', '555-1013', NULL),
(10, 'Mark Jackson', 'spouse', '555-1014', '555-1015'),
(11, 'Susan White', 'sister', '555-1016', NULL),
(12, 'Paul Harris', 'father', '555-1017', NULL),
(13, 'Karen Martin', 'mother', '555-1018', '555-1019'),
(14, 'Steven Thompson', 'spouse', '555-1020', NULL),
(15, 'Sandra Garcia', 'sister', '555-1021', NULL),
(16, 'Kevin Robinson', 'father', '555-1022', NULL),
(17, 'Betty Clark', 'mother', '555-1023', NULL),
(18, 'Brian Lewis', 'spouse', '555-1024', '555-1025'),
(19, 'Nancy Lee', 'sister', '555-1026', NULL),
(20, 'George Walker', 'father', '555-1027', NULL);

-- =============================================================================
-- VERIFY DATA
-- =============================================================================
SELECT 'Departments: ' || COUNT(*) FROM departments;
SELECT 'Jobs: ' || COUNT(*) FROM jobs;
SELECT 'Employees: ' || COUNT(*) FROM employees;
SELECT 'Employees History: ' || COUNT(*) FROM employees_history;
SELECT 'Salaries: ' || COUNT(*) FROM salaries;
SELECT 'Bonuses: ' || COUNT(*) FROM bonuses;
SELECT 'Leave Requests: ' || COUNT(*) FROM leave_requests;
SELECT 'Leave Balances: ' || COUNT(*) FROM leave_balances;
SELECT 'Attendance Logs: ' || COUNT(*) FROM attendance_logs;
SELECT 'Performance Reviews: ' || COUNT(*) FROM performance_reviews;
SELECT 'Training Enrollments: ' || COUNT(*) FROM training_enrollments;
SELECT 'Certifications: ' || COUNT(*) FROM certifications;
SELECT 'Promotions: ' || COUNT(*) FROM promotions;
SELECT 'Approvals: ' || COUNT(*) FROM approvals;
SELECT 'Audit Logs: ' || COUNT(*) FROM audit_logs;
SELECT 'Emergency Contacts: ' || COUNT(*) FROM emergency_contacts;