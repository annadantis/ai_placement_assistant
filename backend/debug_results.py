
from database import SessionLocal
from sqlalchemy import text
from datetime import datetime, timedelta, timezone

def get_ist_date():
    return (datetime.now(timezone.utc) + timedelta(hours=5, minutes=30)).date()

def check_db():
    db = SessionLocal()
    try:
        # Check timezone and current time
        tz_info = db.execute(text("SELECT @@session.time_zone, @@global.time_zone, NOW()")).fetchone()
        print(f"Session TZ: {tz_info[0]}, Global TZ: {tz_info[1]}, DB Now: {tz_info[2]}")
        
        # Check if any interviews exist in results
        interviews = db.execute(text("SELECT id, username, category, score, timestamp FROM results WHERE category='INTERVIEW' ORDER BY timestamp DESC LIMIT 5")).fetchall()
        print(f"\nLatest Interviews in 'results' table:")
        for i in interviews:
            print(f"ID: {i[0]}, User: {i[1]}, Cat: {i[2]}, Score: {i[3]}, Timestamp: {i[4]}")
            
        # Check GD results
        gd_results = db.execute(text("SELECT id, username, final_score, timestamp FROM gd_results ORDER BY timestamp DESC LIMIT 5")).fetchall()
        print(f"\nLatest GD Results:")
        for g in gd_results:
            print(f"ID: {g[0]}, User: {g[1]}, Score: {g[2]}, Timestamp: {g[3]}")

        # Check interview details
        details_count = db.execute(text("SELECT COUNT(*) FROM interview_details")).fetchone()[0]
        print(f"\nTotal entries in interview_details: {details_count}")
        if details_count > 0:
            latest_details = db.execute(text("SELECT id, result_id, question, user_answer FROM interview_details ORDER BY id DESC LIMIT 5")).fetchall()
            print("Latest Interview Details:")
            for d in latest_details:
                print(f"ID: {d[0]}, ResultID: {d[1]}, Q: {d[2][:30]}, A: {str(d[3])[:30]}")

        # Check for any categories with different casing
        case_check = db.execute(text("SELECT category, COUNT(*) FROM results GROUP BY category")).fetchall()
        print(f"\nCategory counts in DB (results table):")
        for c in case_check:
            print(f"{c[0]}: {c[1]}")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    check_db()
