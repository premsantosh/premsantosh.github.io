---
title: SimpleMem: Efficient Lifelong Memory for LLM Agents
description: Notes on Liu et al. (UNC Chapel Hill) — a three-stage memory pipeline that trades write-time compression for read-time efficiency, with multi-view indexing and adaptive retrieval planning.
paper: https://arxiv.org/abs/2601.02553
---

This paper (Liu et al., UNC Chapel Hill) caught my attention because it's tackling the exact problem I've been thinking about: how do you build a memory system for an LLM agent that doesn't blow up in cost as conversations get longer?

#### The Problem Statement

Current approaches fall into two camps:

1. **Full context extension**, where you just keep everything in the context window. Works but you're paying for a ton of redundant tokens. Think about how much of a typical conversation is "Hey!", "Sounds good!", "Talk later!". Zero information content but you're paying for it on every inference.
2. **Iterative reasoning**, where you use the LLM to filter what's relevant at query time. Better relevance but now you're doing multiple inference calls per query.

Neither approach is efficient. The paper frames this as an information density problem: you want to maximize useful information per token.

---

#### The SimpleMem Architecture

Three stage pipeline:

#### Stage 1: Semantic Structured Compression

This is where they filter and transform raw dialogue into compact "memory units" at write time.

**Semantic density gating** uses the LLM itself to judge whether a dialogue window contains useful information. If it's just greetings, discard it entirely. No explicit threshold tuning either. They frame it as an instruction-following task where empty output = nothing worth remembering.

**De-linearization transformation** converts messy dialogue into clean, self-contained facts. This includes:

- Coreference resolution ("my kids" → "Sarah's kids")
- Temporal normalization ("yesterday" → "2023-07-01")
- Atomization (break complex statements into individual facts)

The output is context-independent memory units. Each one should be understandable without needing the surrounding conversation.

This feels like the right tradeoff. You're paying LLM tokens at write time, but you're doing it once per conversation turn. Compared to paying at read time where you might query the same memory hundreds of times.

#### Stage 2: Online Semantic Synthesis

This is basically compaction for memories. Instead of storing three separate entries like "User wants coffee", "User prefers oat milk", "User likes it hot", you'd consolidate into: "User prefers hot coffee with oat milk".

They call it "online" because it happens during the write phase, not as a background job. Related memory units get merged before they're committed to storage.

The analogy to log compaction in Kafka or LSM compaction in databases is pretty direct here. You're trading write amplification for read efficiency. The difference is the "merge function" is semantic rather than key-based. You're merging things that are conceptually related, not just things with the same key.

#### Stage 3: Intent-Aware Retrieval Planning

This is the read path. Instead of fixed top-k retrieval, they use the LLM to analyze the query and generate a retrieval plan:

<code>{q<sub>sem</sub>, q<sub>lex</sub>, q<sub>sym</sub>, d}</code> ~ P(q, H)

Where:

- <code>q<sub>sem</sub></code> = semantic query (for embedding similarity)
- <code>q<sub>lex</sub></code> = lexical query (for BM25/keyword matching)
- <code>q<sub>sym</sub></code> = symbolic query (for metadata filtering)
- <code>d</code> = estimated depth/complexity

The depth parameter <code>d</code> determines how many results to fetch. Simple lookups get small k, complex multi-hop questions get larger k.

They then query all three indexes in parallel and union the results with deduplication. No fancy fusion scoring, just set union. Simple but apparently effective.

---

#### The Multi-View Indexing

This is the part I found most interesting from a data systems perspective. Each memory unit gets indexed three ways:

1. **Semantic layer**: dense embeddings for fuzzy matching ("latte" matches "hot drink")
2. **Lexical layer**: sparse BM25 for exact keyword/entity matching
3. **Symbolic layer**: structured metadata (timestamps, entity types) for deterministic filtering

This is basically the same insight that drove hybrid search in vector databases. Dense embeddings are great for semantic similarity but terrible for rare proper nouns or exact matches. Sparse retrieval (BM25) handles those cases well. And sometimes you just want a SQL WHERE clause on metadata.

The retrieval planner decides which combination of indexes to use based on the query. If someone asks "what did I do last Tuesday?", you probably want to lean heavy on the symbolic layer for the timestamp filter. If they ask "what's my favorite kind of coffee?", semantic similarity is more important.

---

#### Results

The numbers are pretty compelling:

- **26.4% F1 improvement** over Mem0 on LoCoMo benchmark
- **30x token reduction** vs full context approaches
- **4x faster total time** vs Mem0 (construction + retrieval)
- **12x faster** vs A-Mem

The ablation study is useful too. Removing semantic compression hurts temporal reasoning the most (56.7% drop). Removing online synthesis hurts multi-hop reasoning (31.3% drop). Removing intent-aware retrieval hurts open-domain and single-hop queries.

Each component is doing something different and they're all contributing.

---

#### What I Like

**Write-time investment pays off at read-time.** This is a classic systems tradeoff and they're on the right side of it for this use case. Memories get written once but read many times. Spending tokens to clean and compress at write time amortizes over all future reads.

**The filtering happens at the source.** In streaming systems we call this "filter early, filter often". Don't ingest garbage and then try to clean it up later. SimpleMem discards low-information dialogue before it ever hits the memory store.

**Adaptive retrieval based on query complexity.** This is smarter than fixed top-k. A simple "what's my name?" query doesn't need 20 retrieved memories. A complex "compare what I said about project X in January vs March" might need more context.

**Multi-view indexing without complex fusion.** They just do set union instead of trying to learn optimal weights for combining scores. Less tuning, fewer failure modes.

---

#### Questions I Have

**How does the semantic gating work in practice?** They're using the LLM to judge "is this informative?" but the examples in the paper are pretty clear-cut. What about borderline cases? What's the false positive/negative rate on information filtering?

**Compaction conflicts?** When you're merging related memories, how do you handle contradictions? If I said I like oat milk last month but almond milk this week, what happens? The paper mentions prioritizing recent memories but doesn't go deep on conflict resolution.

**Cross-session synthesis.** The online synthesis happens within a session. What about consolidating patterns across sessions? Like noticing that the user asks about coffee every morning. That seems like it needs a different mechanism.

**Cold start for retrieval planning.** The intent-aware planner uses the LLM to estimate query complexity. But that's another LLM call before you even start retrieving. For simple queries, is that overhead worth it? Maybe you want a fast path for obviously simple queries.
