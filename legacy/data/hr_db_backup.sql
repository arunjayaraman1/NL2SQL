--
-- PostgreSQL database dump
--

\restrict Qev3j96MwtHvNNNzUZWB1smibCmM9HKuI2dKuL9uR0iFm5Fh7Xu34uGunaflSYw

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hr; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA hr;


ALTER SCHEMA hr OWNER TO pg_database_owner;

--
-- Name: SCHEMA hr; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA hr IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: approvals; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.approvals (
    id integer NOT NULL,
    request_type character varying(50) NOT NULL,
    requester_id integer,
    approver_id integer,
    request_date date DEFAULT CURRENT_DATE,
    approval_date date,
    status character varying(20) DEFAULT 'pending'::character varying,
    comments text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.approvals OWNER TO newpage;

--
-- Name: approvals_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.approvals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.approvals_id_seq OWNER TO newpage;

--
-- Name: approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.approvals_id_seq OWNED BY hr.approvals.id;


--
-- Name: attendance_logs; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.attendance_logs (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    date date NOT NULL,
    status character varying(20) NOT NULL,
    clock_in time without time zone,
    clock_out time without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.attendance_logs OWNER TO newpage;

--
-- Name: attendance_logs_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.attendance_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.attendance_logs_id_seq OWNER TO newpage;

--
-- Name: attendance_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.attendance_logs_id_seq OWNED BY hr.attendance_logs.id;


--
-- Name: audit_logs; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.audit_logs (
    id integer NOT NULL,
    employee_id integer,
    action character varying(50) NOT NULL,
    table_affected character varying(50),
    record_id integer,
    old_value text,
    new_value text,
    ip_address character varying(45),
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.audit_logs OWNER TO newpage;

--
-- Name: audit_logs_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.audit_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.audit_logs_id_seq OWNER TO newpage;

--
-- Name: audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.audit_logs_id_seq OWNED BY hr.audit_logs.id;


--
-- Name: bonuses; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.bonuses (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    year integer NOT NULL,
    bonus_type character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.bonuses OWNER TO newpage;

--
-- Name: bonuses_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.bonuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.bonuses_id_seq OWNER TO newpage;

--
-- Name: bonuses_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.bonuses_id_seq OWNED BY hr.bonuses.id;


--
-- Name: certifications; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.certifications (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    cert_name character varying(100) NOT NULL,
    issued_date date NOT NULL,
    expiry_date date,
    credential_id character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.certifications OWNER TO newpage;

--
-- Name: certifications_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.certifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.certifications_id_seq OWNER TO newpage;

--
-- Name: certifications_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.certifications_id_seq OWNED BY hr.certifications.id;


--
-- Name: departments; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.departments (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    code character varying(20) NOT NULL,
    manager_id integer,
    parent_department_id integer,
    location character varying(100),
    budget numeric(15,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.departments OWNER TO newpage;

--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.departments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.departments_id_seq OWNER TO newpage;

--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.departments_id_seq OWNED BY hr.departments.id;


--
-- Name: emergency_contacts; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.emergency_contacts (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    name character varying(100) NOT NULL,
    relationship character varying(30),
    phone character varying(20) NOT NULL,
    alternate_phone character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.emergency_contacts OWNER TO newpage;

--
-- Name: emergency_contacts_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.emergency_contacts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.emergency_contacts_id_seq OWNER TO newpage;

--
-- Name: emergency_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.emergency_contacts_id_seq OWNED BY hr.emergency_contacts.id;


--
-- Name: employees; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.employees (
    id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    phone character varying(20),
    hire_date date NOT NULL,
    job_id integer,
    department_id integer,
    manager_id integer,
    salary numeric(12,2),
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.employees OWNER TO newpage;

--
-- Name: employees_history; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.employees_history (
    id integer NOT NULL,
    employee_id integer,
    status character varying(20) NOT NULL,
    effective_date date NOT NULL,
    reason text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.employees_history OWNER TO newpage;

--
-- Name: employees_history_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.employees_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.employees_history_id_seq OWNER TO newpage;

--
-- Name: employees_history_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.employees_history_id_seq OWNED BY hr.employees_history.id;


--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.employees_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.employees_id_seq OWNER TO newpage;

--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.employees_id_seq OWNED BY hr.employees.id;


--
-- Name: jobs; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.jobs (
    id integer NOT NULL,
    title character varying(100) NOT NULL,
    description text,
    min_salary numeric(12,2),
    max_salary numeric(12,2),
    department_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.jobs OWNER TO newpage;

--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.jobs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.jobs_id_seq OWNER TO newpage;

--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.jobs_id_seq OWNED BY hr.jobs.id;


--
-- Name: leave_balances; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.leave_balances (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    leave_type character varying(20) NOT NULL,
    year integer NOT NULL,
    balance_days integer DEFAULT 0 NOT NULL,
    used_days integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.leave_balances OWNER TO newpage;

--
-- Name: leave_balances_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.leave_balances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.leave_balances_id_seq OWNER TO newpage;

--
-- Name: leave_balances_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.leave_balances_id_seq OWNED BY hr.leave_balances.id;


--
-- Name: leave_requests; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.leave_requests (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    leave_type character varying(20) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying,
    approver_id integer,
    request_date date DEFAULT CURRENT_DATE,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.leave_requests OWNER TO newpage;

--
-- Name: leave_requests_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.leave_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.leave_requests_id_seq OWNER TO newpage;

--
-- Name: leave_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.leave_requests_id_seq OWNED BY hr.leave_requests.id;


--
-- Name: performance_reviews; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.performance_reviews (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    review_date date NOT NULL,
    score integer,
    feedback text,
    reviewer_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT performance_reviews_score_check CHECK (((score >= 1) AND (score <= 5)))
);


ALTER TABLE hr.performance_reviews OWNER TO newpage;

--
-- Name: performance_reviews_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.performance_reviews_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.performance_reviews_id_seq OWNER TO newpage;

--
-- Name: performance_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.performance_reviews_id_seq OWNED BY hr.performance_reviews.id;


--
-- Name: promotions; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.promotions (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    old_job_id integer,
    new_job_id integer,
    old_salary numeric(12,2),
    new_salary numeric(12,2),
    promotion_date date NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.promotions OWNER TO newpage;

--
-- Name: promotions_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.promotions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.promotions_id_seq OWNER TO newpage;

--
-- Name: promotions_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.promotions_id_seq OWNED BY hr.promotions.id;


--
-- Name: query_logs; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.query_logs (
    id integer NOT NULL,
    question text NOT NULL,
    sql_query text,
    db_type character varying(50) DEFAULT 'hr'::character varying,
    success boolean DEFAULT false,
    error_message text,
    columns jsonb,
    row_count integer,
    execution_time_ms integer,
    use_schema_linking boolean DEFAULT true,
    use_retry boolean DEFAULT true,
    retry_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    session_id character varying(255),
    user_id character varying(255)
);


ALTER TABLE hr.query_logs OWNER TO newpage;

--
-- Name: TABLE query_logs; Type: COMMENT; Schema: hr; Owner: newpage
--

COMMENT ON TABLE hr.query_logs IS 'Stores all NL2SQL query logs with execution metadata';


--
-- Name: COLUMN query_logs.question; Type: COMMENT; Schema: hr; Owner: newpage
--

COMMENT ON COLUMN hr.query_logs.question IS 'Original natural language question from user';


--
-- Name: COLUMN query_logs.sql_query; Type: COMMENT; Schema: hr; Owner: newpage
--

COMMENT ON COLUMN hr.query_logs.sql_query IS 'Generated SQL query (may be NULL on error)';


--
-- Name: COLUMN query_logs.success; Type: COMMENT; Schema: hr; Owner: newpage
--

COMMENT ON COLUMN hr.query_logs.success IS 'Whether the query executed successfully';


--
-- Name: COLUMN query_logs.error_message; Type: COMMENT; Schema: hr; Owner: newpage
--

COMMENT ON COLUMN hr.query_logs.error_message IS 'Error message if query failed';


--
-- Name: COLUMN query_logs.execution_time_ms; Type: COMMENT; Schema: hr; Owner: newpage
--

COMMENT ON COLUMN hr.query_logs.execution_time_ms IS 'Total execution time in milliseconds';


--
-- Name: query_logs_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.query_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.query_logs_id_seq OWNER TO newpage;

--
-- Name: query_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.query_logs_id_seq OWNED BY hr.query_logs.id;


--
-- Name: salaries; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.salaries (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    effective_date date NOT NULL,
    end_date date,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.salaries OWNER TO newpage;

--
-- Name: salaries_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.salaries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.salaries_id_seq OWNER TO newpage;

--
-- Name: salaries_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.salaries_id_seq OWNED BY hr.salaries.id;


--
-- Name: terminations; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.terminations (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    termination_date date NOT NULL,
    reason character varying(200),
    exit_interview_completed boolean DEFAULT false,
    final_settlement numeric(12,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.terminations OWNER TO newpage;

--
-- Name: terminations_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.terminations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.terminations_id_seq OWNER TO newpage;

--
-- Name: terminations_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.terminations_id_seq OWNED BY hr.terminations.id;


--
-- Name: training_enrollments; Type: TABLE; Schema: hr; Owner: newpage
--

CREATE TABLE hr.training_enrollments (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    training_name character varying(100) NOT NULL,
    training_date date NOT NULL,
    duration_hours integer,
    enrollment_date date DEFAULT CURRENT_DATE,
    status character varying(20) DEFAULT 'enrolled'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE hr.training_enrollments OWNER TO newpage;

--
-- Name: training_enrollments_id_seq; Type: SEQUENCE; Schema: hr; Owner: newpage
--

CREATE SEQUENCE hr.training_enrollments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE hr.training_enrollments_id_seq OWNER TO newpage;

--
-- Name: training_enrollments_id_seq; Type: SEQUENCE OWNED BY; Schema: hr; Owner: newpage
--

ALTER SEQUENCE hr.training_enrollments_id_seq OWNED BY hr.training_enrollments.id;


--
-- Name: approvals id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.approvals ALTER COLUMN id SET DEFAULT nextval('hr.approvals_id_seq'::regclass);


--
-- Name: attendance_logs id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.attendance_logs ALTER COLUMN id SET DEFAULT nextval('hr.attendance_logs_id_seq'::regclass);


--
-- Name: audit_logs id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.audit_logs ALTER COLUMN id SET DEFAULT nextval('hr.audit_logs_id_seq'::regclass);


--
-- Name: bonuses id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.bonuses ALTER COLUMN id SET DEFAULT nextval('hr.bonuses_id_seq'::regclass);


--
-- Name: certifications id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.certifications ALTER COLUMN id SET DEFAULT nextval('hr.certifications_id_seq'::regclass);


--
-- Name: departments id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.departments ALTER COLUMN id SET DEFAULT nextval('hr.departments_id_seq'::regclass);


--
-- Name: emergency_contacts id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.emergency_contacts ALTER COLUMN id SET DEFAULT nextval('hr.emergency_contacts_id_seq'::regclass);


--
-- Name: employees id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.employees ALTER COLUMN id SET DEFAULT nextval('hr.employees_id_seq'::regclass);


--
-- Name: employees_history id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.employees_history ALTER COLUMN id SET DEFAULT nextval('hr.employees_history_id_seq'::regclass);


--
-- Name: jobs id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.jobs ALTER COLUMN id SET DEFAULT nextval('hr.jobs_id_seq'::regclass);


--
-- Name: leave_balances id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.leave_balances ALTER COLUMN id SET DEFAULT nextval('hr.leave_balances_id_seq'::regclass);


--
-- Name: leave_requests id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.leave_requests ALTER COLUMN id SET DEFAULT nextval('hr.leave_requests_id_seq'::regclass);


--
-- Name: performance_reviews id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.performance_reviews ALTER COLUMN id SET DEFAULT nextval('hr.performance_reviews_id_seq'::regclass);


--
-- Name: promotions id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.promotions ALTER COLUMN id SET DEFAULT nextval('hr.promotions_id_seq'::regclass);


--
-- Name: query_logs id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.query_logs ALTER COLUMN id SET DEFAULT nextval('hr.query_logs_id_seq'::regclass);


--
-- Name: salaries id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.salaries ALTER COLUMN id SET DEFAULT nextval('hr.salaries_id_seq'::regclass);


--
-- Name: terminations id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.terminations ALTER COLUMN id SET DEFAULT nextval('hr.terminations_id_seq'::regclass);


--
-- Name: training_enrollments id; Type: DEFAULT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.training_enrollments ALTER COLUMN id SET DEFAULT nextval('hr.training_enrollments_id_seq'::regclass);


--
-- Data for Name: approvals; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.approvals (id, request_type, requester_id, approver_id, request_date, approval_date, status, comments, created_at) FROM stdin;
1	leave	6	5	2023-10-20	2023-10-21	approved	\N	2026-04-17 11:59:24.078903
2	leave	14	1	2023-10-22	2023-10-22	approved	\N	2026-04-17 11:59:24.078903
3	expense	2	1	2023-10-15	2023-10-16	approved	\N	2026-04-17 11:59:24.078903
4	expense	9	13	2023-10-18	2023-10-19	approved	\N	2026-04-17 11:59:24.078903
5	reimbursement	18	5	2023-10-25	\N	pending	\N	2026-04-17 11:59:24.078903
6	leave	8	5	2023-10-28	2023-10-28	approved	\N	2026-04-17 11:59:24.078903
7	expense	13	1	2023-10-10	2023-10-11	approved	\N	2026-04-17 11:59:24.078903
8	leave	24	1	2023-10-30	\N	pending	\N	2026-04-17 11:59:24.078903
9	leave	10	13	2023-11-01	2023-11-01	approved	\N	2026-04-17 11:59:24.078903
10	expense	21	1	2023-10-12	2023-10-13	approved	\N	2026-04-17 11:59:24.078903
11	leave	25	5	2023-11-05	2023-11-05	approved	\N	2026-04-17 11:59:24.078903
12	reimbursement	7	9	2023-10-22	2023-10-23	approved	\N	2026-04-17 11:59:24.078903
13	leave	19	1	2023-11-08	\N	pending	\N	2026-04-17 11:59:24.078903
14	expense	15	5	2023-10-28	2023-10-29	approved	\N	2026-04-17 11:59:24.078903
15	leave	1	\N	2023-11-10	\N	pending	\N	2026-04-17 11:59:24.078903
\.


--
-- Data for Name: attendance_logs; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.attendance_logs (id, employee_id, date, status, clock_in, clock_out, created_at) FROM stdin;
1	2	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
2	2	2023-10-24	present	09:00:00	18:05:00	2026-04-17 11:59:24.074827
3	2	2023-10-25	present	08:55:00	17:55:00	2026-04-17 11:59:24.074827
4	3	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
5	3	2023-10-24	late	09:15:00	18:00:00	2026-04-17 11:59:24.074827
6	3	2023-10-25	present	09:00:00	18:10:00	2026-04-17 11:59:24.074827
7	4	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
8	4	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
9	4	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
10	5	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
11	5	2023-10-24	absent	\N	\N	2026-04-17 11:59:24.074827
12	5	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
13	7	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
14	7	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
15	7	2023-10-25	present	09:00:00	17:45:00	2026-04-17 11:59:24.074827
16	8	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
17	8	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
18	8	2023-10-25	half_day	09:00:00	13:00:00	2026-04-17 11:59:24.074827
19	9	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
20	9	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
21	9	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
22	10	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
23	10	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
24	10	2023-10-25	present	09:10:00	18:00:00	2026-04-17 11:59:24.074827
25	11	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
26	11	2023-10-24	present	08:45:00	18:00:00	2026-04-17 11:59:24.074827
27	11	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
28	12	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
29	12	2023-10-24	absent	\N	\N	2026-04-17 11:59:24.074827
30	12	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
31	13	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
32	13	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
33	13	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
34	14	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
35	14	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
36	14	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
37	15	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
38	15	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
39	15	2023-10-25	present	09:00:00	17:30:00	2026-04-17 11:59:24.074827
40	16	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
41	16	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
42	16	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
43	17	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
44	17	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
45	17	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
46	18	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
47	18	2023-10-24	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
48	18	2023-10-25	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
49	19	2023-10-23	present	09:00:00	18:00:00	2026-04-17 11:59:24.074827
50	19	2023-10-24	late	09:20:00	18:00:00	2026-04-17 11:59:24.074827
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.audit_logs (id, employee_id, action, table_affected, record_id, old_value, new_value, ip_address, "timestamp") FROM stdin;
1	1	login	employees	1	\N	User logged in	192.168.1.100	2026-04-17 11:59:24.079766
2	2	create	employees	3	\N	New employee record created	192.168.1.105	2026-04-17 11:59:24.079766
3	2	update	employees	3	\N	Updated salary information	192.168.1.105	2026-04-17 11:59:24.079766
4	5	create	leave_requests	1	\N	New leave request submitted	192.168.1.110	2026-04-17 11:59:24.079766
5	5	approve	leave_requests	1	\N	Leave request approved	192.168.1.110	2026-04-17 11:59:24.079766
6	1	update	employees	1	\N	Promotion processed	192.168.1.100	2026-04-17 11:59:24.079766
7	2	create	performance_reviews	1	\N	Performance review created	192.168.1.105	2026-04-17 11:59:24.079766
8	2	update	employees	3	\N	Performance score updated	192.168.1.105	2026-04-17 11:59:24.079766
9	3	create	bonuses	1	\N	Bonus record created	192.168.1.108	2026-04-17 11:59:24.079766
10	5	create	leave_requests	2	\N	Leave request submitted	192.168.1.110	2026-04-17 11:59:24.079766
11	5	approve	leave_requests	2	\N	Leave request approved	192.168.1.110	2026-04-17 11:59:24.079766
12	1	create	promotions	1	\N	Promotion record created	192.168.1.100	2026-04-17 11:59:24.079766
13	2	create	training_enrollments	1	\N	Training enrollment created	192.168.1.105	2026-04-17 11:59:24.079766
14	3	update	employees	4	\N	Updated job title	192.168.1.108	2026-04-17 11:59:24.079766
15	4	create	certifications	1	\N	Certification record created	192.168.1.109	2026-04-17 11:59:24.079766
16	5	create	approvals	3	\N	Expense approval request	192.168.1.110	2026-04-17 11:59:24.079766
17	5	update	approvals	3	\N	Expense approved	192.168.1.110	2026-04-17 11:59:24.079766
18	1	login	employees	1	\N	User logged in	192.168.1.100	2026-04-17 11:59:24.079766
19	2	create	attendance_logs	1	\N	Attendance marked	192.168.1.105	2026-04-17 11:59:24.079766
20	3	update	employees	5	\N	Updated department	192.168.1.108	2026-04-17 11:59:24.079766
\.


--
-- Data for Name: bonuses; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.bonuses (id, employee_id, amount, year, bonus_type, created_at) FROM stdin;
1	1	15000.00	2023	performance	2026-04-17 11:59:24.072263
2	4	12000.00	2023	performance	2026-04-17 11:59:24.072263
3	2	8000.00	2023	performance	2026-04-17 11:59:24.072263
4	5	7500.00	2023	referral	2026-04-17 11:59:24.072263
5	7	6000.00	2023	performance	2026-04-17 11:59:24.072263
6	9	5000.00	2023	performance	2026-04-17 11:59:24.072263
7	11	5500.00	2022	performance	2026-04-17 11:59:24.072263
8	13	5000.00	2023	signing	2026-04-17 11:59:24.072263
9	15	7000.00	2023	performance	2026-04-17 11:59:24.072263
10	17	9000.00	2023	performance	2026-04-17 11:59:24.072263
11	19	6000.00	2023	performance	2026-04-17 11:59:24.072263
12	21	7500.00	2023	performance	2026-04-17 11:59:24.072263
13	1	12000.00	2022	performance	2026-04-17 11:59:24.072263
14	4	10000.00	2022	performance	2026-04-17 11:59:24.072263
15	8	5500.00	2022	performance	2026-04-17 11:59:24.072263
\.


--
-- Data for Name: certifications; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.certifications (id, employee_id, cert_name, issued_date, expiry_date, credential_id, created_at) FROM stdin;
1	2	AWS Solutions Architect	2023-03-01	2026-03-01	AWS-SAA-2023-001	2026-04-17 11:59:24.077373
2	3	PMP Certification	2022-11-15	2025-11-15	PMP-2022-455	2026-04-17 11:59:24.077373
3	4	AWS Developer Associate	2023-06-20	2026-06-20	AWS-DEV-2023-089	2026-04-17 11:59:24.077373
4	7	CPA	2021-05-10	2025-05-10	CPA-2021-223	2026-04-17 11:59:24.077373
5	9	Google Analytics Certified	2023-01-15	2024-01-15	GA-2023-112	2026-04-17 11:59:24.077373
6	11	HubSpot Sales Certified	2023-04-01	2024-04-01	HS-SC-2023-445	2026-04-17 11:59:24.077373
7	13	CompTIA A+	2022-08-20	2025-08-20	CompTIA-A-2022-667	2026-04-17 11:59:24.077373
8	15	PMP	2022-03-01	2025-03-01	PMP-2022-889	2026-04-17 11:59:24.077373
9	17	Juris Doctor	2020-06-15	\N	JD-2020-112	2026-04-17 11:59:24.077373
10	19	CSM Certified	2023-02-01	2024-02-01	CSM-2023-223	2026-04-17 11:59:24.077373
11	21	Scrum Master	2023-07-01	2024-07-01	SM-2023-334	2026-04-17 11:59:24.077373
12	22	PhD in Computer Science	2018-05-01	\N	PHD-CS-2018-112	2026-04-17 11:59:24.077373
13	23	Machine Learning Specialization	2023-08-15	2025-08-15	ML-2023-556	2026-04-17 11:59:24.077373
14	1	MBA	2019-12-01	\N	MBA-2019-889	2026-04-17 11:59:24.077373
15	4	System Design Certificate	2023-09-01	2024-09-01	SD-2023-667	2026-04-17 11:59:24.077373
\.


--
-- Data for Name: departments; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.departments (id, name, code, manager_id, parent_department_id, location, budget, created_at) FROM stdin;
6	IT Support	IT	\N	1	Building A, Floor 4	250000.00	2026-04-17 11:59:24.066377
7	Operations	OPS	\N	\N	Building C, Floor 1	350000.00	2026-04-17 11:59:24.066377
8	Legal	LGL	\N	3	Building B, Floor 3	100000.00	2026-04-17 11:59:24.066377
9	Customer Success	CS	\N	5	Building A, Floor 1	180000.00	2026-04-17 11:59:24.066377
10	Product	PROD	\N	1	Building A, Floor 3	220000.00	2026-04-17 11:59:24.066377
11	Research	R&D	\N	1	Building C, Floor 2	280000.00	2026-04-17 11:59:24.066377
12	Administration	ADMIN	\N	2	Building B, Floor 1	80000.00	2026-04-17 11:59:24.066377
1	Engineering	ENG	1	\N	Building A, Floor 3	500000.00	2026-04-17 11:59:24.066377
2	Human Resources	HR	5	\N	Building B, Floor 1	150000.00	2026-04-17 11:59:24.066377
3	Finance	FIN	9	\N	Building B, Floor 2	200000.00	2026-04-17 11:59:24.066377
4	Marketing	MKT	13	\N	Building A, Floor 2	300000.00	2026-04-17 11:59:24.066377
5	Sales	SLS	17	\N	Building A, Floor 1	400000.00	2026-04-17 11:59:24.066377
\.


--
-- Data for Name: emergency_contacts; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.emergency_contacts (id, employee_id, name, relationship, phone, alternate_phone, created_at) FROM stdin;
1	1	Mary Smith	spouse	555-1001	555-1002	2026-04-17 11:59:24.080441
2	2	Tom Johnson	father	555-1003	\N	2026-04-17 11:59:24.080441
3	3	Linda Wilson	mother	555-1004	555-1005	2026-04-17 11:59:24.080441
4	4	Robert Brown	spouse	555-1006	\N	2026-04-17 11:59:24.080441
5	5	Patricia Davis	mother	555-1007	555-1008	2026-04-17 11:59:24.080441
6	6	James Taylor	spouse	555-1009	\N	2026-04-17 11:59:24.080441
7	7	Jennifer Martinez	sister	555-1010	555-1011	2026-04-17 11:59:24.080441
8	8	David Anderson	father	555-1012	\N	2026-04-17 11:59:24.080441
9	9	Lisa Thomas	mother	555-1013	\N	2026-04-17 11:59:24.080441
10	10	Mark Jackson	spouse	555-1014	555-1015	2026-04-17 11:59:24.080441
11	11	Susan White	sister	555-1016	\N	2026-04-17 11:59:24.080441
12	12	Paul Harris	father	555-1017	\N	2026-04-17 11:59:24.080441
13	13	Karen Martin	mother	555-1018	555-1019	2026-04-17 11:59:24.080441
14	14	Steven Thompson	spouse	555-1020	\N	2026-04-17 11:59:24.080441
15	15	Sandra Garcia	sister	555-1021	\N	2026-04-17 11:59:24.080441
16	16	Kevin Robinson	father	555-1022	\N	2026-04-17 11:59:24.080441
17	17	Betty Clark	mother	555-1023	\N	2026-04-17 11:59:24.080441
18	18	Brian Lewis	spouse	555-1024	555-1025	2026-04-17 11:59:24.080441
19	19	Nancy Lee	sister	555-1026	\N	2026-04-17 11:59:24.080441
20	20	George Walker	father	555-1027	\N	2026-04-17 11:59:24.080441
\.


--
-- Data for Name: employees; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.employees (id, first_name, last_name, email, phone, hire_date, job_id, department_id, manager_id, salary, is_active, created_at) FROM stdin;
1	John	Smith	john.smith@company.com	555-0101	2020-01-15	14	1	\N	125000.00	t	2026-04-17 11:59:24.069083
2	Sarah	Johnson	sarah.johnson@company.com	555-0102	2019-03-20	1	1	1	85000.00	t	2026-04-17 11:59:24.069083
3	Michael	Brown	michael.brown@company.com	555-0103	2021-06-10	1	1	1	72000.00	t	2026-04-17 11:59:24.069083
4	Emily	Davis	emily.davis@company.com	555-0104	2018-11-05	2	1	1	105000.00	t	2026-04-17 11:59:24.069083
5	David	Wilson	david.wilson@company.com	555-0105	2020-08-15	3	2	5	68000.00	t	2026-04-17 11:59:24.069083
6	Jessica	Taylor	jessica.taylor@company.com	\N	2017-02-28	3	2	5	72000.00	t	2026-04-17 11:59:24.069083
7	James	Anderson	james.anderson@company.com	555-0107	2019-09-12	4	3	9	62000.00	t	2026-04-17 11:59:24.069083
8	Jennifer	Thomas	jennifer.thomas@company.com	555-0108	2021-01-05	4	3	9	58000.00	t	2026-04-17 11:59:24.069083
9	Robert	Garcia	robert.garcia@company.com	555-0109	2020-04-20	5	4	13	52000.00	t	2026-04-17 11:59:24.069083
10	Lisa	Martinez	lisa.martinez@company.com	555-0110	2022-02-14	5	4	13	48000.00	t	2026-04-17 11:59:24.069083
11	William	Rodriguez	william.rodriguez@company.com	555-0111	2018-07-01	6	5	17	55000.00	t	2026-04-17 11:59:24.069083
12	Ashley	Lee	ashley.lee@company.com	\N	2019-12-10	6	5	17	58000.00	t	2026-04-17 11:59:24.069083
13	Christopher	Gonzalez	christopher.gonzalez@company.com	555-0113	2021-03-25	7	6	1	55000.00	t	2026-04-17 11:59:24.069083
14	Amanda	Walker	amanda.walker@company.com	555-0114	2020-11-30	7	6	1	52000.00	t	2026-04-17 11:59:24.069083
15	Daniel	Hall	daniel.hall@company.com	555-0115	2017-06-15	8	7	5	72000.00	t	2026-04-17 11:59:24.069083
16	Michelle	Allen	michelle.allen@company.com	555-0116	2022-07-20	8	7	5	65000.00	t	2026-04-17 11:59:24.069083
17	Matthew	Young	matthew.young@company.com	555-0117	2019-04-08	9	8	9	95000.00	t	2026-04-17 11:59:24.069083
18	Stephanie	King	stephanie.king@company.com	\N	2020-09-15	9	8	9	82000.00	t	2026-04-17 11:59:24.069083
19	Andrew	Wright	andrew.wright@company.com	555-0119	2021-08-01	10	9	17	62000.00	t	2026-04-17 11:59:24.069083
20	Nicole	Lopez	nicole.lopez@company.com	555-0120	2018-12-20	10	9	17	58000.00	t	2026-04-17 11:59:24.069083
21	Joshua	Hill	joshua.hill@company.com	555-0121	2022-01-10	11	10	1	78000.00	t	2026-04-17 11:59:24.069083
22	Rachel	Scott	rachel.scott@company.com	555-0122	2019-07-25	11	10	1	88000.00	t	2026-04-17 11:59:24.069083
23	Kevin	Green	kevin.green@company.com	555-0123	2020-05-15	12	11	1	82000.00	t	2026-04-17 11:59:24.069083
24	Samantha	Adams	samantha.adams@company.com	\N	2021-10-01	12	11	1	75000.00	t	2026-04-17 11:59:24.069083
25	Brian	Baker	brian.baker@company.com	555-0125	2017-03-10	13	12	5	42000.00	t	2026-04-17 11:59:24.069083
\.


--
-- Data for Name: employees_history; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.employees_history (id, employee_id, status, effective_date, reason, created_at) FROM stdin;
1	1	active	2020-01-15	Hired as Tech Lead	2026-04-17 11:59:24.070666
2	2	active	2021-06-10	New hire	2026-04-17 11:59:24.070666
3	3	active	2021-06-10	Promoted to Senior Engineer	2026-04-17 11:59:24.070666
4	3	active	2023-01-15	Completed probation	2026-04-17 11:59:24.070666
5	4	active	2018-11-05	Hired as Senior Engineer	2026-04-17 11:59:24.070666
6	5	active	2020-08-15	Hired as HR Manager	2026-04-17 11:59:24.070666
7	6	on_leave	2017-02-28	Maternity leave	2026-04-17 11:59:24.070666
8	6	active	2017-06-28	Returned from maternity leave	2026-04-17 11:59:24.070666
9	7	active	2019-09-12	Hired as Finance Analyst	2026-04-17 11:59:24.070666
10	8	active	2021-01-05	Hired	2026-04-17 11:59:24.070666
11	9	active	2020-04-20	Hired as Marketing Coordinator	2026-04-17 11:59:24.070666
12	10	active	2022-02-14	Hired	2026-04-17 11:59:24.070666
13	11	active	2018-07-01	Hired as Sales Rep	2026-04-17 11:59:24.070666
14	12	active	2019-12-10	Hired	2026-04-17 11:59:24.070666
15	13	active	2021-03-25	Hired as IT Support	2026-04-17 11:59:24.070666
16	14	on_leave	2020-11-30	Sick leave	2026-04-17 11:59:24.070666
17	14	active	2020-12-15	Returned	2026-04-17 11:59:24.070666
18	15	active	2017-06-15	Hired as Operations Manager	2026-04-17 11:59:24.070666
19	16	active	2022-07-20	New hire	2026-04-17 11:59:24.070666
20	17	active	2019-04-08	Hired as Legal Counsel	2026-04-17 11:59:24.070666
21	18	active	2020-09-15	Hired	2026-04-17 11:59:24.070666
22	19	active	2021-08-01	Hired	2026-04-17 11:59:24.070666
23	20	active	2018-12-20	Hired	2026-04-17 11:59:24.070666
24	21	active	2022-01-10	Hired as Research Scientist	2026-04-17 11:59:24.070666
25	22	active	2019-07-25	Senior hire	2026-04-17 11:59:24.070666
26	23	active	2020-05-15	Research Scientist	2026-04-17 11:59:24.070666
27	24	active	2021-10-01	Research Scientist	2026-04-17 11:59:24.070666
28	25	active	2017-03-10	Administrative Assistant	2026-04-17 11:59:24.070666
29	5	active	2023-01-01	Promotion to HR Director	2026-04-17 11:59:24.070666
30	1	active	2023-06-01	Promotion to Engineering Director	2026-04-17 11:59:24.070666
\.


--
-- Data for Name: jobs; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.jobs (id, title, description, min_salary, max_salary, department_id, created_at) FROM stdin;
1	Software Engineer	Develops software applications	60000.00	120000.00	1	2026-04-17 11:59:24.067348
2	Senior Software Engineer	Leads software development	90000.00	150000.00	1	2026-04-17 11:59:24.067348
3	HR Manager	Manages HR operations	55000.00	85000.00	2	2026-04-17 11:59:24.067348
4	Finance Analyst	Analyzes financial data	50000.00	75000.00	3	2026-04-17 11:59:24.067348
5	Marketing Coordinator	Coordinates marketing activities	45000.00	65000.00	4	2026-04-17 11:59:24.067348
6	Sales Representative	Handles sales inquiries	40000.00	60000.00	5	2026-04-17 11:59:24.067348
7	IT Support Specialist	Provides IT support	45000.00	70000.00	6	2026-04-17 11:59:24.067348
8	Operations Manager	Manages operations	55000.00	85000.00	7	2026-04-17 11:59:24.067348
9	Legal Counsel	Provides legal advice	70000.00	120000.00	8	2026-04-17 11:59:24.067348
10	Customer Success Manager	Manages customer relations	50000.00	75000.00	9	2026-04-17 11:59:24.067348
11	Product Manager	Manages product development	70000.00	110000.00	10	2026-04-17 11:59:24.067348
12	Research Scientist	Conducts research	65000.00	100000.00	11	2026-04-17 11:59:24.067348
13	Administrative Assistant	Provides administrative support	35000.00	50000.00	12	2026-04-17 11:59:24.067348
14	Tech Lead	Leads technical team	100000.00	160000.00	1	2026-04-17 11:59:24.067348
15	Financial Controller	Controllers financial operations	80000.00	130000.00	3	2026-04-17 11:59:24.067348
\.


--
-- Data for Name: leave_balances; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.leave_balances (id, employee_id, leave_type, year, balance_days, used_days, created_at) FROM stdin;
1	1	vacation	2024	15	0	2026-04-17 11:59:24.073861
2	1	sick	2024	10	0	2026-04-17 11:59:24.073861
3	2	vacation	2024	12	0	2026-04-17 11:59:24.073861
4	2	sick	2024	8	0	2026-04-17 11:59:24.073861
5	3	vacation	2024	10	2	2026-04-17 11:59:24.073861
6	3	sick	2024	8	0	2026-04-17 11:59:24.073861
7	4	vacation	2024	18	0	2026-04-17 11:59:24.073861
8	4	sick	2024	10	0	2026-04-17 11:59:24.073861
9	5	vacation	2024	15	0	2026-04-17 11:59:24.073861
10	5	sick	2024	10	2	2026-04-17 11:59:24.073861
11	6	vacation	2024	15	5	2026-04-17 11:59:24.073861
12	6	sick	2024	10	0	2026-04-17 11:59:24.073861
13	7	vacation	2024	12	0	2026-04-17 11:59:24.073861
14	7	sick	2024	8	0	2026-04-17 11:59:24.073861
15	8	vacation	2024	10	0	2026-04-17 11:59:24.073861
16	8	sick	2024	8	0	2026-04-17 11:59:24.073861
17	9	vacation	2024	12	3	2026-04-17 11:59:24.073861
18	9	sick	2024	8	0	2026-04-17 11:59:24.073861
19	10	vacation	2024	8	0	2026-04-17 11:59:24.073861
20	10	sick	2024	8	0	2026-04-17 11:59:24.073861
21	11	vacation	2024	15	0	2026-04-17 11:59:24.073861
22	11	sick	2024	10	0	2026-04-17 11:59:24.073861
23	12	vacation	2024	10	0	2026-04-17 11:59:24.073861
24	12	sick	2024	8	0	2026-04-17 11:59:24.073861
25	13	vacation	2024	12	0	2026-04-17 11:59:24.073861
26	13	sick	2024	8	0	2026-04-17 11:59:24.073861
27	14	vacation	2024	12	2	2026-04-17 11:59:24.073861
28	14	sick	2024	8	2	2026-04-17 11:59:24.073861
29	15	vacation	2024	18	0	2026-04-17 11:59:24.073861
30	15	sick	2024	10	0	2026-04-17 11:59:24.073861
31	16	vacation	2024	10	0	2026-04-17 11:59:24.073861
32	16	sick	2024	8	0	2026-04-17 11:59:24.073861
33	17	vacation	2024	15	0	2026-04-17 11:59:24.073861
34	17	sick	2024	10	0	2026-04-17 11:59:24.073861
35	18	vacation	2024	12	0	2026-04-17 11:59:24.073861
36	18	sick	2024	8	0	2026-04-17 11:59:24.073861
37	19	vacation	2024	10	0	2026-04-17 11:59:24.073861
38	19	sick	2024	8	0	2026-04-17 11:59:24.073861
39	20	vacation	2024	15	0	2026-04-17 11:59:24.073861
40	20	sick	2024	10	0	2026-04-17 11:59:24.073861
\.


--
-- Data for Name: leave_requests; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.leave_requests (id, employee_id, leave_type, start_date, end_date, status, approver_id, request_date, created_at) FROM stdin;
1	6	maternity	2023-11-01	2023-12-31	approved	5	2026-04-17	2026-04-17 11:59:24.072917
2	14	sick	2023-10-15	2023-10-17	approved	1	2026-04-17	2026-04-17 11:59:24.072917
3	2	vacation	2023-12-20	2023-12-27	approved	1	2026-04-17	2026-04-17 11:59:24.072917
4	3	personal	2023-11-10	2023-11-10	approved	1	2026-04-17	2026-04-17 11:59:24.072917
5	8	vacation	2024-01-05	2024-01-12	pending	5	2026-04-17	2026-04-17 11:59:24.072917
6	12	sick	2023-09-01	2023-09-02	approved	1	2026-04-17	2026-04-17 11:59:24.072917
7	16	vacation	2023-12-25	2023-12-30	approved	5	2026-04-17	2026-04-17 11:59:24.072917
8	21	personal	2023-11-15	2023-11-15	rejected	5	2026-04-17	2026-04-17 11:59:24.072917
9	24	vacation	2024-02-01	2024-02-14	pending	1	2026-04-17	2026-04-17 11:59:24.072917
10	5	sick	2023-10-05	2023-10-06	approved	5	2026-04-17	2026-04-17 11:59:24.072917
11	9	vacation	2023-12-15	2023-12-22	approved	13	2026-04-17	2026-04-17 11:59:24.072917
12	18	maternity	2024-01-15	2024-03-15	approved	5	2026-04-17	2026-04-17 11:59:24.072917
13	22	personal	2023-11-20	2023-11-20	approved	1	2026-04-17	2026-04-17 11:59:24.072917
14	10	vacation	2024-01-20	2024-01-27	pending	13	2026-04-17	2026-04-17 11:59:24.072917
15	25	vacation	2023-12-18	2023-12-24	approved	5	2026-04-17	2026-04-17 11:59:24.072917
16	1	vacation	2024-03-01	2024-03-10	pending	\N	2026-04-17	2026-04-17 11:59:24.072917
17	7	sick	2023-10-20	2023-10-21	approved	9	2026-04-17	2026-04-17 11:59:24.072917
18	15	personal	2023-11-25	2023-11-25	approved	5	2026-04-17	2026-04-17 11:59:24.072917
19	19	vacation	2024-02-15	2024-02-21	pending	1	2026-04-17	2026-04-17 11:59:24.072917
20	23	vacation	2023-12-28	2024-01-03	approved	1	2026-04-17	2026-04-17 11:59:24.072917
\.


--
-- Data for Name: performance_reviews; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.performance_reviews (id, employee_id, review_date, score, feedback, reviewer_id, created_at) FROM stdin;
1	2	2023-06-15	4	Strong technical skills, good teamwork	1	2026-04-17 11:59:24.075861
2	3	2023-06-15	4	Consistent performer, needs leadership development	1	2026-04-17 11:59:24.075861
3	4	2023-06-15	5	Exceptional performer, ready for promotion	1	2026-04-17 11:59:24.075861
4	5	2023-06-15	3	Meets expectations, communication could improve	5	2026-04-17 11:59:24.075861
5	7	2023-06-15	4	Good analytical skills, detailed oriented	9	2026-04-17 11:59:24.075861
6	8	2023-06-15	4	Solid performance, consistent	9	2026-04-17 11:59:24.075861
7	9	2023-06-15	3	Meets expectations, needs more proactive approach	13	2026-04-17 11:59:24.075861
8	10	2023-06-15	3	Developing skills, good potential	13	2026-04-17 11:59:24.075861
9	11	2023-06-15	4	Consistent performer, good client relations	17	2026-04-17 11:59:24.075861
10	12	2023-06-15	4	Strong sales performance	17	2026-04-17 11:59:24.075861
11	13	2023-06-15	4	Reliable IT support, quick problem resolution	1	2026-04-17 11:59:24.075861
12	14	2023-06-15	3	Meets basic expectations	1	2026-04-17 11:59:24.075861
13	15	2023-06-15	4	Good operational management	5	2026-04-17 11:59:24.075861
14	16	2023-06-15	4	Strong performer, take initiative	5	2026-04-17 11:59:24.075861
15	17	2023-06-15	5	Outstanding performance, exceptional legal work	9	2026-04-17 11:59:24.075861
16	18	2023-06-15	4	Good performance, consistent	9	2026-04-17 11:59:24.075861
17	19	2023-06-15	3	Developing, needs more product knowledge	17	2026-04-17 11:59:24.075861
18	20	2023-06-15	4	Good customer engagement	17	2026-04-17 11:59:24.075861
19	21	2023-06-15	4	Strong research capabilities	1	2026-04-17 11:59:24.075861
20	22	2023-06-15	5	Exceptional research output, industry recognized	1	2026-04-17 11:59:24.075861
\.


--
-- Data for Name: promotions; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.promotions (id, employee_id, old_job_id, new_job_id, old_salary, new_salary, promotion_date, created_at) FROM stdin;
1	1	1	14	100000.00	125000.00	2020-01-15	2026-04-17 11:59:24.078073
2	3	1	2	65000.00	78000.00	2023-01-15	2026-04-17 11:59:24.078073
3	5	3	3	60000.00	68000.00	2023-01-01	2026-04-17 11:59:24.078073
4	4	1	2	90000.00	105000.00	2020-06-01	2026-04-17 11:59:24.078073
5	15	8	8	65000.00	72000.00	2022-06-15	2026-04-17 11:59:24.078073
6	17	9	9	85000.00	95000.00	2021-06-01	2026-04-17 11:59:24.078073
7	21	11	11	70000.00	78000.00	2023-06-01	2026-04-17 11:59:24.078073
8	22	11	11	80000.00	88000.00	2022-01-01	2026-04-17 11:59:24.078073
\.


--
-- Data for Name: query_logs; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.query_logs (id, question, sql_query, db_type, success, error_message, columns, row_count, execution_time_ms, use_schema_linking, use_retry, retry_count, created_at, session_id, user_id) FROM stdin;
\.


--
-- Data for Name: salaries; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.salaries (id, employee_id, amount, effective_date, end_date, created_at) FROM stdin;
1	1	125000.00	2020-01-15	2023-05-31	2026-04-17 11:59:24.07151
2	1	140000.00	2023-06-01	\N	2026-04-17 11:59:24.07151
3	2	85000.00	2021-06-10	\N	2026-04-17 11:59:24.07151
4	3	72000.00	2021-06-10	2023-01-14	2026-04-17 11:59:24.07151
5	3	78000.00	2023-01-15	\N	2026-04-17 11:59:24.07151
6	4	105000.00	2018-11-05	\N	2026-04-17 11:59:24.07151
7	5	68000.00	2020-08-15	2022-12-31	2026-04-17 11:59:24.07151
8	5	75000.00	2023-01-01	\N	2026-04-17 11:59:24.07151
9	6	72000.00	2017-02-28	\N	2026-04-17 11:59:24.07151
10	7	62000.00	2019-09-12	\N	2026-04-17 11:59:24.07151
11	8	58000.00	2021-01-05	\N	2026-04-17 11:59:24.07151
12	9	52000.00	2020-04-20	\N	2026-04-17 11:59:24.07151
13	10	48000.00	2022-02-14	\N	2026-04-17 11:59:24.07151
14	11	55000.00	2018-07-01	\N	2026-04-17 11:59:24.07151
15	12	58000.00	2019-12-10	\N	2026-04-17 11:59:24.07151
16	13	55000.00	2021-03-25	\N	2026-04-17 11:59:24.07151
17	14	52000.00	2020-11-30	2020-12-14	2026-04-17 11:59:24.07151
18	14	52000.00	2020-12-15	\N	2026-04-17 11:59:24.07151
19	15	72000.00	2017-06-15	\N	2026-04-17 11:59:24.07151
20	16	65000.00	2022-07-20	\N	2026-04-17 11:59:24.07151
21	17	95000.00	2019-04-08	\N	2026-04-17 11:59:24.07151
22	18	82000.00	2020-09-15	\N	2026-04-17 11:59:24.07151
23	19	62000.00	2021-08-01	\N	2026-04-17 11:59:24.07151
24	20	58000.00	2018-12-20	\N	2026-04-17 11:59:24.07151
25	21	78000.00	2022-01-10	\N	2026-04-17 11:59:24.07151
\.


--
-- Data for Name: terminations; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.terminations (id, employee_id, termination_date, reason, exit_interview_completed, final_settlement, created_at) FROM stdin;
\.


--
-- Data for Name: training_enrollments; Type: TABLE DATA; Schema: hr; Owner: newpage
--

COPY hr.training_enrollments (id, employee_id, training_name, training_date, duration_hours, enrollment_date, status, created_at) FROM stdin;
1	2	Advanced Python Programming	2023-09-15	40	2026-04-17	completed	2026-04-17 11:59:24.076757
2	3	Leadership Skills	2023-10-01	16	2026-04-17	completed	2026-04-17 11:59:24.076757
3	4	Cloud Architecture	2023-11-15	32	2026-04-17	completed	2026-04-17 11:59:24.076757
4	5	HR Management Certification	2023-08-20	24	2026-04-17	completed	2026-04-17 11:59:24.076757
5	7	Financial Modeling	2023-09-10	20	2026-04-17	completed	2026-04-17 11:59:24.076757
6	9	Digital Marketing Strategy	2023-10-15	16	2026-04-17	completed	2026-04-17 11:59:24.076757
7	11	Sales Excellence	2023-08-05	24	2026-04-17	completed	2026-04-17 11:59:24.076757
8	13	ITIL Certification	2023-09-25	32	2026-04-17	completed	2026-04-17 11:59:24.076757
9	15	Project Management Professional	2023-10-20	40	2026-04-17	completed	2026-04-17 11:59:24.076757
10	17	Corporate Law Fundamentals	2023-11-01	24	2026-04-17	completed	2026-04-17 11:59:24.076757
11	19	Customer Success Mastery	2023-09-05	16	2026-04-17	completed	2026-04-17 11:59:24.076757
12	21	Agile Development	2023-10-10	24	2026-04-17	completed	2026-04-17 11:59:24.076757
13	23	Data Science with Python	2023-11-20	40	2026-04-17	enrolled	2026-04-17 11:59:24.076757
14	24	Machine Learning Fundamentals	2023-12-01	32	2026-04-17	enrolled	2026-04-17 11:59:24.076757
15	1	Executive Leadership	2024-01-15	24	2026-04-17	enrolled	2026-04-17 11:59:24.076757
\.


--
-- Name: approvals_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.approvals_id_seq', 15, true);


--
-- Name: attendance_logs_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.attendance_logs_id_seq', 50, true);


--
-- Name: audit_logs_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.audit_logs_id_seq', 20, true);


--
-- Name: bonuses_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.bonuses_id_seq', 15, true);


--
-- Name: certifications_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.certifications_id_seq', 15, true);


--
-- Name: departments_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.departments_id_seq', 12, true);


--
-- Name: emergency_contacts_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.emergency_contacts_id_seq', 20, true);


--
-- Name: employees_history_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.employees_history_id_seq', 30, true);


--
-- Name: employees_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.employees_id_seq', 25, true);


--
-- Name: jobs_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.jobs_id_seq', 15, true);


--
-- Name: leave_balances_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.leave_balances_id_seq', 40, true);


--
-- Name: leave_requests_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.leave_requests_id_seq', 20, true);


--
-- Name: performance_reviews_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.performance_reviews_id_seq', 20, true);


--
-- Name: promotions_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.promotions_id_seq', 8, true);


--
-- Name: query_logs_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.query_logs_id_seq', 1, false);


--
-- Name: salaries_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.salaries_id_seq', 25, true);


--
-- Name: terminations_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.terminations_id_seq', 1, false);


--
-- Name: training_enrollments_id_seq; Type: SEQUENCE SET; Schema: hr; Owner: newpage
--

SELECT pg_catalog.setval('hr.training_enrollments_id_seq', 15, true);


--
-- Name: approvals approvals_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (id);


--
-- Name: attendance_logs attendance_logs_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.attendance_logs
    ADD CONSTRAINT attendance_logs_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: bonuses bonuses_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.bonuses
    ADD CONSTRAINT bonuses_pkey PRIMARY KEY (id);


--
-- Name: certifications certifications_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.certifications
    ADD CONSTRAINT certifications_pkey PRIMARY KEY (id);


--
-- Name: departments departments_code_key; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.departments
    ADD CONSTRAINT departments_code_key UNIQUE (code);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: emergency_contacts emergency_contacts_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.emergency_contacts
    ADD CONSTRAINT emergency_contacts_pkey PRIMARY KEY (id);


--
-- Name: employees employees_email_key; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.employees
    ADD CONSTRAINT employees_email_key UNIQUE (email);


--
-- Name: employees_history employees_history_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.employees_history
    ADD CONSTRAINT employees_history_pkey PRIMARY KEY (id);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: leave_balances leave_balances_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.leave_balances
    ADD CONSTRAINT leave_balances_pkey PRIMARY KEY (id);


--
-- Name: leave_requests leave_requests_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.leave_requests
    ADD CONSTRAINT leave_requests_pkey PRIMARY KEY (id);


--
-- Name: performance_reviews performance_reviews_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.performance_reviews
    ADD CONSTRAINT performance_reviews_pkey PRIMARY KEY (id);


--
-- Name: promotions promotions_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.promotions
    ADD CONSTRAINT promotions_pkey PRIMARY KEY (id);


--
-- Name: query_logs query_logs_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.query_logs
    ADD CONSTRAINT query_logs_pkey PRIMARY KEY (id);


--
-- Name: salaries salaries_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.salaries
    ADD CONSTRAINT salaries_pkey PRIMARY KEY (id);


--
-- Name: terminations terminations_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.terminations
    ADD CONSTRAINT terminations_pkey PRIMARY KEY (id);


--
-- Name: training_enrollments training_enrollments_pkey; Type: CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.training_enrollments
    ADD CONSTRAINT training_enrollments_pkey PRIMARY KEY (id);


--
-- Name: idx_query_logs_created_at; Type: INDEX; Schema: hr; Owner: newpage
--

CREATE INDEX idx_query_logs_created_at ON hr.query_logs USING btree (created_at DESC);


--
-- Name: idx_query_logs_db_type; Type: INDEX; Schema: hr; Owner: newpage
--

CREATE INDEX idx_query_logs_db_type ON hr.query_logs USING btree (db_type);


--
-- Name: idx_query_logs_session; Type: INDEX; Schema: hr; Owner: newpage
--

CREATE INDEX idx_query_logs_session ON hr.query_logs USING btree (session_id);


--
-- Name: idx_query_logs_success; Type: INDEX; Schema: hr; Owner: newpage
--

CREATE INDEX idx_query_logs_success ON hr.query_logs USING btree (success);


--
-- Name: approvals approvals_approver_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.approvals
    ADD CONSTRAINT approvals_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES hr.employees(id);


--
-- Name: approvals approvals_requester_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.approvals
    ADD CONSTRAINT approvals_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES hr.employees(id);


--
-- Name: attendance_logs attendance_logs_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.attendance_logs
    ADD CONSTRAINT attendance_logs_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: audit_logs audit_logs_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.audit_logs
    ADD CONSTRAINT audit_logs_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: bonuses bonuses_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.bonuses
    ADD CONSTRAINT bonuses_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: certifications certifications_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.certifications
    ADD CONSTRAINT certifications_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: departments departments_parent_department_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.departments
    ADD CONSTRAINT departments_parent_department_id_fkey FOREIGN KEY (parent_department_id) REFERENCES hr.departments(id);


--
-- Name: emergency_contacts emergency_contacts_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.emergency_contacts
    ADD CONSTRAINT emergency_contacts_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: employees employees_department_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.employees
    ADD CONSTRAINT employees_department_id_fkey FOREIGN KEY (department_id) REFERENCES hr.departments(id);


--
-- Name: employees_history employees_history_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.employees_history
    ADD CONSTRAINT employees_history_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: employees employees_job_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.employees
    ADD CONSTRAINT employees_job_id_fkey FOREIGN KEY (job_id) REFERENCES hr.jobs(id);


--
-- Name: employees employees_manager_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.employees
    ADD CONSTRAINT employees_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES hr.employees(id);


--
-- Name: jobs jobs_department_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.jobs
    ADD CONSTRAINT jobs_department_id_fkey FOREIGN KEY (department_id) REFERENCES hr.departments(id);


--
-- Name: leave_balances leave_balances_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.leave_balances
    ADD CONSTRAINT leave_balances_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: leave_requests leave_requests_approver_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.leave_requests
    ADD CONSTRAINT leave_requests_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES hr.employees(id);


--
-- Name: leave_requests leave_requests_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.leave_requests
    ADD CONSTRAINT leave_requests_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: performance_reviews performance_reviews_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.performance_reviews
    ADD CONSTRAINT performance_reviews_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: performance_reviews performance_reviews_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.performance_reviews
    ADD CONSTRAINT performance_reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES hr.employees(id);


--
-- Name: promotions promotions_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.promotions
    ADD CONSTRAINT promotions_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: promotions promotions_new_job_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.promotions
    ADD CONSTRAINT promotions_new_job_id_fkey FOREIGN KEY (new_job_id) REFERENCES hr.jobs(id);


--
-- Name: promotions promotions_old_job_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.promotions
    ADD CONSTRAINT promotions_old_job_id_fkey FOREIGN KEY (old_job_id) REFERENCES hr.jobs(id);


--
-- Name: salaries salaries_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.salaries
    ADD CONSTRAINT salaries_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: terminations terminations_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.terminations
    ADD CONSTRAINT terminations_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- Name: training_enrollments training_enrollments_employee_id_fkey; Type: FK CONSTRAINT; Schema: hr; Owner: newpage
--

ALTER TABLE ONLY hr.training_enrollments
    ADD CONSTRAINT training_enrollments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr.employees(id);


--
-- PostgreSQL database dump complete
--

\unrestrict Qev3j96MwtHvNNNzUZWB1smibCmM9HKuI2dKuL9uR0iFm5Fh7Xu34uGunaflSYw

