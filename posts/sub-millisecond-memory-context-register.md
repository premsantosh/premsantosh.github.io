---
title: Sub-Millisecond Memory: How a 4-Slot Register Solves Multi-Turn Conversations
subtitle: Under a kilobyte. Under a millisecond. Entirely on your own hardware.
description: How a tiny 4-slot context register solves multi-turn conversation tracking for on-device personal assistants — under a kilobyte, under a millisecond, no cloud required.
---

There was something really bothering me while I am trying to build my own personal assistant. I can very easily utilize available large language models but it means sending all my information to their servers, especially anything private pertaining to my house, routine etc.

That made me consider building a local-first intent routing system, something that can run on very simple hardware such as a PC or a Mac mini or even a Raspberry Pi, learns your personal vocabulary over time, and never phones home. The broader system is a topic for a future post. But while building it, I hit a specific problem that I think is worth talking about on its own: **how do you maintain conversational context between turns when you're running on hardware that costs less than a nice dinner?**

Alexa solves this with millions of dollars of cloud infrastructure. I need to solve it with a dictionary and a timer.

#### The Constraint That Changes Everything

When you're building on-device, every design decision is filtered through three constraints that cloud-based systems don't have to think about:

**Every byte matters.** A Raspberry Pi 4 has 4GB of RAM shared across the entire system. Your context mechanism can't be a transformer model, it can't even be a large data structure. It needs to be trivially small.

**Every millisecond matters.** The whole point of routing locally is speed. If your context system adds 50ms of overhead, you've defeated the purpose. The target is sub-millisecond. The user should never perceive that context resolution is happening at all.

**Every bit that leaves the device is a failure.** This isn't just a philosophical position. If you're building a personal assistant that knows when you wake up, what medications you take, when you leave the house, and who visits, the aggregate of that data is extraordinarily intimate. The system should be able to understand "set it to 32 degrees" without that utterance ever touching a network interface.

These constraints rule out the obvious solutions. You can't pack conversation history into an LLM prompt, that's a cloud call which also introduces latency. You can't run a dialogue state tracking model, those are too heavy for edge hardware. You can't even concatenate the last few turns and re-encode them, the encoder overhead adds up and the token budget is tight.

So what *can* you do?

---

#### The Smallest Possible Solution

I've been working on this routing system for a while now. This is something inspired by recent research on test-time learning and neural memory, designed to run entirely on-device. While building it, I kept circling back to this multi-turn context problem. No amount of clever routing helps if the system forgets the conversation between turns.

The instinct is to reach for something sophisticated such as a dialogue state tracker, a context transformer or a memory network. But every one of those violates the constraints above. So I asked myself a different question: what is the *minimum viable context* the system needs to resolve a follow-up utterance?

The answer turns out to be surprisingly small. You don't need the full conversation history. You don't need a semantic parse tree. You just need to remember what you did last. The domain, the device, the action, and any parameters and make that available for the next turn.

So I built what I'm calling a **context register**, a small, structured, ephemeral state that sits between the user and the routing system and carries forward just enough context to resolve follow-up utterances.

The key word is *just enough*. This is not a dialogue state tracker. It's not a conversation history buffer. It's not a memory system. It's a register, like a CPU register, that holds a handful of resolved facts from the last successful action and makes them available for the next turn.

---

#### How It Works

After every successfully routed command, the register captures four things:

- **The domain** — what area of the system was involved (HVAC, security, entertainment, etc.)
- **The device** — what specific thing was acted on (living room AC, front gate, wine cellar)
- **The action** — what was done (turned on, locked, queried temperature)
- **The parameters** — any structured values that were resolved (temperature: 72, time: 7am)

That's it. Four slots. When the next utterance comes in, the register prepends this context as a structured prefix before the utterance is processed. So the routing system doesn't see "set it to 65 degrees" in isolation. It sees, *the last thing we did was turn on the living room AC, and now the user is saying "set it to 65 degrees."* The ambiguity disappears.

This is a text-level enrichment, not an architectural change. The routing system's input is still a string. It just has a few extra words at the front. Which means it works with any encoder, any classifier, any downstream model. You don't have to redesign anything to get multi-turn context.

---

#### The Expiry Problem

The tricky part isn't carrying context forward, it's knowing when to let it go.

If you turn on the AC and then immediately ask about the wine cellar temperature, the register needs to realize that the HVAC context is no longer relevant. If you turn on the AC and then walk away for ten minutes, the register shouldn't still be telling the system you're in the middle of an HVAC conversation when you come back asking about something else entirely.

The register clears itself under three conditions:

1. **Too many turns pass** without the context being relevant. If three turns go by and none of them seem related to what's in the register, it clears.
2. **The domain changes.** If the system routes a command to a completely different domain than what's in the register, the old context is replaced.
3. **Too much time passes.** A simple clock-based expiry catches the "walked away" case.

Any one of these conditions triggers a clear and is configurable.

---

#### What It Isn't

I want to be explicit about what the context register does *not* do, because the dialogue state tracking literature is deep and I'm not trying to compete with it.

The register does not maintain a full conversation history. It holds one turn's worth of resolved context. It does not do coreference resolution. It doesn't parse "it" and figure out what "it" refers to. Instead, it provides enough context that the downstream routing system can figure that out from the enriched input. It does not handle multi-intent utterances, e.g. "wake me up at 7am and start the coffee machine" is out of scope (for now). And it does not persist across sessions by default. It's ephemeral. When the session ends, the register is empty.

This is deliberate. The register's value comes from being tiny, fast, and disposable. A dictionary read to check the register takes less than a tenth of a millisecond. The entire state fits in under a kilobyte. It adds essentially zero overhead to the routing pipeline while solving a real and annoying problem.

---

#### Why Not Just Concatenate the Last Few Turns?

A reasonable question. Why not just prepend the raw text of the last 2–3 conversational turns instead of maintaining a structured register?

A few reasons. First, raw conversation text is noisy. "I'm feeling hot" / "I've turned on the air conditioner for you" / "set it to 65 degrees" is a lot of tokens to push through an encoder when the useful information is just: domain=HVAC, device=AC, action=power_on. The register is a compressed, resolved summary. Higher signal, lower noise.

Second, the encoder has a token limit. MiniLM-L6-v2, which is a common lightweight encoder for this kind of system, handles about 256 tokens. Three turns of natural conversation can easily eat into that budget, especially if the assistant's responses are verbose. The register prefix is 10–20 tokens regardless of how long the conversation was.

Third, structured context is easier for the downstream model to learn from. When a routing model sees `[context: domain=HVAC, device=living_room_ac]` a hundred times alongside temperature-related follow-ups, it learns a clean association. When it sees variable-length raw conversation strings, the signal is harder to extract.

---

#### What's Next

The context register is one component of a larger system I'm building for personalized intent routing. The broader goal is a routing layer that learns your specific vocabulary over time, runs entirely on-device, and progressively reduces its reliance on cloud LLMs as it gets to know you. More on that soon.

The register itself will be open-sourced under Apache 2.0. It's designed to be standalone, you don't need the rest of my system to use it. If you're building any kind of conversational assistant and you're tired of your system forgetting what "it" means, this might be useful to you.

I'll share a link when the repo is live.

*If you're working on similar problems — on-device inference, personalized routing, lightweight NLU, I'd love to hear from you.*
