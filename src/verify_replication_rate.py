#!/usr/bin/env python3
"""
Replication Rate Verification Script

This script measures the time it takes for data written to the primary database
to be replicated to the read replicas.
"""

import time
import uuid
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Optional
import psycopg2

# Import configuration from existing test script
from test_replication import load_config_from_env, DatabaseConfig

class ReplicationRateVerifier:
    def __init__(self, primary_config: DatabaseConfig, replica_configs: List[DatabaseConfig]):
        self.primary_config = primary_config
        self.replica_configs = replica_configs
        self.primary_conn = None
        self.replica_conns = []

    def setup_connections(self):
        """Establish connections to all databases"""
        print("Connecting to databases...")
        try:
            # Connect to primary
            self.primary_conn = psycopg2.connect(
                host=self.primary_config.host,
                port=self.primary_config.port,
                database=self.primary_config.database,
                user=self.primary_config.user,
                password=self.primary_config.password
            )
            print(f"✓ Connected to Primary: {self.primary_config.host}")
            
            # Connect to replicas
            for config in self.replica_configs:
                conn = psycopg2.connect(
                    host=config.host,
                    port=config.port,
                    database=config.database,
                    user=config.user,
                    password=config.password
                )
                self.replica_conns.append((config, conn))
                print(f"✓ Connected to Replica: {config.host}")
                
        except Exception as e:
            print(f"✗ Connection error: {e}")
            self.close_connections()
            raise

    def close_connections(self):
        """Close all active connections"""
        if self.primary_conn:
            self.primary_conn.close()
        for _, conn in self.replica_conns:
            conn.close()
        print("Connections closed.")

    def _wait_for_replica(self, replica_config: DatabaseConfig, replica_conn, target_uuid: str) -> Optional[float]:
        """Poll a single replica until the target UUID is found"""
        start_time = time.time()
        timeout = 10.0  # Timeout in seconds
        
        while time.time() - start_time < timeout:
            try:
                with replica_conn.cursor() as cur:
                    # Using the table created by test_replication.py
                    # We look for the UUID in test_data
                    cur.execute("SELECT created_at FROM replication_test WHERE test_data = %s", (target_uuid,))
                    result = cur.fetchone()
                    
                    if result:
                        # Found it!
                        # We return the wall-clock time elapsed since we started polling
                        # Note: This includes network round trip, processing time, etc.
                        return time.time()
                
                # Short sleep to avoid hammering the DB
                time.sleep(0.05) 
                
            except Exception as e:
                print(f"Error polling {replica_config.host}: {e}")
                # Try to reconnect if connection lost? For now just fail this poll.
                return None
                
        return None  # Timed out

    def measure_replication_lag(self) -> Dict[str, float]:
        """
        Inserts a record and measures time to appear in all replicas.
        Returns a dict of {host: lag_seconds}
        """
        # Generate unique ID
        test_uuid = str(uuid.uuid4())
        
        # Insert into primary
        insert_time = time.time()
        try:
            with self.primary_conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO replication_test (test_data, random_value)
                    VALUES (%s, %s)
                """, (test_uuid, 0))
                self.primary_conn.commit()
        except Exception as e:
            self.primary_conn.rollback()
            print(f"Error inserting validation record: {e}")
            raise

        # Poll replicas concurrently
        lags = {}
        with ThreadPoolExecutor(max_workers=len(self.replica_conns)) as executor:
            future_to_host = {
                executor.submit(self._wait_for_replica, config, conn, test_uuid): config.host 
                for config, conn in self.replica_conns
            }
            
            for future in as_completed(future_to_host):
                host = future_to_host[future]
                detection_time = future.result()
                
                if detection_time:
                    # Lag is the time from insert commit to detection
                    lag = detection_time - insert_time
                    lags[host] = lag
                else:
                    lags[host] = -1.0  # Indicator for timeout/failure

        return lags

    def run_verification(self, samples: int = 10):
        """Run multiple samples and verify replication rate"""
        print(f"\nStarting Replication Rate Verification ({samples} samples)...")
        print("Measuring time from Primary INSERT commit to Replica SELECT success.")
        
        results: Dict[str, List[float]] = {config.host: [] for config in self.replica_configs}
        
        for i in range(1, samples + 1):
            print(f"Sample {i}/{samples}...", end='', flush=True)
            lags = self.measure_replication_lag()
            
            for host, lag in lags.items():
                if lag >= 0:
                    results[host].append(lag)
            
            print(" Done")
            time.sleep(0.5)  # Pause between samples

        print("\n" + "="*50)
        print("REPLICATION LAG RESULTS")
        print("="*50)
        
        for host, lags in results.items():
            if not lags:
                print(f"Host: {host} - FAILED (No successful replications detected)")
                continue
                
            avg_lag = statistics.mean(lags)
            min_lag = min(lags)
            max_lag = max(lags)
            p95_lag = sorted(lags)[int(len(lags) * 0.95)] if len(lags) > 1 else max_lag
            
            print(f"Host: {host}")
            print(f"  Samples: {len(lags)}/{samples}")
            print(f"  Average Lag: {avg_lag*1000:.2f} ms")
            print(f"  Min Lag:     {min_lag*1000:.2f} ms")
            print(f"  Max Lag:     {max_lag*1000:.2f} ms")
            print(f"  95th %%:      {p95_lag*1000:.2f} ms")
            print("-" * 30)

def main():
    try:
        # Reuse loading logic
        primary, replicas = load_config_from_env()
        
        verifier = ReplicationRateVerifier(primary, replicas)
        verifier.setup_connections()
        
        # Ensure schema exists (using the other script's table)
        # We assume test_replication.py has been run or at least the table exists.
        # If not, we might fail. Let's rely on the user having set it up or add a check.
        # For now, let's assume the table exists or `test_replication.py` can be run to create it.
        # Actually, let's just try to create it if it doesn't exist for robustness,
        # but the `test_replication.py` logic is encapsulated in a class method.
        # simpler to just assume it's there or catching the error.
        
        verifier.run_verification(samples=20)
        
    except KeyboardInterrupt:
        print("\nStopped by user.")
    except Exception as e:
        print(f"\nError: {e}")
    finally:
        if 'verifier' in locals():
            verifier.close_connections()

if __name__ == "__main__":
    main()
