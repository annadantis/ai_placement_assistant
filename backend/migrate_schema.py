from database import mysql_engine as engine
from sqlalchemy import text

def migrate():
    print("Starting Database Migration...")
    
    commands = [
        # 1. Update gd_topics
        "ALTER TABLE gd_topics ADD COLUMN IF NOT EXISTS keywords TEXT AFTER topic",
        
        # 2. Update gd_results
        "ALTER TABLE gd_results ADD COLUMN IF NOT EXISTS voice_score FLOAT AFTER camera_score",
        "ALTER TABLE gd_results ADD COLUMN IF NOT EXISTS overall_score FLOAT AFTER final_score",
        "ALTER TABLE gd_results ADD COLUMN IF NOT EXISTS content_audit TEXT AFTER overall_score",
        "ALTER TABLE gd_results ADD COLUMN IF NOT EXISTS found_keywords TEXT AFTER content_audit",
        "ALTER TABLE gd_results ADD COLUMN IF NOT EXISTS missing_keywords TEXT AFTER found_keywords",
        "ALTER TABLE gd_results ADD COLUMN IF NOT EXISTS improved_answer TEXT AFTER missing_keywords",
        "ALTER TABLE gd_results ADD COLUMN IF NOT EXISTS strategy_note TEXT AFTER improved_answer",
        
        # Ensure communication_score and content_score are FLOAT (they might be INT)
        "ALTER TABLE gd_results MODIFY COLUMN content_score FLOAT",
        "ALTER TABLE gd_results MODIFY COLUMN communication_score FLOAT",
        "ALTER TABLE gd_results MODIFY COLUMN camera_score FLOAT",
        "ALTER TABLE gd_results MODIFY COLUMN final_score FLOAT",
    ]
    
    with engine.connect() as con:
        for cmd in commands:
            try:
                print(f"Executing: {cmd}")
                con.execute(text(cmd))
                con.commit()
                print("Success.")
            except Exception as e:
                print(f"Error executing {cmd}: {e}")
                # Some versions of MySQL might not support ADD COLUMN IF NOT EXISTS
                if "Duplicate column" in str(e):
                    print("Column already exists, skipping.")
                else:
                    print("Failed.")

    print("Migration complete.")

if __name__ == "__main__":
    migrate()
