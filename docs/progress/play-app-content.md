# Play Console — App content answers

Every declaration Play requires before a release can go to any track, with the
answer for this app and the reason for it. Checked against the code and against
the v1.5 privacy policy on 2026-08-12, so a reviewer comparing the three finds
them saying the same thing.

**These are declarations you sign.** The reasoning is here so you can satisfy
yourself each one is true, rather than take it on trust.

---

## Privacy policy

```
https://meribiodata.web.app
```

Live at v1.5. It names both "Pak Marriage Biodata Maker" and the package
`safarnamastudios.meribiodata.app`, so a reviewer comparing the listing to the
policy sees one app rather than two.

## App access

**All functionality is available without special access.**

There is no login, no account, no email verification, no invite code. A reviewer
can install and reach every screen.

## Ads

**Yes, my app contains ads.**

Banner on home and the editor, an interstitial on create, and a rewarded ad that
unlocks a decorative template. Premium removes them.

## Content rating

Category: **Utility, Productivity, Communication, or Other**.

| Question | Answer |
|---|---|
| Violence, sexual content, profanity, drugs, gambling | No to all |
| Do users interact or exchange content in the app? | **No** — there is no in-app messaging, no feed, no profiles. Sharing hands the file to the phone's share sheet; the app has no channel between users. |
| Does the app share the user's current location with other users? | No — it holds no location permission at all |
| Does the app let users buy digital goods? | **Yes** — Premium |

Expected outcome: **Everyone / PEGI 3**.

## Target audience and content

**18 and over only.** Not designed for children.

Arranging a marriage is an adult activity, the policy says the same in §8, and
selecting any under-18 band pulls the app into the Families programme with
requirements it has no reason to meet.

A biodata is often prepared by a parent for an adult son or daughter. That is
still an adult using the app.

## News apps · COVID-19 contact tracing · Government apps · Financial features · Health

**No** to all.

Premium is an in-app purchase, not a "financial feature" — that category means
lending, banking, or crypto.

## Advertising ID

**Yes, my app uses advertising ID.** Purpose: **Advertising or marketing**.

`com.google.android.gms.permission.AD_ID` is present in the release bundle,
added by the Mobile Ads SDK. Declaring otherwise while shipping that permission
is a mismatch Play checks automatically.

---

## Data safety

### Does your app collect or share any of the required user data types?

**Yes** — not because of anything this app does with a biodata, but because the
Google Mobile Ads SDK collects data on every app that carries it. Third-party
SDKs count as your collection, and forgetting that is the most common reason
this form gets rejected.

### What to declare

All four come from the Mobile Ads SDK, per Google's own disclosure page for it.
For every one: **collected and shared**, **encrypted in transit (TLS)**.

| Data type | Purposes |
|---|---|
| **Location → Approximate location** | Advertising or marketing |
| **App activity → App interactions** | Advertising, analytics, fraud prevention |
| **App info and performance → Diagnostics** | Analytics, performance |
| **Device or other IDs** | Advertising, analytics, fraud prevention |

Approximate location is there because the SDK derives a general location from the
IP address. The app itself holds no location permission and never asks for one.

### Required, or can users choose?

**Users can choose** — for all four.

Google's generic guidance for the SDK says "required", because in most apps the
SDK runs unconditionally. In this app it does not. `ConsentGate` requests UMP
consent *before* the ads SDK is initialised, and on a decline the SDK is never
initialised and no ad is ever requested, so nothing is collected. Every failure
path lands on "no ads" as well.

That is a real difference in the user's favour and the honest answer.

### Deletion

**No**, the app does not provide a way to request data deletion, and there is
nothing for it to delete: no account exists and no server holds anything. The
advertising ID is resettable by the user in Android's own settings, which the
policy points to.

### What is deliberately NOT declared, and why

**The biodata itself** — names, dates of birth, zaat/biradari, maslak, phone
numbers, addresses, family details, photographs.

> "User data accessed by your app that is only processed locally on the user's
> device and not sent off device does not need to be disclosed."

There is no server to send it to. The NFR-1 CI guard fails the build if a fourth
network user is ever added.

**Google Drive backup**, which does leave the device, is exempt on *two*
independent grounds — either alone would be enough:

1. **End-to-end encrypted.** The `.mbd` file is sealed with AES-256-GCM under an
   Argon2id key derived from a password only the user knows, on the phone,
   before upload. Play exempts data "encrypted so it's unreadable by developers
   or intermediaries" — that includes us and it includes Google.
2. **User-directed transfer to their own account.** The user switches it on, it
   goes to their own Drive under Drive's terms, and the app holds only the
   `drive.file` scope so it can see the single file it created and nothing else.

**Photographs** — stored in app-private storage with location and timestamp
metadata stripped before saving, and never uploaded except inside the encrypted
backup above.

**Purchases** — handled entirely by Google Play. The app is told whether this
device has an active entitlement and nothing else; it never sees a card, a bank
detail or a billing address, and is not capable of receiving them.

---

## Before you submit

- [ ] App name reads **Pak Marriage Biodata Maker**, not MeriBiodata
- [ ] Privacy policy URL points at the live v1.5
- [ ] The Data safety answers and the policy agree — they were written together
- [ ] The bundle you upload passed `tool/verify_release.py`

## Sources

- [Data safety section — Play Console Help](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Google Play data disclosure for the Mobile Ads SDK](https://developers.google.com/admob/android/privacy/play-data-disclosure)
