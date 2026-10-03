-- ============================================================================
-- SpendWise (PFIS) - Comprehensive Production Database Seed Script
-- ============================================================================

-- 1. Insert Default Company Configuration
INSERT INTO company_settings (
    id,
    company_name,
    base_currency,
    default_office_benefit_rate,
    office_benefit_by_type,
    receipt_warning_threshold,
    receipt_red_flag_threshold,
    receipt_critical_threshold,
    daily_food_allowance,
    target_profit_margin,
    watch_profit_margin,
    risk_profit_margin
) VALUES (
    'e0000000-0000-0000-0000-000000000001',
    'PFIS Consultancy & Survey Ltd.',
    'BDT',
    0.3000,
    '{"direct_consultancy": 0.30, "government": 0.30, "private": 0.25, "sub_consultancy": 0.20}'::jsonb,
    0.3000,
    0.5000,
    0.7500,
    800.00,
    35.00,
    20.00,
    10.00
) ON CONFLICT (id) DO NOTHING;

-- 2. Insert Default Categories
INSERT INTO categories (id, name, icon_name, is_default, is_active)
VALUES
    ('c0000000-0000-0000-0000-000000000001', 'Equipment', 'hardware', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000002', 'Transportation', 'transport', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000003', 'Food', 'meal', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000004', 'Accommodation', 'lodging', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000005', 'Office Cost', 'office', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000006', 'Travel & Flights', 'travel', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000007', 'Software & Tools', 'software', TRUE, TRUE)
ON CONFLICT (name) DO NOTHING;

-- 3. Insert Corporate Clients
INSERT INTO clients (id, name, client_type, contact_person, email, phone, address, notes)
VALUES
    ('b0000000-0000-0000-0000-000000000001', 'Apex Technologies Inc.', 'private', 'Michael Vance', 'm.vance@apextech.com', '+880 1700-111222', 'Gulshan-2, Dhaka', 'Primary Enterprise Cloud client'),
    ('b0000000-0000-0000-0000-000000000002', 'Prime Bank Digital', 'private', 'Nazmul Karim', 'n.karim@primebank.com', '+880 1700-333444', 'Motijheel C/A, Dhaka', 'Mobile banking transformation partner'),
    ('b0000000-0000-0000-0000-000000000003', 'BioHealth AI Corp', 'private', 'Dr. Arifa Rahman', 'arahman@biohealth.ai', '+880 1700-555666', 'Banani, Dhaka', 'Healthcare AI Diagnostics partner'),
    ('b0000000-0000-0000-0000-000000000004', 'GovTech Defense Systems', 'government', 'Brigadier General (Ret.) S. Ahmed', 'procurement@govtech.bd', '+880 1700-777888', 'Agargaon ICT Zone, Dhaka', 'National security defense contract')
ON CONFLICT (id) DO NOTHING;

-- 4. Insert Default Users (Password: "password123")
INSERT INTO users (id, email, password_hash, full_name, role, department, designation, phone)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'admin@pfis.com', '$2a$10$NcceR3EX5RYDA/ogM9Sys.TztdGvbBlJ4K630rzHG4E9Iole0NK6S', 'Eleanor Vance', 'main_admin', 'Corporate Governance', 'Managing Director / Admin', '+880 1711-000001')
ON CONFLICT (email) DO NOTHING;

-- 5. Insert Core Projects
INSERT INTO projects (
    id,
    project_code,
    name,
    description,
    client_id,
    client_name,
    client_type,
    assignment_type,
    gross_project_value,
    tax_status,
    tax_rate,
    expected_net_revenue,
    advance_received,
    amount_received,
    amount_receivable,
    budget,
    category_budgets,
    estimated_remaining_cost,
    office_benefit_rate,
    start_date,
    end_date,
    status,
    created_by
) VALUES
(
    'd0000000-0000-0000-0000-000000000001',
    'PRJ-2026-001',
    'Enterprise Cloud ERP Platform',
    'Modern microservices-based ERP migration with multi-tenant billing, inventory, and HR automation.',
    'b0000000-0000-0000-0000-000000000001',
    'Apex Technologies Inc.',
    'private',
    'direct_consultancy',
    2500000.00,
    'included',
    0.1000,
    2250000.00,
    500000.00,
    1500000.00,
    1000000.00,
    2080000.00,
    '{"equipment": 300000.0, "transportation": 450000.0, "food": 250000.0, "accommodation": 400000.0, "officecost": 200000.0, "officebenefit": 480000.0}'::jsonb,
    580000.00,
    0.3000,
    '2026-01-15',
    '2026-11-30',
    'ongoing',
    'a0000000-0000-0000-0000-000000000001'
),
(
    'd0000000-0000-0000-0000-000000000002',
    'PRJ-2026-002',
    'Fintech Mobile Banking App (iOS & Android)',
    'Omnichannel mobile banking application with biometric auth, QR payments, and real-time ledger sync.',
    'b0000000-0000-0000-0000-000000000002',
    'Prime Bank Digital',
    'private',
    'sub_consultancy',
    1800000.00,
    'excluded',
    0.1500,
    1800000.00,
    350000.00,
    1000000.00,
    800000.00,
    1500000.00,
    '{"equipment": 250000.0, "transportation": 350000.0, "food": 200000.0, "accommodation": 300000.0, "officecost": 150000.0, "officebenefit": 250000.0}'::jsonb,
    400000.00,
    0.2000,
    '2026-02-01',
    '2026-12-15',
    'ongoing',
    'a0000000-0000-0000-0000-000000000001'
),
(
    'd0000000-0000-0000-0000-000000000003',
    'PRJ-2026-003',
    'AI-Powered Telehealth Diagnostic Portal',
    'HIPAA-compliant video telemedicine portal with AI-assisted clinical note summarization.',
    'b0000000-0000-0000-0000-000000000003',
    'BioHealth AI Corp',
    'private',
    'direct_consultancy',
    1200000.00,
    'included',
    0.1000,
    1080000.00,
    300000.00,
    600000.00,
    600000.00,
    1050000.00,
    '{"equipment": 150000.0, "transportation": 250000.0, "food": 150000.0, "accommodation": 200000.0, "officecost": 100000.0, "officebenefit": 200000.0}'::jsonb,
    200000.00,
    0.3000,
    '2026-03-01',
    '2026-09-30',
    'ongoing',
    'a0000000-0000-0000-0000-000000000001'
),
(
    'd0000000-0000-0000-0000-000000000004',
    'PRJ-2026-004',
    'Cybersecurity SOC & DevSecOps Pipeline',
    'Automated CI/CD security scanning, Kubernetes posture management, and 24/7 SOC incident response.',
    'b0000000-0000-0000-0000-000000000004',
    'GovTech Defense Systems',
    'government',
    'government',
    3500000.00,
    'not_applicable',
    0.0000,
    3500000.00,
    800000.00,
    1800000.00,
    1700000.00,
    2800000.00,
    '{"equipment": 600000.0, "transportation": 500000.0, "food": 300000.0, "accommodation": 400000.0, "officecost": 300000.0, "officebenefit": 700000.0}'::jsonb,
    800000.00,
    0.3000,
    '2026-01-01',
    '2026-10-31',
    'ongoing',
    'a0000000-0000-0000-0000-000000000001'
)
ON CONFLICT (id) DO NOTHING;

-- 6. Insert Team Members Assignments
INSERT INTO project_members (project_id, user_id, role_in_project)
VALUES
    ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Admin Sponsor')
ON CONFLICT (project_id, user_id) DO NOTHING;

-- 7. Insert Project Revenues
INSERT INTO project_revenues (id, project_id, amount, date, note, created_by)
VALUES
    ('f0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 500000.00, '2026-02-01', 'Advance Mobilization Payment', 'a0000000-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- 8. Clean Initial Expenses
-- All demo mock expenses cleared; production system starts clean with Super Admin.

