-- Eval fixture: the index-creation migration for the zero-downtime eval.
-- CREATE INDEX takes a write lock on the table, so the agent is expected to
-- propose CONCURRENTLY (Postgres) or the online-DDL equivalent.
CREATE INDEX idx_orders_customer_id ON orders (customer_id);