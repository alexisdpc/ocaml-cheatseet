## 🎄 Day 1: Secret Entrance

The Elves have good news and bad news.

The **good news** is that they've discovered project management! This has given them the tools they need to prevent their usual Christmas emergency. For example, they now know that the North Pole decorations need to be finished soon so that other critical tasks can start on time.

The **bad news** is that they've realized they have a different emergency: according to their resource planning, none of them have any time left to decorate the North Pole!

To save Christmas, the Elves need you to finish decorating the North Pole by **December 12th**.

---

### ⭐ Puzzles and Stars

Collect stars by solving puzzles.

- Two puzzles will be made available on each day.
- The second puzzle is unlocked when you complete the first.
- Each puzzle grants **one star**.

Good luck!

---

### 🔐 The Secret Entrance

You arrive at the secret entrance to the North Pole base ready to start decorating. Unfortunately, the password seems to have been changed, so you can't get in. A document taped to the wall helpfully explains:

> "Due to new security protocols, the password is locked in the safe below.  
> Please see the attached document for the new combination."

The safe has a dial with only an arrow on it; around the dial are the numbers **0 through 99** in order. As you turn the dial, it makes a small click noise as it reaches each number.

The attached document (your puzzle input) contains a **sequence of rotations**, one per line, which tell you how to open the safe.

A rotation:

- Starts with an **`L`** or **`R`**  
  - `L`: rotate to the left (toward lower numbers)  
  - `R`: rotate to the right (toward higher numbers)
- Followed by a **distance value**, indicating how many clicks the dial should be rotated in that direction.

---

### 🔄 Dial Mechanics

Examples:

- If the dial were pointing at `11`, a rotation of `R8` would cause the dial to point at `19`.
- After that, a rotation of `L19` would cause it to point at `0`.

Because the dial is a circle:

- Turning the dial **left from `0` one click** makes it point at `99`.
- Turning the dial **right from `99` one click** makes it point at `0`.

Another example:

- If the dial were pointing at `5`, a rotation of `L10` would cause it to point at `95`.
- After that, a rotation of `R5` would cause it to point at `0`.

The dial **always starts** by pointing at **`50`**.

---

### 🔑 Actual Password Logic (Part One)

You *could* follow the instructions, but your recent required official North Pole secret entrance security training seminar taught you that the safe is actually a **decoy**.

The actual password is:

> The number of times the dial is left pointing at **0** after any rotation in the sequence.

---

### 📄 Example Rotations

Suppose the attached document contained the following rotations:

```text
L68
L30
R48
L5
R60
L55
L1
L99
R14
L82
```


## --- Part Two: Method 0x434C49434B ---

You're sure that's the right password, but the door won't open.  
You knock, but nobody answers. You build a snowman while you think.

As you're rolling the snowballs for your snowman, you find another security document that must have fallen into the snow:

> "Due to newer security protocols, please use password method `0x434C49434B` until further notice."

You remember from the training seminar that **“method `0x434C49434B`”** means you're actually supposed to:

> Count the number of times **any click** causes the dial to point at `0`,  
> whether that happens **during** a rotation or **at the end** of one.

---

### 🔄 Updated Counting Rules

Using the same rotations as in the earlier example, the dial now points at `0` a few extra times during its rotations:

1. The dial starts by pointing at `50`.
2. The dial is rotated `L68` to point at `82`; **during this rotation, it points at `0` once**.
3. The dial is rotated `L30` to point at `52`.
4. The dial is rotated `R48` to point at `0`.
5. The dial is rotated `L5` to point at `95`.
6. The dial is rotated `R60` to point at `55`; **during this rotation, it points at `0` once**.
7. The dial is rotated `L55` to point at `0`.
8. The dial is rotated `L1` to point at `99`.
9. The dial is rotated `L99` to point at `0`.
10. The dial is rotated `R14` to point at `14`.
11. The dial is rotated `L82` to point at `32`; **during this rotation, it points at `0` once**.

In this example:

- The dial points at `0` **three times at the end** of a rotation.
- And **three more times during** a rotation.

So, with method `0x434C49434B`, the new password in this example would be **`6`**.

---

### ⚠️ A Tricky Edge Case

Be careful:

> If the dial were pointing at `50`, a single rotation like `R1000` would cause the dial to point at `0` **ten times** before returning back to `50`!

---

### 🧩 Your Task (Part Two)

> Using password method **`0x434C49434B`**,  
> **what is the password to open the door?**


