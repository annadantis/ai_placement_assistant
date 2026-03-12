import pymysql
from urllib.parse import quote_plus

def test_conn(user, password, host, port):
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
    hosts = ["127.0.0.1", "localhost"]
    users = ["root"]
    passwords = ["", "Anna4@aa", "root", "admin", "password", "xampp", "Anna"]
    port = "3307"
    
    print(f"--- Testing MySQL on Port {port} ---")
    for h in hosts:
        for u in users:
            for p in passwords:
                ok, msg = test_conn(u, p, h, port)
                status = "[OK]" if ok else "[FAIL]"
                print(f"{status} {u}@{h}:{port} (pass: '{p}'): {msg}")
                if ok:
                    print(f"\n✅ FOUND WORKING CONFIG: {u}@{h}:{port} with pass '{p}'")
                    exit(0)
    print("\nNo working configuration found on port 3307.")
