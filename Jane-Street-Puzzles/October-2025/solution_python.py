"""
Robot Baseball — Fast Solver
============================

Goal: Maximize q(p), the probability that an at‑bat reaches full count (3 balls, 2 strikes)
under optimal (expected-runs) play by both batter and pitcher.

This file is intentionally lean and fast:
 - Tight dynamic programming (tiny 5×4 grid) for values V, mixes r, and hitting probability F.
 - Efficient golden‑section search on [0,1], with an initial coarse scan to bracket the max.
 - No heavy deps (NumPy optional, but not required).

Run as a script:
    python robot_baseball_fast.py

Import as a module:
    import robot_baseball_fast as rb
    p_star, q_star = rb.solve_fast()
"""

from __future__ import annotations

from typing import Tuple
from scipy.optimize import minimize_scalar

# --- Core DP ---------------------------------------------------------------

def _equilibrium_r(A: float, B: float, p: float) -> float:
    """r = Prob(Ball) = Prob(Wait) at state (b,s).
       r = p*(4-B) / ((A-B) + p*(4-B))  with a robust zero‑denominator guard."""
    denom = (A - B) + p * (4.0 - B)
    if abs(denom) < 1e-18:
        return 0.0
    return (p * (4.0 - B)) / denom

def _q_of_p(p: float) -> float:
    """Return q(p) = P(reach 3-2 before absorption) under optimal play at parameter p."""
    # Value grid V[b][s], r[b][s];  b=0..4, s=0..3
    # First create the matrices with zeros
    V = [[0.0]*4 for _ in range(5)]
    r = [[0.0]*4 for _ in range(5)]
    # terminals
    for s in range(4):
        V[4][s] = 1.0     # walk
    for b in range(5):
        V[b][3] = 0.0     # strikeout

    # Backward induction for V and r
    for s in (2,1,0):
        # unroll b loop for tiny speedup
        for b in (3,2,1,0):
            A = V[b+1][s]
            B = V[b][s+1]
            rr = _equilibrium_r(A, B, p)
            r[b][s] = rr
            V[b][s] = B + (A - B) * rr

    # Hitting probability F[b][s]; terminals
    F = [[0.0]*4 for _ in range(5)]
    F[3][2] = 1.0
    # F[4][*] and F[*][3] remain 0

    for s in (2,1,0):
        for b in (3,2,1,0):
            if b == 3 and s == 2:
                continue
            rr = r[b][s]
            F[b][s] = (rr*rr) * F[b+1][s] + (1.0 - rr*rr - (1.0 - rr)*(1.0 - rr) * p) * F[b][s+1]

    return F[0][0]

# --- Fast maximizer --------------------------------------------------------

def _golden_max(f, a: float, b: float, tol: float = 1e-13, max_iter: int = 200) -> Tuple[float,float]:
    """Golden‑section maximization of unimodal f on [a,b]."""
    gr = (5**0.5 - 1.0) / 2.0
    c = b - gr*(b-a)
    d = a + gr*(b-a)
    fc = f(c); fd = f(d)
    it = 0
    while (b-a) > tol and it < max_iter:
        if fc < fd:
            a = c; c = d; fc = fd
            d = a + gr*(b-a); fd = f(d)
        else:
            b = d; d = c; fd = fc
            c = b - gr*(b-a); fc = f(c)
        it += 1
    x = 0.5*(a+b)
    return x, f(x)

def solve_fast() -> Tuple[float, float]:
    """Return (p*, q*) with ~12‑digit accuracy in milliseconds."""
    f = _q_of_p

    # Coarse scan to cheaply bracket the maximizer
    # (2049 samples covers [0,1] at ~5e-4 resolution)
    n = 2049
    best_p = 0.0; best_q = -1.0
    step = 1.0/(n-1)
    q_prev = f(0.0)
    for i in range(1, n):
        p = i*step
        qv = f(p)
        if qv > best_q:
            best_q, best_p = qv, p

    # Narrow bracket around best_p found by coarse scan
    left  = max(0.0, best_p - 0.05)
    right = min(1.0, best_p + 0.05)

    # Golden‑section refinement
    p_star, q_star = _golden_max(f, left, right, tol=1e-14, max_iter=250)
    return p_star, q_star

if __name__ == "__main__":

    # Direct fast solver
    p_star, q_star = solve_fast()
    print("\nDirect fast solver:")
    print(f"p*  = {p_star:.12f}")
    print(f"q*  = {q_star:.12f}")

    # Alternatively, use SciPy's minimize_scalar with bounds and method='bounded'
    # q_of_p(p) must return F(0,0) computed under optimal strategies for that p
    res = minimize_scalar(lambda p: -_q_of_p(p),
                        bounds=(0.0, 1.0), method='bounded',
                        options={'xatol': 1e-13})

    p_star = res.x
    q_star = -res.fun
    print("\nSciPy minimize_scalar:")
    print(f"p*={p_star:.12f}\nq*={q_star:.12f} \n")
