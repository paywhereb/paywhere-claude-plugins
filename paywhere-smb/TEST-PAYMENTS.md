# TEST-PAYMENTS.md — synthetic inline recipients for exercising the rails

Fixture data for manually testing `make_ach_payment` / `make_wire_payment` /
`make_batch_payment` against a **non-mock** Paywhere-compatible backend —
i.e. `PAYWHERE_BASE_URL` pointed at a real sandbox/UAT deployment instead of
the seeded demo mock bank. That environment has no pre-configured
`recipientRef`/saved-payee registry to resolve a name against (`list_saved_payees`
would come back empty), so every payee below is given as **inline** recipient
details instead of a `recipientId`.

This is unrelated to `/demo-setup` and the Meridian dataset (`DATASET.md`) —
that world is a self-contained mock bank with its own saved payees keyed by
name. Use *this* file when you need to hit rails that actually validate a
payment request end-to-end.

## Safety notes — read before using

- **Synthetic data.** Every name, account number, and routing number below is
  invented for this file. The routing numbers pass the standard ABA checksum
  (so format validation accepts them) but deliberately start with `00` — a
  prefix no Federal Reserve district has ever been assigned — so they can't
  collide with a real institution's actual routing number.
- **Sandbox/UAT only — never production.** ACH and Wire generally do **not**
  verify that the recipient name matches the account on file; a same-day
  processor will attempt the transfer against whatever account number you
  give it. Only point these fixtures at a test/sandbox banking backend, never
  a live production one.
- **Nothing moves without human approval regardless.** With `PROPOSE_ONLY_SENDS`
  on (the default), these tools only stage a proposal and return a
  `/confirm/:id/:nonce` link — a person still has to approve with a passkey
  or TOTP before any of this executes. Amounts below are kept small ($1–$5)
  as a second layer of caution.
- **`fromAccountNumber` is yours to fill in** — it's whatever account you're
  testing under on the target backend (`list_accounts` will list it), not a
  fixture value.

## ACH test payees

| Name | ABA (routing) | Account number | Account type | Email | Amount |
|---|---|---|---|---|---|
| Nimbus | `001000012` | `4001000011` | Checking | nimbus@example.test | $1.00 |
| Comet | `001000025` | `4001000022` | Savings | comet@example.test | $2.00 |
| Juniper | `001000038` | `4001000033` | Checking | juniper@example.test | $1.50 |
| Pixel | `001000041` | `4001000044` | Checking | pixel@example.test | $3.00 |
| Marble | `001000054` | `4001000055` | Savings | marble@example.test | $2.50 |

Maps to `make_ach_payment`'s / a batch `ach` item's `recipient` block:
`{ name, aba, accountNumber, accountType, emailAddress }`.

## Wire test payees

| Name | Account number | Account type | Recipient address | Bank name | Bank ABA | Bank address | Amount |
|---|---|---|---|---|---|---|---|
| Falcon | `5002000011` | Checking | 100 Test St, Springfield, IL 62701 | Sandbox National Bank | `001000067` | 1 Sandbox Plaza, Springfield, IL 62701 | $5.00 |
| Ember | `5002000022` | Checking | 200 Test Ave, Austin, TX 78701 | Harbor Trust Bank N.A. | `001000070` | 2 Harbor Way, Austin, TX 78701 | $4.00 |
| Cobalt | `5002000033` | Savings | 300 Test Blvd, Denver, CO 80202 | Meridian Test Bank | `001000083` | 3 Meridian Row, Denver, CO 80202 | $3.50 |

Maps to `make_wire_payment`'s / a batch `wire` item's `recipient` +
`recipientBank` blocks.

## Ready-to-use `make_batch_payment` payload

Swap in your own `fromAccountNumber` (source account on the target backend),
then pass this as the `payments` array — mixed ACH + Wire, one approval gate:

```json
[
  {
    "rail": "ach",
    "fromAccountNumber": "<your-account-number>",
    "recipient": {
      "name": "Nimbus",
      "aba": "001000012",
      "accountNumber": "4001000011",
      "accountType": "Checking",
      "emailAddress": "nimbus@example.test"
    },
    "paymentAmount": 1.00,
    "paymentName": "Test payment - Nimbus"
  },
  {
    "rail": "ach",
    "fromAccountNumber": "<your-account-number>",
    "recipient": {
      "name": "Comet",
      "aba": "001000025",
      "accountNumber": "4001000022",
      "accountType": "Savings",
      "emailAddress": "comet@example.test"
    },
    "paymentAmount": 2.00,
    "paymentName": "Test payment - Comet"
  },
  {
    "rail": "wire",
    "fromAccountNumber": "<your-account-number>",
    "amount": 5.00,
    "recipient": {
      "name": "Falcon",
      "accountNumber": "5002000011",
      "accountType": "Checking",
      "address1": "100 Test St",
      "city": "Springfield",
      "state": "IL",
      "postalCode": "62701"
    },
    "recipientBank": {
      "name": "Sandbox National Bank",
      "aba": "001000067",
      "address1": "1 Sandbox Plaza",
      "city": "Springfield",
      "state": "IL",
      "postalCode": "62701"
    }
  }
]
```

Add more items from the tables above the same way — up to 50 per batch.

## Trigger prompt

Point Claude at a non-demo/sandbox Paywhere connector, then just say:

> Pay Nimbus, Comet, and Falcon their TEST-PAYMENTS.md amounts from
> `<your-account-number>`, one batch, inline recipients.

Or, for the whole set: "Pay everyone in TEST-PAYMENTS.md from
`<your-account-number>`, one batch, inline recipients."
