---
title: Miras: It's All Connected — Unifying Sequence Models Through Memory Objectives
description: Notes on Behrouz et al. (Google Research) — how Transformers, Mamba, Titans, and friends are all just associative memories with different loss functions, and what happens when you explore beyond the two objectives everyone uses.
paper: https://arxiv.org/abs/2504.13173
---

Just read through this paper from Google Research (Behrouz et al.) and it really clicked for me. If you've been following the Titans paper, this is essentially the theoretical framework that explains *why* all these different sequence architectures work, and more importantly, how to design new ones.

#### The Core Insight

The paper makes a simple but powerful observation. Almost every modern sequence model — Transformers, Mamba, RetNet, Titans, TTT, DeltaNet — all of them can be understood as an associative memory that's trying to learn a mapping from keys to values using some internal objective function.

They call this internal objective the "attentional bias". And here's the kinda surprising thing. Despite all the architectural diversity in the field, almost everyone is using the same two attentional biases:

1. Dot-product similarity (Hebbian learning)
2. L2 regression loss (Delta rule)

That's it. All the fancy architectures are just variations on these two objectives with different memory structures and forgetting mechanisms.

#### The Miras Framework

Miras (means "legacy" in Persian/Arabic/Turkish) is their framework for designing sequence models. Four design choices:

1. **Memory Architecture** — What stores the state? Vector, matrix, MLP, something deeper?
2. **Attentional Bias** — What's the internal objective? L2 loss, Lp loss, Huber loss, etc.
3. **Retention Gate** — How do you balance learning new stuff vs keeping old stuff? (They rename "forget gate" to "retention gate" which I think is actually more accurate.)
4. **Memory Learning Algorithm** — How do you optimize? Gradient descent, GD with momentum, Newton's method, closed-form solution?

Once you see it this way, existing architectures just fall out naturally. Linear attention? Dot product similarity + gradient descent. DeltaNet? L2 loss + gradient descent. Transformers? L2 loss + nonparametric solution (Nadaraya-Watson estimator). Titans? L2 loss + GD with momentum + MLP memory.

---

#### The Two Viewpoints

They present two ways to think about the memory update:

**FTRL (Follow-The-Regularized-Leader)**: Classic online learning framing. You're minimizing cumulative loss over all past tokens plus a regularization term for stability.

**Learning-Retaining**: You're learning from the new token while staying close to your previous state. This is the one I found more intuitive — it's basically "learn the new thing but don't forget everything else".

They prove these are equivalent under certain conditions, but Learning-Retaining is more general. The nice thing about Learning-Retaining is it makes the retention gate explicit — you can see exactly how the model trades off plasticity vs stability.

---

#### What's Actually New Here

Beyond the unifying framework, they propose several novel design choices:

**Alternative Attentional Biases:**

- **Lp loss (p ≠ 2)**: L1 gives you a "value-less" memory that only stores -1 or +1. Interesting for extreme robustness.
- **Huber loss**: Robust to outliers. They call this "memory with coping mechanism" — the model protects itself from extreme events by switching between L2 (normal) and L1 (outlier) based on how surprising the token is.
- **Robust optimization**: Explicitly optimizes for worst-case perturbations in values.

**Alternative Retention Gates:**

- **KL divergence**: Instead of L2 distance from previous state, use KL divergence. This gives you a softmax in the update rule which keeps values bounded.
- **Elastic net**: Combination of L1 and L2 regularization. Gives you both "soft forgetting" (multiply by decay) and "hard forgetting" (threshold to zero).
- **Bregman divergence**: Generalizes beyond L2 to arbitrary convex functions.

#### The Three New Models

They instantiate three specific architectures from the framework:

**Moneta**: Uses Lp attentional bias with Lq retention. The idea is that different p values change how the memory responds to error magnitudes.

**Yaad**: Uses Huber loss as attentional bias. Robust to outlier tokens — switches between L2 and L1 based on how "surprising" the token is.

**Memora**: Uses KL divergence for retention gate. The update involves softmax which keeps memory bounded and stable.

All three use a 2-layer MLP as the memory architecture (same as Titans) and gradient descent as the optimizer.

---

#### Results

The results are pretty strong. All three variants beat the baselines (Transformer++, Mamba2, DeltaNet, TTT, Gated DeltaNet) on language modeling and commonsense reasoning. More importantly:

- They scale better with context length. The retention gate choices seem to help with memory management in long sequences.
- On needle-in-haystack, they crush it. ~93% average accuracy vs 66% for TTT and 52% for Mamba2.
- Moneta is most robust to noise (makes sense given the Lp objective).

The ablation on p and q values is interesting — p=3 works best, p=4 is worst. For q, different values actually change the scaling behavior with context length, which suggests the retention gate choice matters more for long context than the attentional bias.

---

#### My Take

This paper does something I really appreciate: it takes a bunch of seemingly different architectures and shows they're all instances of the same underlying pattern. Once you see it, you can't unsee it.

From a systems perspective, the framework is basically saying: sequence models are online learning systems with a memory budget. The "attentional bias" is your consistency model (what does it mean for memory to be correct?), and the "retention gate" is your eviction policy (what do you keep vs forget when memory is full?).

The parallel training trick they use is also worth noting. The recurrence is non-linear so you can't just do a simple scan. Their workaround: divide into chunks, use the same starting state for all gradient computations within a chunk, then apply non-linearities only at chunk boundaries. It's an approximation but apparently works well enough. Similar to how we handle checkpointing in streaming systems — you don't checkpoint every event, you do it periodically and replay from there.

One thing I'd like to see explored more: what happens when you compose different objectives for different parts of the memory? Like, use L2 for "important" keys and L1 for noise. The Huber loss kinda does this dynamically but you could imagine more sophisticated routing.

Also curious how this interacts with the Titans "surprise" interpretation. They mention it briefly but don't go deep. The gradient ∇ℓ(W; k, v) is literally "how surprised is the memory by this token" — larger gradient means more surprising. The retention gate then determines how much you update based on that surprise. Feels like there's more to explore there.
