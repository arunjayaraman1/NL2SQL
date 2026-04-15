"""
HR Database NL→SQL Examples Generator

Generates few-shot examples programmatically based on HR schema patterns.
Each example includes:
- A natural language question
- A corresponding SQL query

These examples are used in the prompt for SQL generation.
"""

from __future__ import annotations

from typing import TypedDict


class FewShotExample(TypedDict):
    question: str
    sql: str


# Template patterns for generating examples
# Each template has placeholders that get filled with actual values
TEMPLATES = {
    # Simple SELECT queries
    "list_all": [
        "List all {table}",
        "Show all {table}",
        "Get all {table}",
    ],
    # COUNT aggregations
    "count_by": [
        "How many {table} are there",
        "Count all {table}",
        "Show the total number of {table}",
    ],
    # GROUP BY with COUNT
    "count_by_column": [
        "Count {table} by {column}",
        "How many {table} in each {column}",
        "Show count of {table} grouped by {column}",
    ],
    # Simple WHERE filter
    "filter_by": [
        "List {table} where {column} equals {value}",
        "Show {table} with {column} = {value}",
        "Find {table} where {column} is {value}",
    ],
    # Date filter
    "filter_by_date": [
        "Show {table} from {date_column} after {date}",
        "Find {table} where {date_column} > {date}",
        "List {table} before {date}",
    ],
    # JOIN two tables
    "join_two": [
        "List {table1} with {table2} data",
        "Show {table1} and {table2} joined",
        "Get {table1} including {table2} information",
    ],
    # JOIN with filter
    "join_filter": [
        "List {table1} with {table2} where {condition}",
        "Show {table1} joined with {table2} filtered by {column}",
    ],
    # Subquery
    "subquery": [
        "Find {table1} where {column} is in (select {column2} from {table2})",
    ],
    # ORDER BY
    "order_by": [
        "Show {table} ordered by {column}",
        "List {table} sorted by {column}",
        "Get {table} in order of {column}",
    ],
    # ORDER BY DESC
    "order_by_desc": [
        "Show top {n} {table} by {column}",
        "List highest {n} {table} based on {column}",
    ],
    # JOIN three tables
    "join_three": [
        "List {table1} with {table2} and {table3}",
    ],
    # Calculation
    "calculate": [
        "Calculate {aggregation} of {column} for {table}",
    ],
    # CASE expression
    "case_expression": [
        "Show {table} with {column} labeled as based on condition",
    ],
}

# Example values for templates (mapped to actual HR data)
EXAMPLE_VALUES = {
    "table": {
        "employees": "employees",
        "departments": "departments",
        "jobs": "jobs",
    },
    "column": {
        "department": "department_id",
        "job": "job_id",
        "status": "status",
        "salary": "salary",
        "name": "last_name",
        "title": "title",
    },
    "value": {
        "engineering": "Engineering",
        "active": "'active'",
        "pending": "'pending'",
    },
    "date": {
        "2023-01-01": "'2023-01-01'",
        "2023-12-31": "'2023-12-31'",
    },
    "table1": {
        "employee": "employees",
        "department": "departments",
        "job": "jobs",
    },
    "table2": {
        "department": "departments",
        "job": "jobs",
        "employee": "employees",
    },
    "table3": {
        "employees": "employees",
    },
    "column2": {
        "department_id": "department_id",
        "job_id": "job_id",
    },
    "condition": {
        "active employees": "e.is_active = TRUE",
        "department": "d.id = e.department_id",
    },
    "aggregation": {
        "average": "AVG",
        "sum": "SUM",
        "minimum": "MIN",
        "maximum": "MAX",
    },
}


def generate_few_shot_examples() -> list[FewShotExample]:
    """
    Generate few-shot examples programmatically.
    Returns a list of NL→SQL example pairs.
    """

    examples: list[FewShotExample] = [
        # Example 1: List all employees
        {
            "question": "List all employees",
            "sql": """SELECT id, first_name, last_name, email, hire_date
FROM employees
ORDER BY last_name, first_name;""",
        },
        # Example 2: Count employees by department
        {
            "question": "How many employees are in each department?",
            "sql": """SELECT d.name AS department, COUNT(e.id) AS employee_count
FROM departments d
LEFT JOIN employees e ON d.id = e.department_id
GROUP BY d.id, d.name
ORDER BY employee_count DESC;""",
        },
        # Example 3: Employees with their job titles
        {
            "question": "Show each employee with their job title",
            "sql": """SELECT e.first_name, e.last_name, j.title AS job_title
FROM employees e
JOIN jobs j ON e.job_id = j.id
ORDER BY e.last_name;""",
        },
        # Example 4: Filter employees by department
        {
            "question": "List employees in the Engineering department",
            "sql": """SELECT e.first_name, e.last_name, e.email
FROM employees e
JOIN departments d ON e.department_id = d.id
WHERE d.name = 'Engineering' AND e.is_active = TRUE
ORDER BY e.last_name;""",
        },
        # Example 5: Count by status
        {
            "question": "How many leave requests are pending?",
            "sql": """SELECT status, COUNT(*) AS request_count
FROM leave_requests
WHERE status = 'pending'
GROUP BY status;""",
        },
        # Example 6: Average salary by department
        {
            "question": "What is the average salary by department?",
            "sql": """SELECT d.name AS department, 
       ROUND(AVG(e.salary), 2) AS average_salary
FROM departments d
LEFT JOIN employees e ON d.id = e.department_id
WHERE e.salary IS NOT NULL
GROUP BY d.id, d.name
ORDER BY average_salary DESC;""",
        },
        # Example 7: Recent hires
        {
            "question": "Show employees hired after January 2023",
            "sql": """SELECT first_name, last_name, hire_date, salary
FROM employees
WHERE hire_date > '2023-01-01'
ORDER BY hire_date DESC;""",
        },
        # Example 8: Top paid employees
        {
            "question": "Show top 5 highest paid employees",
            "sql": """SELECT first_name, last_name, salary, department_id
FROM employees
WHERE salary IS NOT NULL
ORDER BY salary DESC
LIMIT 5;""",
        },
        # Example 9: Employees with no phone
        {
            "question": "Find employees with no phone number listed",
            "sql": """SELECT first_name, last_name, email
FROM employees
WHERE phone IS NULL
ORDER BY last_name;""",
        },
        # Example 10: Department with most employees
        {
            "question": "Which department has the most employees?",
            "sql": """SELECT d.name AS department, COUNT(e.id) AS employee_count
FROM departments d
LEFT JOIN employees e ON d.id = e.department_id
GROUP BY d.id, d.name
ORDER BY employee_count DESC
LIMIT 1;""",
        },
        # Example 11: Leave balance summary
        {
            "question": "Show leave balance for each employee (vacation days)",
            "sql": """SELECT e.first_name, e.last_name, lb.balance_days, lb.used_days
FROM employees e
JOIN leave_balances lb ON e.id = lb.employee_id
WHERE lb.leave_type = 'vacation' AND lb.year = 2024
ORDER BY lb.balance_days DESC;""",
        },
        # Example 12: Attendance summary
        {
            "question": "Show attendance count by status for each employee",
            "sql": """SELECT e.first_name, e.last_name,
       COUNT(CASE WHEN a.status = 'present' THEN 1 END) AS present_days,
       COUNT(CASE WHEN a.status = 'absent' THEN 1 END) AS absent_days
FROM employees e
LEFT JOIN attendance_logs a ON e.id = a.employee_id
WHERE a.date >= '2023-10-23'
GROUP BY e.id, e.first_name, e.last_name
ORDER BY present_days DESC;""",
        },
        # Example 13: Performance average by department
        {
            "question": "What is the average performance score by department?",
            "sql": """SELECT d.name AS department, ROUND(AVG(pr.score), 2) AS avg_performance_score
FROM departments d
LEFT JOIN employees e ON d.id = e.department_id
LEFT JOIN performance_reviews pr ON e.id = pr.employee_id
WHERE pr.score IS NOT NULL
GROUP BY d.id, d.name
ORDER BY avg_performance_score DESC;""",
        },
        # Example 14: Employees with certifications
        {
            "question": "List employees with certifications that expire in 2024",
            "sql": """SELECT e.first_name, e.last_name, c.cert_name, c.expiry_date
FROM employees e
JOIN certifications c ON e.id = c.employee_id
WHERE c.expiry_date BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY c.expiry_date;""",
        },
        # Example 15: Bonuses by year
        {
            "question": "Show total bonus amounts by year",
            "sql": """SELECT year, SUM(amount) AS total_bonus, COUNT(*) AS bonus_count
FROM bonuses
GROUP BY year
ORDER BY year DESC;""",
        },
    ]

    return examples


# Export the examples
FEW_SHOT_EXAMPLES = generate_few_shot_examples()


def get_few_shot_examples() -> list[FewShotExample]:
    """Return the generated few-shot examples."""
    return FEW_SHOT_EXAMPLES


if __name__ == "__main__":
    # Print examples for verification
    for i, ex in enumerate(FEW_SHOT_EXAMPLES, 1):
        print(f"\n--- Example {i} ---")
        print(f"Q: {ex['question']}")
        print(f"SQL: {ex['sql']}")
