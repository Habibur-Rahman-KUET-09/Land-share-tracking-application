# Kistify — security posture

What is actually in place, what is deliberately not, and what is waiting on
something else. Written to be checked against the code rather than believed.

Kistify is a Flutter client talking straight to Firebase. There is no
server of ours in the middle, so almost everything below is either a
Firestore/Storage security rule, a Firebase Auth setting, or a client-side
measure that is honest about being defence in depth rather than the wall.

## OWASP Top 10, item by item

### A01 Broken access control — the one that matters here

This is the whole game for a Firebase app, because the database is on the
public internet and the client is not trusted. Every control lives in
`firestore.rules` / `storage.rules`:

- A group's data is readable only by uids listed in that group's
  `memberIds`. Group isolation is enforced server-side, not by filtering in
  the UI.
- Roles live on each member's own document and are read back through
  `get()` in the rules, so a client cannot claim a role it does not have.
- Maker-checker on contributions: approving requires an approver role *and*
  that the caller is neither the submitter nor the member the entry belongs
  to. Not a UI convention — a rule.
- Role changes may not target the caller's own member document and may
  never grant `creator`. This closed a real hole: a creator could
  previously have demoted themselves through the API and left a group
  nobody could administer.
- Lottery results are `allow update: if false`. A rewritten winner would be
  indistinguishable from a real one, so the only correction is delete
  (creator) and redraw.
- The audit log is append-only, and the actor on a log entry must be the
  authenticated caller.
- Bulk import is restricted to creator/admin and must carry `importedAt`,
  which both marks the entries honestly and stops the branch being used to
  smuggle an ordinary entry past maker-checker.

**Known limitation.** Rules can `get()` a document they are given a path
to; they cannot count or query a collection. So "a group must have two
approvers before its sole approver may file an entry" is enforced in the
UI only. The consequence of bypassing it is a self-inflicted stuck entry,
not access to anyone else's data.

### A02 Cryptographic failures

All traffic is HTTPS to Google endpoints; there is no custom crypto and no
secret held by the client that is worth extracting. The Firebase API keys
in `firebase_options.dart` are identifiers, not credentials — every web
and Android client ships them, and they grant nothing on their own.

### A03 Injection

No SQL, no server-side templating, no `eval`. Firestore queries are
parameterised by construction. The spreadsheet importer parses cells into
typed values and rejects anything that is not a valid member/month/amount,
so a crafted file produces skipped rows, not writes.

### A04 Insecure design

Money moves through approval by a second person, cancellation instead of
deletion, and an audit log nobody can erase — the design assumes mistakes
and disputes rather than trying to prevent them by policy alone.
Single-manager mode deliberately removes the second pair of eyes; it is
opt-in, labelled, and recorded in the audit log when toggled.

### A05 Security misconfiguration

The main risk is shipping rules that were never published. `firestore.rules`
lives in this repository and must be pasted into the Firebase console after
any change — the app surfaces a readable `permission-denied` message rather
than failing silently, which is how this has been caught in practice.

Release builds no longer use the debug signing key. The upload keystore is
gitignored and reaches CI from a secret, and is deleted from the runner
after the build.

### A06 Vulnerable and outdated components

Dependencies are pinned in `pubspec.yaml` and resolved fresh in CI. There
is no automated vulnerability scan yet — `flutter pub outdated` run
periodically is the current answer.

### A07 Identification and authentication failures

- Email/password and Google only; phone OTP was removed.
- Password policy: 8+ characters, at least one letter and one digit, and
  not one of the obvious guesses. Length is what resists guessing;
  character-class thickets mostly produce `Password1!`.
- Sign-in locks out for a minute after five failed attempts **client-side**.
  This is explicitly not the real control — nothing stops an attacker
  calling the Identity Toolkit API directly, which is why Firebase's own
  server-side rate limiting is what actually holds.
- **No user enumeration**: a failed sign-in reports the same message
  whether the account exists or the password is wrong, and password reset
  reports success either way. A failed reset send is swallowed on purpose.
- Changing a password requires re-entering the current one, which also
  blocks account takeover from an unlocked phone.
- Google-only accounts are told their password lives with Google instead of
  being shown a form that cannot work.

**Not implemented, with reasons:**

- **MFA.** Firebase Auth supports SMS and TOTP second factors, both of
  which require upgrading the project to Identity Platform; SMS also costs
  money and we removed phone auth. Email-OTP as a second factor is not
  something Firebase offers at all. Hand-rolling one would mean storing and
  verifying our own one-time codes — a new attack surface in exchange for
  the appearance of MFA. Deferred deliberately; TOTP via Identity Platform
  is the route if it is wanted.
- **CAPTCHA on sign-in.** reCAPTCHA Enterprise for Firebase Auth needs the
  same Identity Platform upgrade.

### A08 Software and data integrity failures

CI builds from the repository and signs with a key held only as a secret.
Imported spreadsheet rows are marked `importedAt` so bulk-approved history
can never be mistaken for a receipt-checked approval.

### A09 Logging and monitoring failures

Every state change that touches money is written to the group's audit log
with actor, action, target and timestamp, readable by creator/admin and
deletable by nobody. What is missing is alerting: nothing watches for
anomalies. A Google Cloud **budget alert** is the one piece of monitoring
worth setting up immediately, since runaway cost is the realistic failure.

### A10 Server-side request forgery

Not applicable — the app makes no server-side requests to
attacker-influenced URLs. Cloud Functions only read Firestore and send FCM.

## The most valuable thing not yet done

**Firebase App Check.** It is what stops the project's API being driven by
anything other than the real app — the gap that remains once rules are
correct. It needs Play Integrity on Android, which can only be configured
once the app exists in Play Console, and reCAPTCHA Enterprise for the web
build. This is the first thing to do after the Play release, not before.

## Operational reminders

- Republish `firestore.rules` in the Firebase console after every change to
  it in this repository.
- After the first Play release, take the **Play App Signing** SHA-1 from
  Play Console and add it in Firebase, or Google sign-in will fail for
  every install from the store while working fine in a sideloaded APK.
- Keep the upload keystore backed up somewhere that is not this repository.
