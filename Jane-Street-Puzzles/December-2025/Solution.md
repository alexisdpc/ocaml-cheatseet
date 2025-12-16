## 1. The original game’s Nash equilibrium (no leak)

Each player, after seeing their first throw \(x\in[0,1]\), chooses:

- **Keep**: final distance \(= x\)
- **Reroll**: final distance \(= \text{new } U[0,1]\) value

A very natural class of strategies is **threshold strategies**:

> keep the first throw iff \(x \ge T\), otherwise reroll.

It turns out (and we’ll see why) that in this game the best responses to threshold strategies are themselves threshold strategies, so we can search for a symmetric equilibrium of this form.

### 1.1 Opponent’s final distance distribution under threshold \(T\)
