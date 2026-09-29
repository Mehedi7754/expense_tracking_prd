-- ============================================================================
-- SpendWise (PFIS) - Database Seed Script (Optional Bootstrap)
-- ============================================================================

-- 1. Insert Default Expense Categories
INSERT INTO categories (id, name, icon_name, is_default, is_active)
VALUES
    ('c0000000-0000-0000-0000-000000000001', 'Travel & Flights', 'travel', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000002', 'Meals & Dining', 'meal', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000003', 'Lodging & Hotels', 'lodging', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000004', 'Hardware & Devices', 'hardware', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000005', 'Software & Tools', 'software', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000006', 'Ground Transport & Taxi', 'transport', TRUE, TRUE),
    ('c0000000-0000-0000-0000-000000000007', 'Office & Supplies', 'office', TRUE, TRUE)
ON CONFLICT (name) DO NOTHING;

-- 2. Insert Default Company Configuration
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
