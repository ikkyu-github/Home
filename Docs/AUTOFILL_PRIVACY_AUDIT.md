# Autofill / Passkeys Privacy Audit Checklist

## What we do NOT collect

- No usernames, passwords, OTP codes, or any form field values.
- No passkey challenges, responses, credential IDs, or attestation payloads.
- No per-site credential metadata.
- No screenshots of pages or forms for Autofill-related features.

## What we MAY record (non-sensitive)

- Debug-only, best-effort `AutofillAvailability` snapshot:
  - `isEnabled`, `supportsPasswords`, `supportsPasskeys`, `lastCheckedAt`
- Debug-only counters for helper instrumentation:
  - count of detected login/signup forms (no domains, no field values)

## Private browsing guarantees

- No helper form observer is installed for private profile.
- No Autofill status is persisted to disk (in-memory cache only).

## Logging constraints

- Do not log domains or payloads.
- In release, any diagnostics must be aggregate-only or use `SiteKey` (eTLD+1) at most.
