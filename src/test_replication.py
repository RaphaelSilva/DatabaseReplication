#!/usr/bin/env python3
"""
Database Replication Test Script

This script tests PostgreSQL replication by:
1. Creating a test schema and table
2. Writing data to the primary database
3. Reading data from replica databases concurrently
4. Verifying that reads come from replica instances
"""

import argparse
from pathlib import Path
import random
import string
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
import os
import sys
import time
from typing import List, Dict, Tuple
import psycopg2
import psycopg2.pool
from psycopg2.extras import RealDictCursor

try:
    from dotenv import load_dotenv
    DOTENV_AVAILABLE = True
except ImportError:
    DOTENV_AVAILABLE = False


@dataclass
class DatabaseConfig:
    """Database connection configuration"""
    host: str
    port: int
    database: str
    user: str
    password: str
    role: str  # 'primary' or 'replica'


class ReplicationTester:
    """Test database replication setup"""
    
    def __init__(self, primary_config: DatabaseConfig, replica_configs: List[DatabaseConfig]):
        self.primary_config = primary_config
        self.replica_configs = replica_configs
        self.primary_pool = None
        self.replica_pools = []
        
    def setup_connections(self):
        """Initialize connection pools"""
        print("Setting up database connection pools...")
        
        # Primary connection pool
        self.primary_pool = psycopg2.pool.SimpleConnectionPool(
            1, 10,
            host=self.primary_config.host,
            port=self.primary_config.port,
            database=self.primary_config.database,
            user=self.primary_config.user,
            password=self.primary_config.password
        )
        print(f"✓ Primary pool created: {self.primary_config.host}")
        
        # Replica connection pools
        for replica_config in self.replica_configs:
            replica_pool = psycopg2.pool.SimpleConnectionPool(
                1, 10,
                host=replica_config.host,
                port=replica_config.port,
                database=replica_config.database,
                user=replica_config.user,
                password=replica_config.password
            )
            self.replica_pools.append((replica_config, replica_pool))
            print(f"✓ Replica pool created: {replica_config.host}")
    
    def close_connections(self):
        """Close all connection pools"""
        if self.primary_pool:
            self.primary_pool.closeall()
        for _, pool in self.replica_pools:
            pool.closeall()
        print("All connection pools closed.")
    
    def create_test_schema(self):
        """Create test table in the database"""
        print("\nCreating test schema...")
        
        conn = self.primary_pool.getconn()
        try:
            with conn.cursor() as cur:
                # Drop table if exists
                cur.execute("DROP TABLE IF EXISTS replication_test CASCADE;")
                
                # Create test table
                cur.execute("""
                    CREATE TABLE replication_test (
                        id SERIAL PRIMARY KEY,
                        test_data VARCHAR(255) NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        random_value INTEGER NOT NULL
                    );
                """)
                
                # Create index for better performance
                cur.execute("""
                    CREATE INDEX idx_replication_test_created_at 
                    ON replication_test(created_at);
                """)
                
                conn.commit()
                print("✓ Test table 'replication_test' created successfully")
        except Exception as e:
            conn.rollback()
            print(f"✗ Error creating schema: {e}")
            raise
        finally:
            self.primary_pool.putconn(conn)
    
    def verify_replica_status(self) -> bool:
        """Verify that replicas are in recovery mode (read-only)"""
        print("\nVerifying replica status...")
        
        all_valid = True
        for replica_config, replica_pool in self.replica_pools:
            conn = replica_pool.getconn()
            try:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    # Check if database is in recovery mode
                    cur.execute("SELECT pg_is_in_recovery() as in_recovery;")
                    result = cur.fetchone()
                    
                    if result['in_recovery']:
                        print(f"✓ {replica_config.host} is in recovery mode (replica)")
                        
                        # Get replication lag
                        cur.execute("""
                            SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) 
                            AS lag_seconds;
                        """)
                        lag_result = cur.fetchone()
                        lag = lag_result['lag_seconds'] if lag_result['lag_seconds'] else 0
                        print(f"  Replication lag: {lag:.2f} seconds")
                    else:
                        print(f"✗ {replica_config.host} is NOT in recovery mode!")
                        all_valid = False
            except Exception as e:
                print(f"✗ Error checking replica status for {replica_config.host}: {e}")
                all_valid = False
            finally:
                replica_pool.putconn(conn)
        
        return all_valid
    
    def write_data(self, num_records: int) -> List[int]:
        """Write test data to primary database"""
        print(f"\nWriting {num_records} records to primary database...")
        
        conn = self.primary_pool.getconn()
        inserted_ids = []
        
        try:
            with conn.cursor() as cur:
                for i in range(num_records):
                    test_data = ''.join(random.choices(string.ascii_letters + string.digits, k=50))
                    random_value = random.randint(1, 1000000)
                    
                    cur.execute("""
                        INSERT INTO replication_test (test_data, random_value)
                        VALUES (%s, %s)
                        RETURNING id;
                    """, (test_data, random_value))
                    
                    inserted_id = cur.fetchone()[0]
                    inserted_ids.append(inserted_id)
                    
                    if (i + 1) % 100 == 0:
                        print(f"  Written {i + 1}/{num_records} records...")
                
                conn.commit()
                print(f"✓ Successfully wrote {num_records} records")
        except Exception as e:
            conn.rollback()
            print(f"✗ Error writing data: {e}")
            raise
        finally:
            self.primary_pool.putconn(conn)
        
        return inserted_ids
    
    def read_from_replica(self, replica_config: DatabaseConfig, replica_pool, 
                         record_ids: List[int]) -> Tuple[str, int, float]:
        """Read data from a specific replica"""
        conn = replica_pool.getconn()
        successful_reads = 0
        start_time = time.time()
        
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                for record_id in record_ids:
                    cur.execute("""
                        SELECT id, test_data, random_value, created_at
                        FROM replication_test
                        WHERE id = %s;
                    """, (record_id,))
                    
                    result = cur.fetchone()
                    if result:
                        successful_reads += 1
        except Exception as e:
            print(f"✗ Error reading from {replica_config.host}: {e}")
        finally:
            replica_pool.putconn(conn)
        
        elapsed_time = time.time() - start_time
        return replica_config.host, successful_reads, elapsed_time
    
    def concurrent_read_test(self, record_ids: List[int], num_operations: int) -> Dict:
        """Perform concurrent reads from all replicas"""
        print(f"\nPerforming {num_operations} concurrent read operations across replicas...")
        
        # Distribute reads across replicas
        reads_per_replica = num_operations // len(self.replica_pools)
        results = {}
        
        with ThreadPoolExecutor(max_workers=len(self.replica_pools)) as executor:
            futures = []
            
            for replica_config, replica_pool in self.replica_pools:
                # Randomly select records to read
                selected_ids = random.choices(record_ids, k=reads_per_replica)
                future = executor.submit(
                    self.read_from_replica,
                    replica_config,
                    replica_pool,
                    selected_ids
                )
                futures.append(future)
            
            for future in as_completed(futures):
                host, successful_reads, elapsed_time = future.result()
                results[host] = {
                    'successful_reads': successful_reads,
                    'elapsed_time': elapsed_time,
                    'reads_per_second': successful_reads / elapsed_time if elapsed_time > 0 else 0
                }
                print(f"✓ {host}: {successful_reads} reads in {elapsed_time:.2f}s "
                      f"({results[host]['reads_per_second']:.2f} reads/s)")
        
        return results
    
    def verify_data_consistency(self, record_ids: List[int]) -> bool:
        """Verify that data is consistent across primary and replicas"""
        print("\nVerifying data consistency across all databases...")
        
        # Get data from primary
        primary_conn = self.primary_pool.getconn()
        primary_data = {}
        
        try:
            with primary_conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT id, test_data, random_value
                    FROM replication_test
                    WHERE id = ANY(%s)
                    ORDER BY id;
                """, (record_ids[:10],))  # Check first 10 records
                
                for row in cur.fetchall():
                    primary_data[row['id']] = {
                        'test_data': row['test_data'],
                        'random_value': row['random_value']
                    }
        finally:
            self.primary_pool.putconn(primary_conn)
        
        # Compare with each replica
        all_consistent = True
        for replica_config, replica_pool in self.replica_pools:
            conn = replica_pool.getconn()
            try:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id, test_data, random_value
                        FROM replication_test
                        WHERE id = ANY(%s)
                        ORDER BY id;
                    """, (list(primary_data.keys()),))
                    
                    replica_data = {row['id']: row for row in cur.fetchall()}
                    
                    # Compare data
                    if len(replica_data) != len(primary_data):
                        print(f"✗ {replica_config.host}: Record count mismatch "
                              f"(expected {len(primary_data)}, got {len(replica_data)})")
                        all_consistent = False
                        continue
                    
                    mismatches = 0
                    for record_id, primary_record in primary_data.items():
                        if record_id not in replica_data:
                            mismatches += 1
                            continue
                        
                        replica_record = replica_data[record_id]
                        if (primary_record['test_data'] != replica_record['test_data'] or
                            primary_record['random_value'] != replica_record['random_value']):
                            mismatches += 1
                    
                    if mismatches > 0:
                        print(f"✗ {replica_config.host}: {mismatches} data mismatches found")
                        all_consistent = False
                    else:
                        print(f"✓ {replica_config.host}: Data is consistent")
            finally:
                replica_pool.putconn(conn)
        
        return all_consistent
    
    def run_full_test(self, num_writes: int, num_reads: int, wait_for_replication: int = 2):
        """Run complete replication test"""
        print("=" * 70)
        print("DATABASE REPLICATION TEST")
        print("=" * 70)
        print(f"Primary: {self.primary_config.host}")
        print(f"Replicas: {', '.join([r.host for r, _ in self.replica_pools])}")
        print(f"Write operations: {num_writes}")
        print(f"Read operations: {num_reads}")
        print("=" * 70)
        
        try:
            # Setup
            self.setup_connections()
            self.create_test_schema()
            
            # Verify replicas
            if not self.verify_replica_status():
                print("\n⚠ Warning: Some replicas are not properly configured!")
                response = input("Continue anyway? (y/n): ")
                if response.lower() != 'y':
                    return
            
            # Write data
            record_ids = self.write_data(num_writes)
            
            # Wait for replication
            print(f"\nWaiting {wait_for_replication} seconds for replication to propagate...")
            time.sleep(wait_for_replication)
            
            # Concurrent reads
            read_results = self.concurrent_read_test(record_ids, num_reads)
            
            # Verify consistency
            is_consistent = self.verify_data_consistency(record_ids)
            
            # Summary
            print("\n" + "=" * 70)
            print("TEST SUMMARY")
            print("=" * 70)
            print(f"Total writes: {num_writes}")
            print(f"Total reads: {num_reads}")
            print(f"Data consistency: {'✓ PASS' if is_consistent else '✗ FAIL'}")
            print("\nRead Performance by Replica:")
            for host, stats in read_results.items():
                print(f"  {host}:")
                print(f"    - Successful reads: {stats['successful_reads']}")
                print(f"    - Time: {stats['elapsed_time']:.2f}s")
                print(f"    - Throughput: {stats['reads_per_second']:.2f} reads/s")
            print("=" * 70)
            
        except Exception as e:
            print(f"\n✗ Test failed with error: {e}")
            import traceback
            traceback.print_exc()
        finally:
            self.close_connections()


def load_config_from_env() -> Tuple[DatabaseConfig, List[DatabaseConfig]]:
    """Load database configuration from environment variables and .env file"""
    
    # Check for .env file and load it if available
    env_file = Path(__file__).parent.parent / '.env'
    if env_file.exists():
        if DOTENV_AVAILABLE:
            load_dotenv(env_file)
            print(f"✓ Loaded configuration from {env_file}")
        else:
            print(f"⚠ Warning: .env file found at {env_file}, but python-dotenv is not installed.")
            print("  Install it with: pip install python-dotenv")
    else:
        print(f"ℹ No .env file found at {env_file}, using system environment variables only")
    
    # Get database password
    db_password = os.getenv('POSTGRES_PASSWORD')
    if not db_password:
        raise ValueError("POSTGRES_PASSWORD environment variable not set")
    
    # Get primary IP
    primary_ip = os.getenv('PRIMARY_IP')
    if not primary_ip:
        raise ValueError("PRIMARY_IP environment variable not set")
    
    primary_config = DatabaseConfig(
        host=primary_ip,
        port=5432,
        database='postgres',
        user='postgres',
        password=db_password,
        role='primary'
    )
    
    # Get replica IPs
    replica_configs = []
    replica_1_ip = os.getenv('REPLICA_1_IP')
    replica_2_ip = os.getenv('REPLICA_2_IP')
    
    for _i, replica_ip in enumerate([replica_1_ip, replica_2_ip], 1):
        if replica_ip:
            replica_configs.append(DatabaseConfig(
                host=replica_ip,
                port=5432,
                database='postgres',
                user='postgres',
                password=db_password,
                role='replica'
            ))
    
    if not replica_configs:
        raise ValueError("No replica IPs configured")
    
    return primary_config, replica_configs


def main():
    parser = argparse.ArgumentParser(
        description='Test PostgreSQL database replication',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  # Run with default settings (1000 writes, 1000 reads)
  python test_replication.py
  
  # Custom number of operations
  python test_replication.py --writes 5000 --reads 10000
  
  # Increase replication wait time
  python test_replication.py --wait 5
"""
    )
    
    parser.add_argument(
        '--writes',
        type=int,
        default=1000,
        help='Number of write operations to perform (default: 1000)'
    )
    
    parser.add_argument(
        '--reads',
        type=int,
        default=1000,
        help='Number of read operations to perform (default: 1000)'
    )
    
    parser.add_argument(
        '--wait',
        type=int,
        default=2,
        help='Seconds to wait for replication after writes (default: 2)'
    )
    
    args = parser.parse_args()
    
    try:
        # Load configuration
        primary_config, replica_configs = load_config_from_env()
        
        # Run test
        tester = ReplicationTester(primary_config, replica_configs)
        tester.run_full_test(args.writes, args.reads, args.wait)
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
