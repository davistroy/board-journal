-- Boardroom Journal Database Schema
-- PostgreSQL 15+

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- Users Table
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255),
    provider VARCHAR(50) NOT NULL,  -- 'apple', 'google'
    provider_user_id VARCHAR(255) NOT NULL,
    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at_utc TIMESTAMP WITH TIME ZONE,
    delete_scheduled_at_utc TIMESTAMP WITH TIME ZONE,  -- 7-day grace period for account deletion

    UNIQUE(provider, provider_user_id)
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_provider ON users(provider, provider_user_id);
CREATE INDEX idx_users_delete_scheduled ON users(delete_scheduled_at_utc) WHERE delete_scheduled_at_utc IS NOT NULL;

-- ============================================
-- Refresh Tokens Table
-- ============================================
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    revoked_at_utc TIMESTAMP WITH TIME ZONE,
    device_info JSONB  -- Optional device metadata
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens(expires_at_utc);

-- ============================================
-- Rate Limiting Tables
-- ============================================
CREATE TABLE rate_limit_auth (
    ip_address INET PRIMARY KEY,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    first_attempt_at_utc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    lockout_until_utc TIMESTAMP WITH TIME ZONE
);

CREATE TABLE rate_limit_account_creation (
    ip_address INET PRIMARY KEY,
    account_count INTEGER NOT NULL DEFAULT 0,
    window_start_utc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================
-- Daily Entries Table
-- ============================================
CREATE TABLE daily_entries (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transcript_raw TEXT NOT NULL,
    transcript_edited TEXT NOT NULL,
    extracted_signals_json JSONB NOT NULL DEFAULT '{}',
    entry_type VARCHAR(20) NOT NULL,  -- 'voice', 'text'
    word_count INTEGER NOT NULL DEFAULT 0,
    duration_seconds INTEGER,  -- NULL for text entries
    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at_timezone VARCHAR(50) NOT NULL,
    updated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at_utc TIMESTAMP WITH TIME ZONE,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_daily_entries_user ON daily_entries(user_id);
CREATE INDEX idx_daily_entries_created ON daily_entries(user_id, created_at_utc);
CREATE INDEX idx_daily_entries_updated ON daily_entries(user_id, updated_at_utc);
CREATE INDEX idx_daily_entries_deleted ON daily_entries(deleted_at_utc) WHERE deleted_at_utc IS NOT NULL;

-- ============================================
-- Weekly Briefs Table
-- ============================================
CREATE TABLE weekly_briefs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_start_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    week_end_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    week_timezone VARCHAR(50) NOT NULL,
    brief_markdown TEXT NOT NULL,
    board_micro_review_markdown TEXT,
    entry_count INTEGER NOT NULL DEFAULT 0,
    regen_count INTEGER NOT NULL DEFAULT 0,
    regen_options_json JSONB NOT NULL DEFAULT '[]',
    micro_review_collapsed BOOLEAN NOT NULL DEFAULT FALSE,
    generated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at_utc TIMESTAMP WITH TIME ZONE,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_weekly_briefs_user ON weekly_briefs(user_id);
CREATE INDEX idx_weekly_briefs_week ON weekly_briefs(user_id, week_start_utc);
CREATE INDEX idx_weekly_briefs_updated ON weekly_briefs(user_id, updated_at_utc);

-- ============================================
-- Problems Table
-- ============================================
CREATE TABLE problems (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    what_breaks TEXT NOT NULL,
    scarcity_signals_json JSONB NOT NULL,
    direction VARCHAR(20) NOT NULL,  -- 'appreciating', 'depreciating', 'stable'
    direction_rationale TEXT NOT NULL,
    evidence_ai_cheaper TEXT NOT NULL,
    evidence_error_cost TEXT NOT NULL,
    evidence_trust_required TEXT NOT NULL,
    time_allocation_percent INTEGER NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at_utc TIMESTAMP WITH TIME ZONE,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT valid_direction CHECK (direction IN ('appreciating', 'depreciating', 'stable')),
    CONSTRAINT valid_allocation CHECK (time_allocation_percent >= 0 AND time_allocation_percent <= 100)
);

CREATE INDEX idx_problems_user ON problems(user_id);
CREATE INDEX idx_problems_updated ON problems(user_id, updated_at_utc);

-- ============================================
-- Portfolio Versions Table
-- ============================================
CREATE TABLE portfolio_versions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    problems_snapshot_json JSONB NOT NULL,
    health_snapshot_json JSONB NOT NULL,
    board_anchoring_snapshot_json JSONB NOT NULL,
    triggers_snapshot_json JSONB NOT NULL,
    trigger_reason TEXT NOT NULL,
    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_portfolio_versions_user ON portfolio_versions(user_id);
CREATE INDEX idx_portfolio_versions_number ON portfolio_versions(user_id, version_number);

-- ============================================
-- Board Members Table
-- ============================================
CREATE TABLE board_members (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_type VARCHAR(30) NOT NULL,  -- 'accountability', 'marketReality', etc.
    is_growth_role BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    anchored_problem_id UUID REFERENCES problems(id) ON DELETE SET NULL,
    anchored_demand TEXT,

    -- Editable persona
    persona_name VARCHAR(50) NOT NULL,
    persona_background VARCHAR(300) NOT NULL,
    persona_communication_style VARCHAR(200) NOT NULL,
    persona_signature_phrase VARCHAR(100),

    -- Original persona (for reset)
    original_persona_name VARCHAR(50) NOT NULL,
    original_persona_background VARCHAR(300) NOT NULL,
    original_persona_communication_style VARCHAR(200) NOT NULL,
    original_persona_signature_phrase VARCHAR(100),

    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at_utc TIMESTAMP WITH TIME ZONE,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT valid_role_type CHECK (role_type IN (
        'accountability', 'marketReality', 'avoidance',
        'longTermPositioning', 'devilsAdvocate',
        'portfolioDefender', 'opportunityScout'
    ))
);

CREATE INDEX idx_board_members_user ON board_members(user_id);
CREATE INDEX idx_board_members_updated ON board_members(user_id, updated_at_utc);

-- ============================================
-- Governance Sessions Table
-- ============================================
CREATE TABLE governance_sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_type VARCHAR(20) NOT NULL,  -- 'quick', 'setup', 'quarterly'
    current_state VARCHAR(50) NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    abstraction_mode BOOLEAN NOT NULL DEFAULT FALSE,
    vagueness_skip_count INTEGER NOT NULL DEFAULT 0,
    transcript_json JSONB NOT NULL DEFAULT '[]',
    output_markdown TEXT,
    created_portfolio_version_id UUID REFERENCES portfolio_versions(id) ON DELETE SET NULL,
    evaluated_bet_id UUID,  -- Don't create FK yet, bets table comes later
    created_bet_id UUID,
    duration_seconds INTEGER,
    started_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at_utc TIMESTAMP WITH TIME ZONE,
    updated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at_utc TIMESTAMP WITH TIME ZONE,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT valid_session_type CHECK (session_type IN ('quick', 'setup', 'quarterly')),
    CONSTRAINT valid_vagueness_count CHECK (vagueness_skip_count <= 2)
);

CREATE INDEX idx_governance_sessions_user ON governance_sessions(user_id);
CREATE INDEX idx_governance_sessions_updated ON governance_sessions(user_id, updated_at_utc);

-- ============================================
-- Bets Table
-- ============================================
CREATE TABLE bets (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    prediction TEXT NOT NULL,
    wrong_if TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'open',  -- 'open', 'correct', 'wrong', 'expired'
    source_session_id UUID REFERENCES governance_sessions(id) ON DELETE SET NULL,
    evaluation_session_id UUID REFERENCES governance_sessions(id) ON DELETE SET NULL,
    evaluation_notes TEXT,
    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    due_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    evaluated_at_utc TIMESTAMP WITH TIME ZONE,
    updated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at_utc TIMESTAMP WITH TIME ZONE,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT valid_bet_status CHECK (status IN ('open', 'correct', 'wrong', 'expired'))
);

CREATE INDEX idx_bets_user ON bets(user_id);
CREATE INDEX idx_bets_due ON bets(user_id, due_at_utc);
CREATE INDEX idx_bets_status ON bets(user_id, status);
CREATE INDEX idx_bets_updated ON bets(user_id, updated_at_utc);

-- Add FK constraints to governance_sessions now that bets table exists
ALTER TABLE governance_sessions
    ADD CONSTRAINT fk_evaluated_bet FOREIGN KEY (evaluated_bet_id) REFERENCES bets(id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_created_bet FOREIGN KEY (created_bet_id) REFERENCES bets(id) ON DELETE SET NULL;

-- ============================================
-- Evidence Items Table
-- ============================================
CREATE TABLE evidence_items (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES governance_sessions(id) ON DELETE CASCADE,
    problem_id UUID REFERENCES problems(id) ON DELETE SET NULL,
    evidence_type VARCHAR(20) NOT NULL,  -- 'decision', 'artifact', 'calendar', 'proxy', 'none'
    statement_text TEXT NOT NULL,
    strength_flag VARCHAR(20) NOT NULL,  -- 'strong', 'medium', 'weak', 'none'
    context TEXT,
    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT valid_evidence_type CHECK (evidence_type IN ('decision', 'artifact', 'calendar', 'proxy', 'none')),
    CONSTRAINT valid_strength CHECK (strength_flag IN ('strong', 'medium', 'weak', 'none'))
);

CREATE INDEX idx_evidence_items_user ON evidence_items(user_id);
CREATE INDEX idx_evidence_items_session ON evidence_items(session_id);

-- ============================================
-- Re-Setup Triggers Table
-- ============================================
CREATE TABLE resetup_triggers (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    trigger_type VARCHAR(30) NOT NULL,  -- 'role_change', 'scope_change', 'direction_shift', 'time_drift', 'annual'
    description TEXT NOT NULL,
    condition TEXT NOT NULL,
    recommended_action VARCHAR(30) NOT NULL,  -- 'full_resetup', 'update_problem', 'review_health'
    is_met BOOLEAN NOT NULL DEFAULT FALSE,
    met_at_utc TIMESTAMP WITH TIME ZONE,
    due_at_utc TIMESTAMP WITH TIME ZONE,  -- For annual triggers
    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT valid_trigger_type CHECK (trigger_type IN (
        'role_change', 'scope_change', 'direction_shift', 'time_drift', 'annual'
    )),
    CONSTRAINT valid_action CHECK (recommended_action IN (
        'full_resetup', 'update_problem', 'review_health'
    ))
);

CREATE INDEX idx_resetup_triggers_user ON resetup_triggers(user_id);
CREATE INDEX idx_resetup_triggers_met ON resetup_triggers(user_id, is_met);

-- ============================================
-- User Preferences Table
-- ============================================
CREATE TABLE user_preferences (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Privacy settings
    abstraction_mode_quick BOOLEAN NOT NULL DEFAULT FALSE,
    abstraction_mode_setup BOOLEAN NOT NULL DEFAULT FALSE,
    abstraction_mode_quarterly BOOLEAN NOT NULL DEFAULT FALSE,
    remember_abstraction_choice BOOLEAN NOT NULL DEFAULT FALSE,
    analytics_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    -- UI preferences
    micro_review_collapsed BOOLEAN NOT NULL DEFAULT FALSE,

    -- Onboarding state
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    setup_prompt_dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    setup_prompt_last_shown_utc TIMESTAMP WITH TIME ZONE,
    total_entry_count INTEGER NOT NULL DEFAULT 0,

    -- Metadata
    created_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced',
    server_version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_user_preferences_user ON user_preferences(user_id);

-- ============================================
-- Sync Log Table (for change tracking)
-- ============================================
CREATE TABLE sync_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    table_name VARCHAR(50) NOT NULL,
    record_id UUID NOT NULL,
    operation VARCHAR(10) NOT NULL,  -- 'INSERT', 'UPDATE', 'DELETE'
    changed_at_utc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    new_version INTEGER NOT NULL
);

CREATE INDEX idx_sync_log_user_time ON sync_log(user_id, changed_at_utc);
CREATE INDEX idx_sync_log_table_record ON sync_log(table_name, record_id);

-- ============================================
-- Functions and Triggers
-- ============================================

-- Function to log sync changes
CREATE OR REPLACE FUNCTION log_sync_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO sync_log (user_id, table_name, record_id, operation, new_version)
        VALUES (OLD.user_id, TG_TABLE_NAME, OLD.id, 'DELETE', COALESCE(OLD.server_version, 0) + 1);
        RETURN OLD;
    ELSE
        INSERT INTO sync_log (user_id, table_name, record_id, operation, new_version)
        VALUES (NEW.user_id, TG_TABLE_NAME, NEW.id, TG_OP, NEW.server_version);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for all synced tables
CREATE TRIGGER sync_daily_entries AFTER INSERT OR UPDATE OR DELETE ON daily_entries
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

CREATE TRIGGER sync_weekly_briefs AFTER INSERT OR UPDATE OR DELETE ON weekly_briefs
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

CREATE TRIGGER sync_problems AFTER INSERT OR UPDATE OR DELETE ON problems
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

CREATE TRIGGER sync_portfolio_versions AFTER INSERT OR UPDATE OR DELETE ON portfolio_versions
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

CREATE TRIGGER sync_board_members AFTER INSERT OR UPDATE OR DELETE ON board_members
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

CREATE TRIGGER sync_governance_sessions AFTER INSERT OR UPDATE OR DELETE ON governance_sessions
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

CREATE TRIGGER sync_bets AFTER INSERT OR UPDATE OR DELETE ON bets
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

CREATE TRIGGER sync_evidence_items AFTER INSERT OR UPDATE OR DELETE ON evidence_items
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

CREATE TRIGGER sync_resetup_triggers AFTER INSERT OR UPDATE OR DELETE ON resetup_triggers
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

CREATE TRIGGER sync_user_preferences AFTER INSERT OR UPDATE OR DELETE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION log_sync_change();

-- Function to auto-expire bets
CREATE OR REPLACE FUNCTION expire_overdue_bets()
RETURNS void AS $$
BEGIN
    UPDATE bets
    SET status = 'expired',
        updated_at_utc = NOW(),
        server_version = server_version + 1
    WHERE status = 'open'
    AND due_at_utc < NOW()
    AND deleted_at_utc IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to process scheduled account deletions
CREATE OR REPLACE FUNCTION process_scheduled_deletions()
RETURNS void AS $$
BEGIN
    -- Hard delete users whose 7-day grace period has passed
    DELETE FROM users
    WHERE delete_scheduled_at_utc IS NOT NULL
    AND delete_scheduled_at_utc < NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to hard delete old soft-deleted records (30-day retention)
CREATE OR REPLACE FUNCTION cleanup_soft_deletes()
RETURNS void AS $$
DECLARE
    cutoff TIMESTAMP WITH TIME ZONE := NOW() - INTERVAL '30 days';
BEGIN
    DELETE FROM daily_entries WHERE deleted_at_utc < cutoff;
    DELETE FROM weekly_briefs WHERE deleted_at_utc < cutoff;
    DELETE FROM problems WHERE deleted_at_utc < cutoff;
    DELETE FROM board_members WHERE deleted_at_utc < cutoff;
    DELETE FROM governance_sessions WHERE deleted_at_utc < cutoff;
    DELETE FROM bets WHERE deleted_at_utc < cutoff;
    -- Also clean up old sync log entries (keep 90 days)
    DELETE FROM sync_log WHERE changed_at_utc < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Initial Setup
-- ============================================

-- Grant permissions (adjust role name as needed)
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO boardroom_journal_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO boardroom_journal_app;
