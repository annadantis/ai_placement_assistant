from database import mysql_engine as engine
from sqlalchemy import text

def force_migrate():
    print("Starting Force Migration...")
    
    # 1. gd_topics
    queries = [
        "ALTER TABLE gd_topics ADD COLUMN keywords TEXT",
        
        "ALTER TABLE gd_results ADD COLUMN voice_score FLOAT",
        "ALTER TABLE gd_results ADD COLUMN overall_score FLOAT",
        "ALTER TABLE gd_results ADD COLUMN content_audit TEXT",
        "ALTER TABLE gd_results ADD COLUMN found_keywords TEXT",
        "ALTER TABLE gd_results ADD COLUMN missing_keywords TEXT",
        "ALTER TABLE gd_results ADD COLUMN improved_answer TEXT",
        "ALTER TABLE gd_results ADD COLUMN strategy_note TEXT",
        
        "ALTER TABLE gd_results MODIFY COLUMN content_score FLOAT",
        "ALTER TABLE gd_results MODIFY COLUMN communication_score FLOAT",
        "ALTER TABLE gd_results MODIFY COLUMN camera_score FLOAT",
        "ALTER TABLE gd_results MODIFY COLUMN final_score FLOAT"
    ]
    
    with engine.connect() as con:
        for q in queries:
            try:
                print(f"Executing: {q}")
                con.execute(text(q))
                con.commit()
                print("Done.")
            except Exception as e:
                # Catch "Duplicate column" specifically
                if "1060" in str(e) or "Duplicate column" in str(e):
                    print("Column already exists, skipping.")
                else:
                    print(f"Error: {e}")
    
    print("Verification:")
    with engine.connect() as con:
        res = con.execute(text("DESCRIBE gd_topics"))
        print("gd_topics columns:", [row[0] for row in res.fetchall()])
        
        res = con.execute(text("DESCRIBE gd_results"))
        print("gd_results columns:", [row[0] for row in res.fetchall()])

if __name__ == "__main__":
    force_migrate()
