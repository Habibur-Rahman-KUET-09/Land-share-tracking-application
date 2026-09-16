# Kistify (জমি কিস্তি ট্র্যাকার)

বন্ধুরা মিলে যৌথভাবে কিস্তিতে কেনা জমির মাসিক কালেকশন ও বিল্ডারকে জমা
ট্র্যাক করার অ্যাপ — FRD অনুযায়ী তৈরি। Flutter + Firebase (Auth, Firestore,
Storage, Cloud Messaging, Cloud Functions)।

## মূল ফিচার

- **User & Group Management** — ফোন নম্বর, ইমেইল, বা Google দিয়ে
  লগইন/রেজিস্ট্রেশন; একটি "Land Group" এ চারটি ভূমিকা:
  - **Creator** — পুরো গ্রুপ ম্যানেজমেন্ট (প্ল্যান এডিট, সদস্য
    যোগ/রোল পরিবর্তন, গ্রুপ ডিলিট) + বাকি সব রোলের ক্ষমতা।
  - **Admin** — এন্ট্রি অনুমোদন/বাতিল করা, রিপোর্ট ডাউনলোড, অ্যাক্টিভিটি লগ।
  - **Collector** — এন্ট্রি অনুমোদন/প্রত্যাখ্যান, বিল্ডারকে জমা দেওয়া।
  - **Member** — নিজের এন্ট্রি জমা দেওয়া (এন্ট্রির status সবাই দেখতে পারে)।
- **Installment Plan Setup** — মোট জমির মূল্য, মোট কিস্তি সংখ্যা, প্রতি
  মাসে বিল্ডারকে কত দিতে হবে, due date, এবং কন্ট্রিবিউশন সমান/আলাদা কিনা —
  সব পরিবর্তনযোগ্য, প্রতিটি পরিবর্তনের history থাকে।
- **Monthly Contribution Collection** — Member নিজেই "Paid" এন্ট্রি দেয়
  (রিসিট ছবি ঐচ্ছিক), অন্য কোনো Admin/Collector সেটা Approve/Reject করে
  (**Maker-Checker** — কেউ নিজের এন্ট্রি নিজে অনুমোদন করতে পারবে না); একটি
  অনুমোদিত এন্ট্রি পরে Admin/Creator বাতিল (cancel) করতে পারে।
- **Builder Payment Tracking** — Collector/Creator বিল্ডারকে কত টাকা কবে
  জমা দিলো তার লেজার (রিসিট এখানেও ঐচ্ছিক), সংগৃহীত বনাম জমাকৃতের হিসাব।
- **Dashboard, Reports (PDF/Excel), Transparency ledger, Audit log,
  Notifications** — বাকিটা `lib/screens/` এর প্রতিটি ফোল্ডার FRD এর একটা
  সেকশনের সাথে মেলে (নিচের "প্রজেক্ট গঠন" দেখুন)।

## ⚠️ Firebase setup — এটা ছাড়া অ্যাপ চলবে না

এই রিপোজিটরিতে **কোনো real Firebase প্রজেক্ট কানেক্ট করা নেই** —
`lib/firebase_options.dart`, `android/app/google-services.json` সব
placeholder ভ্যালু দিয়ে ভরা (কোড কম্পাইল হবে, কিন্তু কোনো real
Auth/Firestore/Storage/Messaging কল কাজ করবে না)। এটা তৈরি করতে আপনার
নিজের Google account লাগবে — তাই এই ধাপটা নিজে করতে হবে (মাত্র কয়েক
মিনিটের কাজ):

1. **Firebase প্রজেক্ট তৈরি করুন**: https://console.firebase.google.com এ
   গিয়ে "Add project" — নাম যা খুশি দিন।
2. **প্রজেক্টে এই সার্ভিসগুলো চালু করুন** (Console থেকে):
   - **Authentication** → Sign-in method → **Phone**, **Email/Password**,
     এবং **Google** তিনটাই enable করুন।
   - **Firestore Database** → Create database (production mode)।
   - **Storage** → Get started।
   - **Cloud Messaging** — এমনিতেই চালু থাকে, আলাদা করে কিছু করতে হবে না।
3. **CLI টুল ইনস্টল করুন** (একবারই):
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```
4. **এই রিপোর অ্যাপ Firebase এর সাথে কানেক্ট করুন**:
   ```bash
   flutterfire configure
   ```
   এটা `lib/firebase_options.dart` আসল ভ্যালু দিয়ে ওভাররাইট করে দেবে, এবং
   Android/iOS এর জন্য `google-services.json`/`GoogleService-Info.plist`
   ডাউনলোড করে সঠিক জায়গায় বসিয়ে দেবে। যে প্রজেক্ট বানিয়েছেন সেটা সিলেক্ট
   করুন, platform হিসেবে অন্তত Android বেছে নিন (FRD: "Android প্রথমে")।
5. **Firestore/Storage security rules ডিপ্লয় করুন** (`firestore.rules`,
   `storage.rules` এই রিপোতে আগে থেকেই লেখা আছে) — **এই ধাপটা ছাড়া লগইন
   করলেও অ্যাপ কিছু দেখাবে না/আটকে থাকবে**, কারণ Firestore এর ডিফল্ট rules
   সব read/write আটকে দেয়:
   ```bash
   firebase use --add   # আপনার প্রজেক্ট সিলেক্ট করুন
   firebase deploy --only firestore:rules,storage
   ```
   `firebase login` করতে না পারলে (CLI অ্যাক্সেস না থাকলে) Console থেকেও
   করা যায়: **Firestore Database → Rules** ট্যাবে গিয়ে এই রিপোর
   `firestore.rules` ফাইলের পুরো কন্টেন্ট paste করে **Publish** চাপুন
   (Storage এর জন্য একইভাবে **Storage → Rules** এ `storage.rules`)।
6. **Google Sign-In চালু করতে SHA-1 ফিঙ্গারপ্রিন্ট যোগ করুন**: এই রিপোতে
   একটা স্থায়ী debug keystore কমিট করা আছে (`android/app/debug.keystore`)
   যেটা দিয়ে লোকাল ও CI দুই জায়গাতেই build সাইন হয়, তাই একবার যোগ করলেই
   চলবে —
   ```bash
   keytool -list -v -keystore android/app/debug.keystore -storepass android -alias androiddebugkey
   ```
   এর SHA1 লাইনটা কপি করে Firebase Console → **Project settings** → **Your
   apps** → Android app (`com.landshare.land_installment_tracker`) →
   **Add fingerprint** এ পেস্ট করুন। (এই রিপোর জন্য সেই ফিঙ্গারপ্রিন্ট:
   `11:F5:BF:CF:B2:92:32:11:12:CE:B2:BA:F4:90:84:20:AF:DA:EE:97`)
7. **(ঐচ্ছিক কিন্তু recommended) Notification Cloud Functions ডিপ্লয় করুন**
   (`functions/` — due-date reminder, missed-payment alert, pending-approval
   push সব এখানে):
   ```bash
   cd functions && npm install && cd ..
   firebase deploy --only functions
   ```
   স্কেজুলড রিমাইন্ডারের (`dailyReminders`) জন্য প্রজেক্ট **Blaze
   (pay-as-you-go) প্ল্যানে** থাকতে হবে (Firebase console থেকে আপগ্রেড
   করুন) — এটা ছাড়া শুধু `onContributionCreated` (approval push) কাজ
   করবে, বাকি reminder গুলো না।
8. এখন `flutter run` চালালেই আসল Firebase এর সাথে কাজ করবে।

## প্রজেক্ট গঠন

```
lib/
  models/        Firestore ডকুমেন্টের Dart ক্লাস
  services/       Firestore/Auth/Storage/Messaging-এর সাথে সব I/O
  providers/      অ্যাপ-ওয়াইড state (auth session, ভাষা)
  l10n/           বাংলা/English ডিকশনারি (see providers/locale_provider.dart)
  screens/
    auth/         লগইন/রেজিস্ট্রেশন (ফোন OTP + ইমেইল)
    home/         গ্রুপ তালিকা
    group/        গ্রুপ তৈরি, সদস্য ম্যানেজমেন্ট, প্ল্যান এডিট
    contribution/ কিস্তি এন্ট্রি + Maker-Checker অনুমোদন
    builder_payment/  বিল্ডারকে জমার এন্ট্রি
    dashboard/    গ্রুপ সামারি ও প্রগ্রেস
    reports/      PDF/Excel এক্সপোর্ট, ব্যক্তিগত হিস্ট্রি
    transparency/ সব সদস্যের সম্মিলিত হিসাব (read-only)
    audit/        অ্যাক্টিভিটি লগ
functions/        Cloud Functions (নোটিফিকেশন) — আলাদা Node.js প্রজেক্ট
firestore.rules, storage.rules, firebase.json   Firebase কনফিগারেশন
```

## এই রাউন্ডে যেসব সিদ্ধান্ত/সরলীকরণ করা হয়েছে

- **"Invite" মানে phone/email দিয়ে খোঁজা**, deferred invite-link সিস্টেম
  নয় — যাকে যোগ করতে চান তাকে আগে অ্যাপে সাইন আপ করে থাকতে হবে। এটা FRD
  এর "Phone number দিয়ে" অংশ পূরণ করে, কিন্তু "Invite link" অংশটা সরল করা
  হয়েছে।
- **State management**: Provider + Firestore `StreamBuilder` সরাসরি — আলাদা
  কোনো ভারী state-management লেয়ার (Bloc/Riverpod) ব্যবহার করা হয়নি,
  যেহেতু Firestore streams নিজেই reactive।
- **বাংলা/English টগল**: build-time `flutter gen-l10n` কোডজেন না ব্যবহার
  করে একটা হালকা ডিকশনারি ক্লাস (`lib/l10n/app_strings.dart`) দিয়ে করা
  হয়েছে — মূল স্ক্রিন/লেবেলগুলো কভার করে, প্রতিটা ছোট tooltip নয়।
- **iOS**: `flutter create` এর ডিফল্ট iOS ফোল্ডার আছে, কিন্তু Firebase iOS
  কনফিগারেশন এখনো ওয়্যার করা হয়নি (FRD: "Android প্রথমে, পরে দরকার হলে
  iOS") — `flutterfire configure` এ iOS platform যোগ করলে সেটাও ঠিক হয়ে
  যাবে।

## টেস্ট

```bash
flutter analyze
flutter test
```

`test/widget_test.dart` এ pure-Dart লজিক (currency formatting, due-amount
calculation) টেস্ট করা আছে — পুরো widget tree pump করা হয়নি যেহেতু সেটা
আসল Firebase.initializeApp() কল করবে placeholder options দিয়ে।
Firestore-নির্ভর সার্ভিস লজিক (approve/reject Maker-Checker guard ইত্যাদি)
আসল প্রজেক্ট কানেক্ট হওয়ার পর Firebase emulator suite দিয়ে টেস্ট করা
ভালো হবে (`firebase emulators:start`)।

## CI

`.github/workflows/build-apk.yml` প্রতি push এ `main` ব্র্যাঞ্চে analyze +
test + release APK build চালায় (placeholder Firebase config দিয়েই কম্পাইল
হয়, artifact হিসেবে APK আপলোড হয় — কিন্তু আসল Firebase কানেক্ট করার আগে
সেই APK-তে লগইন/ডেটা সেভ কিছুই কাজ করবে না)।
