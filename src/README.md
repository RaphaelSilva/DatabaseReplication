# Database Replication Testing

This directory contains tools to test and validate PostgreSQL replication.

## Test Script: `test_replication.py`

A comprehensive Python script that validates database replication by performing concurrent read/write operations and verifying data consistency.

### Features

- ✅ **Schema Creation**: Automatically creates a test table with indexes
- ✅ **Replica Verification**: Confirms replicas are in recovery mode (read-only)
- ✅ **Concurrent Operations**: Performs simultaneous writes to primary and reads from replicas
- ✅ **Data Consistency**: Validates that replicated data matches the primary
- ✅ **Performance Metrics**: Measures read throughput for each replica
- ✅ **Replication Lag**: Reports replication delay for each replica

### Prerequisites

1. Install `uv` (if not already installed):
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

2. Install dependencies:
```bash
# Run from project root
uv sync
```

3. Ensure environment variables are set (loaded from `.env` file):
   - `POSTGRES_PASSWORD`: PostgreSQL password
   - `PRIMARY_IP`: IP address of the primary database
   - `REPLICA_1_IP`: IP address of first replica
   - `REPLICA_2_IP`: IP address of second replica (optional)

### Usage

#### Basic Test (1000 writes, 1000 reads)
```bash
cd /home/my-ubuntu/projects/DatabaseReplication
source .env
uv run src/test_replication.py
```

#### Custom Number of Operations
```bash
# 5000 writes and 10000 reads
uv run src/test_replication.py --writes 5000 --reads 10000
```

#### Adjust Replication Wait Time
```bash
# Wait 5 seconds for replication to propagate
uv run src/test_replication.py --wait 5
```

#### All Options
```bash
uv run src/test_replication.py --writes 2000 --reads 5000 --wait 3
```

### Command-Line Arguments

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `--writes` | int | 1000 | Number of write operations to perform |
| `--reads` | int | 1000 | Number of read operations to perform |
| `--wait` | int | 2 | Seconds to wait for replication after writes |

### What the Script Tests

1. **Connection Setup**: Establishes connection pools to primary and all replicas
2. **Schema Creation**: Creates `replication_test` table with:
   - `id` (serial primary key)
   - `test_data` (varchar 255)
   - `created_at` (timestamp)
   - `random_value` (integer)
3. **Replica Status**: Verifies each replica is in recovery mode using `pg_is_in_recovery()`
4. **Replication Lag**: Measures delay using `pg_last_xact_replay_timestamp()`
5. **Write Operations**: Inserts records into primary database
6. **Concurrent Reads**: Distributes read operations across all replicas using thread pool
7. **Data Consistency**: Compares data between primary and replicas
8. **Performance Metrics**: Reports throughput (reads/second) for each replica

### Output Example

```
======================================================================
DATABASE REPLICATION TEST
======================================================================
Primary: 192.168.1.100
Replicas: 192.168.1.101, 192.168.1.102
Write operations: 1000
Read operations: 1000
======================================================================

Setting up database connection pools...
✓ Primary pool created: 192.168.1.100
✓ Replica pool created: 192.168.1.101
✓ Replica pool created: 192.168.1.102

Creating test schema...
✓ Test table 'replication_test' created successfully

Verifying replica status...
✓ 192.168.1.101 is in recovery mode (replica)
  Replication lag: 0.05 seconds
✓ 192.168.1.102 is in recovery mode (replica)
  Replication lag: 0.03 seconds

Writing 1000 records to primary database...
  Written 100/1000 records...
  Written 200/1000 records...
  ...
✓ Successfully wrote 1000 records

Waiting 2 seconds for replication to propagate...

Performing 1000 concurrent read operations across replicas...
✓ 192.168.1.101: 500 reads in 1.23s (406.50 reads/s)
✓ 192.168.1.102: 500 reads in 1.18s (423.73 reads/s)

Verifying data consistency across all databases...
✓ 192.168.1.101: Data is consistent
✓ 192.168.1.102: Data is consistent

======================================================================
TEST SUMMARY
======================================================================
Total writes: 1000
Total reads: 1000
Data consistency: ✓ PASS

Read Performance by Replica:
  192.168.1.101:
    - Successful reads: 500
    - Time: 1.23s
    - Throughput: 406.50 reads/s
  192.168.1.102:
    - Successful reads: 500
    - Time: 1.18s
    - Throughput: 423.73 reads/s
======================================================================
```

### How It Ensures Reads Come From Replicas

The script verifies reads come from replica instances by:

1. **Recovery Mode Check**: Uses `pg_is_in_recovery()` to confirm each database is a replica
   - Returns `true` for replicas (read-only, receiving WAL)
   - Returns `false` for primary (read-write)

2. **Separate Connection Pools**: Maintains distinct connection pools for each replica
   - Each pool connects directly to a specific replica IP
   - Reads are distributed across these pools

3. **Replication Lag Monitoring**: Measures `pg_last_xact_replay_timestamp()`
   - Only available on replicas
   - Shows how far behind the primary each replica is

### Troubleshooting

#### Error: "POSTGRES_PASSWORD environment variable not set"
```bash
# Make sure .env file exists and is loaded
source .env
# Or export manually
export POSTGRES_PASSWORD="your_password"
```

#### Error: "No replica IPs configured"
```bash
# Ensure replica IPs are set in .env
export REPLICA_1_IP="192.168.1.101"
export REPLICA_2_IP="192.168.1.102"
```

#### Replication lag is high
- Check network connectivity between primary and replicas
- Verify `max_wal_senders` and `max_replication_slots` settings
- Review PostgreSQL logs for replication errors

#### Data consistency fails
- Increase `--wait` parameter to allow more time for replication
- Check replica status with `SELECT * FROM pg_stat_replication;` on primary
- Verify `wal_level = replica` in postgresql.conf

### Integration with Existing Scripts

You can add this test to your deployment workflow:

```bash
# In scripts/run.sh, add a new command:
"test_replication")
    cd ./src
    source ../.env
    python test_replication.py --writes 1000 --reads 2000
    cd ../
    ;;
```

Then run:
```bash
./scripts/run.sh test_replication
```
