import pymysql
import sys
from urllib.parse import quote_plus
from sqlalchemy import create_engine, text

def test_conn(user, password, host, port="3306"):
    try:
        conn = pymysql.connect(
            host=host, 
            user=user, 
            password=password, 
            port=int(port),
            connect_timeout=2
        )
        conn.close()
        return True, "Success"
    except Exception as e:
        return False, str(e)

if __name__ == "__main__":
    hosts = ["127.0.0.1", "localhost", "::1"]
    users = ["root", "admin", "anna"]
    passwords = ["", "Anna4@aa", "root", "admin", "password", "xampp"]
    
    with open("mysql_discovery_log.txt", "w") as f:
        f.write("--- MySQL Extended Discovery ---\n")
        found = False
        for h in hosts:
            for u in users:
                for p in passwords:
                    ok, msg = test_conn(u, p, h)
                    status = "[OK]" if ok else "[FAIL]"
                    line = f"{status} {u}@{h} (pass: '{p}'): {msg}\n"
                    f.write(line)
                    print(line.strip())
                    if ok:
                        found = True
                        print(f"\nFOUND WORKING CONFIG: {u}@{h} with pass '{p}'")
                        f.write(f"\nFOUND WORKING CONFIG: {u}@{h} with pass '{p}'\n")
        
        if not found:
            f.write("\nNo working configuration found.\n")
            print("\nNo working configuration found.")
