# What must be true before Production

Ordered by what blocks what. Items marked **blocker** will fail review or
cannot be answered honestly on a form until they are done.

## 1. Account deletion — blocker, needs code

Play requires that an app which creates accounts lets a user delete that
account **from inside the app**, and also gives a **web URL** where someone
who has already uninstalled can request the same. Kistify has neither. The
Data safety form asks this question directly, so it cannot be submitted
truthfully today.

What it needs:
- An in-app "Delete my account" in Account, with re-authentication first.
- What happens to the user's groups has to be decided, because a group is
  shared property: a creator who leaves cannot silently take everyone's
  records with them. The workable shape is that deleting an account
  removes the user profile, their FCM tokens and their auth identity, and
  marks their group memberships as exited, while the group's own records
  (which other members depend on and which the audit log must keep) stay,
  with their name showing as a removed account. A creator with a live
  group has to delete or hand over that group first — and handing over
  needs a creator-transfer path, which does not exist yet either.
- `firestore.rules` currently has `allow delete: if false` on
  `users/{uid}`; that has to open for the owner.
- A page at `https://kistify.web.app/delete-account` describing the same,
  for people who no longer have the app.

## 2. Store listing

- App icon: `icon-512.png` ✅
- Feature graphic: `feature-graphic-1024x500.png` ✅
- Listing text: `listing-bn.md`, `listing-en.md` ✅
- **Screenshots: 2 minimum, 8 maximum, taken on a real phone.** Suggested
  four, in this order, because they tell the story: the group dashboard
  (money in / money out), a month's contribution list with an approved and
  a pending entry, the members screen showing roles, and the monthly
  matrix report. Portrait, at least 1080px on the short side.

## 3. App content declarations

- Privacy policy URL: `https://kistify.web.app/privacy` ✅ (live)
- Data safety: answers in `data-safety-and-rating.md` — blocked on item 1
- Content rating: answers in `data-safety-and-rating.md`
- Ads: none. Declare "No ads".
- Target audience: adults (18+). Nothing here is aimed at children.
- Government apps / financial features: not a financial-services app; it
  moves no money. Declare accordingly.

## 4. Build

- `versionCode` is `1` (`pubspec.yaml`: `version: 1.0.0+1`). Fine for the
  first upload; **every later upload must increase it**, or Play rejects
  the bundle. Worth wiring to the CI run number when that starts to bite.
- The CI job installs Flutter `stable` unpinned, so the `targetSdk` in the
  bundle is whatever that day's stable defaults to. Play states the
  required target API level when the bundle is uploaded — if it complains,
  the fix is a newer Flutter, not a manual `targetSdk` override.
- The `.aab` from the `play-store-bundle-aab-upload-only` artifact is the
  upload. The APK artifact is for phones and is not what Play takes.

## 5. Signing

- CI signs with the upload key. Play App Signing then re-signs with a key
  of its own, which means **a third SHA-1 appears after the first release**.
  Add it to the Firebase Android app for `com.veryfew.kistify` the same
  day, or Google sign-in breaks for everyone who installs from the store
  while working fine on every APK built here.

## 6. Testing track — the long pole

A personal Play Console account must run a closed test with **12 testers
who stay opted in for 14 continuous days** before Production opens. The
clock restarts if the tester count drops. Start this before the listing is
polished: the listing takes an evening, the 14 days do not compress.

## 7. After release

- Turn on App Check (Play Integrity) once there is a Play-signed build to
  attest — it was deferred for exactly this reason.
- Only then consider `Monetization.enabled`, which has its own list in
  `lib/config/monetization.dart`.
