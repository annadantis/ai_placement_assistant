import pymysql
import sys
from urllib.parse import quote_plus
from sqlalchemy import create_engine, text

def test_conn(user, password, host, port="3306"):
    try:
        # Try raw pymysql first
        conn = pymysql.connect(
            host=host, 
            user=user, 
            password=password, 
            port=int(port),
            connect_timeout=2
        )
        conn.close()
        return True, "Raw PyMySQL Success"
    except Exception as e:
        err_msg = str(e)
        # Try SQLAlchemy
        try:
            url = f"mysql+pymysql://{user}:{quote_plus(password)}@{host}:{port}/"
            engine = create_engine(url, connect_args={"connect_timeout": 2})
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            return True, "SQLAlchemy Success"
        except Exception as e2:
            return False, f"PyMySQL: {err_msg[:50]} | SQLAlchemy: {str(e2)[:50]}"

if __name__ == "__main__":
    hosts = ["127.0.0.1", "localhost"]
    users = ["root", "admin"]
    passwords = ["", "root", "admin", "Anna4@aa", "Anna", "password", "xampp"]
    
    print("--- MySQL Credential Discovery ---")
    
    found = False
    for h in hosts:
        for u in users:
            for p in passwords:
                print(f"Testing {u}@{h} with password '{p}'...", end=" ", flush=True)
                ok, msg = test_conn(u, p, h)
                if ok:
                    print(f"\n✅ SUCCESS! {msg}")
                    print(f"Host: {h}")
                    print(f"User: {u}")
                    print(f"Pass: '{p}'")
                    found = True
                    break
                else:
                    print(f"❌")
            if found: break
        if found: break
    
    if not found:
        print("\n❌ FAILED: Could not connect with any common credential.")
        print("Please verify MySQL is running and provide correct credentials.")
