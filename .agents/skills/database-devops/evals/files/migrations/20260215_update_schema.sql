-- Eval fixture: a destructive migration for the safety review eval.
-- It drops a column without a backup and renames in place, so a partial
-- failure leaves the table in neither old nor new shape.
ALTER TABLE users DROP COLUMN legacy_settings;

ALTER TABLE users RENAME COLUMN display_name TO name;

UPDATE users SET name = UPPER(name);