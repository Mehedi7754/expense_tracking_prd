-- ============================================================================
-- SpendWise (PFIS) - Enterprise-Grade PostgreSQL Database Schema
-- Architecture: Multi-Role, Project-Isolated Financial Intelligence System
-- Target: PostgreSQL 14+ (Recommended: PostgreSQL 16)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTENSIONS
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ----------------------------------------------------------------------------
-- 2. ENUM TYPES & DOMAINS
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role_type') THEN
        CREATE TYPE user_role_type AS ENUM (
            'main_admin',
            'project_manager',
            'project_member',
            'finance',
            'viewer'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_type_enum') THEN
        CREATE TYPE client_type_enum AS ENUM (
            'government',
            'private',
            'ngo',
            'international',
            'other'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'assignment_type_enum') THEN
        CREATE TYPE assignment_type_enum AS ENUM (
            'direct_consultancy',
            'sub_consultancy',
            'government',
            'private'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tax_status_enum') THEN
        CREATE TYPE tax_status_enum AS ENUM (
            'included',
            'excluded',
            'not_applicable'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'project_status_enum') THEN
        CREATE TYPE project_status_enum AS ENUM (
            'proposal',
            'approved',
            'ongoing',
            'completed',
            'suspended',
            'cancelled'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'expense_status_enum') THEN
        CREATE TYPE expense_status_enum AS ENUM (
            'pending',
            'approved',
            'rejected'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'justification_status_enum') THEN
        CREATE TYPE justification_status_enum AS ENUM (
            'none',
            'required',
            'submitted',
            'approved',
            'rejected',
            'clarification_requested'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_status_enum') THEN
        CREATE TYPE task_status_enum AS ENUM (
            'in_progress',
            'completed'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type_enum') THEN
        CREATE TYPE notification_type_enum AS ENUM (
            'expense_approved',
            'expense_rejected',
            'budget_warning',
            'comment_added',
            'general',
            'expense_submitted',
            'justification_submitted',
            'justification_approved',
            'justification_rejected',
            'project_assigned',
            'budget_critical',
            'attendance_reminder',
            'attendance_late',
            'absence_deducted',
            'salary_ready',
            'payroll_finalized',
            'revenue_received',
            'member_added',
            'user_registration',
            'security_alert'
        );
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 3. CORE TABLES
-- ----------------------------------------------------------------------------

-- USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email CITEXT NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    role user_role_type NOT NULL DEFAULT 'project_member',
    department VARCHAR(100) NOT NULL DEFAULT 'Operations',
    designation VARCHAR(100),
    phone VARCHAR(35),
    avatar_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- CLIENTS TABLE
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    client_type client_type_enum NOT NULL DEFAULT 'private',
    contact_person VARCHAR(150) NOT NULL,
    email CITEXT,
    phone VARCHAR(50),
    address TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- CATEGORIES TABLE
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    icon_name VARCHAR(50) NOT NULL DEFAULT 'category',
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- PROJECTS TABLE
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_code VARCHAR(50) NOT NULL UNIQUE, -- e.g. PRJ-2026-001
    name VARCHAR(250) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    client_name VARCHAR(200) NOT NULL,
    client_type client_type_enum NOT NULL DEFAULT 'private',
    assignment_type assignment_type_enum NOT NULL DEFAULT 'direct_consultancy',
    gross_project_value NUMERIC(15, 2) NOT NULL CHECK (gross_project_value >= 0),
    tax_status tax_status_enum NOT NULL DEFAULT 'included',
    tax_rate NUMERIC(5, 4) NOT NULL DEFAULT 0.1000 CHECK (tax_rate >= 0 AND tax_rate <= 1),
    expected_net_revenue NUMERIC(15, 2) NOT NULL CHECK (expected_net_revenue >= 0),
    advance_received NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (advance_received >= 0),
    amount_received NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (amount_received >= 0),
    amount_receivable NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (amount_receivable >= 0),
    budget NUMERIC(15, 2) NOT NULL CHECK (budget >= 0),
    category_budgets JSONB NOT NULL DEFAULT '{}'::jsonb,
    estimated_remaining_cost NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (estimated_remaining_cost >= 0),
    office_benefit_rate NUMERIC(5, 4) NOT NULL DEFAULT 0.3000 CHECK (office_benefit_rate >= 0 AND office_benefit_rate <= 1),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status project_status_enum NOT NULL DEFAULT 'ongoing',
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    closed_at TIMESTAMPTZ,
    closing_summary JSONB,
    image_url TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_project_dates CHECK (end_date >= start_date)
);

-- PROJECT MEMBERS JUNCTION (Role-Based Project Isolation / PRD Section 1)
CREATE TABLE IF NOT EXISTS project_members (
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_in_project VARCHAR(50) NOT NULL DEFAULT 'Member',
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (project_id, user_id)
);

-- PROJECT REVENUES TABLE (Mobilization advances & milestone receipts)
CREATE TABLE IF NOT EXISTS project_revenues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    note TEXT NOT NULL DEFAULT '',
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- TASKS TABLE
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    title VARCHAR(250) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    assignee_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    due_date DATE NOT NULL,
    status task_status_enum NOT NULL DEFAULT 'in_progress',
    budget_line VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- EXPENSES TABLE (Core transactional financial entity)
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
    task_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount >= 0),
    office_benefit_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (office_benefit_amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'BDT',
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    note TEXT NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    has_receipt BOOLEAN NOT NULL DEFAULT TRUE,
    receipt_photo_url TEXT,
    status expense_status_enum NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    
    -- PRD Section 11, 12, 13: Justification for unreceipted / out-of-policy claims
    justification_status justification_status_enum NOT NULL DEFAULT 'none',
    justification_reason TEXT,
    justification_comment TEXT,
    justification_attachment_url TEXT,
    justification_reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    justification_review_comment TEXT,
    justification_reviewed_at TIMESTAMPTZ,
    
    -- Category-specific structured payload (Equipment, Transport, Food, Accommodation, Office)
    category_details JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- EXPENSE COMMENTS TABLE
CREATE TABLE IF NOT EXISTS expense_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    author_name VARCHAR(150) NOT NULL,
    author_role user_role_type NOT NULL,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- AUDIT LOGS TABLE (Partitionable append-only audit trail)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_name VARCHAR(150) NOT NULL,
    user_role user_role_type NOT NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    details TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(250) NOT NULL,
    message TEXT NOT NULL,
    full_explanation TEXT NOT NULL DEFAULT '',
    type notification_type_enum NOT NULL DEFAULT 'general',
    related_expense_id UUID REFERENCES expenses(id) ON DELETE CASCADE,
    related_project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- HISTORICAL BENCHMARKS (For AI Cost Estimator / PRD Section 30)
CREATE TABLE IF NOT EXISTS historical_benchmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_name VARCHAR(250) NOT NULL,
    project_type VARCHAR(100) NOT NULL,
    duration_months INT NOT NULL CHECK (duration_months > 0),
    staff_count INT NOT NULL CHECK (staff_count > 0),
    locations_count INT NOT NULL DEFAULT 1,
    respondents_count INT NOT NULL DEFAULT 0,
    travel_intensity VARCHAR(20) NOT NULL DEFAULT 'Medium',
    total_actual_cost NUMERIC(15, 2) NOT NULL CHECK (total_actual_cost >= 0),
    transport_cost_pct NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    accommodation_cost_pct NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    food_cost_pct NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    equipment_cost_pct NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    office_cost_pct NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    personnel_cost_pct NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    average_profit_margin NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- COMPANY SETTINGS TABLE (Single-tenant or multi-tenant system configuration)
CREATE TABLE IF NOT EXISTS company_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name VARCHAR(200) NOT NULL DEFAULT 'PFIS Consultancy & Survey Ltd.',
    base_currency VARCHAR(3) NOT NULL DEFAULT 'BDT',
    company_logo_url TEXT,
    default_office_benefit_rate NUMERIC(5, 4) NOT NULL DEFAULT 0.3000,
    office_benefit_by_type JSONB NOT NULL DEFAULT '{"direct_consultancy": 0.30, "government": 0.30, "private": 0.25, "sub_consultancy": 0.20}'::jsonb,
    receipt_warning_threshold NUMERIC(5, 4) NOT NULL DEFAULT 0.3000,
    receipt_red_flag_threshold NUMERIC(5, 4) NOT NULL DEFAULT 0.5000,
    receipt_critical_threshold NUMERIC(5, 4) NOT NULL DEFAULT 0.7500,
    daily_food_allowance NUMERIC(15, 2) NOT NULL DEFAULT 800.00,
    target_profit_margin NUMERIC(5, 2) NOT NULL DEFAULT 35.00,
    watch_profit_margin NUMERIC(5, 2) NOT NULL DEFAULT 20.00,
    risk_profit_margin NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- ----------------------------------------------------------------------------
-- 4. OPTIMIZED INDEXING STRATEGY
-- ----------------------------------------------------------------------------

-- Foreign Key Indexes (Eliminate sequential scans during JOINs and CASCADE checks)
CREATE INDEX IF NOT EXISTS idx_projects_client_id ON projects(client_id);
CREATE INDEX IF NOT EXISTS idx_projects_created_by ON projects(created_by);
CREATE INDEX IF NOT EXISTS idx_project_members_user_id ON project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_project_revenues_project_id ON project_revenues(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee_id ON tasks(assignee_id);
CREATE INDEX IF NOT EXISTS idx_expenses_employee_id ON expenses(employee_id);
CREATE INDEX IF NOT EXISTS idx_expenses_project_id ON expenses(project_id);
CREATE INDEX IF NOT EXISTS idx_expenses_category_id ON expenses(category_id);
CREATE INDEX IF NOT EXISTS idx_expenses_task_id ON expenses(task_id);
CREATE INDEX IF NOT EXISTS idx_expense_comments_expense_id ON expense_comments(expense_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);

-- Composite B-Tree Indexes for Frequent Query Filtering and Sorting
CREATE INDEX IF NOT EXISTS idx_expenses_project_date ON expenses(project_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_employee_status_date ON expenses(employee_id, status, date DESC);
CREATE INDEX IF NOT EXISTS idx_tasks_project_status_due ON tasks(project_id, status, due_date ASC);
CREATE INDEX IF NOT EXISTS idx_projects_status_dates ON projects(status, start_date, end_date);

-- Partial Indexes for Operational Queues (Instant response on high-frequency filters)
CREATE INDEX IF NOT EXISTS idx_expenses_pending ON expenses(created_at DESC) 
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_expenses_justification_pending ON expenses(created_at DESC) 
    WHERE justification_status = 'submitted';

CREATE INDEX IF NOT EXISTS idx_expenses_unreceipted ON expenses(employee_id, project_id) 
    WHERE has_receipt = FALSE;

CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, created_at DESC) 
    WHERE is_read = FALSE;

CREATE INDEX IF NOT EXISTS idx_projects_active ON projects(id) 
    WHERE status = 'ongoing';

-- GIN Trigram Indexes for Full-Text Search
CREATE INDEX IF NOT EXISTS idx_projects_search_gin ON projects USING gin(name gin_trgm_ops, description gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clients_search_gin ON clients USING gin(name gin_trgm_ops, contact_person gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_expenses_note_gin ON expenses USING gin(note gin_trgm_ops);

-- BRIN Index for High-Volume Time-Series Audit Log Retention
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_brin ON audit_logs USING brin(created_at);

-- ----------------------------------------------------------------------------
-- 5. AUTOMATED TRIGGERS & BUSINESS LOGIC PROCEDURES
-- ----------------------------------------------------------------------------

-- Universal updated_at timestamp function
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = clock_timestamp();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at to all mutable tables
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_clients_updated_at ON clients;
CREATE TRIGGER trg_clients_updated_at BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_categories_updated_at ON categories;
CREATE TRIGGER trg_categories_updated_at BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_projects_updated_at ON projects;
CREATE TRIGGER trg_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_tasks_updated_at ON tasks;
CREATE TRIGGER trg_tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_expenses_updated_at ON expenses;
CREATE TRIGGER trg_expenses_updated_at BEFORE UPDATE ON expenses FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_company_settings_updated_at ON company_settings;
CREATE TRIGGER trg_company_settings_updated_at BEFORE UPDATE ON company_settings FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

-- Auto-recalculate project received and receivable amounts when revenues change
CREATE OR REPLACE FUNCTION trg_sync_project_revenues()
RETURNS TRIGGER AS $$
DECLARE
    v_project_id UUID;
    v_total_received NUMERIC(15, 2);
    v_gross_value NUMERIC(15, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_project_id := OLD.project_id;
    ELSE
        v_project_id := NEW.project_id;
    END IF;

    SELECT COALESCE(SUM(amount), 0.00) INTO v_total_received
    FROM project_revenues
    WHERE project_id = v_project_id;

    SELECT gross_project_value INTO v_gross_value
    FROM projects
    WHERE id = v_project_id;

    UPDATE projects
    SET amount_received = v_total_received,
        amount_receivable = GREATEST(0.00, v_gross_value - v_total_received)
    WHERE id = v_project_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_project_revenue_sync ON project_revenues;
CREATE TRIGGER trg_project_revenue_sync
AFTER INSERT OR UPDATE OR DELETE ON project_revenues
FOR EACH ROW EXECUTE FUNCTION trg_sync_project_revenues();

-- Auto-calculate Office Benefit Amount (PRD Section 9: 30% default)
CREATE OR REPLACE FUNCTION trg_calculate_office_benefit()
RETURNS TRIGGER AS $$
DECLARE
    v_benefit_rate NUMERIC(5, 4);
BEGIN
    IF NEW.office_benefit_amount IS NULL OR NEW.office_benefit_amount = 0 THEN
        SELECT office_benefit_rate INTO v_benefit_rate
        FROM projects
        WHERE id = NEW.project_id;

        v_benefit_rate := COALESCE(v_benefit_rate, 0.3000);
        NEW.office_benefit_amount := ROUND((NEW.amount * v_benefit_rate)::numeric, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_expense_office_benefit ON expenses;
CREATE TRIGGER trg_expense_office_benefit
BEFORE INSERT OR UPDATE OF amount, project_id ON expenses
FOR EACH ROW EXECUTE FUNCTION trg_calculate_office_benefit();

-- ----------------------------------------------------------------------------
-- 6. ROW-LEVEL SECURITY (RLS) POLICIES (PRD Section 1)
-- ----------------------------------------------------------------------------
-- Project Members can ONLY see projects they are assigned to.
-- Main Admin and Finance can see ALL projects.
-- ----------------------------------------------------------------------------

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Helper function: Is current user an Admin or Finance officer?
CREATE OR REPLACE FUNCTION is_admin_or_finance()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        current_setting('app.current_user_role', true) IN ('main_admin', 'finance')
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Helper function: Get Current User ID from session
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_user_id', true), '')::UUID;
END;
$$ LANGUAGE plpgsql STABLE;

-- PROJECTS POLICY:
DROP POLICY IF EXISTS p_projects_access ON projects;
CREATE POLICY p_projects_access ON projects
    FOR ALL
    USING (
        is_admin_or_finance()
        OR EXISTS (
            SELECT 1 FROM project_members pm
            WHERE pm.project_id = projects.id
              AND pm.user_id = get_current_user_id()
        )
    );

-- EXPENSES POLICY:
DROP POLICY IF EXISTS p_expenses_access ON expenses;
CREATE POLICY p_expenses_access ON expenses
    FOR ALL
    USING (
        is_admin_or_finance()
        OR employee_id = get_current_user_id()
        OR EXISTS (
            SELECT 1 FROM project_members pm
            WHERE pm.project_id = expenses.project_id
              AND pm.user_id = get_current_user_id()
        )
    );

-- TASKS POLICY:
DROP POLICY IF EXISTS p_tasks_access ON tasks;
CREATE POLICY p_tasks_access ON tasks
    FOR ALL
    USING (
        is_admin_or_finance()
        OR assignee_id = get_current_user_id()
        OR EXISTS (
            SELECT 1 FROM project_members pm
            WHERE pm.project_id = tasks.project_id
              AND pm.user_id = get_current_user_id()
        )
    );

-- NOTIFICATIONS POLICY:
DROP POLICY IF EXISTS p_notifications_access ON notifications;
CREATE POLICY p_notifications_access ON notifications
    FOR ALL
    USING (
        user_id = get_current_user_id()
        OR is_admin_or_finance()
    );

-- ----------------------------------------------------------------------------
-- 7. ANALYTICAL REPORTING VIEWS
-- ----------------------------------------------------------------------------

-- View: Project Financial Summary (Real-time P&L rollup per project)
CREATE OR REPLACE VIEW vw_project_financial_summary AS
SELECT 
    p.id AS project_id,
    p.project_code,
    p.name AS project_name,
    p.client_name,
    p.gross_project_value,
    p.tax_status,
    p.tax_rate,
    p.expected_net_revenue,
    p.amount_received,
    p.amount_receivable,
    p.budget,
    COALESCE(exp_summary.total_direct_cost, 0.00) AS direct_expenditure,
    COALESCE(exp_summary.total_office_benefit, 0.00) AS office_benefit,
    (COALESCE(exp_summary.total_direct_cost, 0.00) + COALESCE(exp_summary.total_office_benefit, 0.00)) AS net_project_cost,
    (p.expected_net_revenue - (COALESCE(exp_summary.total_direct_cost, 0.00) + COALESCE(exp_summary.total_office_benefit, 0.00))) AS projected_profit,
    CASE 
        WHEN p.expected_net_revenue > 0 THEN 
            ROUND(
                ((p.expected_net_revenue - (COALESCE(exp_summary.total_direct_cost, 0.00) + COALESCE(exp_summary.total_office_benefit, 0.00))) / p.expected_net_revenue * 100)::numeric,
                2
            )
        ELSE 0.00 
    END AS profit_margin_pct,
    p.status,
    p.is_closed
FROM projects p
LEFT JOIN (
    SELECT 
        project_id,
        SUM(amount) AS total_direct_cost,
        SUM(office_benefit_amount) AS total_office_benefit
    FROM expenses
    WHERE status = 'approved'
    GROUP BY project_id
) exp_summary ON p.id = exp_summary.project_id;

-- View: Member Receipt Compliance Summary (Instant red-flag calculation)
CREATE OR REPLACE VIEW vw_member_receipt_compliance AS
SELECT 
    u.id AS member_id,
    u.full_name AS member_name,
    p.id AS project_id,
    p.name AS project_name,
    COALESCE(SUM(e.amount), 0.00) AS total_claimed,
    COALESCE(SUM(CASE WHEN e.has_receipt = FALSE THEN e.amount ELSE 0.00 END), 0.00) AS unreceipted_amount,
    CASE 
        WHEN SUM(e.amount) > 0 THEN 
            ROUND((SUM(CASE WHEN e.has_receipt = FALSE THEN e.amount ELSE 0.00 END) / SUM(e.amount) * 100)::numeric, 2)
        ELSE 0.00 
    END AS unreceipted_ratio,
    COUNT(CASE WHEN e.has_receipt = FALSE THEN 1 END) AS unreceipted_count,
    CASE 
        WHEN SUM(e.amount) > 0 AND (SUM(CASE WHEN e.has_receipt = FALSE THEN e.amount ELSE 0.00 END) / SUM(e.amount)) >= 0.50 THEN TRUE
        ELSE FALSE 
    END AS is_red_flagged
FROM users u
JOIN expenses e ON u.id = e.employee_id
JOIN projects p ON e.project_id = p.id
GROUP BY u.id, u.full_name, p.id, p.name;

-- ----------------------------------------------------------------------------
-- 8. ATTENDANCE & GEO-LOCATION TRACKING (PRD Section 31)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    session_type VARCHAR(20) NOT NULL DEFAULT 'morning' CHECK (session_type IN ('morning', 'afternoon')),
    login_time TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    address_text TEXT DEFAULT '',
    device_info TEXT DEFAULT '',
    status VARCHAR(20) NOT NULL DEFAULT 'present' CHECK (status IN ('present', 'late', 'half_day', 'missing', 'confirmed_absent')),
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_user_date_session UNIQUE (user_id, date, session_type)
);

CREATE INDEX IF NOT EXISTS idx_attendance_user_date ON attendance_records(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance_records(date DESC);

-- ----------------------------------------------------------------------------
-- 9. MONTHLY SALARY, HOLIDAYS, LEAVES & ATTENDANCE-BASED DEDUCTIONS
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS employee_salaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    monthly_salary NUMERIC(15, 2) NOT NULL DEFAULT 50000.00 CHECK (monthly_salary >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'BDT',
    standard_working_days INT NOT NULL DEFAULT 22 CHECK (standard_working_days > 0),
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_employee_salaries_user_id ON employee_salaries(user_id);

CREATE TABLE IF NOT EXISTS holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_holidays_date ON holidays(date);

CREATE TABLE IF NOT EXISTS leave_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    leave_type VARCHAR(50) NOT NULL DEFAULT 'paid' CHECK (leave_type IN ('paid', 'unpaid', 'sick', 'casual', 'maternity', 'emergency')),
    reason TEXT NOT NULL DEFAULT '',
    is_approved BOOLEAN NOT NULL DEFAULT TRUE,
    approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_leave_dates CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_leave_records_user_dates ON leave_records(user_id, start_date, end_date);

CREATE TABLE IF NOT EXISTS salary_calculations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INT NOT NULL CHECK (year >= 2000),
    base_salary NUMERIC(15, 2) NOT NULL CHECK (base_salary >= 0),
    working_days INT NOT NULL CHECK (working_days > 0),
    present_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
    absent_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
    missing_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
    holidays_count INT NOT NULL DEFAULT 0,
    weekend_days INT NOT NULL DEFAULT 0,
    paid_leave_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
    unpaid_leave_days NUMERIC(5, 1) NOT NULL DEFAULT 0.0,
    daily_rate NUMERIC(15, 2) NOT NULL CHECK (daily_rate >= 0),
    total_deductions NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (total_deductions >= 0),
    bonus_or_additions NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    final_payable NUMERIC(15, 2) NOT NULL CHECK (final_payable >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'calculated' CHECK (status IN ('calculated', 'confirmed', 'paid')),
    notes TEXT DEFAULT '',
    calculated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_user_month_year UNIQUE (user_id, month, year)
);

CREATE INDEX IF NOT EXISTS idx_salary_calc_user_period ON salary_calculations(user_id, year, month);
CREATE INDEX IF NOT EXISTS idx_salary_calc_period ON salary_calculations(year, month);

CREATE TABLE IF NOT EXISTS salary_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salary_calculation_id UUID REFERENCES salary_calculations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    adjustment_type VARCHAR(20) NOT NULL CHECK (adjustment_type IN ('deduction', 'addition', 'override', 'bonus', 'penalty')),
    amount NUMERIC(15, 2) NOT NULL,
    reason TEXT NOT NULL,
    adjusted_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_salary_adj_calc_id ON salary_adjustments(salary_calculation_id);

-- ----------------------------------------------------------------------------
-- 13. REAL-TIME CHAT & MESSENGER
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL DEFAULT 'direct', -- 'direct' or 'project'
    name VARCHAR(255),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS idx_chat_channels_project ON chat_channels(project_id);
CREATE INDEX IF NOT EXISTS idx_chat_channels_updated_at ON chat_channels(updated_at DESC);

CREATE TABLE IF NOT EXISTS chat_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES chat_channels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_channel_user UNIQUE(channel_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_channel ON chat_participants(channel_id);

CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES chat_channels(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL DEFAULT '',
    image_url TEXT,
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
    reply_to_id UUID REFERENCES chat_messages(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS idx_chat_messages_channel_created ON chat_messages(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_project ON chat_messages(project_id);

