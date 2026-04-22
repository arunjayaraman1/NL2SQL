-- ============================================
-- PHARMA DATABASE SEED DATA
-- Generated for JSONB Testing (1500+ rows)
-- ============================================

-- ============================================
-- 1. MANUFACTURERS (80 rows)
-- ============================================
INSERT INTO manufacturers (name, country, founded_year, website, certifications, facility_details, quality_standards) VALUES
('Pfizer Inc', 'United States', 1849, 'www.pfizer.com', '{"iso_certified": "ISO 9001:2015", "gmp_grade": "A", "facilities": ["New York", "Michigan", "Connecticut"]}', '{"headquarters": "New York, NY", "manufacturing_plants": 12, "employees": 4500}', '{"inspection_date": "2025-03-15", "notes": "All facilities compliant", "compliance_history": ["2024-A", "2023-A", "2022-A"]}'),
('Novartis AG', 'Switzerland', 1996, 'www.novartis.com', '{"iso_certified": "ISO 9001:2015", "gmp_grade": "A", "facilities": ["Basel", "Zurich"]}', '{"headquarters": "Basel, Switzerland", "manufacturing_plants": 8, "employees": 3200}', '{"inspection_date": "2025-02-20", "notes": "Excellent compliance record", "compliance_history": ["2024-A", "2023-A"]}'),
('Roche Holding AG', 'Switzerland', 1896, 'www.roche.com', '{"iso_certified": "ISO 13485", "gmp_grade": "A", "facilities": ["Basel", "Geneva"]}', '{"headquarters": "Basel, Switzerland", "manufacturing_plants": 6, "employees": 2800}', '{"inspection_date": "2025-01-10", "notes": "Consistently excellent", "compliance_history": ["2024-A", "2023-A", "2022-A"]}'),
('Johnson & Johnson', 'United States', 1887, 'www.jnj.com', '{"iso_certified": "ISO 9001:2015", "gmp_grade": "A", "facilities": ["New Jersey", "California", "Texas"]}', '{"headquarters": "New Brunswick, NJ", "manufacturing_plants": 15, "employees": 5200}', '{"inspection_date": "2025-04-01", "notes": "All clear", "compliance_history": ["2024-A", "2023-A"]}'),
('Merck & Co', 'United States', 1891, 'www.merck.com', '{"iso_certified": "ISO 9001:2015", "gmp_grade": "A", "facilities": ["New Jersey", "Pennsylvania"]}', '{"headquarters": "Kenilworth, NJ", "manufacturing_plants": 10, "employees": 3800}', '{"inspection_date": "2025-03-22", "notes": "Fully compliant", "compliance_history": ["2024-A", "2023-A"]}'),
('AbbVie Inc', 'United States', 2013, 'www.abbvie.com', '{"iso_certified": "ISO 9001:2015", "gmp_grade": "A", "facilities": ["Illinois", "California"]}', '{"headquarters": "North Chicago, IL", "manufacturing_plants": 5, "employees": 2100}', '{"inspection_date": "2025-02-28", "notes": "Strong compliance", "compliance_history": ["2024-A"]}'),
('Bristol-Myers Squibb', 'United States', 1887, 'www.bms.com', '{"iso_certified": "ISO 9001:2015", "gmp_grade": "A", "facilities": ["New Jersey", "New York"]}', '{"headquarters": "Princeton, NJ", "manufacturing_plants": 7, "employees": 2600}', '{"inspection_date": "2025-03-10", "notes": "Excellent", "compliance_history": ["2024-A", "2023-A"]}'),
('Amgen Inc', 'United States', 1980, 'www.amgen.com', '{"iso_certified": "ISO 9001:2015", "gmp_grade": "A", "facilities": ["California", "Ohio"]}', '{"headquarters": "Thousand Oaks, CA", "manufacturing_plants": 4, "employees": 1800}', '{"inspection_date": "2025-04-05", "notes": "Fully compliant", "compliance_history": ["2024-A"]}'),
('Gilead Sciences', 'United States', 1987, 'www.gilead.com', '{"iso_certified": "ISO 9001:2015", "gmp_grade": "A", "facilities": ["California"]}', '{"headquarters": "Foster City, CA", "manufacturing_plants": 3, "employees": 1400}', '{"inspection_date": "2025-03-18", "notes": "All facilities cleared", "compliance_history": ["2024-A"]}'),
('Eli Lilly and Company', 'United States', 1876, 'www.lilly.com', '{"iso_certified": "ISO 9001:2015", "gmp_grade": "A", "facilities": ["Indiana"]}', '{"headquarters": "Indianapolis, IN", "manufacturing_plants": 6, "employees": 2400}', '{"inspection_date": "2025-02-15", "notes": "Excellent compliance", "compliance_history": ["2024-A", "2023-A"]}')
ON CONFLICT DO NOTHING;

-- Generate more manufacturers
INSERT INTO manufacturers (name, country, founded_year, website, certifications, facility_details, quality_standards)
SELECT
    'Manufacturer ' || i,
    (ARRAY['United States', 'Germany', 'Switzerland', 'United Kingdom', 'France', 'Japan', 'Canada', 'India'])[floor(random()*8)+1],
    1950 + floor(random()*75),
    'www.manufacturer' || i || '.com',
    jsonb_build_object(
        'iso_certified', 'ISO 9001:2015',
        'gmp_grade', (ARRAY['A', 'B', 'A'])[floor(random()*3)+1],
        'facilities', ARRAY[(ARRAY['New York', 'California', 'Texas', 'Florida'])[floor(random()*4)+1]]
    ),
    jsonb_build_object(
        'headquarters', (ARRAY['New York, NY', 'Los Angeles, CA', 'Chicago, IL', 'Boston, MA'])[floor(random()*4)+1],
        'manufacturing_plants', floor(random()*5)+1,
        'employees', floor(random()*1000)+500
    ),
    jsonb_build_object(
        'inspection_date', '2025-01-01'::date + (random()*120)::int || ' days',
        'notes', 'Compliant',
        'compliance_history', ARRAY['2024-A']
    )
FROM generate_series(11, 80) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 2. DRUGS (300 rows)
-- ============================================
INSERT INTO drugs (brand_name, generic_name, ndc_code, manufacturer_id, therapeutic_class, drug_form, strength, schedule, unit_price, active_ingredients, inactive_ingredients, warnings, storage_requirements, contraindications, dosage_guidelines) VALUES
('Lipitor', 'atorvastatin calcium', '0591-3941-02', 1, 'Statin', 'Tablet', '20mg', 'OTC', 45.99, '[{"name": "atorvastatin calcium", "strength": "20mg", "unit": "mg", "route": "oral"}]', '[{"name": "calcium carbonate", "function": "filler"}, {"name": "lactose monohydrate", "function": "binder"}]', '{"black_box": "Contact your doctor if you have muscle problems", "major_warnings": ["Tell your doctor about any muscle pain"], "common_side_effects": ["Joint pain", "Nausea", "Diarrhea"]}', '{"temperature": "20-25C", "humidity": "low", "light_sensitivity": "low", "shelf_life": "24 months"}}', '{"absolute": ["Pregnancy", "Breastfeeding"], "relative": ["Liver disease"]}', '{"adult_dose": "10-80mg once daily", "pediatric_dose": "10-20mg daily", "renal_adjustment": {"mild": "no change", "moderate": "reduce dose", "severe": "avoid"}}'),
('Humira', 'adalimumab', '0591-3942-02', 6, 'TNF Inhibitor', 'Injection', '40mg/0.8mL', 'Rx', 8450.00, '[{"name": "adalimumab", "strength": "40mg", "unit": "mg", "route": "subcutaneous"}]', '[{"name": "mannitol", "function": "stabilizer"}, {"name": "sodium chloride", "function": "tonicity modifier"}]', '{"black_box": "Serious infections and malignancy risk", "major_warnings": ["Increased risk of infections"], "common_side_effects": ["Injection site reactions", "Headache", "Upper respiratory infection"]}', '{"temperature": "2-8C", "humidity": "controlled", "light_sensitivity": "protect from light", "shelf_life": "14 months"}}', '{"absolute": ["Active infection", "Tuberculosis"], "relative": ["Heart failure", "Demyelinating disease"]}', '{"adult_dose": "40mg every other week", "pediatric_dose": "Based on weight", "renal_adjustment": {"renal_impairment": "no adjustment needed"}}'),
('Keytruda', 'pembrolizumab', '0591-3943-02', 1, 'PD-1 Inhibitor', 'Injection', '100mg/4mL', 'Rx', 9450.00, '[{"name": "pembrolizumab", "strength": "100mg", "unit": "mg", "route": "IV infusion"}]', '[{"name": "histidine", "function": "buffer"}, {"name": "sucrose", "function": "stabilizer"}]', '{"black_box": "Immune-mediated adverse reactions", "major_warnings": ["Immune-mediated pneumonitis"], "common_side_effects": ["Fatigue", "Pruritus", "Diarrhea"]}', '{"temperature": "2-8C", "humidity": "controlled", "light_sensitivity": "protect from light", "shelf_life": "24 months"}}', '{"absolute": ["Hypersensitivity"], "relative": ["Autoimmune disorders"]}', '{"adult_dose": "200mg every 3 weeks", "pediatric_dose": "2mg/kg every 3 weeks", "renal_adjustment": {"mild": "no change", "moderate": "no change"}}'),
('Eliquis', 'apixaban', '0591-3944-02', 5, 'Anticoagulant', 'Tablet', '5mg', 'Rx', 520.00, '[{"name": "apixaban", "strength": "5mg", "unit": "mg", "route": "oral"}]', '[{"name": "lactose anhydrous", "function": "filler"}, {"name": " microcrystalline cellulose", "function": "binder"}]', '{"black_box": "Increased risk of spinal/epidural hematoma", "major_warnings": ["Spinal/epidural anesthesia"], "common_side_effects": ["Easy bruising", "Bleeding", "Nausea"]}', '{"temperature": "20-25C", "humidity": "low", "light_sensitivity": "low", "shelf_life": "36 months"}}', '{"absolute": ["Active bleeding", "Severe hepatic impairment"], "relative": ["Prosthetic heart valves"]}', '{"adult_dose": "5mg twice daily", "pediatric_dose": "Not recommended", "renal_adjustment": {"creatinine_clearance": "30-50: consider dose reduction"}}'),
('Jardiance', 'empagliflozin', '0591-3945-02', 10, 'SGLT2 Inhibitor', 'Tablet', '10mg', 'Rx', 580.00, '[{"name": "empagliflozin", "strength": "10mg", "unit": "mg", "route": "oral"}]', '[{"name": "lactose monohydrate", "function": "filler"}, {"name": "magnesium stearate", "function": "lubricant"}]', '{"black_box": "Risk of ketoacidosis", "major_warnings": ["Euglycemic ketoacidosis"], "common_side_effects": ["Urinary tract infections", "Yeast infections", "Increased urination"]}', '{"temperature": "20-25C", "humidity": "low", "light_sensitivity": "low", "shelf_life": "24 months"}}', '{"absolute": ["Type 1 diabetes", "Severe renal impairment"], "relative": ["Pancreatitis history"]}', '{"adult_dose": "10mg once daily", "pediatric_dose": "Not approved", "renal_adjustment": {"eGFR": "30+: approved, <30: avoid"}}')
ON CONFLICT DO NOTHING;

-- Generate more drugs
INSERT INTO drugs (brand_name, generic_name, ndc_code, manufacturer_id, therapeutic_class, drug_form, strength, schedule, unit_price, active_ingredients, inactive_ingredients, warnings, storage_requirements, contraindications, dosage_guidelines)
SELECT
    'Drug_' || i,
    'generic_drug_' || i,
    (10000000000 + i * 1000000)::text,
    floor(random()*50)+1,
    (ARRAY['Analgesic', 'Antibiotic', 'Antihypertensive', 'Antidiabetic', 'Antidepressant', 'Statin', 'Proton Pump Inhibitor', 'Antihistamine', 'Bronchodilator', 'Corticosteroid'])[floor(random()*10)+1],
    (ARRAY['Tablet', 'Capsule', 'Injection', 'Suspension', 'Cream', 'Patch'])[floor(random()*6)+1],
    (ARRAY['10mg', '20mg', '50mg', '100mg', '250mg', '500mg'])[floor(random()*6)+1],
    (ARRAY['Rx', 'Rx', 'Rx', 'OTC'])[floor(random()*4)+1],
    (random()*1000 + 10)::numeric(10,2),
    jsonb_build_array(jsonb_build_object('name', 'active_ingredient_' || i, 'strength', '10mg', 'route', 'oral')),
    jsonb_build_array(jsonb_build_object('name', 'inactive_filler', 'function', 'binder')),
    jsonb_build_object('major_warnings', ARRAY['Use as directed'], 'common_side_effects', ARRAY['Mild nausea']),
    jsonb_build_object('temperature', '20-25C', 'humidity', 'low'),
    jsonb_build_object('absolute', ARRAY['Hypersensitivity']),
    jsonb_build_object('adult_dose', '10-50mg daily', 'renal_adjustment', jsonb_build_object('mild', 'no change'))
FROM generate_series(6, 300) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 3. PATIENTS (500 rows)
-- ============================================
INSERT INTO patients (first_name, last_name, date_of_birth, gender, ssn_last4, phone, email, address, city, state, zip_code, insurance_id, medical_history, emergency_contact, allergies, preferred_pharmacy, payment_method)
SELECT
    'Patient_' || i,
    'Lastname_' || i,
    '1980-01-01'::date + (random()*15000)::int,
    (ARRAY['M', 'F'])[floor(random()*2)+1],
    LPAD(i::text, 4, '0'),
    '555-' || LPAD((1000+floor(random()*9000))::text, 3, '0') || '-' || LPAD((1000+floor(random()*9000))::text, 4, '0'),
    'patient' || i || '@email.com',
    (100 + floor(random()*900)) || ' Main Street',
    (ARRAY['Boston', 'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas'])[floor(random()*10)+1],
    (ARRAY['MA', 'NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'TX', 'CA', 'TX'])[floor(random()*10)+1],
    LPAD((10000+floor(random()*90000))::text, 5, '0'),
    floor(random()*20)+1,
    jsonb_build_object(
        'conditions', ARRAY[(ARRAY['Hypertension', 'Diabetes', 'Asthma', 'Arthritis', 'Depression', 'Anxiety', 'COPD', 'Heart Disease'])[floor(random()*8)+1]],
        'surgeries', ARRAY[],
        'family_history', jsonb_build_object('heart_disease', true, 'diabetes', false),
        'current_medications', ARRAY[]
    ),
    jsonb_build_object(
        'name', 'Emergency_Contact_' || i,
        'relationship', (ARRAY['Spouse', 'Parent', 'Sibling', 'Child', 'Friend'])[floor(random()*5)+1],
        'phone', '555-9999',
        'alternative_phone', '5558888'
    ),
    jsonb_build_object(
        'drug_allergies', ARRAY[(ARRAY['Penicillin', 'Sulfa', 'Aspirin', 'Codeine', 'Latex'])[floor(random()*5)+1]],
        'food_allergies', ARRAY[],
        'environmental_allergies', ARRAY['Dust', 'Pollen'],
        'severity'::jsonb, jsonb_build_object('Penicillin', 'severe')
    ),
    jsonb_build_object('pharmacy_id', floor(random()*40)+1, 'preferred_method', 'pickup'),
    jsonb_build_object('type', 'insurance', 'copay_amount', 25)
FROM generate_series(1, 500) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 4. DOCTORS (100 rows)
-- ============================================
INSERT INTO doctors (first_name, last_name, title, license_number, npi_number, specialty, subspecialty, phone, email, address, accepting_new_patients, specializations, availability, contact_preferences, credentials, practice_details)
SELECT
    'Dr_' || i,
    'Physician_' || i,
    (ARRAY['MD', 'DO', 'MD, PhD'])[floor(random()*3)+1],
    'LIC' || LPAD(i::text, 6, '0'),
    LPAD((1000000000 + i)::text, 10, '0'),
    (ARRAY['Internal Medicine', 'Family Medicine', 'Cardiology', 'Oncology', 'Pediatrics', 'Dermatology', 'Psychiatry', 'Neurology'])[floor(random()*8)+1],
    NULL,
    '555-' || LPAD((1000+floor(random()*9000))::text, 3, '0') || '-' || LPAD((1000+floor(random()*9000))::text, 4, '0'),
    'dr' || i || '@hospital.com',
    (100 + floor(random()*900)) || ' Medical Center Drive',
    true,
    jsonb_build_object(
        'primary', (ARRAY['Internal Medicine', 'Family Medicine', 'Cardiology'])[floor(random()*3)+1],
        'secondary', ARRAY['Geriatrics'],
        'procedures', ARRAY['Biopsy', 'ECG', 'Stress Test']
    ),
    jsonb_build_object('monday', '9AM-5PM', 'tuesday', '9AM-5PM', 'wednesday', '9AM-12PM'),
    jsonb_build_object('preferred_method', 'email', 'response_time', '24 hours'),
    jsonb_build_object(
        'education', ARRAY['Harvard Medical School'],
        'certifications', ARRAY['Board Certified'],
        'licenses', ARRAY['MA Medical License']
    ),
    jsonb_build_object('hospital_affiliations', ARRAY['General Hospital'], 'languages', ARRAY['English'])
FROM generate_series(1, 100) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 5. PHARMACIES (50 rows)
-- ============================================
INSERT INTO pharmacies (name, license_number, address, city, state, zip_code, phone, fax, email, is_24_hour, is_compounding, operating_hours, services, contact_info, accepted_insurance, delivery_zones)
SELECT
    'Pharmacy_' || i || ' Drug Store',
    'LIC' || LPAD(i::text, 5, '0'),
    (100 + floor(random()*900)) || ' Pharmacy Ave',
    (ARRAY['Boston', 'New York', 'Los Angeles', 'Chicago', 'Houston'])[floor(random()*5)+1],
    (ARRAY['MA', 'NY', 'CA', 'IL', 'TX'])[floor(random()*5)+1],
    LPAD((10000+floor(random()*90000))::text, 5, '0'),
    '555-' || LPAD((1000+floor(random()*9000))::text, 3, '0') || '-' || LPAD((1000+floor(random()*9000))::text, 4, '0'),
    '555-' || LPAD((1000+floor(random()*9000))::text, 3, '0') || '-' || LPAD((1000+floor(random()*9000))::text, 4, '0'),
    'store' || i || '@pharmacy.com',
    false,
    true,
    jsonb_build_object('monday', '8AM-10PM', 'tuesday', '8AM-10PM', 'weekend', '9AM-6PM'),
    jsonb_build_object('delivery', true, 'compounding', true, 'immunization', true),
    jsonb_build_object('primary_contact', 'Store Manager', 'pharmacist_name', 'Pharmacist_' || i),
    jsonb_build_object('plans', ARRAY['Aetna', 'Blue Cross'], 'network_status', jsonb_build_object('in_network', true)),
    jsonb_build_object('radius', 10, 'areas', ARRAY['Downtown', 'Suburbs'])
FROM generate_series(1, 50) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 6. INSURANCE_PLANS (30 rows)
-- ============================================
INSERT INTO insurance_plans (provider_name, plan_name, plan_type, coverage_level, monthly_premium, annual_deductible, out_of_pocket_max, coverage_details, prior_auth_requirements, network_info, formulary, exclusions)
SELECT
    (ARRAY['Aetna', 'Blue Cross Blue Shield', 'United Healthcare', 'Cigna', 'Humana', 'Kaiser Permanente', 'Anthem', 'Molina', 'Centene', 'HealthNet'])[floor(random()*10)+1],
    'Plan_' || i || ' Gold',
    (ARRAY['HMO', 'PPO', 'EPO', 'POS'])[floor(random()*4)+1],
    (ARRAY['Bronze', 'Silver', 'Gold', 'Platinum'])[floor(random()*4)+1],
    (random()*500 + 200)::numeric(10,2),
    (random()*3000 + 500)::numeric(10,2),
    (random()*8000 + 2000)::numeric(10,2),
    jsonb_build_object('in_network', jsonb_build_object('coinsurance', '80%'), 'out_of_network', jsonb_build_object('coinsurance', '60%')),
    jsonb_build_object('required_procedures', ARRAY['MRI', 'CT Scan'], 'timeline_days', 14),
    jsonb_build_object('pharmacy_network', ARRAY['CVS', 'Walgreens'], 'doctor_network', ARRAY['Network Doctors']),
    jsonb_build_object('tier_1', ARRAY['Generic'], 'tier_2', ARRAY['Preferred Brand'], 'tier_3', ARRAY['Non-Preferred']),
    jsonb_build_object('pre_existing_conditions', ARRAY[])
FROM generate_series(1, 30) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 7. PRESCRIPTIONS (1000 rows)
-- ============================================
INSERT INTO prescriptions (patient_id, doctor_id, pharmacy_id, drug_id, prescription_date, fill_date, quantity, days_supply, refills_allowed, refills_remaining, instructions, is_compound, status, prescriber_notes, patient_instructions, fill_history, authorization_details, interaction_check)
SELECT
    floor(random()*480)+21,
    floor(random()*90)+10,
    floor(random()*45)+5,
    floor(random()*280)+20,
    '2025-01-01'::date + (random()*365)::int,
    '2025-01-02'::date + (random()*365)::int,
    floor(random()*90)+1,
    floor(random()*90)+1,
    floor(random()*6),
    floor(random()*6),
    'Take as directed',
    false,
    (ARRAY['filled', 'pending', 'cancelled'])[floor(random()*3)+1],
    jsonb_build_object('clinical_notes', 'Regular prescription', 'rationale', 'Maintenance'),
    jsonb_build_object('how_to_take', 'With food', 'storage', 'Room temperature'),
    jsonb_build_object('fills', ARRAY[], 'last_fill_date', '2025-01-15'),
    jsonb_build_object('auth_number', 'AUTH' || i, 'auth_status', 'approved'),
    jsonb_build_object('checked', true, 'warnings', ARRAY[])
FROM generate_series(1, 1000) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 8. PRESCRIPTION_ITEMS (2500 rows)
-- ============================================
INSERT INTO prescription_items (prescription_id, drug_id, quantity, unit_price, discount_amount, dispense_quantity, dispense_date, dispense_notes, substitution_history, inventory_allocation)
SELECT
    floor(random()*980)+20,
    floor(random()*280)+20,
    floor(random()*90)+1,
    (random()*500 + 10)::numeric(10,2),
    (random()*50)::numeric(10,2),
    floor(random()*90)+1,
    '2025-01-01'::date + (random()*365)::int,
    jsonb_build_object('instructions', 'Take as directed', 'counseling_given', true),
    jsonb_build_object('substituted', false),
    jsonb_build_object('from_store', floor(random()*40)+1, 'allocated', true)
FROM generate_series(1, 2500) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 9. CLAIMS (800 rows)
-- ============================================
INSERT INTO claims (prescription_id, patient_id, insurance_plan_id, claim_date, billed_amount, approved_amount, patient_responsibility, status, processing_date, payment_date, claim_data, adjustment_notes, appeal_details, reimbursement_details)
SELECT
    floor(random()*980)+20,
    floor(random()*480)+21,
    floor(random()*25)+5,
    '2025-01-01'::date + (random()*365)::int,
    (random()*1000 + 50)::numeric(10,2),
    (random()*800 + 50)::numeric(10,2),
    (random()*200 + 10)::numeric(10,2),
    (ARRAY['approved', 'pending', 'denied'])[floor(random()*3)+1],
    '2025-01-02'::date + (random()*365)::int,
    '2025-01-15'::date + (random()*365)::int,
    jsonb_build_object('diagnosis_codes', ARRAY['Z00.00'], 'procedure_codes', ARRAY['99213']),
    jsonb_build_object('adjustments', ARRAY[], 'reasons', ARRAY[]),
    jsonb_build_object('appealed', false),
    jsonb_build_object('method', 'direct deposit', 'transaction_id', 'TXN' || i)
FROM generate_series(1, 800) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 10. CLINICAL_TRIALS (60 rows)
-- ============================================
INSERT INTO clinical_trials (protocol_number, title, short_title, sponsor, lead_institution, phase, therapeutic_area, status, start_date, estimated_completion_date, target_enrollment, current_enrollment, inclusion_criteria, exclusion_criteria, sites, endpoints, arm_details, enrollment_data, safety_data, results_summary)
SELECT
    'PROTOCOL-' || LPAD(i::text, 6, '0'),
    'Clinical Trial for Treatment of Condition ' || i,
    'Trial-' || i,
    (ARRAY['Pfizer', 'Novartis', 'Roche', 'Johnson & Johnson', 'Merck'])[floor(random()*5)+1],
    (ARRAY['Mass General', 'Johns Hopkins', 'Cleveland Clinic', 'Mayo Clinic', 'UCSF'])[floor(random()*5)+1],
    (ARRAY['Phase I', 'Phase II', 'Phase III', 'Phase IV'])[floor(random()*4)+1],
    (ARRAY['Oncology', 'Cardiology', 'Neurology', 'Immunology', 'Infectious Disease'])[floor(random()*5)+1],
    (ARRAY['Recruiting', 'Active', 'Completed', 'On Hold'])[floor(random()*4)+1],
    '2024-01-01'::date + (random()*365)::int,
    '2026-01-01'::date + (random()*365)::int,
    floor(random()*500)+100,
    floor(random()*300)+50,
    jsonb_build_object('age_min', 18, 'age_max', 75, 'diagnosis', ARRAY['Condition X'], 'comorbidities', ARRAY[]),
    jsonb_build_object('conditions', ARRAY['Autoimmune disease'], 'medications', ARRAY[], 'lab_values', jsonb_build_object('creatinine', '< 1.5')),
    jsonb_build_array(
        jsonb_build_object('site_id', s.site_id, 'site_name', 'Site ' || s.site_id, 'location', 'Boston, MA', 'investigator', 'Dr. Investigator ' || s.site_id, 'status', 'Active')
    ),
    jsonb_build_object('primary_endpoint', 'Safety and Efficacy', 'secondary_endpoints', ARRAY['Bioarkers']),
    jsonb_build_array(
        jsonb_build_object('arm_id', 'A', 'name', 'Treatment', 'description', 'Drug X 10mg', 'intervention', 'Drug X')
    ),
    jsonb_build_object('screened', 100, 'randomized', 50, 'completed', 25, 'withdrawn', 5),
    jsonb_build_object('serious_adverse_events', ARRAY[], 'common_adverse_events', ARRAY['Headache'], 'deaths', 0),
    jsonb_build_object('findings', 'Study ongoing', 'conclusions', '', 'publication_status', 'pending')
FROM generate_series(1, 60) i
CROSS JOIN LATERAL (SELECT floor(random()*5)+1 site_id) s
ON CONFLICT DO NOTHING;

-- ============================================
-- 11. ADVERSE_EVENTS (500 rows)
-- ============================================
INSERT INTO adverse_events (report_number, trial_id, patient_id, drug_id, event_date, onset_days, resolution_date, outcome, is_serious, is_expected, severity, causality_assessment, event_description, patient_narrative, severity_assessment, investigation_notes, regulatory_reporting, relatedness)
SELECT
    'AE-' || LPAD(i::text, 8, '0'),
    floor(random()*55)+5,
    floor(random()*480)+21,
    floor(random()*280)+20,
    '2025-01-01'::date + (random()*365)::int,
    floor(random()*30)+1,
    '2025-01-15'::date + (random()*365)::int,
    (ARRAY['Recovered', 'Recovering', 'Not Recovered', 'Fatal', 'Unknown'])[floor(random()*5)+1],
    (ARRAY[true, false])[floor(random()*2)+1],
    true,
    (ARRAY['Mild', 'Moderate', 'Severe'])[floor(random()*3)+1],
    (ARRAY['Certain', 'Probable', 'Possible', 'Unlikely'])[floor(random()*4)+1],
    jsonb_build_object('symptoms', ARRAY['Headache', 'Nausea'], 'duration', '2 hours', 'severity_score', 5),
    jsonb_build_object('patient_account', 'Patient reported symptoms after taking medication', 'reporter_observations', 'Observed in clinic'),
    jsonb_build_object('mild', true, 'moderate', false, 'severe', false),
    jsonb_build_object('findings', 'Under investigation', 'conclusions', '', 'recommendations', 'Continue monitoring'),
    jsonb_build_object('filed', true, 'agency', 'FDA', 'report_date', '2025-01-20'),
    jsonb_build_object('certain', '', 'probable', 'Definite relationship', 'possible', '')
FROM generate_series(1, 500) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 12. INVENTORIES (400 rows)
-- ============================================
INSERT INTO inventories (pharmacy_id, drug_id, quantity_on_hand, reorder_level, max_stock_level, unit_cost, last_received_date, last_count_date, is_available, lot_number, expiration_date, stock_alerts, supplier_info, tracking_details, pricing_adjustments)
SELECT
    floor(random()*45)+5,
    floor(random()*280)+20,
    floor(random()*500)+50,
    floor(random()*100)+20,
    floor(random()*500)+100,
    (random()*200 + 10)::numeric(10,2),
    '2025-01-01'::date + (random()*180)::int,
    '2025-01-15'::date + (random()*180)::int,
    true,
    'LOT' || LPAD(i::text, 8, '0'),
    '2026-01-01'::date + (random()*365)::int,
    jsonb_build_object('low_stock', false, 'expiring_soon', true, 'recalls', ARRAY[]),
    jsonb_build_object('supplier_name', 'ABC Suppliers', 'supplier_id', 'SUP001', 'lead_time_days', 7),
    jsonb_build_object('received_from', 'Distributor A', 'transfer_history', ARRAY[]),
    jsonb_build_object('changes', ARRAY[], 'effective_dates', ARRAY[])
FROM generate_series(1, 400) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 13. SALES (1500 rows)
-- ============================================
INSERT INTO sales (prescription_id, patient_id, pharmacy_id, sale_date, subtotal, tax_amount, discount_amount, total_amount, payment_type, transaction_id, transaction_metadata, payment_details, loyalty_points, receipt_details, return_info)
SELECT
    floor(random()*980)+20,
    floor(random()*480)+21,
    floor(random()*45)+5,
    '2025-01-01'::date + (random()*365)::int,
    (random()*500 + 10)::numeric(10,2),
    (random()*40)::numeric(10,2),
    (random()*30)::numeric(10,2),
    (random()*510 + 10)::numeric(10,2),
    (ARRAY['Credit Card', 'Cash', 'Insurance', 'Debit Card'])[floor(random()*4)+1],
    'TXN' || LPAD(i::text, 10, '0'),
    jsonb_build_object('pos_terminal', 'POS1', 'cashier_id', 'CASHIER' || floor(random()*10)+1),
    jsonb_build_object('card_type', 'Visa', 'last_four', LPAD(i%10000, 4, '0'), 'authorization_code', 'AUTH' || i),
    jsonb_build_object('points_earned', floor(random()*100), 'points_redeemed', 0),
    jsonb_build_object('digital_receipt_sent', true, 'email', 'customer@email.com'),
    jsonb_build_object('returned', false)
FROM generate_series(1, 1500) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 14. DRUG_INTERACTIONS (200 rows)
-- ============================================
INSERT INTO drug_interactions (drug_1_id, drug_2_id, severity, documentation_level, clinical_effect, mechanism, management, interaction_severity, mechanism_of_action, clinical_guidance, references, patient_education)
SELECT
    floor(random()*280)+20,
    floor(random()*280)+20,
    (ARRAY['Major', 'Moderate', 'Minor'])[floor(random()*3)+1],
    (ARRAY['Established', 'Probable', 'Possible'])[floor(random()*3)+1],
    'Increased risk of adverse effects',
    'Pharmacodynamic interaction',
    'Monitor closely',
    jsonb_build_object('fda_category', 'Major', 'level', 'High', 'evidence', 'Well documented'),
    jsonb_build_object('pharmacodynamic', 'Additive effect', 'pharmacodynamic', '', 'other', ''),
    jsonb_build_object('monitoring_recommendations', 'Monitor blood pressure', 'dose_adjustment', 'Reduce dose'),
    jsonb_build_object('primary_literature', ARRAY['Study 1'], 'guidlines', ARRAY['FDA Guidelines']),
    jsonb_build_object('what_to_avoid', 'Alcohol', 'symptoms_to_watch', 'Dizziness', 'when_to_seek_help', 'Immediately')
FROM generate_series(1, 200) i
WHERE drug_1_id != drug_2_id
ON CONFLICT DO NOTHING;

-- ============================================
-- 15. PATIENT_VISITS (1200 rows)
-- ============================================
INSERT INTO patient_visits (patient_id, doctor_id, visit_date, appointment_type, reason_for_visit, visit_duration_minutes, chief_complaint, diagnosis, is_follow_up, vital_signs, chief_complaints, assessment_notes, follow_up_plan, prescriptions_written, lab_results, billing_details)
SELECT
    floor(random()*480)+21,
    floor(random()*90)+10,
    '2025-01-01'::date + (random()*365)::int,
    (ARRAY['Routine', 'Follow-up', 'Urgent', 'Annual Exam'])[floor(random()*4)+1],
    (ARRAY['Annual checkup', 'Follow-up visit', 'New symptoms', 'Medication review'])[floor(random()*4)+1],
    floor(random()*60)+15,
    (ARRAY['Routine checkup', 'Follow-up for diabetes', 'Chest pain', 'Headache'])[floor(random()*4)+1],
    NULL,
    (ARRAY[true, false])[floor(random()*2)+1],
    jsonb_build_object('blood_pressure', '120/80', 'heart_rate', 72, 'temperature', 98.6, 'weight', 170, 'height', 70, 'bmi', 24.5),
    jsonb_build_object('primary', 'Annual checkup', 'secondary', ARRAY[]),
    jsonb_build_object('subjective', 'Patient feels well', 'objective', 'Vital signs normal', 'assessment', 'Stable'),
    jsonb_build_object('next_visit', '6 months', 'tests_ordered', ARRAY[], 'referrals', ARRAY[]),
    jsonb_build_object('new_prescriptions', ARRAY[], 'refills', ARRAY[]),
    jsonb_build_object('ordered', ARRAY['CBC'], 'results', jsonb_build_object('CBC', 'Normal'), 'pending', ARRAY[]),
    jsonb_build_object('visit_code', '99213', 'modifiers', ARRAY[], 'charges', jsonb_build_object('visi'))
FROM generate_series(1, 1200) i
ON CONFLICT DO NOTHING;

-- Update statistics
ANALYZE manufacturers;
ANALYZE drugs;
ANALYZE patients;
ANALYZE doctors;
ANALYZE pharmacies;
ANALYZE insurance_plans;
ANALYZE prescriptions;
ANALYZE prescription_items;
ANALYZE claims;
ANALYZE clinical_trials;
ANALYZE adverse_events;
ANALYZE inventories;
ANALYZE sales;
ANALYZE drug_interactions;
ANALYZE patient_visits;