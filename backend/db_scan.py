import pymysql
import sqlite3
import os

def test_mysql(port, user, password):
    try:
        conn = pymysql.connect(host='127.0.0.1', port=port, user=user, password=password, connect_timeout=1)
        cursor = conn.cursor()
        cursor.execute("SELECT username FROM placement_app.users")
        users = [r[0] for r in cursor.fetchall()]
        conn.close()
        return True, users
    except Exception as e:
        return False, str(e)

def test_sqlite(db_path):
    if not os.path.exists(db_path):
        return False, "File not found"
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT username FROM users")
        users = [r[0] for r in cursor.fetchall()]
        conn.close()
        return True, users
    except Exception as e:
        return False, str(e)

if __name__ == "__main__":
    print("--- Database Scan ---")
    
    # Test MySQL 3306
    ok, data = test_mysql(3306, "root", "")
    if ok: print(f"MySQL 3306: Found users {data}")
    else: print(f"MySQL 3306: Failed ({data})")

    # Test MySQL 3307
    ok, data = test_mysql(3307, "root", "")
    if ok: print(f"MySQL 3307: Found users {data}")
    else: print(f"MySQL 3307: Failed ({data})")

    # Test SQLite
    ok, data = test_sqlite("placement_app.db")
    if ok: print(f"SQLite: Found users {data}")
    else: print(f"SQLite: Failed ({data})")
