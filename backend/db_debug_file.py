from database import mysql_engine as engine
from sqlalchemy import text
import traceback
import sys

def run_diagnostics():
    with open("debug_output.txt", "w") as f:
        f.write("--- DATABASE DIAGNOSTICS ---\n")
        
        # 1. Check gd_topics schema
        f.write("\n--- DESCRIBING gd_topics ---\n")
        try:
            with engine.connect() as con:
                res = con.execute(text("DESCRIBE gd_topics"))
                for row in res:
                    f.write(str(row) + "\n")
        except Exception:
            f.write(traceback.format_exc() + "\n")

        # 2. Check results table
        f.write("\n--- RECENT RESULTS (LAST 10) ---\n")
        try:
            with engine.connect() as con:
                res = con.execute(text("SELECT id, username, category, score, timestamp FROM results ORDER BY timestamp DESC LIMIT 10"))
                for row in res:
                    f.write(str(row) + "\n")
        except Exception:
            f.write(traceback.format_exc() + "\n")

        # 3. Check gd_results table schema
        f.write("\n--- DESCRIBING gd_results ---\n")
        try:
            with engine.connect() as con:
                res = con.execute(text("DESCRIBE gd_results"))
                for row in res:
                    f.write(str(row) + "\n")
        except Exception:
            f.write(traceback.format_exc() + "\n")

        # 4. Check Current Date/Time comparison
        f.write("\n--- DATE COMPARISON TEST ---\n")
        try:
            with engine.connect() as con:
                res = con.execute(text("SELECT NOW(), DATE(NOW())"))
                f.write(f"NOW: {res.fetchone()}\n")
                
                res = con.execute(text("SELECT COUNT(*) FROM results WHERE DATE(timestamp) = DATE(NOW())"))
                f.write(f"Count for Today: {res.fetchone()[0]}\n")
        except Exception:
            f.write(traceback.format_exc() + "\n")

        # 5. Category counts
        f.write("\n--- RESULT CATEGORY COUNTS ---\n")
        try:
            with engine.connect() as con:
                res = con.execute(text("SELECT category, COUNT(*) FROM results GROUP BY category"))
                for row in res:
                    f.write(str(row) + "\n")
        except Exception:
            f.write(traceback.format_exc() + "\n")

if __name__ == "__main__":
    run_diagnostics()
    print("Done. Check debug_output.txt")
