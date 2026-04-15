-- ============================================
-- School Management Database Setup
-- ============================================

-- Drop tables if they exist (in correct order due to foreign keys)
DROP TABLE IF EXISTS attendance;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS classes;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS teachers;
DROP TABLE IF EXISTS students;

-- ============================================
-- Create Tables
-- ============================================

-- Students table
CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE NOT NULL,
    grade INTEGER NOT NULL,
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Teachers table
CREATE TABLE teachers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    department VARCHAR(50) NOT NULL,
    specialization VARCHAR(100),
    hire_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Courses table
CREATE TABLE courses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    teacher_id INTEGER REFERENCES teachers(id),
    credits INTEGER NOT NULL DEFAULT 3,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Classes table (course sections)
CREATE TABLE classes (
    id SERIAL PRIMARY KEY,
    course_id INTEGER REFERENCES courses(id) NOT NULL,
    semester VARCHAR(20) NOT NULL,
    year INTEGER NOT NULL,
    section VARCHAR(10),
    schedule VARCHAR(100),
    room VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Enrollments table
CREATE TABLE enrollments (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES students(id) NOT NULL,
    class_id INTEGER REFERENCES classes(id) NOT NULL,
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, class_id)
);

-- Attendance table
CREATE TABLE attendance (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES students(id) NOT NULL,
    class_id INTEGER REFERENCES classes(id) NOT NULL,
    date DATE NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, class_id, date)
);

-- ============================================
-- Insert Sample Data
-- ============================================

-- Insert Students
INSERT INTO students (name, email, phone, date_of_birth, grade, address) VALUES
('Alice Johnson', 'alice.johnson@school.com', '555-0101', '2010-03-15', 10, '123 Oak Street'),
('Bob Smith', 'bob.smith@school.com', '555-0102', '2010-07-22', 10, '456 Maple Avenue'),
('Charlie Brown', 'charlie.brown@school.com', '555-0103', '2010-11-08', 10, '789 Pine Road'),
('Diana Ross', 'diana.ross@school.com', '555-0104', '2010-01-30', 10, '321 Elm Street'),
('Edward Lee', 'edward.lee@school.com', '555-0105', '2010-05-12', 10, '654 Birch Lane'),
('Fiona Garcia', 'fiona.garcia@school.com', '555-0106', '2011-02-28', 9, '987 Cedar Drive'),
('George Wilson', 'george.wilson@school.com', '555-0107', '2011-08-14', 9, '147 Walnut Court'),
('Hannah Martinez', 'hannah.martinez@school.com', '555-0108', '2011-04-03', 9, '258 Spruce Way'),
('Ian Thompson', 'ian.thompson@school.com', '555-0109', '2011-12-19', 9, '369 Ash Boulevard'),
('Julia Anderson', 'julia.anderson@school.com', '555-0110', '2011-06-25', 9, '741 Willow Street');

-- Insert Teachers
INSERT INTO teachers (name, email, phone, department, specialization, hire_date) VALUES
('Dr. Sarah Mitchell', 'sarah.mitchell@school.com', '555-1001', 'Mathematics', 'Calculus & Statistics', '2015-08-20'),
('Mr. James Cooper', 'james.cooper@school.com', '555-1002', 'Physics', 'Mechanics & Thermodynamics', '2016-01-15'),
('Ms. Emily Davis', 'emily.davis@school.com', '555-1003', 'English', 'Literature & Composition', '2014-09-01'),
('Dr. Michael Chen', 'michael.chen@school.com', '555-1004', 'Chemistry', 'Organic Chemistry', '2017-02-10'),
('Mrs. Lisa Brown', 'lisa.brown@school.com', '555-1005', 'History', 'World History', '2013-08-25'),
('Mr. Robert Taylor', 'robert.taylor@school.com', '555-1006', 'Computer Science', 'Programming & Algorithms', '2018-01-10'),
('Ms. Jennifer White', 'jennifer.white@school.com', '555-1007', 'Biology', 'Molecular Biology', '2016-03-15'),
('Dr. David Miller', 'david.miller@school.com', '555-1008', 'Mathematics', 'Algebra & Geometry', '2015-01-20');

-- Insert Courses
INSERT INTO courses (name, description, teacher_id, credits) VALUES
('Mathematics 101', 'Introduction to Algebra and Pre-Calculus', 1, 4),
('Physics 101', 'Basic Physics - Mechanics and Thermodynamics', 2, 4),
('English 101', 'English Literature and Composition', 3, 3),
('Chemistry 101', 'Introduction to Chemistry', 4, 4),
('World History', 'Survey of World History', 5, 3),
('Computer Science 101', 'Introduction to Programming', 6, 3),
('Biology 101', 'Introduction to Biology', 7, 4),
('Geometry', 'Euclidean Geometry and Trigonometry', 8, 3);

-- Insert Classes (course sections for Fall 2024)
INSERT INTO classes (course_id, semester, year, section, schedule, room) VALUES
(1, 'Fall', 2024, 'A', 'Mon/Wed 9:00-10:30', 'Room 101'),
(1, 'Fall', 2024, 'B', 'Tue/Thu 14:00-15:30', 'Room 102'),
(2, 'Fall', 2024, 'A', 'Mon/Wed 11:00-12:30', 'Lab A'),
(3, 'Fall', 2024, 'A', 'Tue/Thu 9:00-10:30', 'Room 201'),
(3, 'Fall', 2024, 'B', 'Mon/Wed 14:00-15:30', 'Room 202'),
(4, 'Fall', 2024, 'A', 'Tue/Thu 11:00-12:30', 'Lab B'),
(5, 'Fall', 2024, 'A', 'Mon/Wed 10:00-11:30', 'Room 301'),
(6, 'Fall', 2024, 'A', 'Tue/Thu 14:00-16:00', 'Computer Lab 1'),
(7, 'Fall', 2024, 'A', 'Mon/Wed 15:00-16:30', 'Lab C'),
(8, 'Fall', 2024, 'A', 'Tue/Thu 9:00-10:30', 'Room 103');

-- Insert Enrollments
INSERT INTO enrollments (student_id, class_id) VALUES
(1, 1), (1, 3), (1, 4), (1, 7), (1, 8),
(2, 1), (2, 3), (2, 4), (2, 5), (2, 7),
(3, 2), (3, 3), (3, 6), (3, 8), (3, 9),
(4, 1), (4, 4), (4, 5), (4, 7), (4, 9),
(5, 2), (5, 3), (5, 6), (5, 8), (5, 10),
(6, 4), (6, 5), (6, 7), (6, 8), (6, 9),
(7, 1), (7, 4), (7, 5), (7, 7), (7, 10),
(8, 2), (8, 5), (8, 6), (8, 8), (8, 9),
(9, 1), (9, 3), (9, 5), (9, 7), (9, 10),
(10, 2), (10, 4), (10, 6), (10, 8), (10, 10);

-- Insert Attendance (sample data for a week)
INSERT INTO attendance (student_id, class_id, date, status) VALUES
(1, 1, '2024-09-02', 'present'),
(1, 3, '2024-09-02', 'present'),
(1, 4, '2024-09-03', 'present'),
(2, 1, '2024-09-02', 'present'),
(2, 3, '2024-09-02', 'absent'),
(2, 4, '2024-09-03', 'present'),
(3, 2, '2024-09-02', 'present'),
(3, 3, '2024-09-02', 'late'),
(3, 6, '2024-09-03', 'present'),
(4, 1, '2024-09-02', 'present'),
(4, 4, '2024-09-03', 'excused'),
(5, 2, '2024-09-02', 'present'),
(5, 3, '2024-09-02', 'present'),
(6, 4, '2024-09-02', 'present'),
(7, 1, '2024-09-02', 'absent'),
(8, 2, '2024-09-02', 'present'),
(9, 1, '2024-09-02', 'present'),
(10, 2, '2024-09-02', 'present');

-- ============================================
-- Verify Data
-- ============================================

SELECT 'Students: ' || COUNT(*) FROM students;
SELECT 'Teachers: ' || COUNT(*) FROM teachers;
SELECT 'Courses: ' || COUNT(*) FROM courses;
SELECT 'Classes: ' || COUNT(*) FROM classes;
SELECT 'Enrollments: ' || COUNT(*) FROM enrollments;
SELECT 'Attendance: ' || COUNT(*) FROM attendance;
