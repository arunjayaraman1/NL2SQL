-- Simplified Pharma Data for Testing (500+ rows)
-- ============================================

-- MANUFACTURERS (80 rows)
INSERT INTO manufacturers (name, country, founded_year, website, certifications, facility_details, quality_standards)
SELECT
    'Manufacturer ' || i,
    (ARRAY['US', 'Switzerland', 'Germany', 'UK', 'France', 'Japan'])[floor(random()*6)+1],
    1950 + floor(random()*75),
    'www.manufacturer' || i || '.com',
    jsonb_build_object('iso_certified', 'ISO 9001', 'gmp_grade', 'A'),
    jsonb_build_object('headquarters', 'City', 'plants', floor(random()*10)+1),
    jsonb_build_object('notes', 'Good standing')
FROM generate_series(1, 80) i;

-- DRUGS (300 rows)
INSERT INTO drugs (brand_name, generic_name, ndc_code, manufacturer_id, therapeutic_class, drug_form, strength, schedule, unit_price, active_ingredients, inactive_ingredients, warnings, storage_requirements, contraindications, dosage_guidelines)
SELECT
    'Brand_' || i,
    'generic_' || i,
    (10000000000 + i * 1000000)::text,
    floor(random()*70)+1,
    (ARRAY['Analgesic', 'Antibiotic', 'Antihypertensive', 'Antidiabetic', 'Antidepressant'])[floor(random()*5)+1],
    'Tablet',
    '20mg',
    'Rx',
    (random()*500 + 10)::numeric(10,2),
    jsonb_build_array(jsonb_build_object('name', 'active', 'strength', '10mg')),
    jsonb_build_array(jsonb_build_object('name', 'filler')),
    jsonb_build_object('warnings', ARRAY['Use as directed']::text[]),
    jsonb_build_object('temp', '20-25C'),
    jsonb_build_object('avoid', 'pregnancy'),
    jsonb_build_object('dose', '20mg daily')
FROM generate_series(6, 300) i;

-- PATIENTS (500 rows)
INSERT INTO patients (first_name, last_name, date_of_birth, gender, ssn_last4, phone, email, address, city, state, zip_code, insurance_id, medical_history, emergency_contact, allergies, preferred_pharmacy, payment_method)
SELECT
    'Patient_' || i,
    'Lastname_' || i,
    '1980-01-01'::date + (random()*15000)::int,
    (ARRAY['M', 'F'])[floor(random()*2)+1],
    LPAD(i::text, 4, '0'),
    '555-0001',
    'p' || i || '@email.com',
    '123 Main St',
    'Boston', 'MA', '02101',
    floor(random()*25)+1,
    jsonb_build_object('conditions', ARRAY['Diabetes']::text[]),
    jsonb_build_object('contact', 'John', 'phone', '555-1234'),
    jsonb_build_object('drugs', ARRAY['Penicillin']::text[]),
    jsonb_build_object('pharmacy_id', floor(random()*40)+1),
    jsonb_build_object('method', 'insurance')
FROM generate_series(1, 500) i;

-- DOCTORS (100 rows)
INSERT INTO doctors (first_name, last_name, title, license_number, npi_number, specialty, subspecialty, phone, email, address, accepting_new_patients, specializations, availability, contact_preferences, credentials, practice_details)
SELECT
    'Dr_' || i,
    'Smith',
    'MD',
    'LIC' || LPAD(i::text, 6, '0'),
    (1000000000 + i)::text,
    'Internal Medicine',
    NULL,
    '555-0001',
    'dr' || i || '@hospital.com',
    '123 Medical Dr',
    true,
    jsonb_build_object('primary', 'Internal Medicine'),
    jsonb_build_object('mon', '9-5'),
    jsonb_build_object('email', 'dr@hospital.com'),
    jsonb_build_object('school', 'Harvard'),
    jsonb_build_object('hospital', 'General Hospital')
FROM generate_series(1, 100) i;

-- PHARMACIES (50 rows)
INSERT INTO pharmacies (name, license_number, address, city, state, zip_code, phone, fax, email, is_24_hour, is_compounding, operating_hours, services, contact_info, accepted_insurance, delivery_zones)
SELECT
    'Pharmacy ' || i,
    'LIC' || LPAD(i::text, 5, '0'),
    '100 Pharmacy Ave',
    'Boston',
    'MA',
    '02101',
    '555-0001',
    '555-0002',
    'pharmacy' || i || '@store.com',
    false,
    true,
    jsonb_build_object('mon', '9-9'),
    jsonb_build_object('delivery', true),
    jsonb_build_object('manager', 'Manager'),
    jsonb_build_object('plans', ARRAY['Aetna']::text[]),
    jsonb_build_object('zones', ARRAY['Downtown']::text[])
FROM generate_series(1, 50) i;

-- INSURANCE_PLANS (30 rows) - note: changed exclusions to plan_exclusions
INSERT INTO insurance_plans (provider_name, plan_name, plan_type, coverage_level, monthly_premium, annual_deductible, out_of_pocket_max, coverage_details, prior_auth_requirements, network_info, formulary, plan_exclusions)
SELECT
    (ARRAY['Aetna', 'Blue Cross', 'United', 'Cigna', 'Humana'])[floor(random()*5)+1],
    'Plan ' || i,
    'HMO',
    'Gold',
    (random()*500 + 200)::numeric(10,2),
    (random()*3000 + 500)::numeric(10,2),
    (random()*8000 + 2000)::numeric(10,2),
    jsonb_build_object('in_network', '80%'),
    jsonb_build_object('procedures', ARRAY['MRI']::text[]),
    jsonb_build_object('pharmacy', ARRAY['CVS']::text[]),
    jsonb_build_object('tier1', ARRAY['Generic']::text[]),
    jsonb_build_object('pre_existing', ARRAY[]::text[])
FROM generate_series(1, 30) i;

-- PRESCRIPTIONS (500 rows)
INSERT INTO prescriptions (patient_id, doctor_id, pharmacy_id, drug_id, prescription_date, fill_date, quantity, days_supply, refills_allowed, refills_remaining, instructions, is_compound, status, prescriber_notes, patient_instructions, fill_history, authorization_details, interaction_check)
SELECT
    floor(random()*480)+21,
    floor(random()*90)+10,
    floor(random()*45)+5,
    floor(random()*280)+20,
    '2025-01-01'::date + (random()*365)::int,
    '2025-01-02'::date + (random()*365)::int,
    30,
    30,
    3,
    3,
    'Take as directed',
    false,
    'filled',
    jsonb_build_object('notes', 'Regular'),
    jsonb_build_object('how', 'with food'),
    jsonb_build_object('fills', ARRAY[]::text[], 'last_fill', '2025-01-15'),
    jsonb_build_object('auth', 'AUTH' || i),
    jsonb_build_object('checked', true)
FROM generate_series(1, 500) i;

-- CLAIMS (200 rows)
INSERT INTO claims (prescription_id, patient_id, insurance_plan_id, claim_date, billed_amount, approved_amount, patient_responsibility, status, processing_date, payment_date, claim_data, adjustment_notes, appeal_details, reimbursement_details)
SELECT
    floor(random()*480)+21,
    floor(random()*480)+21,
    floor(random()*25)+5,
    '2025-01-01'::date + (random()*365)::int,
    (random()*1000 + 50)::numeric(10,2),
    (random()*800 + 50)::numeric(10,2),
    (random()*200 + 10)::numeric(10,2),
    'approved',
    '2025-01-02'::date + (random()*365)::int,
    '2025-01-15'::date + (random()*365)::int,
    jsonb_build_object('codes', ARRAY['Z00']::text[]),
    jsonb_build_object('adjustments', ARRAY[]::text[]),
    jsonb_build_object('appealed', false),
    jsonb_build_object('method', 'direct')
FROM generate_series(1, 200) i;

-- CLINICAL_TRIALS (60 rows) - changed: inclusion_criteria to inclusion_criteria_jsonb, exclusion_criteria to exclusion_criteria_jsonb
INSERT INTO clinical_trials (protocol_number, title, short_title, sponsor, lead_institution, phase, therapeutic_area, status, start_date, estimated_completion_date, target_enrollment, current_enrollment, inclusion_criteria_jsonb, exclusion_criteria_jsonb, sites, endpoints, arm_details, enrollment_data, safety_data, study_results)
SELECT
    'PROT-' || LPAD(i::text, 6, '0'),
    'Trial for Treatment ' || i,
    'Trial-' || i,
    'Pfizer',
    'Mass General',
    'Phase II',
    'Oncology',
    'Recruiting',
    '2024-01-01'::date + (random()*365)::int,
    '2026-01-01'::date + (random()*365)::int,
    200,
    100,
    jsonb_build_object('age_min', 18, 'age_max', 75),
    jsonb_build_object('conditions', ARRAY['Autoimmune']::text[]),
    jsonb_build_array(jsonb_build_object('site', 'Boston', 'investigator', 'Dr. Smith')),
    jsonb_build_object('primary', 'Efficacy'),
    jsonb_build_array(jsonb_build_object('arm', 'Treatment', 'dose', '10mg')),
    jsonb_build_object('enrolled', 100, 'completed', 50),
    jsonb_build_object('sae', 0),
    jsonb_build_object('findings', 'Pending')
FROM generate_series(1, 60) i;

-- ADVERSE_EVENTS (100 rows)
INSERT INTO adverse_events (report_number, trial_id, patient_id, drug_id, event_date, onset_days, resolution_date, outcome, is_serious, is_expected, severity, causality_assessment, event_description, patient_narrative, severity_assessment, investigation_notes, regulatory_reporting, relatedness)
SELECT
    'AE-' || LPAD(i::text, 8, '0'),
    floor(random()*55)+5,
    floor(random()*480)+21,
    floor(random()*280)+20,
    '2025-01-01'::date + (random()*365)::int,
    floor(random()*30)+1,
    '2025-01-15'::date + (random()*365)::int,
    'Recovered',
    false,
    true,
    'Mild',
    'Possible',
    jsonb_build_object('symptoms', ARRAY['Headache']::text[]),
    jsonb_build_object('account', 'Patient reported'),
    jsonb_build_object('mild', true),
    jsonb_build_object('findings', 'Under review'),
    jsonb_build_object('filed', false),
    jsonb_build_object('certain', '')
FROM generate_series(1, 100) i;

-- SALES (200 rows)
INSERT INTO sales (prescription_id, patient_id, pharmacy_id, sale_date, subtotal, tax_amount, discount_amount, total_amount, payment_type, transaction_id, transaction_metadata, payment_details, loyalty_points, receipt_details, return_info)
SELECT
    floor(random()*480)+21,
    floor(random()*480)+21,
    floor(random()*45)+5,
    '2025-01-01'::date + (random()*365)::int,
    (random()*500 + 10)::numeric(10,2),
    (random()*40)::numeric(10,2),
    (random()*30)::numeric(10,2),
    (random()*510 + 10)::numeric(10,2),
    'Credit Card',
    'TXN' || LPAD(i::text, 10, '0'),
    jsonb_build_object('terminal', 'POS1'),
    jsonb_build_object('card', 'Visa', 'last4', '1234'),
    jsonb_build_object('earned', floor(random()*100)),
    jsonb_build_object('sent', true),
    jsonb_build_object('returned', false)
FROM generate_series(1, 200) i;

-- PATIENT_VISITS (200 rows) - changed: results_summary JSONB was removed
INSERT INTO patient_visits (patient_id, doctor_id, visit_date, appointment_type, reason_for_visit, visit_duration_minutes, chief_complaint, diagnosis, is_follow_up, vital_signs, chief_complaints, assessment_notes, follow_up_plan, prescriptions_written, lab_results, billing_details)
SELECT
    floor(random()*480)+21,
    floor(random()*90)+10,
    '2025-01-01'::date + (random()*365)::int,
    'Routine',
    'Annual checkup',
    30,
    'Checkup',
    NULL,
    false,
    jsonb_build_object('bp', '120/80', 'hr', 72),
    jsonb_build_object('primary', 'Annual'),
    jsonb_build_object('subjective', 'Well'),
    jsonb_build_object('next', '6 months'),
    jsonb_build_object('new', ARRAY[]::text[]),
    jsonb_build_object('ordered', ARRAY[]::text[]),
    jsonb_build_object('code', '99213')
FROM generate_series(1, 200) i;

ANALYZE manufacturers;
ANALYZE drugs;
ANALYZE patients;
ANALYZE doctors;
ANALYZE pharmacies;
ANALYZE insurance_plans;
ANALYZE prescriptions;
ANALYZE claims;
ANALYZE clinical_trials;
ANALYZE adverse_events;
ANALYZE sales;
ANALYZE patient_visits;