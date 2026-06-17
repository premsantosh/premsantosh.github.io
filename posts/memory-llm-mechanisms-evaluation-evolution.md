---
title: Memory in Large Language Models: Mechanisms, Evaluation and Evolution
description: Notes on Zhang et al.'s survey (arXiv 2509.18868) — how to think about and evaluate LLM memory as a system property, not just a bag of techniques.
paper: https://arxiv.org/abs/2509.18868
---

Another LLM memory survey paper crossed my feed, this one from Zhang et al. (arXiv 2509.18868). It's more recent than the Li Auto paper I wrote about before and takes a different angle. Less about implementation techniques and more about how to actually think about and evaluate memory as a system property.

#### The Core Framing

The paper starts with a pretty good operational definition: LLM memory is "a persistent state written during pretraining, finetuning, or inference that can later be addressed and stably influences outputs."

I like this framing because it gets at the lifecycle aspect. Memory isn't just one thing, it gets written at different stages and has different characteristics depending on when and how it was created.

#### The Taxonomy

They break down memory into four types:

1. **Parametric memory**: facts baked into model weights during training. Think of this as the read-only data that ships with the binary.
2. **Contextual memory**: what fits in the context window during inference. This is your working set.
3. **External memory**: RAG, vector DBs, knowledge graphs etc. External storage you query at runtime.
4. **Procedural/episodic memory**: cross-session state, user-specific memories. The stuff that makes the model "remember" you across conversations.

They also define a "memory quadruple" for characterizing each type: storage location, persistence, write/access path, controllability. This is the kind of structured thinking that's actually useful when you're trying to reason about system design.

---

#### The Evaluation Protocol - This is the Good Stuff

What I found most interesting was their evaluation framework. They argue (correctly imo) that a lot of LLM memory research is hard to compare because everyone uses different setups. A model with RAG enabled isn't comparable to a model without it, you're measuring different things.

So they propose a three-setting protocol:

1. **Parameter-only (PO)** closed book, no retrieval. Tests what the model actually "knows" from training.
2. **Offline retrieval** RAG with a fixed corpus prepared ahead of time.
3. **Online retrieval** RAG with live/dynamic sources.

The idea is you evaluate the same model under all three settings to decouple capability from information availability. This is actually a really clean separation. It's similar to how in benchmarking distributed systems you want to isolate variables — test with local storage vs remote storage vs cached results separately, then compare.

#### Mid-Sequence Drop

One phenomenon they call out that I hadn't heard named before: the "mid-sequence drop". Basically, as context windows get longer, models get worse at using information in the middle of the context. They attend heavily to the beginning and end, but stuff in the middle gets lost.

This feels related to the "attention sink" phenomenon from the other paper, there's something about transformer attention that creates these position-dependent biases. Would be interesting to see if this is a fundamental architectural limitation or something that can be trained away.

---

#### The Governance Angle

The paper spends a lot of time on what they call "temporal governance", how do you update and forget things in a controlled way? This is where it gets interesting from an ops perspective.

They talk about coordinating multiple update mechanisms:

- Continued pretraining (DAPT/TAPT)
- Parameter-efficient finetuning (PEFT/LoRA)
- Direct model editing (ROME, MEMIT, etc.)
- RAG updates

And they propose a governance framework called DMM-Gov with: admission thresholds, progressive rollout, online monitoring, reversible rollback, and audit certificates.

This is... basically a change management system for model knowledge. If you've ever dealt with database migrations or config management at scale, this should feel familiar. The challenge is that unlike a database where you can query what data exists, model parameters are opaque. You can't just `SELECT * FROM model_knowledge WHERE topic='outdated_medical_advice'`.

The model editing techniques (ROME, MEMIT) try to do targeted edits to specific facts, but they acknowledge there's tension between effectiveness, locality, and generalization. Edit one thing and you might break something else. Sounds like every complex system I've worked with tbh.

---

#### Thoughts

This paper is more academic than practical, lots of framework and taxonomy, less hands-on implementation guidance. But I think that's actually valuable? The field seems to need some standardization on how to even talk about these problems.

A few things that stood out to me:

**The write-read-inhibit chain** - they frame memory operations as write (store new info) → read (retrieve) → inhibit/update (forget or modify). This is a useful mental model. Every memory system needs all three and they're in tension with each other.

**Correctness vs faithfulness** - for external memory (RAG), they distinguish between "did you get the right answer" and "did you actually use the retrieved evidence vs making stuff up". These can diverge, model might get lucky and be correct without being faithful to sources, or vice versa. Good distinction for evaluating RAG pipelines.

**The stability-plasticity tradeoff** - updating parametric memory (via continued training) risks catastrophic forgetting. This is the classic ML problem but framed nicely in terms of memory. You want the system to learn new things without forgetting old things. No free lunch here.

Overall I'd say this is a good complement to the Li Auto paper. That one was more "here are all the techniques people use", this one is more "here's how to think about and evaluate memory systematically". If you're building something production-grade you probably need both perspectives.
