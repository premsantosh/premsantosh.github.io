---
title: The Reservation Agent: Teaching Friday to Make a Booking Without Selling Me Out
subtitle: It calls restaurants and salons. It fills out forms. It waits for openings. But it never books without asking, and it never phones your card details home.
description: A high-level tour of the booking workflow I built into Friday: it books restaurant tables, salon appointments, and more across reservation platforms, web forms, phone, and email, waits for openings, and handles deposits, all behind a strict confirmation gate that keeps your data and money safe.
---

Friday is the personal assistant I've been building, the same project behind [the context register I wrote about earlier](brief.html?p=sub-millisecond-memory-context-register). Most of what it does is small and local: lights, the coffee machine, answering questions. But I wanted to see how far a personal agent could go on a task that's genuinely annoying and genuinely *consequential*: making a real-world booking: a dinner reservation, a hair salon appointment, that sort of errand.

"Annoying" because booking a table, or a barber's chair, is a little scavenger hunt every time. Which platform do they use? Is there a form? Do you have to call? Is 7pm even available? "Consequential" because the moment an agent can act on your behalf in the real world, it can also embarrass you, spend your money, or leak your private details. A reservation agent is a perfect little microcosm of the whole "agents that do things" problem: small enough to finish, dangerous enough to take seriously.

This is a high-level tour of what I built: what it can do, how the pieces fit together, and (the part I cared about most) how it stays safe.

<figure class="figure-wide">
  <img src="assets/posts/friday-reservation-agent/hero-demo.png" alt="A full booking conversation with Friday in chat mode: the user asks to book a table for 2 at Copra in SF on June 30 at 6:30pm, Friday confirms the details and asks to go ahead, and after approval reports the table is confirmed and added to the calendar with a Signal confirmation.">
  <figcaption>The whole interaction is just a conversation. You ask; it asks back only when it has to.</figcaption>
</figure>

<figure class="figure-narrow">
  <img src="assets/posts/friday-reservation-agent/signal-confirmation.png" alt="A Signal 'Note to Self' thread where Friday reports it is booking Copra for 2 on Tuesday June 30 at 6:30 PM via OpenTable, then confirms: Reservation confirmed: Copra for 2 on Tuesday, June 30 at 6:30.">
  <figcaption>Signal message</figcaption>
</figure>

---

#### What It Actually Does

You ask in plain language, out loud or by text, something like *"book a table for two at Copra next Friday at seven"* or *"get me a haircut this Saturday morning."* From there, Friday handles the whole errand:

- **Fills in the gaps.** If you left out the date, the time, or the party size, it asks for exactly the missing piece, nothing more, and understands fuzzy answers like "next Friday" or "half past seven."
- **Figures out how the place takes bookings.** It looks the place up and works out whether they use a reservation platform (OpenTable, Resy, Tock), their own web form, or just a phone number.
- **Books it the right way.** For the big platforms it drives the real booking site using your own logged-in account. For a plain web form, it fills it in. If the only option is the phone, it places an actual call and talks to the front desk. If they prefer email, it drafts the request for you.
- **Waits for an opening.** If nothing's open at your time, it offers to keep watching and grab the slot the moment one frees up.
- **Handles the deposit card.** Some places require a card on file to hold the spot. Friday can supply a single-use, spend-capped virtual card for exactly that (more on this below).
- **Tells you it's done.** A confirmed booking lands on your calendar and pings you a confirmation over Signal, so there's a written record even if you were away from the mic.

The throughline is that Friday adapts to *how the business works* instead of forcing you to. You shouldn't have to know or care that one place is on Resy and another only answers the phone.

---

#### The Anatomy of a Booking

Every request, no matter how it ends up being booked, flows through the same six stages. The fourth one, the confirmation, is the hinge the whole design turns on.

<figure>
  <div class="diagram" data-svg="assets/posts/friday-reservation-agent/booking-pipeline.svg"></div>
  <figcaption>One pipeline, every booking. Nothing irreversible happens to the left of “Confirm with you.”</figcaption>
</figure>

Notice what's *before* the confirmation: understanding, looking things up, checking availability. All of it is read-only research. The first time Friday does anything that can't be taken back (pressing the button, placing the call, sending the email) is strictly *after* you've said yes.

---

#### One Ask, Many Ways to Book

The interesting engineering is that a business can take bookings in wildly different ways, and the user shouldn't have to think about any of it. Internally there's a single confirmation step, and behind it a set of interchangeable "channels", one per way-of-booking. Friday picks the right one and everything downstream looks the same.

<figure>
  <div class="diagram" data-svg="assets/posts/friday-reservation-agent/booking-channels.svg"></div>
  <figcaption>The channels are interchangeable. Adding a new way to book doesn't change anything above the dashed box.</figcaption>
</figure>

A few of these are more than they sound:

- **The phone channel actually talks.** When a place only takes bookings by phone, Friday places a real call, has the conversation, and reports back what was agreed. If the place is closed, it waits and rings when they open. If it doesn't get through, it retries a few times before giving up.
- **The email channel drafts, then waits.** It writes the request, shows it to you so you can tweak the wording, sends it once you approve, and then keeps an eye on the thread for the reply.
- **The "wait for an opening" mode** turns a dead end into a background task. Instead of "sorry, nothing at 7," you get "I'll watch and grab it the moment something opens."

---

#### The Part I Cared About Most: Not Selling Myself Out

An agent that can book on your behalf is, by definition, an agent that can do things you didn't intend. So I designed the safety in from the start rather than bolting it on. The mental model is defense in depth: a request has to pass through several independent guards before anything real happens, and each guard can stop it cold.

<figure>
  <div class="diagram" data-svg="assets/posts/friday-reservation-agent/safety-layers.svg"></div>
  <figcaption>Defense in depth. A request has to clear every layer; any one of them can stop it.</figcaption>
</figure>

Walking through those guards:

**Nothing happens without a clear yes.** Every irreversible action (booking, calling, emailing, charging) is held behind a single approval step. And you approve the *resolved* facts ("Copra, party of 2, Tuesday June 30 at 6:30pm"), not the ambiguous thing you originally said. A question or an "umm" is never read as consent; if your answer is unclear, it asks again rather than guessing in the dangerous direction.

**There's a kill switch.** A single setting puts the whole agent into research-only mode, where it will happily look things up and tell you what it *would* do, but won't take any real-world action. It's the seatbelt for when you want to experiment.

**Your data stays yours.** When Friday searches the web to find a place, the only thing that goes out is the business name and city. Never your name, phone, email, or card. That boundary is enforced, not just intended. And the genuinely private details are treated as disposable: once the booking is done, they're purged, while the harmless booking facts (where, when, confirmation number) stick around so you can ask "what did I book?" later.

**The card is single-use and capped.** For deposits, Friday never reaches for your real card. It uses a single-use virtual card with a hard spending cap, the kind that simply declines if anyone tries to over-charge it. The card details are passed straight to the checkout and never logged, never persisted, and never sent to the language model.

**It uses your sessions, not your passwords.** To book on a platform, Friday rides your own already-logged-in browser session rather than storing any credentials. There's no password vault to leak.

**It fails honestly.** This one matters more than it sounds. If Friday can't complete a booking (the page changed, the session expired, the card was refused), it tells you that plainly and hands you a link to finish, instead of pretending it succeeded. A confident lie from an agent is worse than an honest shrug.

<div class="callout">
  <strong>The design rule, in one line:</strong> the agent is allowed to do all the research it wants on its own, but it is never allowed to take an irreversible action you didn't explicitly approve, and it would rather hand the task back than fake a win.
</div>

---

#### What's Next

The reservation agent is one workflow inside Friday, but it's the one that taught me the most about what "an assistant that does things" really demands, and it's mostly the boring, careful parts: confirming before acting, minimizing what leaves the machine, capping what can go wrong, and refusing to fake success.

From here I want to push the same pattern at other real-world errands (pranking friends, simple purchases) and tighten the failure handling to make sure Friday degrades gracefully instead of guessing.

*Scripted by human, edited by LLM*
