# Kite Bucket Manager

A lightweight Bash-based tool for creating and managing **portfolio allocation buckets** using target weights for different stocks.

> **Important:** This script manages buckets locally. It does **not** create or modify Zerodha Kite's native Basket Orders, since those baskets aren't exposed through the Kite Connect API.

## Features

* Create a new bucket
* Update an existing bucket
* Upsert a bucket in a single command
* View a bucket
* List all buckets
* Delete a bucket
* Validate that stock weights add up to exactly 100%
* Store bucket definitions as simple JSON files

## Requirements

* macOS or Linux
* Bash
* `awk`

No Python or additional packages are required.

## Installation

Save the script as:

```text
bucket.sh
```

Make it executable:

```bash
chmod +x bucket.sh
```

Optionally put it somewhere in your `PATH`:

```bash
mkdir -p ~/.local/bin
cp bucket.sh ~/.local/bin/
```

Then make sure `~/.local/bin` is in your `PATH`.

## Storage

By default, buckets are stored in:

```text
~/.kite-buckets/
```

For example:

```text
~/.kite-buckets/
├── Long_Term.json
├── Aggressive.json
└── Dividend.json
```

You can change the storage location using `BUCKET_DIR`:

```bash
BUCKET_DIR="$HOME/my-buckets" ./bucket.sh list
```

## Commands

### Upsert a bucket

The primary operation is `upsert`.

If the bucket doesn't exist, it is created.

If it already exists, its allocation is replaced with the supplied allocation.

```bash
./bucket.sh upsert "Long Term" \
  RELIANCE=25 \
  HDFCBANK=20 \
  INFY=15 \
  ICICIBANK=15 \
  TCS=10 \
  ITC=15
```

The weights must add up to **100%**.

The resulting bucket will look like:

```json
{
  "name": "Long Term",
  "weights": {
    "RELIANCE": 25,
    "HDFCBANK": 20,
    "INFY": 15,
    "ICICIBANK": 15,
    "TCS": 10,
    "ITC": 15
  }
}
```

### Update an existing bucket

There is no separate update command.

Simply run `upsert` again:

```bash
./bucket.sh upsert "Long Term" \
  RELIANCE=30 \
  HDFCBANK=20 \
  INFY=15 \
  ICICIBANK=15 \
  TCS=10
```

The previous allocation is replaced.

The new total must still equal 100%.

### View a bucket

```bash
./bucket.sh get "Long Term"
```

Example:

```json
{
  "name": "Long Term",
  "weights": {
    "RELIANCE": 30,
    "HDFCBANK": 20,
    "INFY": 15,
    "ICICIBANK": 15,
    "TCS": 10
  }
}
```

### List buckets

```bash
./bucket.sh list
```

Example:

```text
Long_Term
Aggressive
Dividend
```

### Delete a bucket

```bash
./bucket.sh delete "Long Term"
```

This permanently deletes the local bucket definition.

## Weight Validation

Every bucket must have allocations totaling 100%.

This works:

```bash
./bucket.sh upsert "Example" \
  RELIANCE=40 \
  HDFCBANK=30 \
  INFY=20 \
  TCS=10
```

Total:

```text
40 + 30 + 20 + 10 = 100%
```

This fails:

```bash
./bucket.sh upsert "Example" \
  RELIANCE=40 \
  HDFCBANK=30 \
  INFY=20
```

because:

```text
40 + 30 + 20 = 90%
```

The script will return an error instead of creating the bucket.

Decimal weights are supported:

```bash
./bucket.sh upsert "Example" \
  RELIANCE=33.33 \
  HDFCBANK=33.33 \
  INFY=33.34
```

## Bucket Names

Bucket names can contain spaces:

```bash
./bucket.sh upsert "My Retirement Portfolio" \
  RELIANCE=25 \
  HDFCBANK=25 \
  INFY=25 \
  TCS=25
```

The name is sanitized when used as the filename.

For example:

```text
My Retirement Portfolio
```

becomes:

```text
My_Retirement_Portfolio.json
```

## Environment Variables

### `BUCKET_DIR`

Controls where bucket files are stored.

Default:

```bash
$HOME/.kite-buckets
```

Example:

```bash
export BUCKET_DIR="$HOME/portfolio-buckets"
```

Then:

```bash
./bucket.sh list
```

will use:

```text
~/portfolio-buckets/
```

## Typical Workflow

Create your target portfolio:

```bash
./bucket.sh upsert "Core Equity" \
  RELIANCE=20 \
  HDFCBANK=20 \
  ICICIBANK=15 \
  INFY=15 \
  TCS=10 \
  LT=10 \
  ITC=10
```

Check it:

```bash
./bucket.sh get "Core Equity"
```

Later, change the allocation:

```bash
./bucket.sh upsert "Core Equity" \
  RELIANCE=25 \
  HDFCBANK=20 \
  ICICIBANK=15 \
  INFY=15 \
  TCS=10 \
  LT=5 \
  ITC=10
```

List all portfolios:

```bash
./bucket.sh list
```

## What This Script Does NOT Do

Currently, the script only manages the **target allocation**.

It does not:

* Connect to Zerodha
* Read current holdings
* Fetch stock prices
* Calculate current portfolio weights
* Calculate rebalance quantities
* Place BUY orders
* Place SELL orders
* Modify Zerodha Basket Orders
* Execute trades automatically

For example, this bucket:

```text
RELIANCE   25%
HDFCBANK   20%
INFY       15%
ICICIBANK  15%
TCS        10%
ITC        15%
```

only describes the **desired state**.

## Future Rebalancing

The natural next step is to add a command such as:

```bash
./bucket.sh rebalance "Core Equity"
```

which could:

1. Read the bucket's target weights.
2. Fetch current Zerodha holdings.
3. Fetch current market prices.
4. Calculate the current portfolio value.
5. Calculate target rupee values.
6. Calculate BUY/SELL quantities.
7. Show the proposed trades.
8. Optionally place the trades through Kite Connect.

A safer version would support:

```bash
./bucket.sh rebalance "Core Equity" --dry-run
```

to show something like:

```text
Current portfolio: ₹10,25,000

Target allocation:

RELIANCE    25%    ₹2,56,250
HDFCBANK    20%    ₹2,05,000
INFY        15%    ₹1,53,750
ICICIBANK   15%    ₹1,53,750
TCS         10%    ₹1,02,500
ITC         15%    ₹1,53,750

Proposed trades:

BUY   RELIANCE     12 shares
SELL  INFY          8 shares
BUY   ICICIBANK     5 shares

DRY RUN — no orders placed.
```

That would turn this from a simple bucket-definition tool into a **portfolio rebalancing tool** while keeping the bucket itself independent of Zerodha's native Basket feature.
