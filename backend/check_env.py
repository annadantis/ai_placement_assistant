import os
import sys
import traceback
from sqlalchemy import create_engine, text
from urllib.parse import quote_plus

def test_combination(host, pwd):
    user = "root"
    port = "3306"
    try:
        url = f"mysql+pymysql://{user}:{quote_plus(pwd)}@{host}:{port}/"
        engine = create_engine(url, connect_args={"connect_timeout": 2})
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            print(f"✅ Success! Connected to {host} as root with password '{pwd}'")
            return True
    except Exception as e:
        print(f"❌ Failed: {host} with password '{pwd}' -> {str(e)[:100]}")
        return False

if __name__ == "__main__":
    hosts = ["127.0.0.1", "localhost"]
    passwords = ["", "Anna4@aa", "root", "Anna", "admin", "password"]
    
    found = False
    for h in hosts:
        for p in passwords:
            if test_combination(h, p):
                found = True
                print(f"\nRecommended Config: DB_HOST={h}, DB_PASSWORD={p}")
                break
        if found: break
        
    if not found:
        print("\n❌ Could not find a working combination.")
