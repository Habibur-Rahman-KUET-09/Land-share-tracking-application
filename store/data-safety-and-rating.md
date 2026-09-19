# Data safety + content rating answers

Answers below are what the code actually does, checked against
`lib/models/app_user.dart`, `lib/services/storage_service.dart` and
`pubspec.yaml`. If the app changes, change this file in the same commit —
a Data safety form that no longer matches the app is a policy violation,
not a paperwork slip.

## Data safety

**Does your app collect or share any of the required user data types?** Yes.
**Is all of the user data collected by your app encrypted in transit?** Yes
(everything goes to Firebase over TLS).
**Do you provide a way for users to request that their data be deleted?**
Yes. In-app: Account → "অ্যাকাউন্ট মুছে ফেলুন". On the web, for people who
have uninstalled: https://kistify.web.app/delete-account (the URL to give
Play for the deletion request link).

| Data type | Collected | Shared | Required | Purpose |
|---|---|---|---|---|
| Personal info → Name | Yes | No | Required | App functionality, Account management |
| Personal info → Email address | Yes | No | Required | App functionality, Account management |
| Personal info → Phone number | Yes | No | Optional | App functionality (members are found by phone or email when being invited) |
| Photos and videos → Photos | Yes | No | Optional | App functionality (receipt images attached to an entry) |
| Financial info → Other financial info | Yes | No | Required | App functionality (the contribution and payment amounts the app exists to record) |
| Device or other IDs | Yes | No | Optional | App functionality (Firebase Cloud Messaging token, for group notifications) |

Not collected, and the form should say so: location, contacts, calendar,
SMS, call logs, health, files other than the receipt images the user picks,
app activity analytics, crash logs, advertising ID. There is no analytics
or crash-reporting SDK in `pubspec.yaml` — only Auth, Firestore, Storage
and Messaging.

No data is sold. No data is shared with third parties. There are no ads
and no ad networks.

## Content rating (IARC questionnaire)

Category: **Utility, Productivity, Communication or Other**.

Every content question is answered No: no violence, no sexual content, no
profanity, no drugs, no user-to-user free-text communication beyond the
group records themselves, no location sharing, no purchases of digital
content (until billing ships — revisit then).

**The gambling question deserves care.** Answer No, and mean it: the
সমিতি/rotating-fund feature has no wager, no stake and no house. Every
member receives the pot exactly once per cycle and pays the same amount
either way; the draw only decides the order. Nothing of value is risked,
and the app moves no money at all.

Because a reviewer reads the listing before the app, the English listing
says "rotating fund" rather than "lottery". Keep it that way — describing
it as a lottery invites a gambling-policy review that the feature would
pass but that costs days.

Financial-services policy: the app is a ledger. It does not process
payments, hold funds, lend, or facilitate transfers, so the personal-loan
and payments declarations do not apply. The listing says this outright.
