from database import mysql_engine as engine
from sqlalchemy import text
import json

import traceback

def check_gd_topics():
    print("--- DESCRIBING gd_topics ---")
    try:
        with engine.connect() as con:
            res = con.execute(text("DESCRIBE gd_topics"))
            rows = res.fetchall()
            for row in rows:
                print(str(row))
    except Exception:
        print(traceback.format_exc())

def check_results():
    print("\n--- RECENT RESULTS (LAST 5) ---")
    try:
        with engine.connect() as con:
            res = con.execute(text("SELECT id, username, category, score, timestamp FROM results ORDER BY timestamp DESC LIMIT 5"))
            rows = res.fetchall()
            for row in rows:
                print(str(row))
    except Exception:
        print(traceback.format_exc())

def check_gd_results():
    print("\n--- RECENT GD RESULTS (LAST 5) ---")
    try:
        with engine.connect() as con:
            res = con.execute(text("SELECT id, username, topic_id, overall_score, timestamp FROM gd_results ORDER BY timestamp DESC LIMIT 5"))
            rows = res.fetchall()
            for row in rows:
                print(str(row))
    except Exception:
        print(traceback.format_exc())

if __name__ == "__main__":
    try:
        check_gd_topics()
        check_results()
        check_gd_results()
    except Exception:
        print(traceback.format_exc())
