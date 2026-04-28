# Artyug New User Onboarding: Questions, Options, and Full Walkthrough

This document captures the current onboarding flow implemented in:

- `lib/features/onboarding/onboarding_screen.dart`
- `lib/router/app_router.dart`
- `lib/screens/legal/terms_acceptance_screen.dart`
- `lib/widgets/onboarding_guide.dart`

## 1) Entry and Routing Logic

After sign-in/sign-up:

- If user is **not authenticated**: route to `/sign-in`
- If authenticated but `profiles.onboarding_complete = false`: route to `/onboarding`
- If onboarding complete but terms not accepted (local pref): route to `/terms-acceptance`
- If both complete: route to `/main`

Notes:

- Onboarding is treated as mandatory first-time profile setup.
- Terms acceptance is mandatory after onboarding.

## 2) Global Step 1 (Both User Types)

### Step 1 of 1 (pre-branch)
Question: **"CHOOSE YOUR PATH."**  
Subtext: **"Are you here to create the culture or collect it?"**

Options:

- **I'm a Creator** (`role = "creator"`)
- **I'm a Collector** (`role = "collector"`)

Selecting role changes total steps:

- Creator path: **8 steps**
- Collector path: **6 steps**

---

## 3) Creator Onboarding Questions (8 Steps)

### Step 1 of 8
Role selection (same as above).

### Step 2 of 8: Name + Username
Title: **"NAME + USERNAME."**  
Prompt: **"Set your public Artyug identity."**

Fields:

- Display Name (required)
- Username (required)

Username rules:

- 3-20 chars
- lowercase letters, numbers, underscore only (`[a-z0-9_]`)
- invalid characters auto-removed
- live availability check with debounce

### Step 3 of 8: Mediums
Title: **"YOUR MEDIUMS."**  
Prompt: **"Select all that apply. Collectors use this to find you."**

Options:

- Painting
- Photography
- Sculpture
- Digital Art
- Illustration
- Printmaking
- Mixed Media
- Textile & Fiber
- Ceramics
- Street Art
- Video Art
- Installation

Validation: at least one medium required.

### Step 4 of 8: Bio
Title: **"YOUR BIO."**  
Prompt: **"A short intro shown on your public profile."**

Field:

- Bio textarea (max 300 chars, optional in validation logic)

### Step 5 of 8: What Do You Sell?
Title: **"WHAT DO YOU SELL?"**  
Prompt: **"Select all types of work you offer."**

Options:

- Original works
- Prints & editions
- Digital downloads
- Commissions

Validation: no mandatory selection enforced.

### Step 6 of 8: Events
Title: **"EVENTS?"**  
Prompt: **"Are you interested in hosting or joining art events on Artyug?"**

Options:

- Yes, I'm in
- Not right now

Validation: must select yes/no.

If "Yes":

- Shows info message about access to self-serve event creation in Creator Pro.

### Step 7 of 8: Join a Guild
Title: **"JOIN A GUILD?"**  
Prompt: **"Which creator community resonates with you? (Optional.)"**

Options:

- Painters Guild
- Digital Artists
- Photography Circle
- Mixed Media Collective
- None right now

Validation: optional.

### Step 8 of 8: Completion
Headline: **"YOU'RE READY."**  
Message: creator profile configured, dashboard launch.

Summary shown:

- Name
- Username
- Role = Creator
- Mediums (first 2 selected)

Button label on final step: **"Enter Artyug"**

---

## 4) Collector Onboarding Questions (6 Steps)

### Step 1 of 6
Role selection (same as above).

### Step 2 of 6: Name + Username
Same structure and validation as creator:

- Display Name (required)
- Username (required, same rules + live availability check)

### Step 3 of 6: Interests
Title: **"WHAT ART DO YOU LOVE?"**  
Prompt: **"We'll personalize your Artyug feed based on your interests."**

Options:

- Paintings
- Photography
- Digital Art
- Sculpture
- Prints
- Street Art
- Emerging Artists
- Abstract
- Portraits
- Landscapes

Validation: no mandatory selection enforced.

### Step 4 of 6: Purchase Style
Title: **"HOW DO YOU BUY?"**  
Prompt: **"Tell us how you prefer to acquire art."**

Options (single select):

- Direct purchase (`buy`)
- Auctions & bidding (`bid`)
- Both styles (`both`)

Validation: one option required.

### Step 5 of 6: Events
Title: **"EVENTS?"**  
Prompt: **"Interested in attending art exhibitions and events?"**

Options:

- Yes, I'm in
- Not right now

Validation: must select yes/no.

### Step 6 of 6: Completion
Headline: **"YOUR VAULT AWAITS."**  
Message: collector profile ready.

Summary shown:

- Name
- Username
- Role = Collector
- Interests (first 2 selected)

Button label on final step: **"Enter Artyug"**

---

## 5) Shared Navigation and Validation Behavior

- Bottom actions:
  - Left: `Back` (from step > 1)
  - Right: `Continue` (or `Enter Artyug` on final step)
- Progress bar shown top of screen.
- Step transitions animated.
- Continue button disabled unless current step requirements are met.
- Username is revalidated before moving forward from step 2.

If username is already taken:

- Snackbar error shown
- User stays on current step

If save fails at final submit:

- Error shown in snackbar + inline on completion card
- User is not navigated away

## 6) Data Saved at Onboarding Completion

Profile upsert payload includes:

- `id` (current user id)
- `display_name`
- `username`
- `bio` (creator only; collector saves empty string)
- `role` (`creator` or `collector`)
- `onboarding_complete = true`
- `updated_at`

After success:

- `AuthProvider.refreshOnboardingStatus()` called
- `OnboardingGuide.markAsShown()` called
- Navigate to `/terms-acceptance?next=/main`

## 7) Mandatory Terms Step (After Onboarding)

Screen: `/terms-acceptance`

User must:

- check "I agree to the terms and conditions"
- tap `Continue`

Then:

- local per-user preference `termsAccepted = true` stored
- user routed to `next` (default `/main`)

## 8) Product Walkthrough / App Guide (Modal Slides)

Guide source: `OnboardingGuide` (`lib/widgets/onboarding_guide.dart`)

Behavior:

- Shown once per install unless reset from settings
- Skipped automatically for users with onboarding already complete
- Can be forced/replayed manually

Slides:

1. **Welcome to Artyug**
2. **Discover & Collect**
3. **Join a Guild**
4. **AI Art Assistant**
5. **Demo vs Live Mode**

Guide controls:

- `Skip`
- `Next` (changes to `Get Started` on last slide)

## 9) Quick End-to-End Flow Summary

1. User signs in/signs up.
2. App checks auth + onboarding status.
3. User completes onboarding wizard:
   - Step 1 role selection
   - Creator (8 steps) or Collector (6 steps)
4. Profile saved with `onboarding_complete = true`.
5. User must accept Terms & Conditions.
6. User enters `/main`.
7. Optional one-time app walkthrough modal appears only when applicable.

