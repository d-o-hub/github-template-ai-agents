-- Eval fixture: the migration under review adds a settings table.
--
-- The eval asserts the agent notices the three things that matter: the foreign
-- key to users, the missing IF NOT EXISTS guard, and the absent rollback plan.
--
-- Portable SQL on purpose. T-SQL-flavoured variants (SET QUOTED_IDENTIFIER ON,
-- a bare GO batch separator) satisfy TSLint's dialect rule but are syntax errors
-- to every other SQL analyser, which traded one warning for two errors.

CREATE TABLE IF NOT EXISTS settings (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS idx_settings_user_id ON settings (user_id);

-- Rollback (absent from the migration under review; the eval expects the agent
-- to ask for it):
--   DROP INDEX idx_settings_user_id;
--   DROP TABLE settings;