# Infrastructure safety

The proof of concept runs inside cloud accounts that already hold the operator's
own live infrastructure. Those pre-existing resources are unrelated to this
project and are not disposable.

## Rule

Never delete, resize, rebuild, power off, rename, or reassign a cloud resource
this project did not create. This holds even when a resource looks idle,
untagged, wrongly named, or expensive.

At the time of writing, the DigitalOcean account used for the temporary
deployment experiment contains pre-existing instances belonging to separate,
unrelated projects. Treat every account this project touches the same way.

## How the rule is enforced

Before any write or destroy operation against a provider:

1. **Record a baseline.** Run read-only discovery and write down every resource
   that already exists, with its identifier. Do this before the first write call
   of the session, not after.
2. **Tag what you create.** Every instance this project provisions carries the
   tag `vpn-gcore-experiment`. An untagged instance is somebody else's.
3. **Destroy only by tag, never by scope.** A destroy is permitted only when the
   target carries the experiment tag and is absent from the baseline. Never use
   an account-wide or region-wide bulk delete.
4. **Fail closed.** If the baseline is missing, the identifier is ambiguous, or
   the discovered resource count does not match what the operator expects, stop
   and ask. A wrong stop costs a minute; a wrong delete costs someone's server.
5. **Confirm before the irreversible step.** Destroy operations require explicit
   confirmation naming the specific resource.

## Where the details live

Baselines contain live public addresses and account identifiers, so they stay in
private mode-600 files outside this repository and are never committed, pasted
into an issue, or published. This document records the rule; it does not record
the resources.

The code that enforces the rule is a different matter. `scripts/do-guard.sh`
holds the decision logic — what counts as protected, what payload gets the
experiment tag, and the only sanctioned destroy path — and is committed,
reviewed, and tested. Safety-critical logic that nobody can review is not a
safeguard. It reads the private baseline from `DO_PROTECTED_IDS`; with no
baseline present, every Droplet is treated as protected.
