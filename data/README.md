# data/ — Northgate Provisions Co. dataset

Synthetic dataset for the workshop. **Northgate Provisions Co.** is a fictional B2B
food & beverage wholesaler supplying outlets (pubs, cafés, delis, convenience stores)
across the UK.

Everything here is produced by one deterministic, dependency-free script —
[`generate_data.py`](generate_data.py) (`RANDOM_SEED = 42`). The generated JSON is
**committed** so the bootstrap can copy it straight into a Unity Catalog volume with no
manual upload. Re-running the script is byte-for-byte reproducible.

```bash
python data/generate_data.py     # regenerate (standard library only)
```

## Two flavours

| Folder        | Purpose                                                              | Used by |
|---------------|----------------------------------------------------------------------|---------|
| `clean/`      | CLEAN curated data — no data-quality issues.                         | Genie (practical 1), Lakebase fallback, the bootstrap's shared tables. |
| `raw/`        | RAW DIRTY data — the clean rows **plus** deliberately seeded issues. | The SDP lab (practical 2) ingests this from the volume and cleans it. |

Both are **newline-delimited JSON** (one object per line), one file per entity:

```
data/clean/customers/customers.json      data/raw/customers/customers.json
data/clean/products/products.json        data/raw/products/products.json
data/clean/orders/orders.json            data/raw/orders/orders.json
```

## Row counts

| Entity    | clean | raw (dirty) | dirty rows added/mutated |
|-----------|------:|------------:|-------------------------:|
| customers |    70 |          81 |                      +11 |
| products  |    34 |          37 |                       +3 |
| orders    | 2,200 |       2,261 |                      +61 |

---

## Schema

### customers — the outlets Northgate supplies

| Column            | Type    | Notes |
|-------------------|---------|-------|
| `customer_id`     | INT     | Primary key. 1–70 in clean data. |
| `customer_name`   | STRING  | Outlet name, e.g. *"The White Hart Bistro"*. |
| `region`          | STRING  | UK region — one of: `London`, `South East`, `South West`, `East of England`, `Midlands`, `North West`, `North East`, `Yorkshire`, `Scotland`, `Wales`, `Northern Ireland`. |
| `segment`         | STRING  | `National Group`, `Regional`, or `Independent`. |
| `account_manager` | STRING  | Owning Northgate account manager. |
| `join_date`       | DATE    | When the outlet became a customer (2021–2025). |

```json
{"customer_id": 1, "customer_name": "The White Hart Bistro", "region": "Midlands", "segment": "National Group", "account_manager": "Tom Whitfield", "join_date": "2022-04-03"}
```

### products — the SKUs in the catalogue

| Column         | Type           | Notes |
|----------------|----------------|-------|
| `product_id`   | STRING         | Primary key, `SKU-001` … `SKU-034`. |
| `product_name` | STRING         | e.g. *"Sparkling Water 330ml x24"*. |
| `category`     | STRING         | `Beverages`, `Ambient`, `Chilled`, `Frozen`, or `Alcohol`. |
| `list_price`   | DECIMAL(10,2)  | Wholesale list price (GBP). |
| `cost`         | DECIMAL(10,2)  | Northgate's unit cost (62–80 % of list price). |
| `launch_date`  | DATE           | When the SKU was added (2020–2024). |

```json
{"product_id": "SKU-001", "product_name": "Sparkling Water 330ml x24", "category": "Beverages", "list_price": 8.4, "cost": 5.32, "launch_date": "2023-11-16"}
```

### orders — order lines

| Column         | Type           | Notes |
|----------------|----------------|-------|
| `order_id`     | INT            | Order-line key, `100001` … (clean). |
| `customer_id`  | INT            | FK → `customers.customer_id`. |
| `product_id`   | STRING         | FK → `products.product_id`. |
| `order_date`   | DATE           | 2025-01-01 … 2026-05-31 (clean). |
| `quantity`     | INT            | Units ordered (1–40 clean). |
| `unit_price`   | DECIMAL(10,2)  | Sold price per unit (≈ list price ±8 %). |
| `discount_pct` | DECIMAL(5,2)   | Line discount, one of {0, 5, 10, 15, 20} (clean). |
| `currency`     | STRING         | Always `GBP`. |

```json
{"order_id": 100001, "customer_id": 34, "product_id": "SKU-012", "order_date": "2025-02-09", "quantity": 7, "unit_price": 34.44, "discount_pct": 20.0, "currency": "GBP"}
```

> Line revenue = `quantity * unit_price * (1 - discount_pct/100)`.
> Line profit  = revenue − `quantity * products.cost`.
> "Today" for the workshop is **2026-05-31**.

---

## Seeded data-quality issues (RAW only)

The `clean/` files contain **none** of the below (verified: zero on every check). The
`raw/` files are the clean rows plus these deliberately seeded issues. Counts are exact
and reproducible. The SDP lab's silver layer is expected to drop / quarantine them.

### customers (raw: 81 rows)

| Issue                         | Count | How it appears |
|-------------------------------|------:|----------------|
| Invalid `region` value        |     6 | Existing rows (customer_id 3, 11, 19, 27, 38, 52) mutated to values **not** in the valid region set: `EMEA`, `Atlantis`, `Unknown`, `MARS`, `n/a`, `Europe`. |
| `segment = 'TEST'`            |     4 | Appended outlets named *"QA Test Outlet 1–4"* (customer_id 170–173). |
| `customer_name LIKE '%test%'` |  **9** | The 4 *"QA Test Outlet"* rows above **plus** 5 dedicated test-named outlets with **valid** segments (customer_id 270–274): *"Test Kitchen Ltd"*, *"The Testing Tavern"*, *"Beta Test Bistro"*, *"Smoke-Test Stores"*, *"Regression Test Deli"*. |
| Null `customer_id`            |     2 | Appended rows with `customer_id: null`. |

> **Overlap note.** The 4 `segment='TEST'` rows are named *"QA Test Outlet …"*, so they
> are **also** matched by the name filter. Hence `customer_name LIKE '%test%'` returns
> **9** (the 4 QA rows + the 5 dedicated test-named rows), while `segment = 'TEST'`
> returns **4**. These two filters overlap on exactly those 4 rows.
>
> **Row accounting.** Raw = 81 rows = 70 clean + 11 appended (4 + 5 + 2). The 6 invalid
> regions are mutations of existing rows (no new rows). So **17** of the 81 raw customer
> rows are dirty (6 mutated + 11 appended); the other 64 are pristine clean rows.

### products (raw: 37 rows)

| Issue                       | Count | How it appears |
|-----------------------------|------:|----------------|
| Null `product_id`           |     1 | Appended *"Unknown Product"* row (`product_id: null`, `list_price: 0.0`) — mirrors the original WithSecure shape. |
| `list_price <= 0`           |  **3** | 2 appended *"Discontinued Line"* rows (`SKU-084` = `0.0`, `SKU-085` = `-5.0`) **plus** the *"Unknown Product"* row above (`0.0`). |

> Overlap note: the null-`product_id` row also has `list_price = 0.0`, so a
> `list_price <= 0` filter returns **3** while a `product_id IS NULL` filter returns 1.

### orders (raw: 2,261 rows)

| Issue                          | Count | How it appears |
|--------------------------------|------:|----------------|
| Duplicate `order_id`           |    15 | 15 existing clean rows re-appended verbatim (same `order_id`) → 15 extra duplicate rows. |
| Null `customer_id`             |     8 | Appended rows with `customer_id: null`. |
| Null `product_id`              |     7 | Appended rows with `product_id: null`. |
| `quantity <= 0`                |    12 | Appended rows alternating `quantity = 0` and small negatives. |
| `discount_pct` outside 0–100   |    10 | Appended rows alternating negative (`-10.0`) and `>100` (e.g. 101–250). |
| Future `order_date`            |     9 | Appended rows dated after 2026-05-31 (15–400 days ahead). |

All appended bad order rows use `order_id` in the reserved `900001+` range (except the
duplicates, which intentionally reuse existing IDs). Total seeded order rows: **61**.

---

## Suggested silver-layer expectations (for the SDP lab)

| Table     | Expectation |
|-----------|-------------|
| customers | `customer_id IS NOT NULL`; `region IN (<valid set>)`; `segment <> 'TEST'`; `customer_name NOT ILIKE '%test%'`. |
| products  | `product_id IS NOT NULL`; `list_price > 0`. |
| orders    | `order_id IS NOT NULL`; `customer_id IS NOT NULL`; `product_id IS NOT NULL`; `quantity > 0`; `discount_pct BETWEEN 0 AND 100`; `order_date <= current_date()`; de-duplicate on `order_id`. |
