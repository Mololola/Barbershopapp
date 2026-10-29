# UX audit and redesign plan (step 8)

30 Oct 2026, on `launch-prep` at `377fb1a`. Checked against the Broch Builds UX checklist (https://brochbuilds.com/ux, 132 items; numbers below are its item numbers). Read-only so far: nothing has been changed.

Screens: Find a shop, Worker profile, My bookings, the business Bookings, Edit profile, and Settings (customers and businesses share one Settings screen).

## Findings

HIGH = slows or blocks the main job on a key screen, or a store/legal risk. MEDIUM = friction. LOW = polish.

| # | Priority | Screen | Item | What's wrong | Evidence | Fix |
|---|---|---|---|---|---|---|
| 1 | HIGH | Business Bookings | 86, 106 | **Bug:** "Mark as done" shows on every confirmed booking, including future ones, and the backend accepts it. The customer then gets the compulsory review prompt for a cut they haven't had. | `mobile/lib/features/business/presentation/bookings_screen.dart:59`, `backend/app/api/bookings.py:346-363` | Show the button only after the start time, and make the backend refuse before then. |
| 2 | HIGH | My bookings | 36, 44 | A booking shows only the date and its status: no shop, service, barber or price. The fields exist but nothing fills them. | `my_bookings_screen.dart:50`, `bookings_repository.dart:15-22`, `booking.dart:37-41` | Load shop, service, barber and price with the booking and show them on the card. |
| 3 | HIGH | Business Bookings | 36, 44 | A booking shows only the time and status: no customer, service or barber, so the shop can't tell who is coming. | `bookings_screen.dart:57-58` | Show customer name, service, barber and duration on each row. |
| 4 | HIGH | My bookings | 86, 14, 92 | "Cancel" cancels straight away: no confirmation, no undo, no message afterwards. One wrong tap loses the appointment. | `my_bookings_screen.dart:71-75` | Confirm first ("Cancel your 14:00 cut at X?"), then show "Booking cancelled". |
| 5 | HIGH | Settings | 132 | No Terms, Privacy Policy or contact/help link anywhere after sign-up. Both stores expect the privacy policy to be reachable inside the app. | `account_settings_screen.dart:123-220` (links exist only in `sign_up_screen.dart`) | Add an "About" group: Terms, Privacy, Contact us. |
| 6 | HIGH | Find a shop | 44, 36, 100 | Each shop card shows only the logo and name. To compare rating, location or price you have to open every shop. Search is by name only, with no city or location. | `business_list_screen.dart:115-138`, `:65` | Card shows rating and review count, city, "from £X" and the logo. Add search by city and sort by rating. |
| 7 | HIGH | Edit profile | 19, 55 | "Edit profile" on your profile opens a screen that only changes the photo. The handoff already flags this. | `profile_screen.dart:87`, `edit_profile_screen.dart:47` | A real Edit profile screen: photo (camera or gallery, remove), plus the details people expect to change. See question 1 below. |
| 8 | MEDIUM | Business Bookings | 46, 87 | The list starts at the oldest booking ever, so today is buried under past days. | `bookings_repository.dart:29`, `bookings_screen.dart:43` | Open on today, with Upcoming and Past tabs or a day picker. |
| 9 | MEDIUM | My bookings | 46, 59 | Newest first, so a far-off booking sits above the next one and past and future are mixed. Dates show as "2026-10-30" instead of "Fri 30 Oct". | `bookings_repository.dart:20`, `my_bookings_screen.dart:109-112` | Upcoming (soonest first), then Past. Dates in the user's language, like the business screen already does. |
| 10 | MEDIUM | My bookings, Business Bookings | 97, 98 | The empty state is a single line of text with no next step. | `my_bookings_screen.dart:25`, `bookings_screen.dart:39` | Customer: "Find a shop" button. Shop: "Share your shop page" button. |
| 11 | MEDIUM | All six screens | project rule | None has a wide (website or tablet) layout; on the business website the Bookings list stretches across the whole screen. | no `isWideLayout`/`ResponsiveColumns` in these files | Add wide layouts; Bookings first because shops use it at the desk. |
| 12 | MEDIUM | Worker profile | 45, 46, 12 | Three jobs on one long page: the form, a Save button in the middle, then current job, then invitations at the very bottom. A pending job offer is the easiest thing to miss. | `worker_profile_screen.dart:120-298` | Pending invitations on top as a card; the form below with Save pinned to the bottom of the screen. |
| 13 | MEDIUM | Worker profile | 92 | Switching "Available as a barber" off and tapping Save does nothing and says nothing. | `worker_profile_screen.dart:48` | Disable Save when there's nothing to save, or explain what switching off does. |
| 14 | MEDIUM | Worker profile | 14, 117, 93 | Accept and decline are small tick and cross icons side by side, told apart only by green and red; decline happens at once. | `worker_profile_screen.dart:269-290` | Labelled "Accept" and "Decline" buttons, and confirm before declining. |
| 15 | MEDIUM | My bookings, Business Bookings | 92 | No pull-to-refresh on the phone (the website gets a refresh button). | `bookings_screen.dart:26` | Pull down to refresh on both. |
| 16 | MEDIUM | Edit profile | 32, 92 | After picking a photo you have to find and tap a separate Save, and nothing confirms it worked. | `edit_profile_screen.dart:33-39`, `:80-85` | Save when chosen (with a progress ring on the photo), then "Photo updated". |
| 17 | LOW | Worker profile | 118, 112, 61 | The hint text is hardcoded 12 px grey, smaller and fainter than the app's theme. | `worker_profile_screen.dart:135-138` | Use the theme's body style and colour. |
| 18 | LOW | Worker profile | 81 | Fields are checked only on Save. | `worker_profile_screen.dart:140-181` | Check each field when the user leaves it. |
| 19 | LOW | Settings | 19, 125 | The customer entry is called "Profile photo"; it will be "Edit profile" after #7. | `account_settings_screen.dart:166` | Rename with #7. |

**Passed:** loading skeletons on all lists, whole shop card tappable, helpful "no matches" text on Find a shop, Delete account double-confirmed and kept apart from Sign out, settings grouped under headings, language names written in their own language.

## To check on the A33 (can't judge from code)

- **Tap sizes**: accept/decline icons, the Cancel and "Mark as done" text buttons. Each should be at least about a fingertip (48 dp).
- **Contrast**: grey text (`AppColors.steel`) on the dark cards.
- **One-handed reach**: Save on Worker profile, and the search box at the top of Find a shop.
- **Feel**: how long Find a shop and My bookings take on mobile data on the first open of the day (Render's free plan wakes up slowly).

## Redesign plan (proposed order)

Each step is one small commit with tests, English and Spanish text, and the phone layout kept working.

1. **Fix the "Mark as done" bug** (#1): app and backend. Small, and it's a real bug.
2. **Booking cards that say what the booking is** (#2, #3, #9): one shared card for customers and shops with the shop or customer, service, barber, time, duration and price. Upcoming and Past for customers; open on today for shops.
3. **Safe cancel** (#4) and the empty states and pull-to-refresh (#10, #15).
4. **Settings "About" group** (#5): Terms, Privacy, Contact us.
5. **Find a shop cards and search** (#6).
6. **Edit profile** (#7, #16, #19).
7. **Worker profile reorganised** (#12, #13, #14, #17, #18).
8. **Wide layouts** (#11), Bookings first.

## Decisions (30 Oct)

1. **Edit profile:** the user wants "a bit of content" there but left the exact fields open. Proposal to confirm at step 6: photo, display name and a short bio, all optional.
2. **Find a shop:** "Near me", sorted by distance. Ask for location **only when the user taps Near me**, never at install or first launch; without permission, fall back to search by city. Shops store no coordinates today, so their addresses need turning into map positions when saved, plus a line in the Privacy Policy about location.

## Progress

- Step 1 done: "Mark as done" only appears once a booking has started, and the backend refuses it before then.
