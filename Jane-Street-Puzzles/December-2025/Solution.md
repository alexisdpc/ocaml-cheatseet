## 1. The original game’s Nash equilibrium (no leak)

Each player, after seeing their first throw \(x\in[0,1]\), chooses:

- **Keep**: final distance $= x$
- **Reroll**: final distance $= \text{new } U[0,1]$ value

A very natural class of strategies is **threshold strategies**:

- keep the first throw iff $x \ge T$, otherwise reroll.

It turns out (and we’ll see why) that in this game the best responses to threshold strategies are themselves threshold strategies, so we can search for a symmetric equilibrium of this form.

### 1.1 Opponent’s final distance distribution under threshold $T$

Let the opponent use threshold $T$:

- First throw $Y_1 \sim U[0,1]$.
- If $Y_1 \ge T$, keep $Y_1$.
- If $Y_1 < T$, reroll to $Y_2 \sim U[0,1]$.

Let $V$ be their final distance.

Density of $V$:

- For $v \in [0,T)$: only comes from rerolls (probability $T$), each with uniform density $1$:

$$
f_V(v) = T\quad (0 \le v < T)
$$

- For $v \in [T,1]$: comes from both rerolls and keeps:

$$
f_V(v) = T + 1 \quad (T \le v \le 1)
$$

(It integrates to $1$: $\int_0^T T dv + \int_T^1 (T+1) dv = T^2 + (T+1)(1-T) = 1$.)

CDF:

$$
F_V(x) =
\begin{cases}
Tx & 0 \le x < T \\
T^2 + (T+1)(x - T) = (1+T)x - T & T \le x \le 1.
\end{cases}
$$

Expected value:

$$
\mathbb{E}[V] = \int_0^T vT\,dv + \int_T^1 v(T+1)\,dv
= \frac{1 + T - T^2}{2}.
$$

So

$$
1 - \mathbb{E}[V] = \frac{1 - T + T^2}{2}.
$$
