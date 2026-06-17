---
title: Cognitive Memory in Large Language Models — A Distributed Systems Perspective
description: Notes on a survey from Li Auto — and why the LLM memory problem looks a lot like distributed systems problems I've worked on before.
paper: https://arxiv.org/html/2504.02441v1
---

#### The Core Problem

LLMs are stateless. Every request comes in, gets processed, response goes out, and the model forgets everything. Sound familiar? It's basically how we used to build web services before we figured out we needed sessions and state management.

The paper frames this through a cognitive science lens — sensory memory, short-term memory, long-term memory. But when I read through it, I kept seeing parallels to problems I've worked on before.

---

#### KV Cache as a Buffer Management Problem

The KV cache section was probably the most interesting to me. Transformers store key-value pairs during inference to avoid recomputing attention for previous tokens. As context gets longer, this cache grows linearly and becomes a memory bottleneck. The strategies for managing it are basically the same playbook we use in streaming systems:

- **LRU eviction** — literally the same algorithm we use everywhere.
- **Attention sink** — models always attend heavily to the first few tokens regardless of semantic importance, so you always keep those in cache. Weird behavior but apparently it stabilizes generation quality.
- **Scoring-based eviction** — rank tokens by importance (attention score) and evict low scorers. We do similar things when deciding what to spill to disk vs keep in memory.

There's also work on offloading KV cache to CPU memory or even disk, with prefetching strategies. This is just tiered storage with extra steps.

#### Text-based Memory = Event Sourcing?

The text-based memory section talks about storing conversation history and summaries in external databases. The way they describe "memory acquisition" (deciding what to store) and "memory management" (updates, conflict resolution) sounds a lot like event sourcing patterns.

They even discuss handling contradictory memories — one approach is keeping conflicting memories around because context matters. This is eventually consistent systems thinking applied to AI.

#### The Retrieval Problem

Memory is useless if you can't find what you need. The paper covers: full text search, SQL queries on metadata, semantic search via embeddings, tree-based hierarchical search, and hash-based lookup (LSH). In practice most systems probably need a combination — the same conclusion we reach in data platforms. No single query pattern fits all use cases.

---

#### What's Missing (IMO)

- **Durability and recovery** — not much discussion on what happens when things fail. If you're storing memories in external systems, how do you handle partial failures? What's the consistency model?
- **Multi-tenancy** — in production you're serving many users. How do you isolate memories? What are the resource allocation strategies? This matters a lot for cost.
- **Latency budgets** — retrieval adds latency to every request. The paper doesn't quantify acceptable tradeoffs. In streaming we obsess over p99 latency; would be nice to see similar rigor here.

#### Random Thought

The "forgetting curve" for memory decay is modeled as exponential decay with a strength parameter — every time a memory is accessed, strength goes up and the decay timer resets. This is basically TTL with access-based refresh. We do this all the time in caching layers.

---

#### Wrapping Up

Overall a solid survey if you want to understand the landscape of LLM memory research. The cognitive framing is interesting but I found it more useful to think about it through distributed systems primitives. At the end of the day we're talking about state management, caching, retrieval, and consistency — problems that have been around forever.

The main difference is that "importance" of data is harder to define. In traditional systems you know what's hot based on access patterns. In LLMs, what's "important" depends on semantic relevance to future queries, which is quite hard to predict. That's where all the attention-based scoring and embedding similarity stuff comes in.

Anyway, if you work on infra and are curious about LLMs, worth skimming at least.
