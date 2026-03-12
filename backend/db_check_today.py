import pymysql
import json
from datetime import datetime, date

DB_CONFIG = {
    'host': '127.0.0.1',
    'user': 'root',
    'password': 'Anna4@aa',
    'database': 'placement_app',
    'port': 3306
}

def check_today_results():
    today = date.today().strftime('%Y-%m-%d')
    print(f"Checking results for {today}...")
    try:
        conn = pymysql.connect(**DB_CONFIG)
        with conn.cursor() as cursor:
            # Check latest generic results
            print("\n--- RESULTS FROM TODAY ---")
            cursor.execute("""
                SELECT id, username, category, score, area, timestamp 
                FROM results 
                WHERE DATE(timestamp) >= :t
                ORDER BY timestamp DESC
            """.replace(':t', f"'{today}'"))
            rows = cursor.fetchall()
            if not rows:
                print("No results found for today.")
            for r in rows:
                print(f"ID: {r[0]}, User: {r[1]}, Cat: {r[2]}, Score: {r[3]}, Area: {r[4]}, Time: {r[5]}")
                
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_today_results()
