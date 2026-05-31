#!/usr/bin/env python3
"""
Deterministic generator for the Northgate Provisions Co. workshop dataset.

Northgate Provisions Co. is a fictional B2B food & beverage wholesaler supplying
outlets across the UK. This script emits THREE entities — customers (outlets),
products (SKUs) and orders (order lines) — in two flavours:

  data/clean/<entity>/<entity>.json   CLEAN curated data (Genie + Lakebase fallback)
  data/raw/<entity>/<entity>.json     RAW DIRTY data (SDP lab source) with seeded
                                      data-quality issues appended/mutated

Both are newline-delimited JSON (one object per line), the same format the SDP lab
reads from a Unity Catalog volume.

The generator is fully deterministic: a fixed RANDOM_SEED and an explicit, hand-placed
set of dirty records mean the output is byte-identical on every run, and the exact list
of seeded issues is known up front. Run it, then read the printed summary; it is mirrored
in data/README.md.

Usage:  python data/generate_data.py
        (no third-party dependencies — standard library only)
"""

import json
import os
import random
from datetime import date, timedelta

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
RANDOM_SEED = 42

NUM_CUSTOMERS = 70
NUM_ORDERS = 2200            # clean order lines; dirty file adds the seeded rows on top

# "Today" for the workshop — anything dated after this is in the future.
TODAY = date(2026, 5, 31)
HISTORY_START = date(2025, 1, 1)   # orders span this range up to TODAY (clean data)

HERE = os.path.dirname(os.path.abspath(__file__))
CLEAN_DIR = os.path.join(HERE, "clean")
RAW_DIR = os.path.join(HERE, "raw")

# Valid UK regions (the SDP silver layer validates against this set).
VALID_REGIONS = [
    "London", "South East", "South West", "East of England", "Midlands",
    "North West", "North East", "Yorkshire", "Scotland", "Wales", "Northern Ireland",
]
# Region values deliberately injected into the dirty data (NOT in VALID_REGIONS).
INVALID_REGIONS = ["EMEA", "Atlantis", "Unknown", "MARS", "n/a", "Europe"]

VALID_SEGMENTS = ["National Group", "Regional", "Independent"]

ACCOUNT_MANAGERS = [
    "Priya Sharma", "Tom Whitfield", "Aisha Bello", "Daniel O'Connor",
    "Sophie Laurent", "Marcus Reid", "Yusuf Khan",
]

# Outlet name building blocks (synthetic, branding-neutral).
NAME_PREFIX = [
    "The Crown", "Riverside", "Greenfield", "Oakwood", "Harbour", "Kings Head",
    "The Bell", "Highgate", "Maple", "Station", "The Anchor", "Ashfield",
    "Bridge Street", "Old Mill", "The Royal Oak", "Willow", "Castle", "Market Square",
    "Corner", "Hillside", "The White Hart", "Brookside", "Park Lane", "The George",
    "Elm Tree", "Victoria", "The Swan", "Clifton", "Meadow", "The Plough",
]
NAME_SUFFIX = [
    "Inn", "Café", "Stores", "Bistro", "Kitchen", "Provisions", "Deli", "Tavern",
    "Pantry", "Larder", "Brasserie", "Grill", "Coffee House", "Food Hall",
    "Convenience", "Eatery", "Wine Bar", "Diner",
]

# Product catalogue: (name, category, list_price). cost is derived from a margin band.
PRODUCT_CATALOGUE = [
    # Beverages (non-alcoholic)
    ("Sparkling Water 330ml x24", "Beverages", 8.40),
    ("Still Water 500ml x24", "Beverages", 7.20),
    ("Classic Cola 330ml x24", "Beverages", 11.50),
    ("Orange Juice 1L x12", "Beverages", 14.80),
    ("Apple Juice 1L x12", "Beverages", 13.90),
    ("Energy Drink 250ml x24", "Beverages", 19.20),
    ("Cloudy Lemonade 2L x6", "Beverages", 9.60),
    ("Cold Brew Coffee 1L x6", "Beverages", 16.50),
    # Ambient (shelf-stable)
    ("Penne Pasta 5kg", "Ambient", 9.75),
    ("Basmati Rice 10kg", "Ambient", 18.40),
    ("Chopped Tomatoes 2.5kg x6", "Ambient", 12.30),
    ("Extra Virgin Olive Oil 5L", "Ambient", 34.00),
    ("Plain Flour 16kg", "Ambient", 13.20),
    ("Granulated Sugar 25kg", "Ambient", 22.50),
    ("Baked Beans 2.6kg x6", "Ambient", 15.40),
    ("Strawberry Jam 3kg", "Ambient", 11.10),
    # Chilled
    ("Mature Cheddar 5kg", "Chilled", 41.00),
    ("Salted Butter 5kg", "Chilled", 36.50),
    ("Whole Milk 2L x6", "Chilled", 7.80),
    ("Greek Yoghurt 5kg", "Chilled", 18.90),
    ("Pork Sausages 5kg", "Chilled", 27.60),
    ("Smoked Back Bacon 2.5kg", "Chilled", 24.30),
    ("Free-Range Eggs x60", "Chilled", 16.20),
    # Frozen
    ("Garden Peas 2.5kg", "Frozen", 6.90),
    ("Battered Fish Fillets 4kg", "Frozen", 38.40),
    ("Straight-Cut Chips 5kg", "Frozen", 12.80),
    ("Vanilla Ice Cream 5L", "Frozen", 15.60),
    ("Chicken Breast Fillets 5kg", "Frozen", 44.00),
    ("Mixed Berries 2.5kg", "Frozen", 17.30),
    # Alcohol
    ("Premium Lager 330ml x24", "Alcohol", 28.80),
    ("Session IPA 500ml x12", "Alcohol", 31.20),
    ("House Red Wine 750ml x6", "Alcohol", 39.00),
    ("House White Wine 750ml x6", "Alcohol", 37.50),
    ("Prosecco 750ml x6", "Alcohol", 49.80),
]

DISCOUNT_CHOICES = [0.0, 5.0, 10.0, 15.0, 20.0]


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
def _rand_date(rng, start, end):
    """Uniform random date in [start, end] inclusive."""
    span = (end - start).days
    return start + timedelta(days=rng.randint(0, span))


def _write_ndjson(directory, filename, rows):
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, filename)
    with open(path, "w") as fh:
        for row in rows:
            fh.write(json.dumps(row) + "\n")
    return path


# ----------------------------------------------------------------------------
# Clean generators
# ----------------------------------------------------------------------------
def gen_customers(rng):
    customers = []
    used_names = set()
    for cid in range(1, NUM_CUSTOMERS + 1):
        # Build a unique outlet name.
        while True:
            name = f"{rng.choice(NAME_PREFIX)} {rng.choice(NAME_SUFFIX)}"
            if name not in used_names:
                used_names.add(name)
                break
        # Segment skew: more independents than national groups.
        segment = rng.choices(VALID_SEGMENTS, weights=[2, 3, 6])[0]
        customers.append({
            "customer_id": cid,
            "customer_name": name,
            "region": rng.choice(VALID_REGIONS),
            "segment": segment,
            "account_manager": rng.choice(ACCOUNT_MANAGERS),
            "join_date": _rand_date(rng, date(2021, 1, 1), date(2025, 12, 31)).isoformat(),
        })
    return customers


def gen_products(rng):
    products = []
    for idx, (name, category, list_price) in enumerate(PRODUCT_CATALOGUE, start=1):
        # Cost is a margin band off list price (wholesale margins are thin).
        margin = rng.uniform(0.62, 0.80)   # cost is 62-80% of list price
        cost = round(list_price * margin, 2)
        products.append({
            "product_id": f"SKU-{idx:03d}",
            "product_name": name,
            "category": category,
            "list_price": round(list_price, 2),
            "cost": cost,
            "launch_date": _rand_date(rng, date(2020, 1, 1), date(2024, 6, 30)).isoformat(),
        })
    return products


def gen_orders(rng, customers, products):
    orders = []
    customer_ids = [c["customer_id"] for c in customers]
    price_by_product = {p["product_id"]: p["list_price"] for p in products}
    product_ids = list(price_by_product.keys())

    for oid in range(1, NUM_ORDERS + 1):
        pid = rng.choice(product_ids)
        list_price = price_by_product[pid]
        # Sold price wobbles slightly around list price (+/- 8%), rounded to 2dp.
        unit_price = round(list_price * rng.uniform(0.92, 1.08), 2)
        orders.append({
            "order_id": 100000 + oid,
            "customer_id": rng.choice(customer_ids),
            "product_id": pid,
            "order_date": _rand_date(rng, HISTORY_START, TODAY).isoformat(),
            "quantity": rng.randint(1, 40),
            "unit_price": unit_price,
            "discount_pct": rng.choice(DISCOUNT_CHOICES),
            "currency": "GBP",
        })
    return orders


# ----------------------------------------------------------------------------
# Dirty injection — explicit, hand-placed, fully countable
# ----------------------------------------------------------------------------
def dirty_customers(rng, clean):
    """Return (rows, issue_counts). Clean rows are preserved; dirty rows appended/mutated."""
    rows = [dict(c) for c in clean]
    counts = {
        "invalid_region": 0,
        "segment_TEST": 0,
        "name_like_test": 0,
        "null_customer_id": 0,
    }

    # (a) invalid region values — mutate 6 existing rows in place.
    for i, cid in enumerate([3, 11, 19, 27, 38, 52]):
        rows[cid - 1]["region"] = INVALID_REGIONS[i % len(INVALID_REGIONS)]
        counts["invalid_region"] += 1

    # (b) segment = 'TEST' — append 4 obvious test outlets.
    for n in range(4):
        new_id = NUM_CUSTOMERS + 100 + n
        rows.append({
            "customer_id": new_id,
            "customer_name": f"QA Test Outlet {n + 1}",
            "region": rng.choice(VALID_REGIONS),
            "segment": "TEST",
            "account_manager": rng.choice(ACCOUNT_MANAGERS),
            "join_date": TODAY.isoformat(),
        })
        counts["segment_TEST"] += 1

    # (c) customer_name like '%test%' but with a VALID segment — append 5.
    #     (kept separate from the TEST-segment rows so both filters are exercised)
    test_names = [
        "Test Kitchen Ltd", "The Testing Tavern", "Beta Test Bistro",
        "Smoke-Test Stores", "Regression Test Deli",
    ]
    for n, nm in enumerate(test_names):
        new_id = NUM_CUSTOMERS + 200 + n
        rows.append({
            "customer_id": new_id,
            "customer_name": nm,
            "region": rng.choice(VALID_REGIONS),
            "segment": rng.choice(VALID_SEGMENTS),
            "account_manager": rng.choice(ACCOUNT_MANAGERS),
            "join_date": _rand_date(rng, date(2024, 1, 1), TODAY).isoformat(),
        })
        counts["name_like_test"] += 1

    # (d) null customer_id — append 2 rows with a missing key.
    for n in range(2):
        rows.append({
            "customer_id": None,
            "customer_name": f"{rng.choice(NAME_PREFIX)} {rng.choice(NAME_SUFFIX)}",
            "region": rng.choice(VALID_REGIONS),
            "segment": rng.choice(VALID_SEGMENTS),
            "account_manager": rng.choice(ACCOUNT_MANAGERS),
            "join_date": _rand_date(rng, date(2024, 1, 1), TODAY).isoformat(),
        })
        counts["null_customer_id"] += 1

    return rows, counts


def dirty_products(rng, clean):
    rows = [dict(p) for p in clean]
    counts = {"null_product_id": 0, "nonpositive_list_price": 0}

    # (a) null product_id — one "unknown product" row (mirrors the WithSecure shape).
    rows.append({
        "product_id": None,
        "product_name": "Unknown Product",
        "category": "Unknown",
        "list_price": 0.0,
        "cost": 0.0,
        "launch_date": None,
    })
    counts["null_product_id"] += 1

    # (b) non-positive list_price — append 2 broken catalogue rows.
    for n in range(2):
        new_idx = len(PRODUCT_CATALOGUE) + 50 + n
        rows.append({
            "product_id": f"SKU-{new_idx:03d}",
            "product_name": f"Discontinued Line {n + 1}",
            "category": rng.choice(["Beverages", "Ambient", "Chilled", "Frozen", "Alcohol"]),
            "list_price": 0.0 if n == 0 else -5.0,
            "cost": 2.0,
            "launch_date": _rand_date(rng, date(2020, 1, 1), date(2023, 1, 1)).isoformat(),
        })
        counts["nonpositive_list_price"] += 1

    return rows, counts


def dirty_orders(rng, clean, customers, products):
    rows = [dict(o) for o in clean]
    counts = {
        "duplicate_order_id": 0,
        "null_customer_id": 0,
        "null_product_id": 0,
        "nonpositive_quantity": 0,
        "discount_out_of_range": 0,
        "future_order_date": 0,
    }
    valid_customer_ids = [c["customer_id"] for c in customers]
    valid_product_ids = [p["product_id"] for p in products]
    base_id = 900000   # reserved id range for appended bad rows (won't collide with clean)
    seq = 0

    def _template():
        nonlocal seq
        seq += 1
        return {
            "order_id": base_id + seq,
            "customer_id": rng.choice(valid_customer_ids),
            "product_id": rng.choice(valid_product_ids),
            "order_date": _rand_date(rng, HISTORY_START, TODAY).isoformat(),
            "quantity": rng.randint(1, 40),
            "unit_price": round(rng.uniform(5, 50), 2),
            "discount_pct": rng.choice(DISCOUNT_CHOICES),
            "currency": "GBP",
        }

    # (a) duplicate order_ids — re-append 15 EXISTING clean rows verbatim (same order_id).
    for o in rng.sample(clean, 15):
        rows.append(dict(o))
        counts["duplicate_order_id"] += 1

    # (b) null customer_id — 8 rows.
    for _ in range(8):
        r = _template(); r["customer_id"] = None
        rows.append(r); counts["null_customer_id"] += 1

    # (c) null product_id — 7 rows.
    for _ in range(7):
        r = _template(); r["product_id"] = None
        rows.append(r); counts["null_product_id"] += 1

    # (d) non-positive quantity — 12 rows (mix of 0 and negative).
    for n in range(12):
        r = _template(); r["quantity"] = 0 if n % 2 == 0 else -rng.randint(1, 8)
        rows.append(r); counts["nonpositive_quantity"] += 1

    # (e) discount_pct outside 0-100 — 10 rows (mix of negative and >100).
    for n in range(10):
        r = _template(); r["discount_pct"] = -10.0 if n % 2 == 0 else round(rng.uniform(101, 250), 1)
        rows.append(r); counts["discount_out_of_range"] += 1

    # (f) future order_date — 9 rows dated after TODAY.
    for _ in range(9):
        r = _template()
        r["order_date"] = (TODAY + timedelta(days=rng.randint(15, 400))).isoformat()
        rows.append(r); counts["future_order_date"] += 1

    return rows, counts


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def main():
    rng = random.Random(RANDOM_SEED)

    # Clean entities (order matters for determinism: customers, products, orders).
    customers = gen_customers(rng)
    products = gen_products(rng)
    orders = gen_orders(rng, customers, products)

    # Clean files.
    _write_ndjson(os.path.join(CLEAN_DIR, "customers"), "customers.json", customers)
    _write_ndjson(os.path.join(CLEAN_DIR, "products"), "products.json", products)
    _write_ndjson(os.path.join(CLEAN_DIR, "orders"), "orders.json", orders)

    # Dirty entities (continue drawing from the same rng — still deterministic).
    d_customers, c_counts = dirty_customers(rng, customers)
    d_products, p_counts = dirty_products(rng, products)
    d_orders, o_counts = dirty_orders(rng, orders, customers, products)

    _write_ndjson(os.path.join(RAW_DIR, "customers"), "customers.json", d_customers)
    _write_ndjson(os.path.join(RAW_DIR, "products"), "products.json", d_products)
    _write_ndjson(os.path.join(RAW_DIR, "orders"), "orders.json", d_orders)

    # Report — mirror this in data/README.md.
    print("=" * 64)
    print("Northgate Provisions Co. dataset generated (deterministic, seed="
          f"{RANDOM_SEED})")
    print("=" * 64)
    print("\nCLEAN row counts:")
    print(f"  customers : {len(customers)}")
    print(f"  products  : {len(products)}")
    print(f"  orders    : {len(orders)}")
    print("\nRAW (dirty) row counts:")
    print(f"  customers : {len(d_customers)}  (+{len(d_customers) - len(customers)} dirty)")
    print(f"  products  : {len(d_products)}  (+{len(d_products) - len(products)} dirty)")
    print(f"  orders    : {len(d_orders)}  (+{len(d_orders) - len(orders)} dirty)")
    print("\nSeeded DQ issues — customers:")
    for k, v in c_counts.items():
        print(f"  {k:24s}: {v}")
    print("Seeded DQ issues — products:")
    for k, v in p_counts.items():
        print(f"  {k:24s}: {v}")
    print("Seeded DQ issues — orders:")
    for k, v in o_counts.items():
        print(f"  {k:24s}: {v}")
    total = sum(c_counts.values()) + sum(p_counts.values()) + sum(o_counts.values())
    print(f"\nTotal seeded dirty records (rows added/mutated): {total}")


if __name__ == "__main__":
    main()
