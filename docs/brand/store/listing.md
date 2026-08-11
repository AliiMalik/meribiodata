# Play Store listing copy

ASO-tuned against the actual category, August 2026. Nothing here claims a
feature the app does not have — a listing that oversells is the fastest route to
one-star reviews, and Play removes apps whose descriptions misrepresent them.

---

## What the competition is doing

Read from live listings for `com.aquaappstudio.biodatamakerglobal`,
`com.yooashu.shaadiprofile`, `com.additive.mbiodata`, `matrimonybiodata.com`,
`com.iw.biodatamakerhindi` and `com.radhikatech.biodata`.

**Keywords every one of them uses:** marriage biodata · biodata format ·
shaadi biodata · rishta · matrimonial profile · biodata PDF · share on WhatsApp ·
print-ready · templates / formats · free · offline · no sign-up ·
partner preferences · family background.

**Their two standard boasts** are a format count ("140+ biodata formats",
"24+ beautifully designed formats") and a language list (10–13 languages).

**The gap, and the whole reason the name is right.** Every serious app in this
category is built for India. They advertise "all Indian communities", offer
Hindu / Sikh / Jain / Christian formats, carry kundli and horoscope fields, and
lead with Hindi, Marathi, Gujarati and Tamil. Urdu appears eleventh in a list.
Nobody owns *Pakistan* — not the word, not zaat/biradari, not maslak, not
Nastaliq. That is the position this listing takes, and it is defensible because
the app genuinely is built that way.

**Deliberately not copied:** no inflated format count (we have 17 and say 17),
no claim of languages whose labels are still unreviewed.

---

## App name (30 characters max)

```
Pak Marriage Biodata Maker
```

26 characters. Leads with the market nobody else claims, then the two highest-
volume terms in the category. Play weights the *start* of the name most.

The package name `safarnamastudios.meribiodata.app` is permanent and unaffected,
and `meribiodata.web.app` remains the policy URL. The privacy policy names both,
so a reviewer comparing the listing to the policy sees one app rather than two.

---

## Short description (80 characters max)

```
Shadi & rishta biodata maker in Urdu. Free marriage biodata PDF formats.
```

72 characters. Carries six of the category's highest-volume terms — shadi,
rishta, biodata maker, Urdu, marriage biodata, PDF — in the single most-read
line of the listing.

---

## Full description (4000 characters max)

```
Pak Marriage Biodata Maker — make a shadi biodata your family is proud to send.

Fill in a simple form and get a clean, print-ready marriage biodata as a PDF or an image, then send it straight to WhatsApp. Built in Pakistan, for Pakistani families — not an Indian biodata app with Urdu bolted on.

FREE MARRIAGE BIODATA MAKER
• 17 biodata templates and formats — classic, elegant, decorative, and plain black-and-white for the print shop
• Export a print-ready biodata PDF, or a JPG image for WhatsApp
• Copy your whole biodata as text and paste it into any chat
• No sign-up, no account, no email verification

WRITTEN IN PROPER URDU
Urdu is set in real Nastaliq, not squeezed into a font made for English. Names, dates, height and numbers all sit the right way round. Prefer English? The whole biodata switches over.

Typing Urdu is easy: type "naveed malik" in Roman and the app offers نوید ملک.

EVERYTHING A RISHTA BIODATA NEEDS
Name, age, date of birth, zaat / biradari, maslak, height, weight, blood group, education, occupation and income. Father's and mother's name and occupation, brothers, sisters and nanihal. Address and contact. Add a photo if you want one.

Missing a field? Add it. Don't need one? Hide it. Rename anything. The form bends to your family, instead of the other way about.

TWO VERSIONS OF EVERY BIODATA — THE PART THAT MATTERS
"Wide sharing" leaves out your phone number and exact address. That is the copy for a WhatsApp group, a rishta aunty or a marriage bureau. "One family" includes everything, for people you have already decided to trust.

The app always starts on the safe one. A biodata that goes into a group chat cannot be taken back, so choosing the full version takes a second, deliberate tap.

PHOTOS, HANDLED CAREFULLY
Add a photo and the app strips the hidden information out of it first. Most people never learn that a photo taken at home carries the exact location of that home, invisibly, inside the file. Yours will not.

YOUR BIODATA STAYS ON YOUR PHONE
We run no server. There is nowhere for your details to be sent to us, even in principle. No matching, no profile browsing, nobody looking at your daughter's information. Works completely offline.

Optional: turn on Google Drive backup and one encrypted file is kept in your own Drive, locked with a password only you know. Google stores it but cannot read it.

FREE, PROPERLY FREE
Every feature works without paying. Premium is optional and does two things: removes the ads, and removes the small watermark on your exports. Nothing is locked behind it.

Perfect for shadi proposals, rishta, nikah, wedding and matrimonial profiles. Made in Pakistan.
```

2,690 characters of 4,000.

### Keyword density

biodata ×15 · Urdu ×5 · marriage ×5 · free ×4 · rishta ×4 · photo ×4 ·
PDF ×3 · WhatsApp ×3 · shadi ×3 · Pakistan ×3 · print ×3 · format ×2 ·
image ×2 · template, Nastaliq, zaat, biradari, maslak, nikah, wedding,
matrimonial, proposal, offline ×1 each.

Placed in prose rather than a keyword block — Play penalises stuffing, and the
first two lines are what a reader actually sees before tapping "more".

### Before publishing, check

- [ ] Sindhi, Pashto and Punjabi are **not claimed** anywhere in this copy. Their
      labels are still marked `draft` and unreviewed. Add them only once a native
      reader has signed them off.
- [ ] "17 biodata templates" matches `Templates.all.length`.
- [ ] The Premium paragraph matches the final prices and product setup.

---

## Screenshots

`screenshots/phone/`, 1080×1920, upload in this order:

1. `1-designs.png` — the template picker showing border artwork
2. `2-preview.png` — a complete biodata in English
3. `6-urdu.png` — the same biodata in Urdu, the differentiator
4. `3-templates.png` — choosing a template
5. `4-form.png` — the form
6. `5-library.png` — saved biodatas

`7-sindhi.png` and `8-pashto.png` exist but are held back for the same reason
the copy does not claim those languages.

Regenerate the rendered ones after any change to the watermark or fixture:

```bash
flutter test --tags store test/render/store_screenshots_test.dart
```
