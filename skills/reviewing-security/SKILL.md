---
name: reviewing-security
description: Optional review skill — invoke when /lean-spec:submit-review is called with `security` in $ARGUMENTS. Audits the diff for OWASP-relevant vulnerabilities, secret leakage, and unsafe data handling.
---

## When to Invoke

Invoke ONLY when the Reviewer subagent receives `security` in its dispatch payload's extras list. Owned by the Reviewer subagent during the `reviewing` phase. Never invoked by default — security review is opt-in via:

```
/lean-spec:submit-review <slug> security
```

## What to Audit

Scope is the **diff under review**, not the whole project. Don't propose security findings for code the spec didn't touch.

### Injection (OWASP A03)

- **SQL injection**: any string-concatenated SQL must use parameterised queries instead. Look for `` `${userInput}` `` inside SQL/Cypher/MongoDB query strings.
- **Command injection**: `child_process.exec` / `shell=true` / `os.system` with user input. Replace with array-form `spawn` or escaped quoting.
- **Path injection**: user input flowing into `fs.readFile`, `path.join`, or filesystem APIs without `path.normalize` + allowlist check.
- **HTML/JS injection (XSS)**: `dangerouslySetInnerHTML`, `v-html`, `innerHTML =`, `document.write` with non-static input. React's default escaping protects most cases — flag only when raw HTML is asserted.

### Auth & access control (OWASP A01, A07)

- Missing auth check before sensitive route handler / server action.
- Authorisation inferred from client-side gate only (e.g. hidden button) without server-side enforcement.
- Long-lived tokens stored in `localStorage` (XSS-readable) when `httpOnly` cookie is the appropriate choice.
- Session fixation: post-auth state not regenerated.

### Secret hygiene (OWASP A02)

- Hardcoded API keys, tokens, JWT secrets, DB passwords, AWS access keys in committed files.
- Secrets read from `process.env` and then logged or returned in error messages.
- `.env*` files in the diff (should be gitignored).

### Data exposure (OWASP A02, A04)

- Server response leaking PII, password hashes, or internal IDs that the client doesn't need.
- Stack traces / SQL errors returned verbatim to the client in production code paths.
- Verbose logging of request bodies containing credentials or tokens.

### Cross-origin / CSRF (OWASP A05)

- State-mutating endpoints accepting `GET`.
- CORS `Access-Control-Allow-Origin: *` paired with credentials.
- Missing CSRF token on form-encoded POSTs in non-SPA contexts.

### Dependency risk

- Newly-added direct dependencies in `package.json` / `requirements.txt` / `go.mod` — note them so the user can confirm provenance. Don't run vulnerability scanners; that's user-configured tooling.

## What to Skip

- Theoretical vulnerabilities not reachable from the actual diff
- Hardening recommendations beyond OWASP top-10 lite (e.g. defence-in-depth nice-to-haves)
- Anything requiring runtime fuzzing, pen-testing, or external-service inspection
- Compliance frameworks (SOC2, HIPAA, PCI) — out of scope for v1

## Output

Append findings to `review.md` under a `## Security Review` heading. Group by severity:

```markdown
## Security Review

### Critical
- `path/to/file.ts:42` — Description. Why it's exploitable. Specific fix.

### Important
- ...

### Minor
- ...

### Notes
- Dependencies added: `package@version` (verify provenance)
- N/A items: <list categories audited but no findings, e.g. "no SQL queries in diff", "no auth surface touched">
```

If zero findings: write `**No security findings.**` under the heading. Don't omit the heading — its presence proves the audit ran.

## Verdict contribution

- Critical → reviewer's overall verdict becomes `NEEDS_FIXES` or `BLOCKED` (block if exploitable in production).
- Important → contributes to `NEEDS_FIXES` if other lenses also raise concerns; otherwise note in summary.
- Minor / Notes → never block approval on their own.
