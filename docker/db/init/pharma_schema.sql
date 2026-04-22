-- Pharma Database Schema for JSONB Testing
-- 15 tables with 40+ JSONB columns

-- ============================================
-- 1. MANUFACTURERS
-- ============================================
CREATE TABLE manufacturers (
    manufacturer_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    country TEXT,
    founded_year INTEGER,
    website TEXT,
    certifications JSONB,         -- {iso_certified: "", gmp_grade: "", facilities: []}
    facility_details JSONB,         -- {headquarters: "", manufacturing_plants: [], employees: 0}
    quality_standards JSONB          -- {inspection_date: "", notes: "", compliance_history: []}
);

-- ============================================
-- 2. DRUGS
-- ============================================
CREATE TABLE drugs (
    drug_id SERIAL PRIMARY KEY,
    brand_name TEXT NOT NULL,
    generic_name TEXT NOT NULL,
    ndc_code TEXT UNIQUE,
    manufacturer_id INT REFERENCES manufacturers(manufacturer_id),
    therapeutic_class TEXT,
    drug_form TEXT,
    strength TEXT,
    schedule TEXT,
    unit_price NUMERIC(10,2),
    active_ingredients JSONB,        -- [{name: "", strength: "", unit: "", route: ""}]
    inactive_ingredients JSONB,     -- [{name: "", function: "", amount: ""}]
    warnings JSONB,                  -- {black_box: "", major_warnings: [], common_side_effects: []}
    storage_requirements JSONB,     -- {temperature: "", humidity: "", light_sensitivity: "", shelf_life: ""}
    contraindications JSONB,       -- {absolute: [], relative: [], interactions: []}
    dosage_guidelines JSONB        -- {adult_dose: "", pediatric_dose: "", renal_adjustment: {}}
);

-- ============================================
-- 3. PATIENTS
-- ============================================
CREATE TABLE patients (
    patient_id SERIAL PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    date_of_birth DATE,
    gender TEXT,
    ssn_last4 TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    insurance_id INT,
    medical_history JSONB,         -- {conditions: [], surgeries: [], family_history: {}, current_medications: []}
    emergency_contact JSONB,         -- {name: "", relationship: "", phone: "", alternative_phone: ""}
    allergies JSONB,               -- {drug_allergies: [], food_allergies: [], environmental_allergies: [], severity: {}}
    preferred_pharmacy JSONB,      -- {pharmacy_id: "", preferred_method: "", delivery_address: ""}
    payment_method JSONB          -- {type: "", insurance_id: "", copay_amount: 0}
);

-- ============================================
-- 4. DOCTORS
-- ============================================
CREATE TABLE doctors (
    doctor_id SERIAL PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    title TEXT,
    license_number TEXT UNIQUE,
    npi_number TEXT UNIQUE,
    specialty TEXT,
    subspecialty TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    accepting_new_patients BOOLEAN DEFAULT true,
    specializations JSONB,         -- {primary: "", secondary: [], procedures: []}
    availability JSONB,            -- {monday: "", tuesday: "", wednesday: "", thursday: "", friday: ""}
    contact_preferences JSONB,      -- {preferred_method: "", response_time: "", emergency_contact: ""}
    credentials JSONB,              -- {education: [], certifications: [], licenses: [], awards: []}
    practice_details JSONB         -- {hospital_affiliations: [], languages: [], office_hours: {}}
);

-- ============================================
-- 5. PHARMACIES
-- ============================================
CREATE TABLE pharmacies (
    pharmacy_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    license_number TEXT UNIQUE,
    address TEXT NOT NULL,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    phone TEXT,
    fax TEXT,
    email TEXT,
    is_24_hour BOOLEAN DEFAULT false,
    is_compounding BOOLEAN DEFAULT false,
    operating_hours JSONB,         -- {monday: {}, tuesday: {}, weekend: {}}
    services JSONB,                 -- {delivery: boolean, compounding: boolean, immunization: boolean, consultation: boolean}
    contact_info JSONB,            -- {primary_contact: "", pharmacist_name: "", emergency_contact: ""}
    accepted_insurance JSONB,     -- {plans: [], network_status: {}}
    delivery_zones JSONB           -- {radius: 0, areas: [], restrictions: []}
);

-- ============================================
-- 6. INSURANCE_PLANS
-- ============================================
CREATE TABLE insurance_plans (
    plan_id SERIAL PRIMARY KEY,
    provider_name TEXT NOT NULL,
    plan_name TEXT NOT NULL,
    plan_type TEXT,
    coverage_level TEXT,
    monthly_premium NUMERIC(10,2),
    annual_deductible NUMERIC(10,2),
    out_of_pocket_max NUMERIC(10,2),
    coverage_details JSONB,        -- {in_network: {}, out_of_network: {}, prescription: {}}
    prior_auth_requirements JSONB, -- {required_procedures: [], required_medications: [], timeline_days: 0}
    network_info JSONB,             -- {pharmacy_network: [], doctor_network: [], hospital_network: []}
    formulary JSONB,               -- {tier_1: [], tier_2: [], tier_3: [], specialty: []}
    plan_exclusions JSONB        -- {procedures: [], medications: {}, preexisting_conditions: []}
);

-- ============================================
-- 7. PRESCRIPTIONS
-- ============================================
CREATE TABLE prescriptions (
    prescription_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    doctor_id INT REFERENCES doctors(doctor_id),
    pharmacy_id INT REFERENCES pharmacies(pharmacy_id),
    drug_id INT REFERENCES drugs(drug_id),
    prescription_date DATE,
    fill_date DATE,
    quantity INTEGER,
    days_supply INTEGER,
    refills_allowed INTEGER,
    refills_remaining INTEGER,
    instructions TEXT,
    is_compound BOOLEAN DEFAULT false,
    status TEXT,
    prescriber_notes JSONB,       -- {clinical_notes: "", rationale: "", patient_counseling: ""}
    patient_instructions JSONB,    -- {how_to_take: "", when_to_take: "", storage: "", side_effects_to_watch: []}
    fill_history JSONB,            -- {fills: [], last_fill_date: "", next_fill_date: ""}
    authorization_details JSONB,  -- {auth_number: "", auth_status: "", expiration_date: ""}
    interaction_check JSONB       -- {checked: boolean, warnings: [], overridden_by: ""}
);

-- ============================================
-- 8. PRESCRIPTION_ITEMS
-- ============================================
CREATE TABLE prescription_items (
    item_id SERIAL PRIMARY KEY,
    prescription_id INT REFERENCES prescriptions(prescription_id),
    drug_id INT REFERENCES drugs(drug_id),
    quantity INTEGER,
    unit_price NUMERIC(10,2),
    discount_amount NUMERIC(10,2),
    dispense_quantity INTEGER,
    dispense_date DATE,
    dispense_notes JSONB,          -- {instructions: "", counseling_given: boolean, remaining_refills: 0}
    substitution_history JSONB,    -- {substituted: boolean, original_drug: "", reason: "", approved_by: ""}
    inventory_allocation JSONB    -- {from_store: "", allocated: boolean, batch_number: ""}
);

-- ============================================
-- 9. CLAIMS
-- ============================================
CREATE TABLE claims (
    claim_id SERIAL PRIMARY KEY,
    prescription_id INT REFERENCES prescriptions(prescription_id),
    patient_id INT REFERENCES patients(patient_id),
    insurance_plan_id INT REFERENCES insurance_plans(plan_id),
    claim_date DATE,
    billed_amount NUMERIC(10,2),
    approved_amount NUMERIC(10,2),
    patient_responsibility NUMERIC(10,2),
    status TEXT,
    processing_date DATE,
    payment_date DATE,
    claim_data JSONB,              -- {diagnosis_codes: [], procedure_codes: [], ndc_code: ""}
    adjustment_notes JSONB,        -- {adjustments: [], reasons: [], new_amounts: {}}
    appeal_details JSONB,           -- {appealed: boolean, appeal_date: "", appeal_reason: "", outcome: ""}
    reimbursement_details JSONB     -- {method: "", transaction_id: "", payment_ref: ""}
);

-- ============================================
-- 10. CLINICAL_TRIALS
-- ============================================
CREATE TABLE clinical_trials (
    trial_id SERIAL PRIMARY KEY,
    protocol_number TEXT UNIQUE,
    title TEXT NOT NULL,
    short_title TEXT,
    sponsor TEXT NOT NULL,
    lead_institution TEXT,
    phase TEXT,
    therapeutic_area TEXT,
    status TEXT,
    start_date DATE,
    estimated_completion_date DATE,
    actual_completion_date DATE,
    target_enrollment INTEGER,
    current_enrollment INTEGER,
    inclusion_criteria_jsonb JSONB,
    exclusion_criteria_jsonb JSONB,
    sites JSONB,                    -- [{site_id: "", site_name: "", location: "", investigator: "", status: ""}]
    endpoints JSONB,                -- {primary_endpoint: "", secondary_endpoints: [], exploratory_endpoints: []}
    arm_details JSONB,             -- [{arm_id: "", name: "", description: "", intervention: "", dosage: ""}]
    enrollment_data JSONB,         -- {screened: 0, randomized: 0, completed: 0, withdrawn: 0}
    safety_data JSONB,             -- {serious_adverse_events: [], common_adverse_events: [], deaths: 0}
    study_results JSONB            -- {findings: "", conclusions: "", publication_status: ""}
);

-- ============================================
-- 11. ADVERSE_EVENTS
-- ============================================
CREATE TABLE adverse_events (
    event_id SERIAL PRIMARY KEY,
    report_number TEXT UNIQUE,
    trial_id INT REFERENCES clinical_trials(trial_id),
    patient_id INT REFERENCES patients(patient_id),
    drug_id INT REFERENCES drugs(drug_id),
    event_date DATE,
    onset_days INTEGER,
    resolution_date DATE,
    outcome TEXT,
    is_serious BOOLEAN DEFAULT false,
    is_expected BOOLEAN DEFAULT true,
    severity TEXT,
    causality_assessment TEXT,
    event_description JSONB,        -- {symptoms: [], duration: "", severity_score: 0, impact_on_daily_life: ""}
    patient_narrative JSONB,         -- {patient_account: "", reporter_observations: "", timeline: ""}
    severity_assessment JSONB,       -- {mild: boolean, moderate: boolean, severe: boolean, life_threatening: boolean}
    investigation_notes JSONB,       -- {findings: "", conclusions: "", recommendations: ""}
    regulatory_reporting JSONB,    -- {filed: boolean, agency: "", report_date: "", ack_date: ""}
    relatedness JSONB               -- {certain: "", probable: "", possible: "", unlikely: ""}
);

-- ============================================
-- 12. INVENTORIES
-- ============================================

-- ============================================
-- 12. INVENTORIES
-- ============================================
CREATE TABLE inventories (
    inventory_id SERIAL PRIMARY KEY,
    pharmacy_id INT REFERENCES pharmacies(pharmacy_id),
    drug_id INT REFERENCES drugs(drug_id),
    quantity_on_hand INTEGER,
    reorder_level INTEGER,
    max_stock_level INTEGER,
    unit_cost NUMERIC(10,2),
    last_received_date DATE,
    last_count_date DATE,
    is_available BOOLEAN DEFAULT true,
    lot_number TEXT,
    expiration_date DATE,
    stock_alerts JSONB,             -- {low_stock: boolean, expiring_soon: boolean, recalls: []}
    supplier_info JSONB,            -- {supplier_name: "", supplier_id: "", lead_time_days: 0, minimum_order: 0}
    tracking_details JSONB,         -- {received_from: "", transfer_history: [], temperature_log: []}
    pricing_adjustments JSONB      -- {changes: [], effective_dates: [], reasons: []}
);

-- ============================================
-- 13. SALES
-- ============================================
CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    prescription_id INT REFERENCES prescriptions(prescription_id),
    patient_id INT REFERENCES patients(patient_id),
    pharmacy_id INT REFERENCES pharmacies(pharmacy_id),
    sale_date DATE,
    subtotal NUMERIC(10,2),
    tax_amount NUMERIC(10,2),
    discount_amount NUMERIC(10,2),
    total_amount NUMERIC(10,2),
    payment_type TEXT,
    transaction_id TEXT,
    transaction_metadata JSONB,     -- {pos_terminal: "", cashier_id: "", register_number: ""}
    payment_details JSONB,          -- {card_type: "", last_four: "", authorization_code: "", transaction_ref: ""}
    loyalty_points JSONB,         -- {points_earned: 0, points_redeemed: 0, membership_tier: ""}
    receipt_details JSONB,        -- {digital_receipt_sent: boolean, email: "", sms_sent: boolean}
    return_info JSONB              -- {returned: boolean, return_date: "", reason: "", refund_amount: 0}
);

-- ============================================
-- 14. DRUG_INTERACTIONS
-- ============================================
CREATE TABLE drug_interactions (
    interaction_id SERIAL PRIMARY KEY,
    drug_1_id INT REFERENCES drugs(drug_id),
    drug_2_id INT REFERENCES drugs(drug_id),
    severity TEXT,
    documentation_level TEXT,
    clinical_effect TEXT,
    mechanism TEXT,
    management TEXT,
    interaction_severity JSONB,    -- {fda_category: "", level: "", evidence: ""}
    mechanism_of_action JSONB,      -- {pharmacokinetic: "", pharmacodynamic: "", other: ""}
    clinical_guidance JSONB,         -- {monitoring_recommendations: "", dose_adjustment: "", alternatives: []}
    literature_references JSONB,      -- {primary_literature: [], guidlines: [], reviews: []}
    patient_education JSONB        -- {what_to_avoid: "", symptoms_to_watch: "", when_to_seek_help: ""}
);

-- ============================================
-- 15. PATIENT_VISITS
-- ============================================
CREATE TABLE patient_visits (
    visit_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    doctor_id INT REFERENCES doctors(doctor_id),
    visit_date DATE,
    appointment_type TEXT,
    reason_for_visit TEXT,
    visit_duration_minutes INTEGER,
    chief_complaint TEXT,
    diagnosis TEXT,
    is_follow_up BOOLEAN DEFAULT false,
    vital_signs JSONB,               -- {blood_pressure: "", heart_rate: 0, temperature: 0, weight: 0, height: 0, bmi: 0}
    chief_complaints JSONB,          -- {primary: "", secondary: [], associated_symptoms: []}
    assessment_notes JSONB,           -- {subjective: "", objective: "", assessment: "", plan: ""}
    follow_up_plan JSONB,            -- {next_visit: "", tests_ordered: [], referrals: [], lifestyle_changes: []}
    prescriptions_written JSONB,  -- {new_prescriptions: [], refills: [], discontinued: []}
    lab_results JSONB,             -- {ordered: [], results: {}, pending: []}
    billing_details JSONB          -- {visit_code: "", modifiers: [], charges: {}, insurance_filed: boolean}
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_patients_insurance ON patients(insurance_id);
CREATE INDEX idx_drugs_ndc ON drugs(ndc_code);
CREATE INDEX idx_drugs_manufacturer ON drugs(manufacturer_id);
CREATE INDEX idx_prescriptions_patient ON prescriptions(patient_id);
CREATE INDEX idx_prescriptions_doctor ON prescriptions(doctor_id);
CREATE INDEX idx_prescriptions_drug ON prescriptions(drug_id);
CREATE INDEX idx_prescriptions_date ON prescriptions(prescription_date);
CREATE INDEX idx_claims_patient ON claims(patient_id);
CREATE INDEX idx_claims_insurance ON claims(insurance_plan_id);
CREATE INDEX idx_clinical_trials_status ON clinical_trials(status);
CREATE INDEX idx_clinical_trials_phase ON clinical_trials(phase);
CREATE INDEX idx_adverse_events_patient ON adverse_events(patient_id);
CREATE INDEX idx_adverse_events_drug ON adverse_events(drug_id);
CREATE INDEX idx_inventories_pharmacy ON inventories(pharmacy_id);
CREATE INDEX idx_inventories_drug ON inventories(drug_id);
CREATE INDEX idx_sales_patient ON sales(patient_id);
CREATE INDEX idx_sales_pharmacy ON sales(pharmacy_id);
CREATE INDEX idx_patient_visits_patient ON patient_visits(patient_id);
CREATE INDEX idx_patient_visits_date ON patient_visits(visit_date);

-- JSONB Indexes
CREATE INDEX idx_patients_medical_history ON patients USING GIN(medical_history);
CREATE INDEX idx_patients_allergies ON patients USING GIN(allergies);
CREATE INDEX idx_drugs_active_ingredients ON drugs USING GIN(active_ingredients);
CREATE INDEX idx_drugs_warnings ON drugs USING GIN(warnings);
CREATE INDEX idx_clinical_trials_inclusion ON clinical_trials USING GIN(inclusion_criteria_jsonb);
CREATE INDEX idx_clinical_trials_sites ON clinical_trials USING GIN(sites);
CREATE INDEX idx_adverse_events_description ON adverse_events USING GIN(event_description);
CREATE INDEX idx_inventories_stock_alerts ON inventories USING GIN(stock_alerts);
CREATE INDEX idx_sales_transaction ON sales USING GIN(transaction_metadata);
CREATE INDEX idx_patient_visits_vital_signs ON patient_visits USING GIN(vital_signs);