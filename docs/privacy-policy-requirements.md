# What the privacy policy has to say, and why

This is the working document behind `docs/privacy/index.html`. It exists separately because the
policy itself is written for a family in Lahore, not for a lawyer or an engineer — so the reasoning
lives here and the plain words live there.

It also doubles as the checklist for the **Play Data Safety** form, which must agree with the policy
line for line. A mismatch between the two is one of the more common reasons a submission is rejected.

## The one-sentence version

MeriBiodata has no account, no server and no analytics. Everything a user types stays on their
phone. Exactly two things reach the internet, both of them optional and both disclosed by name.

## Required sections

### 1. Who this is and how to reach them

Play requires a named developer and a working contact. Safarnama Studios, plus an email that is
monitored. **Open:** the contact address is a placeholder in the page today — see "Before publishing"
below.

### 2. What is collected — nothing, and say so first

The single most important sentence in the document, and it belongs at the top rather than buried
under headings. Every biodata field, every photo, every schema change is written to an encrypted
database in the app's private storage and read back by the app alone. There is no upload path in
the code: `INTERNET` is declared for two callers only, and CI fails the build if a third appears.

State plainly that this includes the sensitive categories the app deliberately collects — names,
dates of birth, caste/biradari, maslak, income, addresses, phone numbers, photographs. A policy that
says "we collect nothing" without naming what it is not collecting reads as boilerplate.

### 3. The two exceptions, named

**Google AdMob.** The only third-party SDK in the app. It requests ads over the network and, subject
to consent, may use the device's advertising ID and coarse device data for ad selection and
measurement. Must include:

- that consent is asked for through Google's UMP flow before the ads SDK starts, not after;
- a link to Google's own privacy policy, because that is where the actual data handling is
  described;
- how to reset or delete the advertising ID in Android settings;
- that refusing consent leaves the app fully usable — there is no paywall behind the ads.

**The Matchmaker Pro waitlist.** Opens a form in the user's own browser. If — and only if — they
choose to submit it, the name, WhatsApp number and city they type go to the form provider. The app
itself never posts anything and never pre-fills the form from stored data. Must name the provider
and link to its policy.

### 4. What happens when the user shares an export

Worth its own section, because it is where users' intuitions are wrong. Once a PDF or image is sent
to WhatsApp, it is out of the app's hands and travels under WhatsApp's terms. The policy should
point at the Wide-sharing mode as the mitigation and be honest that the app cannot recall a file.

### 5. Photographs

- Stored in the app's private storage, in a directory the FileProvider cannot grant to other apps.
- **Location and camera metadata are removed before the photo is saved.** Say this explicitly and
  say why: a photo taken at home carries the coordinates of that home.
- Included in an export only when the user switches it on for that export, and the switch resets
  every time the sharing mode changes.
- Never uploaded.

### 6. Backups

The `.mbd` file is encrypted with a password only the user knows, derived with Argon2id. Nobody —
including us — can open it without that password, and there is no recovery. Where the user puts the
file afterwards (a cloud drive, a chat to themselves) is their choice and that provider's policy
then applies.

### 7. Permissions, and the ones deliberately not requested

Listing what is *not* asked for is more reassuring than listing what is:

| Permission | Status |
|---|---|
| `INTERNET` | Requested. Ads and opening the waitlist form only. |
| Photo/media access | **Not requested.** Photos come through the system picker, which grants access to the one file chosen. |
| `CAMERA` | **Not requested.** The camera is used through the system camera app. |
| Storage / external storage | **Not requested.** |
| Location, contacts, microphone | **Not requested.** |

### 8. Children

The app is for arranging marriages and is not directed at children. State a minimum age of 18 for
the person using the app, and note that a biodata is normally prepared by an adult family member.

### 9. Retention and deletion

There is nothing on a server to delete, so this section is short and unusual: **uninstalling the app
removes everything.** Say that in those words.

There is deliberately no in-app "delete all my data" button (see `docs/decisions.md` D13). Play's
data-deletion requirement applies to accounts and server-side data; this app has neither, so the
uninstall path is the complete answer and a second button would only imply there was something else
somewhere.

### 10. Changes, and an effective date

A dated version, and a note that material changes will be surfaced in the app.

## Play Data Safety — the answers this policy commits us to

| Question | Answer |
|---|---|
| Does the app collect or share user data? | Yes — advertising data only, via AdMob. |
| Is data encrypted in transit? | Yes (AdMob's own transport). |
| Can users request deletion? | No server-side data exists; uninstall removes everything. |
| Personal info / photos / files collected? | **No.** They never leave the device. |
| Device or other IDs? | Yes — advertising ID, for ads, with consent. |
| Is any collection optional? | Yes. Refusing consent disables ads and the app still works. |

The tempting mistake here is to declare "no data collected" because the *app's own* data never
moves. AdMob's collection is still collection, and it is the developer who declares it.

## Before publishing

1. **Contact email** — currently `privacy@safarnamastudios.com`, which does not exist yet. Either
   stand that address up or substitute a real one.
2. **Waitlist form provider** — the policy names the provider and links its policy. Fill this in once
   the form exists (open question 8).
3. **Effective date** — set on the day it goes live.
4. The hosted URL then goes into the Play listing, into the Settings screen, and into
   `AppConfig.privacyPolicyUrl`.
