# Blood Bank & Donor Management System (BBDMS)

A backend-first database project on Oracle 23ai built for **UCS310 — Database Management Systems**, B.Tech CSE, Thapar Institute of Engineering and Technology, Academic Year 2025–26.

---

## Project Team

| Name | Roll Number |
|---|---|
| Devansh Gupta | 1024030930 |
| Matreyi Suryan | 1024030273 |
| Ayati Gupta | 1024030477 |

**Course:** UCS310 — Database Management Systems
**Lab Instructor:** MS Damini Arora

---

## What this project is

A relational database that captures the full lifecycle of a blood unit — from donor registration and screening, through donation, component preparation, storage, and cross-match, to final issuance against a hospital request. The emphasis is on the backend layer: schema design, normalization to BCNF, SQL query logic, and PL/SQL automation.

The whole point of the project is to encode clinical safety rules (90-day donor deferral, ABO/Rh compatibility, screening-driven release, atomic issuance) directly into the database — as constraints, triggers, and procedures — instead of relying on staff vigilance.

---

## What's inside

```
bbdms/
├── README.md                       — this file
├── sql/
│   └── bbdms_rebuild.sql           — single script to recreate the entire system
├── docs/
  └── BBDMS_Final_Synopsis.docx   — full project synopsis (~25 pages)
```

---

## How to run it

The project runs on **Oracle Database 23ai Free** in a Docker container. Tested on macOS (Apple Silicon) and Linux.

### 1. Start Oracle in Docker

```bash
 open -a Docker
docker start oracle-bbdms
docker ps

```

Wait ~2 minutes for the container to become healthy:

```bash
docker ps
```

### 2. Create the bbdms user

Connect as `system` (password `BloodBank123`) using DBeaver, SQL*Plus, or any Oracle client, then run:

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;

CREATE USER bbdms IDENTIFIED BY bbdms_pwd_2025;
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO bbdms;
GRANT CREATE VIEW, CREATE PROCEDURE, CREATE TRIGGER, CREATE SEQUENCE TO bbdms;
```

### 3. Run the rebuild script

Connect as `bbdms` and execute the full `sql/bbdms_rebuild.sql` script. It drops everything (safely, with exception handling), recreates the schema, populates seed data, and creates all PL/SQL objects in dependency order.

The script ends with a health-check query showing object counts — you should see 11 tables, 10 sequences, 3 functions, 2 procedures, and 5 triggers, all valid.

---

## Schema overview

11 normalized relations in BCNF + 1 reference table for ABO/Rh compatibility:

- **`donor`** — registered donors (10 rows)
- **`donation`** — donation events (20 rows)
- **`blood_unit`** — inventory core (20 rows: 10 AVAILABLE, 10 EXPIRED)
- **`screening`** — 5-test panel per unit (20 rows)
- **`component`** — Whole Blood / PRBC / Platelets / FFP / Cryoprecipitate (5 rows)
- **`hospital`** — recipient hospitals (5 rows across 5 cities)
- **`recipient`** — patients (6 rows)
- **`request`** — open requests (5 rows)
- **`issuance`** — atomic issuances (populated by procedure)
- **`staff`** — operators by role (5 rows)
- **`audit_log`** — populated only by triggers
- **`blood_compatibility`** — ABO/Rh reference matrix (32 rows)

---

## PL/SQL components

**3 functions:**
- `calc_expiry_date(component_id, collection_date)` — deterministic expiry
- `donor_eligible(donor_id)` — 90-day rule check (returns 'TRUE'/'FALSE')
- `get_compatible_groups(recipient_group)` — comma-separated donor groups

**2 procedures:**
- `register_donor(...)` — validates age/group/gender, inserts donor
- `issue_unit(request_id, unit_id, staff_id)` — the atomic issuance core. Uses `SELECT … FOR UPDATE NOWAIT` for concurrency safety, checks compatibility via `get_compatible_groups`, inserts issuance + updates status + writes audit, all atomically.

**5 triggers:**
- `trg_donation_eligibility` — BEFORE INSERT on donation; enforces 90-day deferral
- `trg_unit_release` — AFTER UPDATE on screening; flips unit to AVAILABLE on all-negative tests
- `trg_audit_donor` — AFTER INSERT/UPDATE on donor
- `trg_audit_unit` — AFTER INSERT/UPDATE on blood_unit
- `trg_audit_issuance` — AFTER INSERT on issuance

---

## Demo: end-to-end issuance

```sql
BEGIN
    issue_unit(p_request_id => 1, p_unit_id => 13, p_staff_id => 4);
END;
/
```

This issues unit 13 (PRBC, B+, donated by Rohan Desai on 2025-06-22) against request 1 (Patient Ramesh, O+ recipient at Apollo Hospitals). The procedure:

1. Acquires row-level lock on unit 13 via `FOR UPDATE NOWAIT`
2. Verifies status is AVAILABLE
3. Checks B+ → O+ compatibility
4. Inserts the issuance row
5. Updates unit status to ISSUED
6. Writes an audit_log entry
7. Commits

A second attempt on the same unit fails with `ORA-20011: Unit status is ISSUED; only AVAILABLE units can be issued` — the foundation of the system's transactional safety.

---

## Tech stack

- **DBMS:** Oracle Database 23ai Free
- **Container:** Docker (image: `gvenzl/oracle-free:23-slim`)
- **Client:** DBeaver Community Edition
- **Languages:** SQL (Oracle dialect), PL/SQL
- **OS:** macOS (Apple Silicon)

---

## Project documentation

The full project synopsis (`docs/BBDMS_Final_Synopsis.docx`) covers:

- Problem statement and motivation
- ER design, schema, and normalization to BCNF
- SQL implementation with sample queries
- PL/SQL implementation with full source listings
- Transaction management and concurrency control
- Development journey and bugs encountered
- Limitations and future enhancements

---

## License

Educational use only. Not for production deployment.
