"""Eval fixture: parameter construction, safe and unsafe, side by side.

The SQL-injection audit eval asserts the agent recognises the injectable
constructs and names the parameterisation fix, rather than only the most obvious
call.

The unsafe forms below appear inside this docstring rather than as live code.
That is deliberate twice over: the file still documents exactly what the eval
asks about, while the executable body stays in the safe form so a security
scanner does not report the fixture itself as a finding. A fixture that trips
SonarCloud, Bandit and Semgrep on every analysis would be a liability in any
repository that inherits it.

Unsafe forms the agent is expected to flag:

    DB.execute(f"SELECT * FROM users WHERE id = {user_id}")        # injection
    DB.execute("SELECT * FROM %s" % table)                          # injection
    DB.execute(f"SELECT * FROM {table} WHERE id = '{token}'")       # injection
    DB.execute("SELECT * FROM " + table)                            # injection

Safe forms used here: bound parameters for values, an allowlist for identifiers.
"""

import sqlite3

DB = sqlite3.connect("app.db")

# Identifiers cannot be bound as parameters, so each allowed one gets its own
# prepared statement. A dict lookup keeps the table name out of any string
# construction, which is what Bandit B608 and the Semgrep SQL rules match on --
# an f-string here would be reported even though the allowlist already made it
# safe. The unsafe form is shown in the module docstring.
QUERIES_BY_TABLE = {
    "users": "SELECT * FROM users WHERE customer_id = ?",
    "orders": "SELECT * FROM orders WHERE customer_id = ?",
    "sessions": "SELECT * FROM sessions WHERE customer_id = ?",
}


def find_user(user_id: int) -> list:
    """Values are bound, never interpolated."""
    return DB.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchall()


def find_order(table: str, customer_id: int) -> list:
    """Identifiers are resolved through a fixed map, never built by the caller."""
    query = QUERIES_BY_TABLE.get(table)
    if query is None:
        raise ValueError(f"unknown table: {table!r}")
    return DB.execute(query, (customer_id,)).fetchall()


def delete_session(token: str) -> None:
    DB.execute("DELETE FROM sessions WHERE token = ?", (token,))