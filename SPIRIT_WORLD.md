# The Tiffin Route — Spirit-World Rules (Cosmology)

A short, authored set of rules for how the night-world works. Keep these
consistent in any new dialogue. The player never reads this document; it leaks
into the game only through a few threaded lines (see the end).

## The Sight
- Some people can *see* — perceive the lingering dead. It is not a power so much
  as an inheritance and a temperament: an attentiveness to the unsaid.
- The player has it because **Babulal**, their grandfather, had it. He ran the
  same route for forty years, delivering more than food without quite naming it.
- The Sight only switches on at night, in the lantern-city — the same streets as
  the day-world, lit differently, walked by those who haven't finished leaving.

## What a Spirit Is
- A spirit is not a whole person. It is a person reduced to **one unfinished
  delivery** — a single thing they meant to say or do and didn't.
- The five arcs are literal about this: a letter (Mehta), a phone call (Raju),
  a form (Desai), a word through a door (Arjun), a train ticket home (Champa).
- Everyone else — the peacefully finished — has already gone on and cannot be
  seen. Only the *unsaid* stays lantern-bright.

## The Deliveryman's Role
- The player cannot fix a life or reverse a death. They can only do what a
  dabbawala does: **carry a thing from where it is stuck to where it belongs.**
- Resolution is never "healing" in a tidy sense. It is helping someone set a
  heavy thing down. Sometimes (Desai) the loss still happens; the point is that
  it stops *spreading*.

## Moving On
- "Moving on" is not vanishing in triumph. It is the quiet act of **putting the
  tin down** — the lantern is not blown out, it is *lowered gently*.
- Grief in the player (the GRIEF stat) grows by witnessing this. It is treated
  as competence, not damage: the more you've carried, the steadier your hands.

## Neglect and Hardening (stakes)
- A spirit reached in time gets a warm homecoming. A spirit left waiting too
  many nights (see `DECAY_DAYS` in `GameState.gd`) does not disappear — it
  **hardens**: the ache calcifies into a cold, resigned quiet.
- Hardened spirits can *still* be resolved, but only bittersweetly (the
  `spirit_hardened` trees). Nothing is ever permanently lost; but lateness has
  a cost that cannot be fully undone.

## The Protagonist's Own Delivery
- The last spirit is **Babulal himself**. His one unfinished delivery was his
  goodbye to the player. The finale reverses the whole game: for once the
  deliveryman *receives* instead of carries, and then sets that down too.

## Threaded into dialogue (so the world feels authored)
- Mrs. Mehta (`spirit_intro`): "You're one of the ones who can see. Your
  grandfather could too" + the GRIEF interjection stating the rule of the Sight.
- Every `spirit_hardened` tree: the neglect/hardening rule, in the spirit's own
  resigned voice.
- Babulal's `finale`: "moving on = putting the tin down," and the reversal of
  the deliveryman finally receiving a delivery.
