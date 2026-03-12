import pymysql
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

if __name__ == "__main__":
    print("--- Database Scan V2 ---")
    
    # Test MySQL 3306 with Anna4@aa
    ok, data = test_mysql(3306, "root", "Anna4@aa")
    if ok: print(f"MySQL 3306 (Anna4@aa): Found users {data}")
    else: print(f"MySQL 3306 (Anna4@aa): Failed ({data})")
