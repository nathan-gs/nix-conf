# Complexity: Home Assistant on StarRocks instead of MariaDB

**Verdict: Not feasible without significant custom work. Estimated effort: very high, ongoing maintenance burden.**

## What we're currently running

- MariaDB with a `hass` database, connected via unix socket
- `purge_keep_days = 3650` (10 years of history retained)
- 16 GB InnoDB buffer pool — heavily tuned for write-heavy OLTP
- Custom nightly cleanup job (`home-assistant-states-cleanup`) using MariaDB-specific SQL (JOIN-DELETE, `UNIX_TIMESTAMP`, `OPTIMIZE TABLE`)
- `mysqldump`-based backup
- HA Python stack uses `mysqlclient` (libmysqlclient binding)

## What StarRocks is

StarRocks is a **columnar OLAP database** (MPP architecture, inspired by Doris/Apache Impala). It exposes a MySQL-compatible wire protocol, which makes it look attractive for this kind of migration. It is designed for analytical queries over large datasets — aggregations, joins, time-series scans — not for the high-frequency, low-latency small writes that HA's recorder does.

---

## Blockers

### 1. Home Assistant does not support StarRocks

HA's recorder component officially supports **SQLite, MySQL/MariaDB, and PostgreSQL** only. The supported backends are hard-coded in the recorder's dialect detection (`homeassistant/components/recorder/db_schema.py`, `util/`). StarRocks would be detected as MySQL (same wire protocol) but immediately runs into incompatibilities at the SQL dialect layer.

There is no community workaround or custom component for StarRocks support. This is a fundamental blocker that would require patching HA core or maintaining a fork.

### 2. SQLAlchemy dialect incompatibility

HA uses SQLAlchemy's ORM and generates SQL targeting MySQL. StarRocks has a community SQLAlchemy dialect (`sqlalchemy-starrocks`) but it is incomplete and not integrated into HA's dependency tree. Even if wired up:

- HA's MySQL dialect emits `INSERT IGNORE`, `REPLACE INTO`, and `ON DUPLICATE KEY UPDATE` — the last two have different semantics or are unsupported in StarRocks.
- StarRocks does not support `AUTO_INCREMENT` columns in the same way; it uses sequence functions or manual ID management.
- HA schema migrations use Alembic via `alembic_version` tables; StarRocks DDL semantics (especially `ALTER TABLE`) differ significantly.

### 3. DML limitations in StarRocks

StarRocks has **three table models**, each with different mutation support:

| Model | INSERT | UPDATE | DELETE |
|---|---|---|---|
| Duplicate Key (default) | Yes | No | No (only full partition drop) |
| Aggregate Key | Yes | No | No |
| Primary Key | Yes | Yes | Yes (by PK only) |

HA's recorder does:
- High-frequency INSERTs (every state change, ~seconds)
- `UPDATE states SET last_reported_ts = ...` (partial updates by PK)
- `DELETE FROM states WHERE last_updated_ts < ...` (range deletes, not PK-bounded)
- `DELETE FROM state_attributes WHERE attributes_id NOT IN (...)` (orphan cleanup)

Primary Key tables support point DELETEs, but **range DELETEs** (by timestamp) require either a partition drop or a scan-and-delete that is orders of magnitude slower than MariaDB's indexed DELETE. HA's cleanup SQL uses multi-table JOINs in DELETE statements which StarRocks does not support at all.

### 4. Transaction semantics

MariaDB provides full ACID transactions. StarRocks offers "micro-batch" commits on Primary Key tables with eventual visibility — individual row-level transactions are not guaranteed to be visible immediately. HA's recorder relies on transactional consistency (e.g., rolling back a state write if the attributes write fails). This would require significant work to either disable or work around.

### 5. Custom cleanup SQL is incompatible

The `home-assistant-states-cleanup` service uses:

```sql
DELETE s FROM states s LEFT JOIN state_attributes ON ... LEFT JOIN states_meta ON ...
WHERE s.last_updated_ts < UNIX_TIMESTAMP(...)
```

StarRocks does not support multi-table DELETE syntax (`DELETE t1 FROM t1 JOIN t2`). This would need to be rewritten as a CTE-based or subquery approach, but StarRocks's Primary Key DELETE only accepts `WHERE` clauses on primary key columns or via `DELETE FROM ... WHERE <non-pk-column>` in newer versions (3.0+) with limitations.

`OPTIMIZE TABLE` is also unsupported — StarRocks manages compaction internally.

### 6. Unix socket connection

StarRocks only accepts TCP/IP connections. The current `db_url` uses `unix_socket=/run/mysqld/mysqld.sock`. This is a minor change (switch to `mysql://hass:...@127.0.0.1:9030/hass`) but requires a new secret and firewall consideration.

### 7. NixOS packaging

StarRocks is **not in nixpkgs**. It would need a custom package derivation. StarRocks ships as a large (~1 GB) pre-built binary distribution (JVM + native code); building from source is complex. This alone adds significant maintenance overhead — each StarRocks update requires manual packaging work.

### 8. Python connector

HA uses `mysqlclient` (C extension binding to libmysqlclient). StarRocks works with standard MySQL connectors at the protocol level, so `mysqlclient` would likely connect. However, the dialect mismatch issues above mean protocol compatibility alone is not sufficient.

---

## What StarRocks would actually be good for here

StarRocks's strength is analytical queries over the HA history data — e.g., "sum of energy consumption per device over the last year, grouped by hour." The long-term statistics HA writes to `statistics` and `statistics_short_term` are exactly the kind of aggregation-friendly data StarRocks handles well. The `states` table (high-write, frequent deletes) is not.

A more realistic architecture would be:
- Keep MariaDB for HA recorder (OLTP writes)
- ETL the `statistics` table into StarRocks periodically for analytical dashboards
- Query StarRocks from Grafana for long-range energy/sensor analysis

This is much less work and plays to each system's strengths.

---

## Effort estimate

| Area | Work |
|---|---|
| StarRocks NixOS package | 2–4 days (binary packaging, service module, upgrade path) |
| HA recorder compatibility shim | Unknown (requires patching HA core; may break on every HA update) |
| Schema migration | 3–5 days (schema translation, Primary Key model decisions, test data migration) |
| Cleanup SQL rewrite | 1–2 days (port multi-table DELETE to StarRocks-compatible form) |
| Backup replacement (mysqldump → stream export) | 1 day |
| Testing / validation | 1–2 weeks (10 years of history, validate no data loss) |
| Ongoing maintenance | High (HA updates that touch recorder internals, StarRocks packaging updates) |

**Total: 4–6 weeks of initial work + high ongoing burden.**

Compare to the current setup which is zero ongoing maintenance (MariaDB is stable in nixpkgs, HA has first-class support).

---

## Recommendation

**Do not migrate.** StarRocks is the wrong database for HA's write pattern. The MySQL wire protocol compatibility is superficial — the storage semantics, DML restrictions, and transaction model are incompatible with how HA's recorder operates.

If the motivation is **faster long-range history queries** (e.g., energy dashboards over years of data): consider a lighter approach like TimescaleDB (PostgreSQL extension, HA supports PostgreSQL) or simply improving MariaDB indexing. TimescaleDB in particular is designed for exactly this workload and HA would treat it as plain PostgreSQL.

If the motivation is **reducing MariaDB resource use**: the 16 GB buffer pool in `mariadb.nix` could be tuned down, or a switch to PostgreSQL (smaller footprint, better vacuum behavior) explored — both have zero compatibility risk.
