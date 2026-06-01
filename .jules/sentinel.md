## Security Finding: Command Injection in CLI Providers

* **Vulnerability**: The `do-web-doc-resolver` used `subprocess.run` with unsanitized URLs for `docling` and `ocr` providers, leaving them vulnerable to command injection payloads.
* **Fix**: Implemented `is_shell_safe_url` in `utils.py` and updated the providers to check and block shell-dangerous characters in the URL string prior to calling `subprocess.run()`.
* **Testing**: Added `tests/test_shell_safety.py` to ensure defense-in-depth against malicious URLs, including validating safe characters (`&`, `;`) and rejecting invalid ones (`|`, `<`, `>`, etc).

## 2026-04-28 - Fail-closed SSRF Protection

**Vulnerability:** The `is_safe_url` helper used a fail-open approach where DNS resolution failures or empty results would allow the URL to pass validation.
**Learning:** Security validation functions must explicitly handle errors by denying access (fail-closed) rather than ignoring them.
**Prevention:** Always implement explicit exception handling in safety-critical code that defaults to `False` or `AccessDenied`.

## 2026-05-02 - Shell Arithmetic Injection in Validation Logic

**Vulnerability:** Shell arithmetic expansion `$((...))` with unvalidated variables derived from `SKILL.md` frontmatter allowed arbitrary command execution during skill validation.
**Learning:** Bash evaluates variables within arithmetic contexts (`$(( ))` and `(( ))`) as expressions. If these variables contain command substitution or other shell constructs, they are executed.
**Prevention:** Strictly validate that all variables used in shell arithmetic contexts are numeric (e.g., using `[[ "$var" =~ ^[0-9]+$ ]]`) before evaluation.

## 2026-05-03 - Shell Arithmetic Injection via Environment Variables

**Vulnerability:** Environment-overridable numeric variables used in `(( ))`, `$(( ))`, and `[[ $A -lt $B ]]` were vulnerable to command injection (e.g., `VAR='a[$(id)0]'`).
**Learning:** Bash evaluates operands in arithmetic contexts as expressions. If a variable contains an array index like `a[$(...)0]`, the code inside `$(...)` is executed during evaluation.
**Prevention:** Strictly validate that all variables used in Bash arithmetic contexts are numeric (e.g., using `[[ "$var" =~ ^[0-9]+$ ]]`) before they are evaluated.

## 2026-05-04 - Command Injection via Bash sed Substitution

**Vulnerability:** Unvalidated variables in Bash `sed` substitution commands, especially when the `e` (execute) flag is supported or delimiters are manipulated, can lead to command injection.
**Learning:** Variables read from external files (like `VERSION`) must be treated as untrusted input before being used as patterns or replacement strings in `sed` to prevent arbitrary code execution or file corruption.
**Prevention:** Enforce strict format validation (e.g., regex `^[0-9]+\.[0-9]+\.[0-9]+$`) for all external variables before passing them to `sed` or other shell commands.

## 2026-05-06 - Bash Arithmetic Injection via Associative Array Keys

**Vulnerability:** Associative array keys in Bash arithmetic expansion contexts (`$((MAP[$key]))`) were evaluated as expressions. If `$key` was derived from an untrusted source (like a cache file), it allowed arbitrary command execution.
**Learning:** Bash treats array indices in arithmetic contexts as expressions. Maliciously crafted keys containing `$(...)` or `a[$(...)0]` are executed during expansion.
**Prevention:** Strictly validate keys against a whitelist (e.g., `^(safe|conditional|dangerous|unknown)$`) before use in arithmetic contexts and use `jq -n --arg` for secure JSON serialization of commands.

## 2026-05-07 - Option Injection in Utility Scripts

**Vulnerability:** Use of `echo "$VAR"` and `grep "$VAR"` in utility scripts allowed variables derived from `SKILL.md` (e.g., categories or skill names) to be interpreted as command-line options if they started with a hyphen.
**Learning:** `echo` behavior is inconsistent when its first argument looks like a flag (e.g., `-e`). `grep` interprets patterns starting with `-` as options unless explicitly told not to.
**Prevention:** Always use `printf "%s\n" "$VAR"` instead of `echo` for printing variables. Use the `--` separator with `grep` and other commands to terminate option processing before passing variables.

## 2026-05-10 - Structural and Option Injection in Commit Tooling

**Vulnerability:** `scripts/ai-commit.sh` used `echo -e` to write commit messages to temporary files, allowing backslash escape sequences in agent-generated input to manipulate message structure. It also used `echo` for variable wrapping, susceptible to option injection.
**Learning:** `echo -e` interprets escapes like `\n` in the variable content itself, not just the format string. This can lead to structural injection when the output is written to a file or piped.
**Prevention:** Use `printf "%s\n"` for all variable output. Use literal newlines (`$'\n'`) for intentional line breaks in variables. Always implement `trap` cleanup for temporary files.

## 2026-05-11 - Command Substitution via Unquoted Heredocs and Option Injection in Utility Scripts

**Vulnerability:** `scripts/lib/research-engine.sh` used an unquoted heredoc (`<< EOF`) to generate research queries, allowing command substitution (e.g., `$(...)`) embedded in the `topic` variable to be executed. Multiple utility scripts also used `echo "$VAR"`, leading to option injection risks.

**Learning:** Unquoted heredocs in Bash are treated like double-quoted strings, performing expansion and substitution on their content. Using `echo` with untrusted variables allows those variables to be interpreted as command flags.

**Prevention:** Use `printf` or quoted heredocs (`<< 'EOF'`) when incorporating variables into multi-line output to prevent shell expansion. Replace all `echo "$VAR"` with `printf "%s\n" "$VAR"` to ensure variables are treated as literal data.

## 2026-05-14 - Structural and Option Injection in Utility Scripts

**Vulnerability:** `scripts/health-check.sh`, `scripts/self-fix-loop.sh`, and `scripts/discover-commands.sh` used `echo -e` or `echo` with untrusted variables, allowing structural injection (via newlines/ANSI escapes) and option injection (via leading hyphens).

**Learning:** `echo -e` behaves inconsistently across shells and interprets escape sequences within the variable content itself, not just the format string. This allows malicious input to spoof script output or manipulate logging. `echo` also interprets arguments starting with `-` as options.

**Prevention:** Always use `printf` with a literal format string (e.g., `printf "%s\n" "$VAR"`) to ensure variables are treated as literal data and cannot be interpreted as command options or escape sequences.

## 2026-05-15 - Option Injection in Library Scripts

**Vulnerability:** Shell scripts in `scripts/lib/` were vulnerable to option injection because they passed variables (like branch names or file paths) to commands like `git`, `mkdir`, `rm`, and `cat` without the `--` separator.

**Learning:** Even internal library functions are vulnerable if they handle variables that might be influenced by external input (e.g., branch names from git, or cached file names).

**Prevention:** Always use the `--` separator before positional arguments in shell commands to terminate option processing. Use `printf` instead of `echo`. Implement strict path validation (canonicalization with `realpath -m`, root/dangerous path rejection, and boundary checks) before recursive deletions. Use exact ref checks (`git rev-parse`) instead of partial string matching for branch verification.

## 2026-05-22 - Octal Interpretation Errors in Bash Arithmetic

**Vulnerability:** Arithmetic expansion in Bash ($(( ))) interprets numbers with leading zeros as octal, causing errors for values like '08' or '09'.
**Learning:** Logic for version comparison or numeric validation can crash if it handles version strings or numeric input with leading zeros without specifying the base.
**Prevention:** Use the 10# prefix (e.g., $((10#$var))) to force decimal interpretation in Bash arithmetic expansion when dealing with potentially padded numbers.

## 2026-05-24 - Python Command Injection via Shell Variable Interpolation

**Vulnerability:** Directly interpolating shell variables into `python3 -c` command strings in `scripts/check-plan-numbering.sh` and `scripts/validate-skills.sh` allowed for arbitrary Python code execution.
**Learning:** Shell variables expanded inside a Python command string are treated as part of the code. If a variable contains characters like `'`, it can break out of the string literal and execute arbitrary Python commands.
**Prevention:** Always pass shell variables as positional arguments to `python3 -c` and access them via `sys.argv`. This ensures the variables are treated as data rather than code.

## 2026-05-25 - GitHub Actions Expression Injection

**Vulnerability:** GitHub Actions workflows using `${{ ... }}` interpolation in `run:` or `script:` blocks were vulnerable to command injection if the interpolated variable was untrusted (e.g., `github.event.issue.title`).
**Learning:** GitHub Actions performs expression expansion before executing the shell command or script. If the result contains shell metacharacters or JavaScript code, it can lead to arbitrary code execution in the runner.
**Prevention:** Always use environment variables to pass untrusted data to `run:` blocks. In `actions/github-script`, use the `github` or `context` objects instead of `${{ ... }}`. Enforce a strict whitelist of safe contexts (env, steps, jobs, inputs, matrix, strategy, secrets, needs) and specific safe github properties (repository, actor, sha, workflow, run_id, run_number, event_name, job, token) in validation tooling. Controllable properties like `github.ref`, `github.head_ref`, and `github.base_ref` must be excluded.

## 2026-05-26 - Standardized AWK and Utility Hardening against Option Injection

**Vulnerability:** Utility scripts using `awk` or `wc` were vulnerable to option injection when processing filenames starting with a hyphen (e.g., `-v`, `-f`, `-l`).
**Learning:** For `awk`, the correct robust pattern to terminate option processing before the program string and filenames is `awk [options] -- 'program' [files]`. For `wc`, it is `wc [options] -- [files]`. Adding `--` *after* the program string in a piped or xargs context (e.g., `... | awk 'program' --`) can cause `awk` to treat `--` as a literal filename, leading to "file not found" errors and script failure.
**Prevention:** Always use the `--` separator before the first positional argument (the program string for `awk`, or the first filename for `wc`) in utility scripts to ensure subsequent arguments are treated as data, not options.

## 2026-06-01 - Widespread Option Injection in Utility Scripts

**Vulnerability:** Core utility scripts (chmod, readlink, head, tail, mv, grep) were vulnerable to option injection when handling hyphenated filenames.
**Learning:** Standard POSIX utilities interpret arguments starting with hyphens as options unless the -- delimiter is used. This can be exploited to crash scripts or change command behavior.
**Prevention:** Always use the -- separator before positional arguments in shell commands and prefer printf over echo for variable output.
