# 26. kaidb overview

kaidb is a small, self contained database engine written in Zig. It speaks SQL,
stores your data durably on a single machine, and ships as two binaries: `kaidb`
(the server) and `kaidb-cli` (a command line client). A Kyte application talks to
it through the same `Connection` and `Driver` vocabulary you already use for the
other databases in [Chapter 20](20-database-drivers.md), using the `kyte-kaidb`
driver package covered in [Chapter 29](29-kaidb-driver.md).

This chapter explains what kaidb is, where it fits, and how to run the server. The
next three chapters cover the SQL it supports, the CLI, and connecting from Kyte.

> **A note on names.** The product is kaidb. The storage engine underneath is still
> called btree, and a few older spellings survive in the code and on the wire: the
> server prints the NovaDB name, the connection scheme is `novadb://`, the data file
> is `nova.db`, the environment variables are prefixed `NOVADB_`, and the admin
> subcommands are spelled `novadb backup`, `novadb restore`, and so on. These are all
> the same system. Read `novadb` as a legacy spelling of kaidb wherever you see it.

## What kaidb is

kaidb is an **index organised** engine. A table is physically its own primary key
B+Tree, and the full row lives in the leaf next to its key. There is no separate
heap. A lookup or a range scan by primary key therefore does strictly less I/O than
a heap based engine would, because finding the key and reading the row are the same
descent.

On top of that clustered store, kaidb adds the machinery you expect from a real
database:

- **MVCC** (multi version concurrency control), so readers see a consistent snapshot
  and do not block writers. Row versions are kept inline, with an undo log for older
  versions.
- **A write ahead log** with doublewrite and a committed set sidecar, so a crash in
  the middle of a write recovers cleanly to the last committed state.
- **Secondary indexes**, single column or composite, with order preserving keys so
  that range scans and `ORDER BY` can walk the index in order.
- **A cost based planner** that picks index scans, index only aggregates, and, for
  joins, nested loop versus hash join by estimated cost.

There is also a document mode (a MongoDB style collection API over BSON) which we
touch on at the end of this chapter.

## Where kaidb fits

kaidb is at its best as a **single node store for bounded, mostly steady workloads**:
configuration, control plane state, workload specifications, leases, membership,
manifests, and application data that comfortably fits one machine. It was built as
the control plane store for the Kyte orchestrator, and that is the role it is
verified in. It gives you durability, MVCC, and a familiar SQL surface without a
separate database server to operate.

Be honest with yourself about the ceiling. kaidb is a single node engine. It is not
(yet) a general purpose, large scale OLTP or document store: a very wide secondary
index read pays a per row descent back into the clustered base tree, and scans past
the size of the buffer pool fall back to synchronous reads. The practical remedy for
the read heavy cases, a covering composite index, is described in
[Chapter 27](27-kaidb-sql.md). For a workload that fits one machine and values simple
operations and durable storage, kaidb is a good fit. For sharded, multi node,
high churn OLTP at very large scale, reach for a dedicated database.

## Running the server

The server binary is `kaidb`. With no configuration file present it boots on all
defaults, so a fresh install just runs:

```sh
kaidb
```

Configuration lives in a `db.json` file in the working directory. Every field has a
shipped default, so you only set what you want to change. The defaults are:

| Setting | Default | Meaning |
| --- | --- | --- |
| `address` | `127.0.0.1` | Interface the listeners bind to. |
| wire `port` | `3009` | The binary protocol port (SQL clients and the Kyte driver). |
| HTTP `port` | `3008` | Health and metrics endpoints. |
| `base_dir` | `data` | Directory holding `nova.db` and the `wal/` folder. |
| `mode` | `relational` | `relational` (SQL) or `document` (NoSQL). |
| TLS `enabled` | `false` | Whether the wire port requires TLS. |
| `durability.synchronous_commit` | `false` | Whether a commit waits for the WAL flush. |
| `pool_size` | `0` | Buffer pool pages; `0` means auto size to about half of RAM. |

A minimal `db.json` that moves the data directory and turns on synchronous commit
looks like this:

```json
{
  "base_dir": "/var/lib/kaidb",
  "durability": { "synchronous_commit": true }
}
```

### Server modes

kaidb runs in one of two modes, chosen by the `mode` field:

- **`relational`** (the default) serves SQL over the wire protocol and rejects
  document operations. This is the mode the Kyte driver and `kaidb-cli` use.
- **`document`** serves the MongoDB style collection API and rejects SQL frames.

A server is one mode or the other for its lifetime, so pick the mode that matches how
your application talks to it.

### Health and metrics

Alongside the wire port, kaidb serves a small HTTP surface on the HTTP port for
operations:

- `GET /healthz` : liveness.
- `GET /readyz` : readiness.
- `GET /metrics` : Prometheus metrics, for example `kaidb_mmap_borrow_serves_total`.

### Admin subcommands

The `kaidb` binary also runs offline maintenance tasks. These operate directly on the
data directory, so run them when the server for that directory is stopped (or against
a copy):

```sh
# Compact a data file.
novadb compact <src> <dst>

# Take a hot backup. base_dir must directly contain nova.db and wal/.
novadb backup <base_dir> <dest_dir>

# Restore, with optional point in time recovery.
novadb restore <snapshot_dir> <dest_base_dir> [--archive=<dir>] [--target-lsn=<N>]

# Rotate a user's password offline.
novadb passwd <base_dir> <user> <newpassword>
```

> These subcommands keep the legacy `novadb` spelling. They are part of the same
> `kaidb` binary.

## The document mode in brief

When started in `document` mode, kaidb exposes MongoDB style collections. Documents
are BSON, and the operations include creating a collection, inserting one or many
documents, finding by filter (an empty filter `{}` matches everything), finding one,
counting, updating and deleting by filter, creating a secondary index on a field path
such as `price` or `address.city`, cursor based pagination, and atomic multi document
transactions with begin, commit, and rollback.

Document mode is a distinct server mode and is not reached through the SQL driver.
The rest of this section of the guide focuses on the relational surface, which is what
a typical Kyte web application uses.

## Where to go next

- [Chapter 27, kaidb SQL reference](27-kaidb-sql.md): the exact SQL kaidb supports.
- [Chapter 28, the kaidb CLI](28-kaidb-cli.md): running queries from the terminal.
- [Chapter 29, connecting from Kyte](29-kaidb-driver.md): the `kyte-kaidb` driver.
