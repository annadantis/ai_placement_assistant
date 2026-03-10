from database import SessionLocal
from sqlalchemy import text

db = SessionLocal()
db.execute(text("DELETE FROM questions WHERE question = '' OR question IS NULL"))
db.commit()
db.execute(text("DELETE FROM daily_quiz")) # clear cached daily quiz so new questions are fetched
db.commit()
print("Cleaned up database")
db.close()
