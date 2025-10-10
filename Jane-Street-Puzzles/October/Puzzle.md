# October 2025 - Robot Baseball

The pitcher can either throw a ball or a strike, while the batter can either wait or swing.\
Here is the table with the different possibilities:

| Batter \\ Pitcher | Ball                    | Strike                                  |
|:------------------|:-----------------------:|:----------------------------------------:|
| **Wait**          | $A \equiv V(b+1, s)$     | $B \equiv V(b, s+1)$                      |
| **Swing**         | $B \equiv V(b, s+1)$     | $D \equiv 4p + (1 - p) V(b, s+1)$        |


<img width="755" height="837" alt="graphviz" src="https://github.com/user-attachments/assets/10c74118-2e15-4c60-8ec7-03bb5c50b81d" />
