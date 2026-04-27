-- ============================================
-- INDIAN MEDICAL DATABASE SCHEMA
-- Realistic Healthcare Data for NL2SQL Testing
-- ============================================

-- ============================================
-- 1. PATIENTS
-- ============================================
CREATE TABLE patients (
    patient_id SERIAL PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    date_of_birth DATE,
    gender TEXT CHECK (gender IN ('M', 'F', 'O')),
    phone TEXT,
    email TEXT,
    address TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    pin_code TEXT,
    blood_group TEXT,
    insurance_id INT,
    is_active BOOLEAN DEFAULT true,
    registration_date DATE DEFAULT CURRENT_DATE,
    medical_history JSONB,
    allergies JSONB,
    emergency_contact JSONB,
    family_history JSONB,
    lifestyle JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2. DOCTORS
-- ============================================
CREATE TABLE doctors (
    doctor_id SERIAL PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    qualification TEXT NOT NULL,
    registration_number TEXT UNIQUE,
    specialty TEXT NOT NULL,
    subspecialty TEXT,
    experience_years INT,
    hospital_affiliation TEXT,
    clinic_address TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    consultation_fee NUMERIC(10,2),
    is_available BOOLEAN DEFAULT true,
    languages JSONB,
    timings JSONB,
    education JSONB,
    awards JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 3. PHARMACIES
-- ============================================
CREATE TABLE pharmacies (
    pharmacy_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    license_number TEXT UNIQUE,
    owner_name TEXT,
    address TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    pin_code TEXT,
    phone TEXT,
    email TEXT,
    is_24x7 BOOLEAN DEFAULT false,
    is_home_delivery BOOLEAN DEFAULT true,
    operating_hours JSONB,
    services JSONB,
    ratings NUMERIC(2,1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 4. INSURANCE_PLANS
-- ============================================
CREATE TABLE insurance_plans (
    plan_id SERIAL PRIMARY KEY,
    provider_name TEXT NOT NULL,
    plan_name TEXT NOT NULL,
    plan_type TEXT,
    coverage_type TEXT,
    coverage_amount NUMERIC(12,2),
    premium_monthly NUMERIC(10,2),
    deductible NUMERIC(10,2),
    copay_percentage NUMERIC(5,2),
    waiting_period_days INT,
    max_age INT,
    min_age INT,
    is_active BOOLEAN DEFAULT true,
    coverage_details JSONB,
    exclusions JSONB,
    benefits JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 5. PRESCRIPTIONS
-- ============================================
CREATE TABLE prescriptions (
    prescription_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    doctor_id INT REFERENCES doctors(doctor_id),
    pharmacy_id INT REFERENCES pharmacies(pharmacy_id),
    prescription_date DATE DEFAULT CURRENT_DATE,
    diagnosis TEXT,
    symptoms JSONB,
    medicine JSONB NOT NULL,
    dosage TEXT,
    duration TEXT,
    frequency TEXT,
    instructions TEXT,
    follow_up_date DATE,
    is_active BOOLEAN DEFAULT true,
    notes JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. APPOINTMENTS
-- ============================================
CREATE TABLE appointments (
    appointment_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    doctor_id INT REFERENCES doctors(doctor_id),
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    department TEXT,
    purpose TEXT,
    status TEXT CHECK (status IN ('Scheduled', 'Completed', 'Cancelled', 'No-Show')),
    type TEXT,
    is_follow_up BOOLEAN DEFAULT false,
    symptoms TEXT,
    diagnosis TEXT,
    vitals JSONB,
    prescription_id INT REFERENCES prescriptions(prescription_id),
    notes JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 7. BILLING
-- ============================================
CREATE TABLE billing (
    bill_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    appointment_id INT REFERENCES appointments(appointment_id),
    prescription_id INT REFERENCES prescriptions(prescription_id),
    bill_date DATE DEFAULT CURRENT_DATE,
    bill_number TEXT UNIQUE,
    bill_type TEXT,
    amount NUMERIC(12,2) NOT NULL,
    discount_percentage NUMERIC(5,2),
    discount_amount NUMERIC(10,2),
    tax_amount NUMERIC(10,2),
    final_amount NUMERIC(12,2) NOT NULL,
    payment_method TEXT,
    payment_status TEXT CHECK (payment_status IN ('Pending', 'Paid', 'Refunded', 'Partial')),
    insurance_claim_id INT,
    insurance_amount NUMERIC(12,2),
    patient_paid_amount NUMERIC(12,2),
    payment_date DATE,
    generated_by TEXT,
    notes JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 8. MEDICAL_RECORDS
-- ============================================
CREATE TABLE medical_records (
    record_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    appointment_id INT REFERENCES appointments(appointment_id),
    record_date DATE DEFAULT CURRENT_DATE,
    record_type TEXT,
    description TEXT,
    attachments JSONB,
    is_confidential BOOLEAN DEFAULT false,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 9. LAB_REPORTS
-- ============================================
CREATE TABLE lab_reports (
    report_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    appointment_id INT REFERENCES appointments(appointment_id),
    test_name TEXT NOT NULL,
    test_date DATE DEFAULT CURRENT_DATE,
    report_date DATE,
    lab_name TEXT,
    result_status TEXT CHECK (result_status In ('Pending', 'Completed', 'Abnormal', 'Normal')),
    results JSONB,
    reference_range JSONB,
    interpretations TEXT,
    is_confidential BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================================================================
-- INDEXES
-- ==================================================================
CREATE INDEX idx_patients_city ON patients(city);
CREATE INDEX idx_patients_state ON patients(state);
CREATE INDEX idx_patients_insurance ON patients(insurance_id);
CREATE INDEX idx_patients_active ON patients(is_active);
CREATE INDEX idx_patients_medical_history ON patients USING GIN(medical_history);
CREATE INDEX idx_patients_allergies ON patients USING GIN(allergies);

CREATE INDEX idx_doctors_city ON doctors(city);
CREATE INDEX idx_doctors_specialty ON doctors(specialty);
CREATE INDEX idx_doctors_available ON doctors(is_available);

CREATE INDEX idx_pharmacies_city ON pharmacies(city);
CREATE INDEX idx_pharmacies_license ON pharmacies(license_number);

CREATE INDEX idx_insurance_provider ON insurance_plans(provider_name);
CREATE INDEX idx_insurance_active ON insurance_plans(is_active);

CREATE INDEX idx_prescriptions_patient ON prescriptions(patient_id);
CREATE INDEX idx_prescriptions_doctor ON prescriptions(doctor_id);
CREATE INDEX idx_prescriptions_date ON prescriptions(prescription_date);
CREATE INDEX idx_prescriptions_active ON prescriptions(is_active);

CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor ON appointments(doctor_id);
CREATE INDEX idx_appointments_date ON appointments(appointment_date);
CREATE INDEX idx_appointments_status ON appointments(status);

CREATE INDEX idx_billing_patient ON billing(patient_id);
CREATE INDEX idx_billing_date ON billing(bill_date);
CREATE INDEX idx_billing_status ON billing(payment_status);

CREATE INDEX idx_lab_reports_patient ON lab_reports(patient_id);
CREATE INDEX idx_lab_reports_status ON lab_reports(result_status);
CREATE INDEX idx_lab_reports_date ON lab_reports(test_date);
CREATE INDEX idx_lab_reports_results ON lab_reports USING GIN(results);