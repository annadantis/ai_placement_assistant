from sqlalchemy import Column, Integer, String, Text, TIMESTAMP, Date
from sqlalchemy.sql import func
from database import Base

class DailyQuiz(Base):
    """Tracks the daily quiz given to a user to prevent showing new random questions on reload."""
    __tablename__ = "daily_quiz"

    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(255), nullable=False)
    category = Column(String(50), nullable=False)
    quiz_date = Column(Date, nullable=False)
    question_ids = Column(Text)
    created_at = Column(TIMESTAMP, server_default=func.now())
