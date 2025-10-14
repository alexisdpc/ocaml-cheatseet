
# October 2025 - Robot Baseball

The pitcher can either throw a ball or a strike, while the batter can either wait or swing.\
Here is the table with the different possibilities:

| Batter \\ Pitcher | Ball                    | Strike                                  |
|:------------------|:-----------------------:|:----------------------------------------:|
| **Wait**          | $A \equiv V(b+1, s)$     | $B \equiv V(b, s+1)$                      |
| **Swing**         | $B \equiv V(b, s+1)$     | $D \equiv 4p + (1 - p) V(b, s+1)$        |

Let the pitcher throw Ball with probability $x$ and the batter Wait with probability $y$.
In equilibrium the batter must be indifferent between Wait and Swing, and the pitcher indifferent between Ball and Strike. 
This yields the same expression for both players (equilibrium probability):

$$ x = y = r(b,s) =  \frac{D-B}{(A-2B+D)} = \frac{p(4-B)}{(A-B)+p(4-B)}  $$

where $A \equiv V(b+1, s)$  and $B \equiv V(b, s+1)$.

The value of the stage game (and hence of the state) is then (see appendix for the general 2×2 zero-sum formula)

$$ V(b,s) = B + (A-B)\frac{p(4-B)}{(A-B)+p(4-B)}  $$

for nonterminal
$(b,s)$. Boundary cases: 
$V(4,s)=1$, 
$V(b,3)=0$.
This recursion uniquely determines 
$V(b,s)$ for all 
$(b,s)$ once 
$p$ is fixed.

At a nonterminal state $(b,s)$ we have the following transition probabilities (where $r$ depends on the state $r(b,s)$:

$$ {\rm Pr}( (b,s) \to (b+1,s) \ = r^2 $$ 

$$ {\rm Pr}( {\rm HR}) = (1-r^2) p  $$ 

Everything else moves to $(b,s+1)$, so

$$ {\rm Pr}()$$

Let F(b,s) be the probability that play starting from 
(b,s) ever reaches 
(3,2) before ending (walk, strikeout, or HR), thenwe have that:

$$ F $$ 

and the boundary conditions:

$$ F $$

Finally, $q(p)=F(0,0)$ is the desired probability (starting from 0–0) that an at-bat ever hits full count under optimal play. Quad-A wants to choose $p$ that maximizes $q(p)$.

- If $p$ is too small, swinging at a strike is nearly costless; the pitcher then prefers strikes, pushing counts towards 2 strikes before 3 balls — so full counts are rare.

- If $p$ is too large, swinging at a strike often ends the at-bat immediately with a Home Run — again suppressing the chance to reach full count.

- At the critical point  $p^* \approx 0.227$, the batter’s threat of a Home Run is just strong enough to induce more balls earlier (raising balls before strikes) but not so strong that at-bats end too quickly with Home Runss. That trade-off peaks the full-count probability near 29.6%.


<img width="500" height="554" alt="graphviz" src="https://github.com/user-attachments/assets/10c74118-2e15-4c60-8ec7-03bb5c50b81d" />

## Appendix: Optimal mixed strategies

In a 2x2 zero-sum game with a payoff matrix

|  | $C_1$                | $C_2$                               |
|:------------------|:-----------------------:|:----------------------------------------:|
| $R_1$         | $a$     | $b$                      |
| $R_2$         | $c$     | $d$        |

At a mixed equilibrium the column player chooses the parameters that makes the row player indifferent between 
$R_1$ and $R_2$ (otherwise the row player would put all probability on the better row). The value of the game (for the row player, here the batter) under mixed strategies can be computed using the formula:

$$\boxed{
v = \frac{ad-bc}{(a-b) + (d-c)}
}$$


