# October 2025 - Robot Baseball

The pitcher can either throw a ball or a strike, while the batter can either wait or swing.\
Here is the table with the different possibilities:

| Batter \\ Pitcher | Ball                    | Strike                                  |
|:------------------|:-----------------------:|:----------------------------------------:|
| **Wait**          | $A \equiv V(b+1, s)$     | $B \equiv V(b, s+1)$                      |
| **Swing**         | $B \equiv V(b, s+1)$     | $D \equiv 4p + (1 - p) V(b, s+1)$        |



- If $p$ is too small, swinging at a strike is nearly costless; the pitcher then prefers strikes, pushing counts towards 2 strikes before 3 balls — so full counts are rare.

- If $p$ is too large, swinging at a strike often ends the at-bat immediately with a Home Run — again suppressing the chance to reach full count.

- At the critical point  $p^* \approx 0.227$, the batter’s threat of a Home Run is just strong enough to induce more balls earlier (raising balls before strikes) but not so strong that at-bats end too quickly with Home Runss. That trade-off peaks the full-count probability near 29.6%.


<img width="755" height="837" alt="graphviz" src="https://github.com/user-attachments/assets/10c74118-2e15-4c60-8ec7-03bb5c50b81d" />

## Appendix: Optimal mixed strategies

In a 2x2 zero-sum game with a payoff matrix

|  | $C_1$                | $C_2$                               |
|:------------------|:-----------------------:|:----------------------------------------:|
| $R_1$         | $a$     | $b)$                      |
| $R_2$         | $c$     | $d$        |

The value of the game (for the row player, here the batter) under mixed strategies can be computed using the formula:

$$\boxed{
v = \frac{ad-bc}{(a-b) + (d-c)}
}$$

