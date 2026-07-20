# Security Reviewer Profile

A security-specific review profile launched with `harness-review --security`.
Based on the OWASP Top 10, it comprehensively checks authentication, authorization, secrets, and vulnerabilities in dependency packages.

## Role premise (authorized defensive review)

This profile is for reviewing **the harness plugin's own code, and the
code of your own project that the user has explicitly designated as a review target**,
from the standpoint of **authorized defensive code review**. Generating attack code,
assisting intrusion into real third-party systems, and probing unauthorized systems
for vulnerabilities are out of scope for this profile.
**Findings only describe "where the weakness is" and "how to fix it"; they do not
include runnable exploit payloads or attack PoCs.** This is audit-only behavior that
reports observations only.

Placed as the formal scope declaration for issue #172 (cases where the reviewer's
security review false-triggers the Anthropic-side cyber-safeguard).

> **Read-only constraint**: The reviewer operating under this profile uses
> Read / Grep / Glob / Bash (read-only commands only).
> It never executes Write / Edit / any write-capable Bash.

---

## Contract for fresh-context isolation and findings return (model-safeguard relaxation)

The Anthropic-side cyber-safeguard (Fable 5's automatic model switch) evaluates not
only the latest message but **the entire context the model reads** (conversation
history, memory, already-read files, git status). A security review is structurally
dense in security vocabulary, so the following is fixed as **relaxation measures**.
This is a relaxation, not a guarantee. **The guarantee is to make the calling session
Opus** (in Fable 5, once security findings return to the parent session it auto-switches
to Opus).

1. **Isolated execution**: The security review runs with `context: fork`
   (`skills/harness-review/SKILL.md` frontmatter) in an isolated context that does not
   inherit the parent conversation history. The reviewer subagent is **pinned to a
   non-Fable model** in `agents/reviewer.md` (default `claude-sonnet-4-6`) and does not
   inherit the parent model. These two points structurally reduce the total amount of
   security vocabulary the classifier reads.

2. **Neutral return of findings**: The result returned to the parent orchestrator is
   limited to **verdict (`APPROVE | REQUEST_CHANGES`) + counts + `file:line` references
   + a one-line remediation direction**. Attack payloads, exploit PoCs, and verbatim
   threat scenarios are not passed to the parent context
   (the `critical_issues[]` / `major_issues[]` of `review-result.v1` are expressed as
   `file:line` + a short remediation). Verbatim dumps are the main cause of flipping the
   parent session (under Fable).

3. **Model pin is a safeguard invariant**: Do not change `model:` in `agents/reviewer.md`
   to `inherit` or a Fable-family model. `scripts/ci/check-consistency.sh` verifies the
   presence of the non-Fable pin and this contract phrase.

---

## Security Review flow

### Step 1: Identify the scope

```bash
# Collect changed files (BASE_REF is inherited from the caller)
CHANGED_FILES="$(git diff --name-only --diff-filter=ACMR "${BASE_REF:-HEAD~1}")"
git diff "${BASE_REF:-HEAD~1}" -- ${CHANGED_FILES}
```

### Step 2: OWASP Top 10 check

Verify each of the following items against the **change diff** and **related files**.

#### A01: Broken Access Control

| Check item | How to verify |
|------------|---------------|
| Missing authorization check | Whether an authentication middleware is applied to route/endpoint definitions |
| Horizontal privilege escalation | Whether user-owned resources are filtered by `userId` etc. on fetch |
| Vertical privilege escalation | Whether role checks (admin/user/guest etc.) are properly implemented |
| IDOR | Whether IDs in URL parameters or request bodies are accepted without authorization |
| Directory traversal | Whether path operations containing `../` are sanitized |

**Detection patterns (verify with Grep)**:
```bash
# Candidate routes without authentication
grep -rn "app\.\(get\|post\|put\|delete\|patch\)" --include="*.ts" --include="*.js"
# DB fetch without userId
grep -rn "findById\|findOne\|select.*where" --include="*.ts"
```

#### A02: Cryptographic Failures

| Check item | How to verify |
|------------|---------------|
| Plaintext storage of sensitive data | Whether passwords, tokens, PII are stored in plaintext in DB/logs |
| Weak hash algorithm | Whether MD5 / SHA1 is used for password hashing |
| Insecure randomness | Whether `Math.random()` is used to generate auth tokens |
| TLS strength | Whether sensitive data is sent/received over HTTP (non-HTTPS) |
| Hardcoded keys | Whether crypto keys/IVs are embedded as constants |

**Detection patterns**:
```bash
grep -rn "md5\|sha1\|Math\.random\(\)" --include="*.ts" --include="*.js"
grep -rn "createHash.*md5\|createHash.*sha1" --include="*.ts"
grep -rn "http://" --include="*.ts" --include="*.js" --include="*.env*"
```

#### A03: Injection

| Check item | How to verify |
|------------|---------------|
| SQL injection | Whether user input is built into SQL via string concatenation |
| NoSQL injection | Whether `$where` or input values are used as operators in MongoDB etc. |
| Command injection | Whether user input is passed to `exec()` / `spawn()` |
| LDAP injection | Whether unsanitized input is used in LDAP queries |
| Template injection | Whether user input is passed directly to the template engine |

**Detection patterns**:
```bash
grep -rn "exec\|execSync\|spawn" --include="*.ts" --include="*.js"
grep -rn "\`SELECT\|\"SELECT\|'SELECT" --include="*.ts" --include="*.js"
grep -rn "\$where\|\$\[" --include="*.ts" --include="*.js"
```

#### A04: Insecure Design

| Check item | How to verify |
|------------|---------------|
| Missing rate limiting | Whether rate limiting is implemented on auth endpoints |
| TOCTOU race condition | Whether a state change between check and use can be exploited |
| Business logic flaw | Whether state transitions can be executed in an invalid order |

#### A05: Security Misconfiguration

| Check item | How to verify |
|------------|---------------|
| Default credentials | Whether default passwords/usernames are still in use as-is |
| Verbose error messages | Whether stack traces or internal info are returned to clients in production |
| Unnecessary features enabled | Whether debug endpoints/admin panels are enabled in production |
| HTTP security headers | Whether HSTS, CSP, X-Frame-Options etc. are set |
| CORS configuration | Whether `Access-Control-Allow-Origin: *` is set in production |

**Detection patterns**:
```bash
grep -rn "cors.*origin.*\*\|allowedOrigins.*\*" --include="*.ts" --include="*.js"
grep -rn "debug.*true\|NODE_ENV.*development" --include="*.ts"
grep -rn "console\.log.*password\|console\.log.*token\|console\.log.*secret" --include="*.ts"
```

#### A06: Vulnerable and Outdated Components

| Check item | How to verify |
|------------|---------------|
| Packages with known vulnerabilities | Whether `package.json` dependencies include versions with reported CVEs |
| `npm audit` results | Whether high / critical vulnerabilities are left unaddressed |
| Lockfile consistency | Whether `package-lock.json` / `yarn.lock` is up to date |

**Verification commands**:
```bash
# Check package.json dependencies (read-only)
cat package.json | grep -E '"dependencies"|"devDependencies"' -A 50 | head -60
# Check for the existence of lockfiles
ls -la package-lock.json yarn.lock pnpm-lock.yaml 2>/dev/null
```

#### A07: Identification and Authentication Failures

| Check item | How to verify |
|------------|---------------|
| Brute-force protection | Whether login attempt limits / account lockout are implemented |
| Weak password policy | Whether minimum length / complexity requirements are set |
| Session fixation | Whether the session ID is regenerated after login |
| Session expiry | Whether long-lived sessions/tokens expire appropriately |
| JWT verification | Whether `alg: none` or signatures with weak keys are accepted |

**Detection patterns**:
```bash
grep -rn "jwt\.verify\|jwt\.sign" --include="*.ts" --include="*.js"
grep -rn "expiresIn.*\|expire.*" --include="*.ts"
grep -rn "algorithm.*none\|alg.*none" --include="*.ts" --include="*.js"
```

#### A08: Software and Data Integrity Failures

| Check item | How to verify |
|------------|---------------|
| Code execution from untrusted sources | Whether scripts are dynamically loaded from external CDNs / URLs |
| Deserialization | Whether untrusted data is passed directly to `eval()` / `Function()` |
| CI/CD pipeline protection | Whether build scripts execute external input without validation |

**Detection patterns**:
```bash
grep -rn "eval(\|new Function(" --include="*.ts" --include="*.js"
grep -rn "require(.*\$\|import(.*\$" --include="*.ts" --include="*.js"
```

#### A09: Security Logging and Monitoring Failures

| Check item | How to verify |
|------------|---------------|
| Logging of auth failures | Whether login failures / authorization errors are recorded |
| Logging of sensitive data | Whether passwords / tokens / PII are included in logs |
| Log injection | Whether user input is written directly to logs (CRLF injection) |

#### A10: Server-Side Request Forgery (SSRF)

| Check item | How to verify |
|------------|---------------|
| Requests to user-specified URLs | Whether access to the internal network is possible via user-input URLs |
| URL validation | Whether an allowlist of domains or IP filtering is implemented |
| Redirect following | Whether the request library follows redirects to internal addresses |

**Detection patterns**:
```bash
grep -rn "fetch(\|axios\.\|got(\|request(" --include="*.ts" --include="*.js"
```

---

## Authentication / Authorization review points

### Authentication flow

```
1. Input validation → Are there type/length/format checks
2. Auth processing → Is there timing-attack protection (constantTimeCompare etc.)
3. Token issuance → Is there sufficient entropy (crypto.randomBytes etc.)
4. Token storage → httpOnly + Secure + SameSite Cookie, or LocalStorage
5. Token verification → Are signature/expiry/revocation checks complete
6. Logout → Is server-side token invalidation implemented
```

### Authorization flow

```
1. Is the required role stated explicitly per endpoint
2. Is it checked in both the middleware and the route handler (defense in depth)
3. Does it rely only on frontend hiding (backend enforcement required)
4. Is resource ownership verification missing
```

---

## Handling of secrets

### Hardcoding detection

```bash
# API key / secret-like patterns
grep -rn "api[_-]key\s*=\s*['\"][^'\"]\|secret\s*=\s*['\"][^'\"]" \
  --include="*.ts" --include="*.js" --include="*.sh"

# AWS / GCP / Azure credentials
grep -rn "AKIA\|sk-[a-zA-Z0-9]\{20\}\|AIza" --include="*.ts" --include="*.js"

# Hardcoded JWT signing key
grep -rn "jwt.*secret.*=\s*['\"][^'\"]\{8,\}" --include="*.ts" --include="*.js"

# Committing a .env file
git diff "${BASE_REF:-HEAD~1}" -- .env .env.local .env.production
```

### Proper use of environment variables

| Good pattern | Bad pattern |
|--------------|-------------|
| `process.env.DATABASE_URL` | `"postgresql://user:pass@localhost/db"` |
| `process.env.JWT_SECRET` | `const JWT_SECRET = "my-super-secret"` |
| `process.env.API_KEY` | `const API_KEY = "sk-abc123..."` |

### Management of .env files

- Whether `.env.example` contains dummy values
- Whether `.env` / `.env.local` is included in `.gitignore`
- Whether production secrets are committed to `.env.production`

```bash
# Check .gitignore
grep -n "\.env" .gitignore 2>/dev/null
# Check whether .env files are included in the repository
git diff "${BASE_REF:-HEAD~1}" --name-only | grep "\.env"
```

---

## Known-vulnerability check for dependency packages

### package.json review procedure

1. Read the changed `package.json`
2. Identify newly added / version-bumped packages
3. Cross-checking against known CVE databases (NVD, Snyk, GitHub Advisory) is recommended

```bash
# Check the changed packages
git diff "${BASE_REF:-HEAD~1}" -- package.json package-lock.json

# Check current dependency versions
cat package.json | python3 -c "import json,sys; d=json.load(sys.stdin); [print(k,v) for d2 in [d.get('dependencies',{}),d.get('devDependencies',{})] for k,v in d2.items()]" 2>/dev/null
```

### High-risk package categories

| Category | Points of caution |
|----------|-------------------|
| Auth libraries | passport, jsonwebtoken, bcrypt — many version-dependent vulnerabilities |
| HTTP clients | axios, node-fetch, got — check the default SSRF-protection settings |
| Template engines | handlebars, ejs, pug — past cases of RCE vulnerabilities |
| XML parsers | xml2js, fast-xml-parser — beware of XXE attacks |
| Serialization | serialize-javascript, node-serialize — RCE risk |
| Image processing | sharp, imagemagick — buffer-overflow-class vulnerabilities |

---

## Security Review output format

It uses the same JSON schema as a normal Code Review, but sets `reviewer_profile: "security"`.

```json
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES",
  "reviewer_profile": "security",
  "critical_issues": [
    {
      "severity": "critical",
      "category": "Security",
      "owasp": "A03:2021 - Injection",
      "location": "src/api/users.ts:42",
      "issue": "User input is concatenated directly into the SQL string",
      "suggestion": "Use a prepared statement or an ORM",
      "cwe": "CWE-89"
    }
  ],
  "major_issues": [],
  "observations": [],
  "recommendations": []
}
```

### Security-specific fields

| Field | Description |
|-------|-------------|
| `owasp` | The applicable OWASP Top 10 category (e.g., `A01:2021 - Broken Access Control`) |
| `cwe` | The applicable CWE number (e.g., `CWE-89`) |
| `cvss_estimate` | Rough CVSS score (Critical: 9.0+, High: 7.0-8.9, Medium: 4.0-6.9) |

### Verdict criteria (Security mode)

Security mode applies stricter criteria than usual.

| Severity | Definition | verdict |
|----------|------------|---------|
| **critical** | RCE, auth bypass, direct exposure of sensitive data, SQLi/CMDi | REQUEST_CHANGES on even one |
| **major** | Insufficient authorization check, hardcoded secrets, weak cryptography | REQUEST_CHANGES on even one |
| **minor** | Missing security headers, excessive error info, minor misconfiguration | APPROVE (with a fix recommendation attached) |
| **recommendation** | Suggestions for security best practices | APPROVE |
