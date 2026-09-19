# What must be true before Production

Ordered by what blocks what. Items marked **blocker** will fail review or
cannot be answered honestly on a form until they are done.

## 1. Account deletion — done

Play requires that an app which creates accounts lets a user delete that
account from inside the app, and gives a web URL for someone who has
already uninstalled. Both now exist:

- In-app: Account → "অ্যাকাউন্ট মুছে ফেলুন", after re-authentication.
- Web: `https://kistify.web.app/delete-account`, linked from the privacy
  policy.

The deletion itself runs as a callable Cloud Function, because it has to
delete a Firebase Auth user — something no client may do to itself here.
Group records survive, since they belong to everyone in the group; a
creator who still shares a group must hand it over (Group management →
"Creator হস্তান্তর") or delete it first, and the app names the groups in
the way.

Answer the Data safety question "Do you provide a way for users to
request that their data be deleted?" as **Yes**.

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
