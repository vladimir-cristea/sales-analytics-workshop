# data/ - Northgate Provisions Co. dataset

Synthetic dataset for the workshop. **Northgate Provisions Co.** is a fictional B2B food &
beverage wholesaler supplying outlets (pubs, cafés, delis, convenience stores) across the UK.

Everything here is produced by one deterministic, dependency-free script -
[`generate_data.py`](generate_data.py) (`RANDOM_SEED = 42`). The generated JSON is committed
so the bootstrap can copy it straight into a Unity Catalog volume with no manual upload.
Re-running the script is byte-for-byte reproducible.

```bash
python data/generate_data.py     # regenerate (standard library only)
```

## Two flavours

| Folder   | Purpose                                                              | Used by |
|----------|----------------------------------------------------------------------|---------|
| `clean/` | Clean curated data, no data-quality issues.                          | Genie, Lakebase fallback, the bootstrap's shared tables. |
| `raw/`   | Raw dirty data: the clean rows plus deliberately seeded issues.      | The SDP topic ingests this from the volume and cleans it. |

Both are newline-delimited JSON (one object per line), one file per entity:

```
data/clean/customers/customers.json      data/raw/customers/customers.json
data/clean/products/products.json        data/raw/products/products.json
data/clean/orders/orders.json            data/raw/orders/orders.json
```

## Schema

### customers - the outlets Northgate supplies

| Column            | Type    | Notes |
|-------------------|---------|-------|
| `customer_id`     | INT     | Primary key. |
| `customer_name`   | STRING  | Outlet name, e.g. *"The White Hart Bistro"*. |
| `region`          | STRING  | UK region from a fixed set (`London`, `South East`, `South West`, `East of England`, `Midlands`, `North West`, `North East`, `Yorkshire`, `Scotland`, `Wales`, `Northern Ireland`). |
| `segment`         | STRING  | `National Group`, `Regional`, or `Independent`. |
| `account_manager` | STRING  | Owning Northgate account manager. |
| `join_date`       | DATE    | When the outlet became a customer. |

```json
{"customer_id": 1, "customer_name": "The White Hart Bistro", "region": "Midlands", "segment": "National Group", "account_manager": "Tom Whitfield", "join_date": "2022-04-03"}
```

### products - the SKUs in the catalogue

| Column         | Type           | Notes |
|----------------|----------------|-------|
| `product_id`   | STRING         | Primary key, `SKU-001` onwards. |
| `product_name` | STRING         | e.g. *"Sparkling Water 330ml x24"*. |
| `category`     | STRING         | `Beverages`, `Ambient`, `Chilled`, `Frozen`, or `Alcohol`. |
| `list_price`   | DECIMAL(10,2)  | Wholesale list price (GBP). |
| `cost`         | DECIMAL(10,2)  | Northgate's unit cost (62-80% of list price). |
| `launch_date`  | DATE           | When the SKU was added. |

```json
{"product_id": "SKU-001", "product_name": "Sparkling Water 330ml x24", "category": "Beverages", "list_price": 8.4, "cost": 5.32, "launch_date": "2023-11-16"}
```

### orders - order lines

| Column         | Type           | Notes |
|----------------|----------------|-------|
| `order_id`     | INT            | Order-line key. |
| `customer_id`  | INT            | FK to `customers.customer_id`. |
| `product_id`   | STRING         | FK to `products.product_id`. |
| `order_date`   | DATE           | |
| `quantity`     | INT            | Units ordered. |
| `unit_price`   | DECIMAL(10,2)  | Sold price per unit (around list price ±8%). |
| `discount_pct` | DECIMAL(5,2)   | Line discount, a whole-number percentage. |
| `currency`     | STRING         | Always `GBP`. |

```json
{"order_id": 100001, "customer_id": 34, "product_id": "SKU-012", "order_date": "2025-02-09", "quantity": 7, "unit_price": 34.44, "discount_pct": 20.0, "currency": "GBP"}
```

> Line revenue = `quantity * unit_price * (1 - discount_pct/100)`.
> Line profit = revenue - `quantity * products.cost`.
> The dataset's reference "today" (the anchor for recency and rolling-window metrics) is
> **2026-05-31**.

## Data quality

The `clean/` files are clean. The `raw/` files are the same rows with deliberate quality
issues seeded in, for the SDP practical's silver layer to find and handle. Inspecting the raw
data and working out what to do about it is part of that exercise.
