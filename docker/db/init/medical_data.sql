-- ============================================
-- INDIAN MEDICAL DATABASE SEED DATA
-- Realistic Healthcare Data for NL2SQL Testing
-- ============================================
-- Skipping static insurance data - will generate all via random

-- ============================================
-- 2. INSURANCE PLANS (50 rows)
-- ============================================
INSERT INTO insurance_plans (provider_name, plan_name, plan_type, coverage_type, coverage_amount, premium_monthly, deductible, copay_percentage, waiting_period_days, max_age, min_age, is_active, coverage_details, exclusions, benefits) VALUES
('LIC', 'LIC Gold Health', 'Individual', 'Comprehensive', 500000, 2500, 5000, 10, 30, 75, 18, true, '{"hospitalization": true, "ICU": true, "daycare": true, "pre_post": true}', '{"pre_existing": "4 years", "cosmetic": true, "fertility": true}', '{"cashless_hospitals": 5000, "reuse_limit": 5}'),
('LIC', 'LIC Silver Health', 'Family', 'Basic', 200000, 1500, 10000, 15, 45, 65, 18, true, '{"hospitalization": true, "daycare": true}', '{"pre_existing": "5 years", "cosmetic": true}', '{"cashless_hospitals": 3000}'),
('CGHS', 'CGHS Card', 'Government', 'Comprehensive', 500000, 0, 0, 0, 0, 75, 0, true, '{"hospitalization": true, "ICU": true, "AYUSH": true}', '{"self-inflicted": true}', '{"all_govt_hospitals": true, "empaneled": 1000}'),
('New India Assurance', 'Corona Guard', 'Critical Illness', 'Disease Specific', 1000000, 800, 25000, 20, 90, 70, 18, true, '{"COVID": true, "hospitalization": true, "home_treatment": true}', '{"pre_existing": "3 years", "pandemic_exclusion": "First 30 days"}', '{"lump_sum": true, "daily_cash": 500}'),
('New India Assurance', 'Health Plus', 'Family', 'Comprehensive', 500000, 2200, 5000, 10, 30, 70, 18, true, '{"hospitalization": true, "ICU": true, "maternity": true}', '{"pre_existing": "3 years", "first_year": "N/A"}', '{"day_cash": 1000, "glass": true}'),
('Star Health', 'Star Comprehensive', 'Individual', 'Comprehensive', 500000, 2800, 5000, 10, 30, 70, 18, true, '{"hospitalization": true, "ICU": true, "AYUSH": true, "dental": true}', '{"pre_existing": "2 years"}', '{"wellness_bonus": 500, "no_claim_bonus": 10}'),
('Star Health', 'Star Family Health', 'Family', 'Comprehensive', 300000, 3500, 10000, 15, 30, 70, 3 months, true, '{"hospitalization": true, "maternity": true}', '{"first_year": "N/A", "pre_existing": "4 years"}', '{}'),
('HDFC Ergo', 'Health Optimiser', 'Individual', 'Comprehensive', 500000, 3000, 5000, 10, 30, 75, 18, true, '{"hospitalization": true, "ICU": true, "dental": true, "lens": true}', '{"pre_existing": "3 years"}', '{"restore_benefit": true, "reunion": true}'),
('HDFC Ergo', 'Health Suraksha', 'Family', 'Basic', 200000, 1800, 10000, 15, 30, 65, 18, true, '{"hospitalization": true, "daycare": true}', '{"first_year_exclusions": true}', '{}'),
('ICICI Lombard', 'Health Insurance', 'Individual', 'Comprehensive', 500000, 3200, 5000, 10, 30, 75, 18, true, '{"hospitalization": true, "ICU": true, "alternate_treatment": true}', '{"pre_existing": "3 years"}', '{"guarded_bonus": 10, "smart_card": true}'),
('ICICI Lombard', 'Family Floater', 'Family', 'Comprehensive', 300000, 2800, 10000, 15, 30, 70, 18, true, '{"hospitalization": true, "maternity": true}', '{"first_year": "N/A", "pre_existing": "4 years"}', '{}'),
('Bajaj Allianz', 'Health Guard', 'Individual', 'Comprehensive', 500000, 2500, 5000, 10, 30, 70, 18, true, '{"hospitalization": true, "ICU": true, "daycare": true}', '{"pre_existing": "3 years"}', '{"no_claim_bonus": 50}'),
('Bajaj Allianz', 'Family Health', 'Family', 'Basic', 200000, 2000, 10000, 15, 30, 65, 18, true, '{"hospitalization": true, "daycare": true}', '{"first_year": "N/A"}', '{}'),
('Reliance Mutual Fund', 'Reliance Health', 'Individual', 'Comprehensive', 500000, 2800, 5000, 10, 30, 75, 18, true, '{"hospitalization": true, "ICU": true, "wellness": true}', '{"pre_existing": "3 years"}', '{"wellness": 5000}'),
('Apollo Munich', 'Optima Restore', 'Individual', 'Comprehensive', 500000, 3500, 5000, 10, 30, 75, 18, true, '{"hospitalization": true, "ICU": true, "restore": true}', '{"pre_existing": "3 years"}', '{"restore_benefit": true}'),
('Apollo Munich', 'Easy Health', 'Family', 'Basic', 200000, 2200, 10000, 15, 30, 65, 18, true, '{"hospitalization": true}', '{"first_year": "N/A", "pre_existing": "4 years"}', '{}'),
('ManipalCigna', 'Health Insurance', 'Individual', 'Comprehensive', 500000, 3000, 5000, 10, 30, 75, 18, true, '{"hospitalization": true, "ICU": true, "mental_illness": true}', '{"pre_existing": "3 years"}', '{}'),
('Tata AIG', 'Health Insurance', 'Individual', 'Comprehensive', 500000, 2800, 5000, 10, 30, 70, 18, true, '{"hospitalization": true, "ICU": true, "AYUSH": true}', '{"pre_existing": "3 years"}', '{"daily_allowance": 500}'),
('Royal Sundaram', 'Lifeline', 'Individual', 'Comprehensive', 500000, 3200, 5000, 10, 30, 75, 18, true, '{"hospitalization": true, "ICU": true}', '{"pre_existing": "3 years"}', '{"health_check": 1}'),
('Future Generali', 'Future Health', 'Individual', 'Comprehensive', 500000, 2600, 5000, 10, 30, 70, 18, true, '{"hospitalization": true, "ICU": true}', '{"pre_existing": "3 years"}', '{}'),
('Liberty', 'Liberty Health', 'Individual', 'Comprehensive', 500000, 2900, 5000, 10, 30, 75, 18, true, '{"hospitalization": true, "ICU": true, "restore": true}', '{"pre_existing": "3 years"}', '{"restore": true}')
ON CONFLICT DO NOTHING;
INSERT INTO insurance_plans (provider_name, plan_name, plan_type, coverage_type, coverage_amount, premium_monthly, deductible, copay_percentage, waiting_period_days, max_age, min_age, is_active, coverage_details, exclusions, benefits)
SELECT
    (ARRAY['Aditya Birla', 'Bharti Axa', 'Kotak Mahindra', ' Edelweiss', 'Sbi General', 'PNB', 'Orient', 'Universal Sompo'])[floor(random()*8)+1] || ' ' || (ARRAY['Health', 'Mediclaim', 'Wellness', 'Care', 'Protect', 'Sure'])[floor(random()*6)+1],
    'Plan Type ' || i,
    (ARRAY['Individual', 'Family', 'Senior Citizen', 'Critical Illness', 'Top-up'])[floor(random()*5)+1],
    (ARRAY['Basic', 'Comprehensive', 'Disease Specific'])[floor(random()*3)+1],
    (ARRAY[100000, 200000, 300000, 500000, 1000000])[floor(random()*5)+1],
    (random()*3000 + 500)::numeric(10,2),
    (random()*20000 + 1000)::numeric(10,2),
    (random()*20 + 5)::numeric(5,2),
    floor(random()*90) + 15,
    floor(random()*20) + 55,
    18,
    (ARRAY[true, true, true, false])[floor(random()*4)+1],
    jsonb_build_object('hospitalization', true),
    jsonb_build_object('pre_existing', '3 years'),
    jsonb_build_object('cashless_hospitals', floor(random()*5000)+500)
FROM generate_series(21, 50) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 3. PHARMACIES (100 rows)
-- ============================================
INSERT INTO pharmacies (name, license_number, owner_name, address, city, state, pin_code, phone, email, is_24x7, is_home_delivery, operating_hours, services, ratings) VALUES
('Apollo Pharmacy', 'DL-MED-2024-001', 'Amit Sharma', 'Shop 12, City Center Mall, Linking Road', 'Mumbai', 'Maharashtra', '400050', '+91 98765 43210', 'apollo.mumbai@gmail.com', true, true, '{"monday":"24 hours", "tuesday":"24 hours", "wednesday":"24 hours", "thursday":"24 hours", "friday":"24 hours", "saturday":"24 hours", "sunday":"24 hours"}', '{"home_delivery": true, "online_consultation": true, "medicine_reminder": true}', 4.5),
('MedPlus', 'KA-MED-2024-001', 'Rajesh Kumar', '#45, MG Road', 'Bangalore', 'Karnataka', '560001', '+91 98765 43211', 'medplus.blr@gmail.com', false, true, '{"monday":"9AM-10PM", "tuesday":"9AM-10PM", "wednesday":"9AM-10PM", "thursday":"9AM-10PM", "friday":"9AM-10PM", "saturday":"9AM-10PM", "sunday":"9AM-6PM"}', '{"home_delivery": true, "medicine_reminder": true}', 4.2),
('Fortis Medical Store', 'DL-MED-2024-002', 'Dr. Suresh Reddy', 'Near Fortis Hospital, Sector 16', 'Delhi', 'Delhi', '110001', '+91 98765 43212', 'fortis.medical@gmail.com', true, true, '{"monday":"24 hours", "tuesday":"24 hours"}', '{"home_delivery": true, "compounding": true, "biomedical_waste": true}', 4.8),
('Netaji Pharmacy', 'WB-MED-2024-001', 'Babul Das', 'Park Street Area', 'Kolkata', 'West Bengal', '700016', '+91 98765 43213', 'netaji.pharma@gmail.com', false, true, '{"monday":"8AM-9PM", "tuesday":"8AM-9PM"}', '{"home_delivery": true}', 4.0),
('Apollo Pharmacy', 'TN-MED-2024-001', 'Priya Iyer', 'T-Nagar, NS Avenue', 'Chennai', 'Tamil Nadu', '600017', '+91 98765 43214', 'apollo.chn@gmail.com', false, true, '{"monday":"8AM-10PM", "tuesday":"8AM-10PM"}', '{"home_delivery": true, "online_consultation": true}', 4.6),
('Life Care Pharmacy', 'TS-MED-2024-001', 'Mahesh Goud', 'Banjara Hills', 'Hyderabad', 'Telangana', '500034', '+91 98765 43215', 'lifecare.hyd@gmail.com', true, true, '{"monday":"24 hours", "tuesday":"24 hours"}', '{"home_delivery": true, "compounding": true}', 4.3),
('MedWide', 'MH-MED-2024-001', 'Vikram Joshi', 'Koregaon Park', 'Pune', 'Maharashtra', '411001', '+91 98765 43216', 'medwide.pune@gmail.com', false, true, '{"monday":"9AM-11PM", "tuesday":"9AM-11PM"}', '{"home_delivery": true}', 4.1),
('Pharma World', 'GJ-MED-2024-001', 'Bharat Patel', 'CG Road', 'Ahmedabad', 'Gujarat', '380009', '+91 98765 43217', 'pharmaworld.ahm@gmail.com', false, true, '{"monday":"9AM-9PM", "tuesday":"9AM-9PM"}', '{"home_delivery": true, "surgical": true}', 4.4),
('Apollo Pharmacy', 'DL-MED-2024-003', 'Mohit Singh', 'Lajpat Nagar', 'Delhi', 'Delhi', '110024', '+91 98765 43218', 'apollo.lajpat@gmail.com', false, true, '{"monday":"8AM-10PM", "tuesday":"8AM-10PM"}', '{"home_delivery": true}', 4.5),
('Guardian Pharmacy', 'KA-MED-2024-002', 'Shiva Kumar', 'Indiranagar', 'Bangalore', 'Karnataka', '560038', '+91 98765 43219', 'guardian.b lr@gmail.com', false, true, '{"monday":"8AM-9PM", "tuesday":"8AM-9PM"}', '{"home_delivery": true, "online_consultation": true}', 4.7)
ON CONFLICT DO NOTHING;

-- Generate more pharmacies
INSERT INTO pharmacies (name, license_number, owner_name, address, city, state, pin_code, phone, email, is_24x7, is_home_delivery, operating_hours, services, ratings)
SELECT
    (ARRAY['Medi Care', 'Health Plus', 'Sai Pharmacy', 'Jan Aushadhi', 'Medical Hall', 'City Pharmacy', 'Wellness Center', 'Cure Pharma', 'Blue Cross', 'Red Cross'])[floor(random()*10)+1] || ' ' || i,
    (ARRAY['DL', 'MH', 'KA', 'TN', 'WB', 'TS', 'GJ'])[floor(random()*7)+1] || '-MED-2024-' || LPAD(i::text, 4, '0'),
    (ARRAY['Ramesh', 'Suresh', 'Mahesh', 'Vikram', 'Anil', 'Bharat', 'Deepak', 'Gopal', 'Nitin', 'Raj'])[floor(random()*10)+1] || ' ' || (ARRAY['Sharma', 'Patel', 'Singh', 'Kumar', 'Reddy', 'Iyer', 'Das', 'Joshi', 'Gupta', 'Mehta'])[floor(random()*10)+1],
    (ARRAY['Sector ', 'Block ', 'Phase '])[floor(random()*3)+1] || (floor(random()*50)+1) || ', ' || (ARRAY['Main Road', 'Market Road', 'Commercial Area', 'Residential Colony'])[floor(random()*4)+1],
    (ARRAY['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Kolkata', 'Hyderabad', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow'])[floor(random()*10)+1],
    (ARRAY['Maharashtra', 'Delhi', 'Karnataka', 'Tamil Nadu', 'West Bengal', 'Telangana', 'Gujarat', 'Rajasthan', 'Uttar Pradesh', 'Madhya Pradesh'])[floor(random()*10)+1],
    LPAD(((10000 + floor(random()*90000))::text), 6, '0'),
    '+91 98765 ' || LPAD((1000+floor(random()*9000))::text, 4, '0'),
    'pharmacy' || i || '@gmail.com',
    (ARRAY[true, false])[floor(random()*2)+1],
    (ARRAY[true, false])[floor(random()*2)+1],
    jsonb_build_object('monday', '9AM-9PM', 'tuesday', '9AM-9PM'),
    jsonb_build_object('home_delivery', true),
    (random()*1 + 3.5)::numeric(2,1)
FROM generate_series(11, 100) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 4. DOCTORS (200 rows)
-- ============================================
INSERT INTO doctors (first_name, last_name, qualification, registration_number, specialty, subspecialty, experience_years, hospital_affiliation, clinic_address, city, state, phone, email, consultation_fee, is_available, languages, timings, education, awards) VALUES
('Ramesh', 'Sharma', 'MBBS, MD', 'DL-MED-2015-1234', 'General Medicine', NULL, 15, 'AIIMS', 'Room 201, AIIMS New Delhi', 'Delhi', 'Delhi', '+91 98765 50101', 'dr.ramesh@aiims.edu', 1500, true, '["English", "Hindi"]', '{"monday":"9AM-4PM", "tuesday":"9AM-4PM", "wednesday":"9AM-4PM"}', '{"mbbs":"AIIMS", "md":"AIIMS"}', '{"best_doctor_2019": true}'),
('Priya', 'Patel', 'MBBS, MD, DM', 'MH-MED-2014-5678', 'Cardiology', 'Interventional Cardiology', 12, 'Fortis Mumbai', 'Fortis Hospital, Mulund', 'Mumbai', 'Maharashtra', '+91 98765 50102', 'dr.priya@fortis.in', 2000, true, '["English", "Hindi", "Marathi"]', '{"monday":"10AM-5PM", "tuesday":"10AM-5PM"}', '{"mbbs":"KEM", "md":"GS Medical", "dm":"AIIMS"}', '{"cardiology_excellence": true}'),
('Anil', 'Kumar', 'MBBS, MS', 'KA-MED-2016-9012', 'Orthopedics', 'Joint Replacement', 10, 'Apollo Bangalore', 'Apollo Hospital, Bannerghatta', 'Bangalore', 'Karnataka', '+91 98765 50103', 'dr.anil@apollo.in', 1800, true, '["English", "Hindi", "Kannada"]', '{"monday":"9AM-5PM", "wednesday":"9AM-5PM"}', '{"mbbs":"Bangalore Medical", "ms":"NIMHANS"}', '{}'),
('Sunita', 'Reddy', 'MBBS, MD', 'TN-MED-2013-3456', 'Gynecology', 'High-Risk Pregnancy', 18, 'Apollo Chennai', 'Apollo Women Center', 'Chennai', 'Tamil Nadu', '+91 98765 50104', 'dr.sunita@apollo.in', 1200, true, '["English", "Tamil", "Hindi"]', '{"monday":"10AM-6PM", "tuesday":"10AM-6PM"}', '{"mbbs":"Madras Medical", "md":"PGI Chandigarh"}', '{"best_gynae_2020": true}'),
('Vikram', 'Singh', 'MBBS, MD, DM', 'WB-MED-2015-7890', 'Neurology', 'Stroke', 14, 'AMRI Kolkata', 'EMRI Facility, Salt Lake', 'Kolkata', 'West Bengal', '+91 98765 50105', 'dr.vikram@amri.in', 2500, true, '["English", "Hindi", "Bengali"]', '{"monday":"9AM-4PM", "thursday":"9AM-4PM"}', '{"mbbs":"RG Kar", "md":"IPGMER", "dm":"AIIMS"}', '{}'),
('Arjun', 'Iyer', 'MBBS, MS, MCh', 'TS-MED-2017-1235', 'Neurosurgery', 'Spine Surgery', 8, 'KIMS Hyderabad', 'KIMS Hospital, Secunderabad', 'Hyderabad', 'Telangana', '+91 98765 50106', 'dr.arjun@kims.in', 3000, true, '["English", "Telugu", "Hindi"]', '{"monday":"10AM-5PM", "friday":"10AM-5PM"}', '{"mbbs":"Osmania", "ms":"PGI", "mch":"NIMHANS"}', '{"spine_expert": true}'),
('Kavya', 'Murthy', 'MBBS, MD', 'KA-MED-2018-4567', 'Pediatrics', 'Neonatology', 6, 'Manipal Bangalore', 'Manipal Hospital, Whitefield', 'Bangalore', 'Karnataka', '+91 98765 50107', 'dr.kavya@manipal.in', 1000, true, '["English", "Kannada", "Hindi"]', '{"monday":"9AM-4PM", "tuesday":"9AM-4PM"}', '{"mbbs":"Manipal", "md":"AIIMS"}', '{"best_pediatric_2023": true}'),
('Rahul', 'Gandhi', 'MBBS', 'GJ-MED-2019-8901', 'General Medicine', NULL, 5, 'CIVIL Hospital Ahmedabad', 'Civil Hospital Campus', 'Ahmedabad', 'Gujarat', '+91 98765 50108', 'dr.rahul@civil.in', 500, true, '["English", "Gujarati", "Hindi"]', '{"monday":"8AM-2PM", "tuesday":"8AM-2PM"}', '{"mbbs":"B J Medical"}', '{}'),
('Meera', 'Shah', 'MBBS, MD', 'MH-MED-2020-2345', 'Dermatology', 'Cosmetic', 4, 'Kokilaben Mumbai', 'Kokilaben Dhirubhai Ambani', 'Mumbai', 'Maharashtra', '+91 98765 50109', 'dr.meera@kokilaben.in', 1500, true, '["English", "Hindi", "Marathi"]', '{"monday":"11AM-6PM", "wednesday":"11AM-6PM"}', '{"mbbs":"Grant Medical", "md":"KEM"}', '{"cosmetic_expert": true}'),
('Suresh', 'Malhotra', 'MBBS, MS, FRCS', 'DL-MED-2012-6789', 'Ophthalmology', 'Cataract', 20, 'Eye7 Delhi', 'Eye7 Hospital, Lajpat Nagar', 'Delhi', 'Delhi', '+91 98765 50110', 'dr.suresh@eye7.in', 1200, true, '["English", "Hindi", "Punjabi"]', '{"monday":"10AM-5PM", "tuesday":"10AM-5PM"}', '{"mbbs":"MAMC", "ms":"AIIMS", "frcs":"UK"}', '{"cataract_surgeon_award": true}')
ON CONFLICT DO NOTHING;

-- Generate more doctors
INSERT INTO doctors (first_name, last_name, qualification, registration_number, specialty, subspecialty, experience_years, hospital_affiliation, clinic_address, city, state, phone, email, consultation_fee, is_available, languages, timings)
SELECT
    (ARRAY['Dr', 'Dr'])[floor(random()*2)+1] || ' ' || (ARRAY['Ramesh', 'Suresh', 'Mahesh', 'Vikram', 'Anil', 'Bharat', 'Deepak', 'Gopal', 'Nitin', 'Raj', 'Karan', 'Omar', 'Farhan', 'Ayan', 'Rohan'])[floor(random()*15)+1],
    (ARRAY['Sharma', 'Patel', 'Singh', 'Kumar', 'Reddy', 'Iyer', 'Das', 'Joshi', 'Gupta', 'Mehta', 'Shah', 'Kapoor', 'Trivedi', 'Banerjee', 'Chatterjee'])[floor(random()*15)+1],
    (ARRAY['MBBS', 'MBBS, MD', 'MBBS, MS', 'MBBS, MD, DM', 'MBBS, MS, MCh', 'MBBS, Diploma'])[floor(random()*6)+1],
    (ARRAY['DL', 'MH', 'KA', 'TN', 'WB', 'TS', 'GJ'])[floor(random()*7)+1] || '-MED-20' || (15 + floor(random()*10)) || '-' || LPAD((1000 + floor(random()*9000))::text, 4, '0'),
    (ARRAY['General Medicine', 'Cardiology', 'Orthopedics', 'Gynecology', 'Neurology', 'Pediatrics', 'Dermatology', 'Ophthalmology', 'ENT', 'Psychiatry', 'Gastroenterology', 'Urology', 'Oncology', 'Nephrology', 'Pulmonology'])[floor(random()*15)+1],
    NULL,
    floor(random()*35) + 3,
    (ARRAY['AIIMS', 'Fortis', 'Apollo', 'Max', 'Manipal', 'Narayana', 'Aster', 'Cloudnine', 'Lilavati', 'Saibaba'])[floor(random()*10)+1],
    'Clinic/Hospital Address ' || i,
    (ARRAY['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Kolkata', 'Hyderabad', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow', 'Chandigarh', 'Indore', 'Bhopal', 'Surat', 'Vadodara'])[floor(random()*15)+1],
    (ARRAY['Maharashtra', 'Delhi', 'Karnataka', 'Tamil Nadu', 'West Bengal', 'Telangana', 'Gujarat', 'Rajasthan', 'Uttar Pradesh', 'Punjab', 'Madhya Pradesh'])[floor(random()*11)+1],
    '+91 98765 ' || LPAD((5000 + floor(random()*5000))::text, 5, '0'),
    'doctor' || i || '@hospital.com',
    (random()*2500 + 300)::numeric(10,2),
    (ARRAY[true, true, true, false])[floor(random()*4)+1],
    '["English", "Hindi"]',
    jsonb_build_object('monday', '9AM-5PM')
FROM generate_series(11, 200) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 5. PATIENTS (1500+ rows with realistic Indian data)
-- ============================================
-- First Name Arrays (Common Indian Names)
-- Last Name Arrays (Common Indian Surnames)
-- Medical Conditions Distribution (realistic Indian healthcare context)

INSERT INTO patients (first_name, last_name, date_of_birth, gender, phone, email, address, city, state, pin_code, blood_group, insurance_id, is_active, registration_date, medical_history, allergies, emergency_contact, family_history, lifestyle)
SELECT
    -- Generate first names
    CASE floor(random()*20)
        WHEN 0 THEN 'Rahul'
        WHEN 1 THEN 'Priya'
        WHEN 2 THEN 'Aarav'
        WHEN 3 THEN 'Anjali'
        WHEN 4 THEN 'Arjun'
        WHEN 5 THEN 'Kavya'
        WHEN 6 THEN 'Raj'
        WHEN 7 THEN 'Sneha'
        WHEN 8 THEN 'Aditya'
        WHEN 9 THEN 'Meera'
        WHEN 10 THEN 'Vikram'
        WHEN 11 THEN 'Deepa'
        WHEN 12 THEN 'Sanjay'
        WHEN 13 THEN 'Ananya'
        WHEN 14 THEN 'Karan'
        WHEN 15 THEN 'Pooja'
        WHEN 16 THEN 'Nikhil'
        WHEN 17 THEN 'Riya'
        WHEN 18 THEN 'Amit'
        WHEN 19 THEN 'Shreya'
    END,
    -- Generate last names
    CASE floor(random()*25)
        WHEN 0 THEN 'Sharma'
        WHEN 1 THEN 'Patel'
        WHEN 2 THEN 'Singh'
        WHEN 3 THEN 'Kumar'
        WHEN 4 THEN 'Reddy'
        WHEN 5 THEN 'Iyer'
        WHEN 6 THEN 'Das'
        WHEN 7 THEN 'Joshi'
        WHEN 8 THEN 'Gupta'
        WHEN 9 THEN 'Mehta'
        WHEN 10 THEN 'Shah'
        WHEN 11 THEN 'Kapoor'
        WHEN 12 THEN 'Trivedi'
        WHEN 13 THEN 'Banerjee'
        WHEN 14 THEN 'Chatterjee'
        WHEN 15 THEN 'Verma'
        WHEN 16 THEN 'Chowdhury'
        WHEN 17 THEN 'Nair'
        WHEN 18 THEN 'Menon'
        WHEN 19 THEN 'Mukherjee'
        WHEN 20 THEN 'Agarwal'
        WHEN 21 THEN 'Tripathi'
        WHEN 22 THEN 'Sinha'
        WHEN 23 THEN 'Mishra'
        WHEN 24 THEN 'Pandey'
    END,
    -- Date of birth (varied ages: 5 to 90 years)
    DATE '1970-01-01' + (random()*20000)::int,
    -- Gender
    CASE floor(random()*3)
        WHEN 0 THEN 'M'
        WHEN 1 THEN 'F'
        WHEN 2 THEN 'O'
    END,
    -- Phone (Indian format)
    '+91 ' || LPAD((90000 + floor(random()*9999))::text, 5, '0') || ' ' || LPAD((1000 + floor(random()*8999))::text, 4, '0'),
    -- Email
    'patient' || i || '@gmail.com',
    -- Address
    (ARRAY['A-', 'B-', 'C-', 'D-', 'E-'])[floor(random()*5)+1] || (floor(random()*299)+1) || ', ' ||
    (ARRAY['MG Road', 'Linking Road', 'FC Road', 'Commercial Street', 'Residency Road', 'Brigade Road', 'Forum Mall', 'Inorbit Mall', 'Phoenix Mall', 'DLF'])[floor(random()*10)+1],
    -- City (major Indian cities)
    CASE floor(random()*15)
        WHEN 0 THEN 'Mumbai'
        WHEN 1 THEN 'Delhi'
        WHEN 2 THEN 'Bangalore'
        WHEN 3 THEN 'Chennai'
        WHEN 4 THEN 'Kolkata'
        WHEN 5 THEN 'Hyderabad'
        WHEN 6 THEN 'Pune'
        WHEN 7 THEN 'Ahmedabad'
        WHEN 8 THEN 'Jaipur'
        WHEN 9 THEN 'Lucknow'
        WHEN 10 THEN 'Chandigarh'
        WHEN 11 THEN 'Indore'
        WHEN 12 THEN 'Bhopal'
        WHEN 13 THEN 'Surat'
        WHEN 14 THEN 'Vadodara'
    END,
    -- State (matching city)
    CASE floor(random()*15)
        WHEN 0 THEN 'Maharashtra'
        WHEN 1 THEN 'Delhi'
        WHEN 2 THEN 'Karnataka'
        WHEN 3 THEN 'Tamil Nadu'
        WHEN 4 THEN 'West Bengal'
        WHEN 5 THEN 'Telangana'
        WHEN 6 THEN 'Maharashtra'
        WHEN 7 THEN 'Gujarat'
        WHEN 8 THEN 'Rajasthan'
        WHEN 9 THEN 'Uttar Pradesh'
        WHEN 10 THEN 'Punjab'
        WHEN 11 THEN 'Madhya Pradesh'
        WHEN 12 THEN 'Madhya Pradesh'
        WHEN 13 THEN 'Gujarat'
        WHEN 14 THEN 'Gujarat'
    END,
    -- Pin code (6 digit)
    LPAD((10000 + floor(random()*90000))::text, 6, '0'),
    -- Blood group
    (ARRAY['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'NA'])[floor(random()*9)+1],
    -- Insurance (1-50 or NULL)
    CASE WHEN random() > 0.1 THEN floor(random()*50)+1 ELSE NULL END,
    -- Active status
    CASE WHEN random() > 0.05 THEN true ELSE false END,
    -- Registration date (2015-2024)
    DATE '2015-01-01' + (random()*3650)::int,
    -- Medical History (realistic Indian conditions - multiple, some empty)
    CASE floor(random()*10)
        WHEN 0 THEN jsonb_build_object('conditions', '[]', 'surgeries', '[]', 'current_medications', '[]')
        WHEN 1 THEN jsonb_build_object('conditions', ARRAY['Diabetes'], 'surgeries', '[]', 'current_medications', ARRAY['Metformin 500mg'])
        WHEN 2 THEN jsonb_build_object('conditions', ARRAY['Hypertension'], 'surgeries', '[]', 'current_medications', ARRAY['Amlodipine 5mg'])
        WHEN 3 THEN jsonb_build_object('conditions', ARRAY['Diabetes', 'Hypertension'], 'surgeries', '[]', 'current_medications', ARRAY['Metformin', 'Amlodipine'])
        WHEN 4 THEN jsonb_build_object('conditions', ARRAY['Thyroid'], 'surgeries', '[]', 'current_medications', ARRAY['Thyroxine'])
        WHEN 5 THEN jsonb_build_object('conditions', ARRAY['Asthma'], 'surgeries', '[]', 'current_medications', ARRAY['Salbutamol'])
        WHEN 6 THEN jsonb_build_object('conditions', ARRAY['Arthritis'], 'surgeries', ARRAY['Knee Replacement'], 'current_medications', '[]')
        WHEN 7 THEN jsonb_build_object('conditions', ARRAY['Heart Disease'], 'surgeries', ARRAY['Angioplasty'], 'current_medications', ARRAY['Aspirin', 'Statins'])
        WHEN 8 THEN jsonb_build_object('conditions', ARRAY['Diabetes', 'Thyroid'], 'surgeries', '[]', 'current_medications', ARRAY['Metformin', 'Thyroxine'])
        WHEN 9 THEN jsonb_build_object('conditions', ARRAY['Hypertension', 'Diabetes', 'High Cholesterol'], 'surgeries', '[]', 'current_medications', ARRAY['Amlodipine', 'Atorvastatin'])
    END,
    -- Allergies (some none, some with allergies)
    CASE floor(random()*5)
        WHEN 0 THEN jsonb_build_object('drug_allergies', '[]', 'food_allergies', '[]', 'environmental_allergies', '[]')
        WHEN 1 THEN jsonb_build_object('drug_allergies', ARRAY['Penicillin'], 'food_allergies', '[]', 'environmental_allergies', '[]')
        WHEN 2 THEN jsonb_build_object('drug_allergies', ARRAY['Aspirin'], 'food_allergies', ARRAY['Seafood'], 'environmental_allergies', '[]')
        WHEN 3 THEN jsonb_build_object('drug_allergies', '[]', 'food_allergies', '[]', 'environmental_allergies', ARRAY['Dust', 'Pollen'])
        WHEN 4 THEN jsonb_build_object('drug_allergies', ARRAY['Sulfa', 'Ibuprofen'], 'food_allergies', ARRAY['Nuts'], 'environmental_allergies', ARRAY['Dust'])
    END,
    -- Emergency Contact
    jsonb_build_object(
        'name', (ARRAY['Wife', 'Husband', 'Mother', 'Father', 'Brother', 'Sister', 'Son', 'Daughter'])[floor(random()*8)+1],
        'relationship', (ARRAY['Spouse', 'Parent', 'Sibling'])[floor(random()*3)+1],
        'phone', '+91 98765 ' || LPAD((1000 + floor(random()*8999))::text, 4, '0')
    ),
    -- Family History
    CASE floor(random()*5)
        WHEN 0 THEN jsonb_build_object('diabetes', false, 'hypertension', false, 'heart_disease', false, 'cancer', false)
        WHEN 1 THEN jsonb_build_object('diabetes', true, 'hypertension', false, 'heart_disease', false, 'cancer', false)
        WHEN 2 THEN jsonb_build_object('diabetes', false, 'hypertension', true, 'heart_disease', false, 'cancer', false)
        WHEN 3 THEN jsonb_build_object('diabetes', true, 'hypertension', true, 'heart_disease', true, 'cancer', false)
        WHEN 4 THEN jsonb_build_object('diabetes', false, 'hypertension', false, 'heart_disease', false, 'cancer', true)
    END,
    -- Lifestyle
    CASE floor(random()*5)
        WHEN 0 THEN jsonb_build_object('smoking', false, 'alcohol', 'never', 'exercise', 'regular', 'diet', 'vegetarian')
        WHEN 1 THEN jsonb_build_object('smoking', true, 'alcohol', 'occasionally', 'exercise', 'none', 'diet', 'mixed')
        WHEN 2 THEN jsonb_build_object('smoking', false, 'alcohol', 'regularly', 'exercise', 'occasional', 'diet', 'vegetarian')
        WHEN 3 THEN jsonb_build_object('smoking', false, 'alcohol', 'never', 'exercise', 'regular', 'diet', 'non_vegetarian')
        WHEN 4 THEN jsonb_build_object('smoking', 'former', 'alcohol', 'never', 'exercise', 'none', 'diet', 'vegan')
    END
FROM generate_series(1, 1500) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 6. PRESCRIPTIONS (3000+ rows)
-- ============================================
INSERT INTO prescriptions (patient_id, doctor_id, pharmacy_id, prescription_date, diagnosis, symptoms, medicine, dosage, duration, frequency, instructions, follow_up_date, is_active, notes)
SELECT
    -- Patient (random within range)
    floor(random()*1500)+1,
    -- Doctor (random)
    floor(random()*200)+1,
    -- Pharmacy (random)
    floor(random()*100)+1,
    -- Prescription date (2022-2025)
    DATE '2022-01-01' + (random()*1460)::int,
    -- Diagnosis
    CASE floor(random()*15)
        WHEN 0 THEN 'Type 2 Diabetes'
        WHEN 1 THEN 'Hypertension'
        WHEN 2 THEN 'Fever'
        WHEN 3 THEN 'Cough and Cold'
        WHEN 4 THEN 'Headache'
        WHEN 5 THEN 'Joint Pain'
        WHEN 6 THEN 'Thyroid Disorder'
        WHEN 7 THEN 'Asthma'
        WHEN 8 THEN 'GERD'
        WHEN 9 THEN 'Back Pain'
        WHEN 10 THEN 'Anxiety'
        WHEN 11 THEN 'Skin Allergy'
        WHEN 12 THEN 'Eye Infection'
        WHEN 13 THEN 'Viral Fever'
        WHEN 14 THEN 'Acute Bronchitis'
    END,
    -- Symptoms (JSONB array)
    jsonb_build_array(
        CASE floor(random()*3)
            WHEN 0 THEN 'Fever'
            WHEN 1 THEN 'Cough'
            WHEN 2 THEN 'Headache'
        END,
        CASE floor(random()*3)
            WHEN 0 THEN 'Fatigue'
            WHEN 1 THEN 'Body ache'
            WHEN 2 THEN 'Runny nose'
        END
    ),
    -- Medicine (JSONB - realistic medicines for Indian context)
    jsonb_build_array(
        jsonb_build_object('name', (ARRAY['Metformin', 'Glipizide', 'Amlodipine', 'Telmisartan', 'Atorvastatin', 'Omeprazole', 'Cetirizine', 'Paracetamol', 'Azithromycin', 'Doxycycline'])[floor(random()*10)+1], 'strength', (ARRAY['500mg', '10mg', '5mg', '40mg', '20mg', '250mg', '10mg', '650mg', '500mg', '100mg'])[floor(random()*10)+1], 'type', (ARRAY['Tablet', 'Capsule', 'Syrup', 'Cream'])[floor(random()*4)+1])
    ),
    -- Dosage
    CASE floor(random()*4)
        WHEN 0 THEN '1-0-1'
        WHEN 1 THEN '1-1-1'
        WHEN 2 THEN '0-0-1'
        WHEN 3 THEN '1-0-0'
    END,
    -- Duration
    CASE floor(random()*4)
        WHEN 0 THEN '7 days'
        WHEN 1 THEN '14 days'
        WHEN 2 THEN '30 days'
        WHEN 3 THEN '3 months'
    END,
    -- Frequency
    CASE floor(random()*3)
        WHEN 0 THEN 'Before food'
        WHEN 1 THEN 'After food'
        WHEN 2 THEN 'With food'
    END,
    -- Instructions
    CASE floor(random()*3)
        WHEN 0 THEN 'Take with water after meals'
        WHEN 1 THEN 'Complete full course'
        WHEN 2 THEN 'Store in cool place'
    END,
    -- Follow up date
    CASE WHEN random() > 0.3 THEN DATE '2022-01-01' + (random()*1460 + 30)::int ELSE NULL END,
    -- Is active
    CASE WHEN random() > 0.3 THEN true ELSE false END,
    -- Notes
    CASE floor(random()*3)
        WHEN 0 THEN jsonb_build_object('advice', 'Rest and hydrate', 'follow_up_after', '14 days')
        WHEN 1 THEN jsonb_build_object('advice', 'Reduce salt intake', 'monitor_bp', true)
        WHEN 2 THEN NULL
    END
FROM generate_series(1, 3000) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 7. APPOINTMENTS (2500+ rows)
-- ============================================
INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, department, purpose, status, type, is_follow_up, symptoms, diagnosis, vitals, prescription_id, notes)
SELECT
    floor(random()*1500)+1,
    floor(random()*200)+1,
    DATE '2020-01-01' + (random()*2190)::int,
    -- Time slots: cast text to time
    (ARRAY['09:00:00', '10:00:00', '11:00:00', '14:00:00', '15:00:00', '16:00:00', '17:00:00', '18:00:00'])[floor(random()*8)+1]::time,
    -- Department
    CASE floor(random()*10)
        WHEN 0 THEN 'General Medicine'
        WHEN 1 THEN 'Cardiology'
        WHEN 2 THEN 'Orthopedics'
        WHEN 3 THEN 'Gynecology'
        WHEN 4 THEN 'Pediatrics'
        WHEN 5 THEN 'Dermatology'
        WHEN 6 THEN 'Neurology'
        WHEN 7 THEN 'Ophthalmology'
        WHEN 8 THEN 'ENT'
        WHEN 9 THEN 'Psychiatry'
    END,
    -- Purpose
    CASE floor(random()*5)
        WHEN 0 THEN 'Regular Checkup'
        WHEN 1 THEN 'Follow up'
        WHEN 2 THEN 'New Symptoms'
        WHEN 3 THEN 'Report Review'
        WHEN 4 THEN 'Prescription Renewal'
    END,
    -- Status
    CASE floor(random()*4)
        WHEN 0 THEN 'Completed'
        WHEN 1 THEN 'Completed'
        WHEN 2 THEN 'Completed'
        WHEN 3 THEN 'Scheduled'
        WHEN 4 THEN 'Cancelled'
    END,
    -- Type
    CASE floor(random()*3)
        WHEN 0 THEN 'In-Person'
        WHEN 1 THEN 'Teleconsultation'
        WHEN 2 THEN 'Follow-up'
    END,
    -- Is follow up
    CASE WHEN random() > 0.6 THEN true ELSE false END,
    -- Symptoms
    CASE floor(random()*3)
        WHEN 0 THEN 'Fever, cough'
        WHEN 1 THEN 'Body ache, headache'
        WHEN 2 THEN 'NA'
    END,
    -- Diagnosis
    CASE floor(random()*5)
        WHEN 0 THEN 'Viral Fever'
        WHEN 1 THEN 'Common Cold'
        WHEN 2 THEN 'Type 2 Diabetes'
        WHEN 3 THEN 'Hypertension'
        WHEN 4 THEN 'NA'
    END,
    -- Vitals
    CASE floor(random()*3)
        WHEN 0 THEN jsonb_build_object('bp', '120/80', 'pulse', 72, 'temp', 98.6, 'weight', 70)
        WHEN 1 THEN jsonb_build_object('bp', '140/90', 'pulse', 80, 'temp', 99.0, 'weight', 75)
        WHEN 2 THEN jsonb_build_object('bp', '110/70', 'pulse', 68, 'temp', 98.4, 'weight', 65)
    END,
    -- Prescription ID
    floor(random()*3000)+1,
    -- Notes
    CASE floor(random()*3)
        WHEN 0 THEN jsonb_build_object('consultation_notes', 'Patient advised rest')
        WHEN 1 THEN jsonb_build_object('next_visit', 'After 14 days')
        WHEN 2 THEN NULL
    END
FROM generate_series(1, 2500) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 8. BILLING (3000+ rows)
-- ============================================
INSERT INTO billing (patient_id, appointment_id, prescription_id, bill_date, bill_number, bill_type, amount, discount_percentage, discount_amount, tax_amount, final_amount, payment_method, payment_status, insurance_amount, patient_paid_amount, payment_date, generated_by, notes)
SELECT
    floor(random()*1500)+1,
    floor(random()*2500)+1,
    floor(random()*3000)+1,
    DATE '2020-01-01' + (random()*2190)::int,
    'BILL-' || LPAD(i::text, 6, '0'),
    CASE floor(random()*3)
        WHEN 0 THEN 'Consultation'
        WHEN 1 THEN 'Medicine'
        WHEN 2 THEN 'Lab Tests'
    END,
    -- Amount
    (random()*10000 + 200)::numeric(12,2),
    -- Discount percentage
    CASE floor(random()*5)
        WHEN 0 THEN 0
        WHEN 1 THEN 5
        WHEN 2 THEN 10
        WHEN 3 THEN 15
        WHEN 4 THEN 20
    END,
    -- Discount amount (calculated)
    0,
    -- Tax
    (random()*500 + 50)::numeric(10,2),
    -- Final amount
    (random()*8000 + 300)::numeric(12,2),
    -- Payment method
    CASE floor(random()*4)
        WHEN 0 THEN 'Cash'
        WHEN 1 THEN 'Card'
        WHEN 2 THEN 'UPI'
        WHEN 3 THEN 'Insurance'
    END,
    -- Payment status (valid values: Paid, Pending, Partial)
    CASE floor(random()*3)
        WHEN 0 THEN 'Paid'
        WHEN 1 THEN 'Paid'
        WHEN 2 THEN 'Pending'
        -- Removed Refund - was causing check constraint error
    END,
    -- Insurance amount
    CASE WHEN random() > 0.3 THEN (random()*5000 + 1000)::numeric(12,2) ELSE 0 END,
    -- Patient paid amount
    (random()*3000 + 200)::numeric(12,2),
    -- Payment date
    DATE '2020-01-01' + (random()*2190)::int,
    -- Generated by
    CASE floor(random()*3)
        WHEN 0 THEN 'Reception'
        WHEN 1 THEN 'Online'
        WHEN 2 THEN 'Pharmacy'
    END,
    -- Notes
    CASE floor(random()*3)
        WHEN 0 THEN jsonb_build_object('remarks', 'Patient eligible for discount')
        WHEN 1 THEN jsonb_build_object('remarks', 'Insurance claim filed')
        WHEN 2 THEN NULL
    END
FROM generate_series(1, 3000) i
ON CONFLICT DO NOTHING;

-- ============================================
-- 9. LAB REPORTS (1000+ rows)
-- ============================================
-- NOTE: Making appointment_id nullable to avoid FK issues
INSERT INTO lab_reports (patient_id, test_name, test_date, report_date, lab_name, result_status, results, reference_range, interpretations)
SELECT
    floor(random()*1500)+1,
    CASE floor(random()*12)
        WHEN 0 THEN 'Complete Blood Count'
        WHEN 1 THEN 'Lipid Profile'
        WHEN 2 THEN 'Liver Function Test'
        WHEN 3 THEN 'Kidney Function Test'
        WHEN 4 THEN 'Thyroid Profile'
        WHEN 5 THEN 'HbA1c'
        WHEN 6 THEN 'ECG'
        WHEN 7 THEN 'X-Ray Chest'
        WHEN 8 THEN 'MRI Brain'
        WHEN 9 THEN 'CT Scan'
        WHEN 10 THEN 'Ultrasound'
        WHEN 11 THEN 'Urine Analysis'
    END,
    DATE '2020-01-01' + (random()*2190)::int,
    DATE '2020-01-01' + (random()*2190 + 3)::int,
    CASE floor(random()*5)
        WHEN 0 THEN 'AIIMS Lab'
        WHEN 1 THEN 'Fortis Lab'
        WHEN 2 THEN 'Apollo Lab'
        WHEN 3 THEN 'SRL Diagnostics'
        WHEN 4 THEN 'Dr Lal PathLabs'
    END,
    CASE floor(random()*4)
        WHEN 0 THEN 'Normal'
        WHEN 1 THEN 'Normal'
        WHEN 2 THEN 'Abnormal'
        WHEN 3 THEN 'Pending'
    END,
    -- Results JSONB
    CASE floor(random()*3)
        WHEN 0 THEN jsonb_build_object('hb', '12.5', 'tibc', '250', 'ferritin', '50')
        WHEN 1 THEN jsonb_build_object('glucose_fasting', '95', 'glucose_pp', '120', 'hba1c', '5.5')
        WHEN 2 THEN jsonb_build_object('tsh', '4.5', 't3', '120', 't4', '8.5')
    END,
    -- Reference range
    CASE floor(random()*3)
        WHEN 0 THEN jsonb_build_object('hb_male', '13.5-17.5', 'hb_female', '12.0-15.5')
        WHEN 1 THEN jsonb_build_object('glucose_fasting', '70-100', 'glucose_pp', 'less than 140')
        WHEN 2 THEN jsonb_build_object('tsh', '0.4-4.0')
    END,
    -- Interpretations
    CASE floor(random()*3)
        WHEN 0 THEN 'All parameters within normal range'
        WHEN 1 THEN 'Slightly elevated, clinical correlation advised'
        WHEN 2 THEN 'Further testing recommended'
    END
FROM generate_series(1, 1000) i
ON CONFLICT DO NOTHING;

-- ============================================
-- DATA VERIFICATION
-- ============================================
-- SELECT 'Total patients: ' || COUNT(*) FROM patients;
-- SELECT 'Total doctors: ' || COUNT(*) FROM doctors;
-- SELECT 'Total pharmacies: ' || COUNT(*) FROM pharmacies;
-- SELECT 'Total insurance: ' || COUNT(*) FROM insurance_plans;
-- SELECT 'Total prescriptions: ' || COUNT(*) FROM prescriptions;
-- SELECT 'Total appointments: ' || COUNT(*) FROM appointments;
-- SELECT 'Total billing: ' || COUNT(*) FROM billing;
-- SELECT 'Total lab reports: ' || COUNT(*) FROM lab_reports;