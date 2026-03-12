import pymysql
import json
from datetime import datetime

DB_CONFIG = {
    'host': '127.0.0.1',
    'user': 'root',
    'password': 'Anna4@aa',
    'database': 'placement_app',
    'port': 3306
}

def check_latest_absolute():
    try:
        conn = pymysql.connect(**DB_CONFIG)
        with conn.cursor() as cursor:
            # Check latest generic results
            print("\n--- LATEST 10 RESULTS (ALL USERS) ---")
            cursor.execute("""
                SELECT id, username, category, score, area, timestamp 
                FROM results 
                ORDER BY id DESC LIMIT 10
            """)
            rows = cursor.fetchall()
            for r in rows:
                print(f"ID: {r[0]}, User: {r[1]}, Cat: {r[2]}, Score: {r[3]}, Area: {r[4]}, Time: {r[5]}")

            print("\n--- LATEST 10 GD RESULTS ---")
            cursor.execute("""
                SELECT id, topic_id, content_score, communication_score, camera_score, overall_score, timestamp 
                FROM gd_results 
                ORDER BY id DESC LIMIT 10
            """)
            rows = cursor.fetchall()
            for r in rows:
                print(f"ID: {r[0]}, Topic: {r[1]}, Content: {r[2]}, Comm: {r[3]}, Camera: {r[4]}, Overall: {r[5]}, Time: {r[6]}")
                
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_latest_absolute()
