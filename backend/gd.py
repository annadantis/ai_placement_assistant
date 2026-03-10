from database import SessionLocal, get_db
from gd_evaluator import evaluate_gd
from camera_eval import CameraEvaluator
from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
import subprocess
import whisper
import os
import uuid
import json
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel

class GDResponse(BaseModel):
    topic: str
    transcript: str
    content_score: float
    communication_score: float
    camera_score: float
    voice_score: float
    overall_score: float
    found_keywords: list
    missing_keywords: list
    content_audit: dict
    feedback: str
    camera_feedback: str
    improved_answer: str
    ideal_answer: str
    strategy_note: str


router = APIRouter()

# ---------------- LOAD WHISPER ONCE ----------------
whisper_model = whisper.load_model("base")


# ---------------- DB Dependency ----------------
# Overriding get_db to ensure it uses the one passed in if needed, 
# but the request provided a specific implementation.

# =================================================
# 1️⃣ FETCH RANDOM GD TOPIC
# =================================================
@router.get("/gd/topic")
def get_gd_topic(db: Session = Depends(get_db)):
    # Debug: Check if the table has ANY data first
    count = db.execute(text("SELECT COUNT(*) FROM gd_topics")).scalar()
    print(f"DEBUG: Total topics in database: {count}")

    result = db.execute(
        text("SELECT id, topic, keywords FROM gd_topics ORDER BY RAND() LIMIT 1")
    ).fetchone()

    if not result:
        print("DEBUG: No result returned from query")
        raise HTTPException(status_code=404, detail="No GD topics found")

    print(f"DEBUG: Selected Topic ID: {result[0]}")
    
    return {
        "topic_id": result[0],
        "topic": result[1],
        "keywords": result[2]
    }


# =================================================
# 2️⃣ SUBMIT AUDIO + VIDEO + FULL AI EVALUATION
# =================================================
@router.post("/submit", response_model=GDResponse)
async def submit_gd(
    topic_id: int = Form(...),
    audio: UploadFile = File(...),
    video: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    os.makedirs("uploads", exist_ok=True)

    # ---------- SAVE AUDIO ----------
    raw_audio_path = f"uploads/{uuid.uuid4()}_{audio.filename}"

    with open(raw_audio_path, "wb") as f:
        f.write(await audio.read())

    # ---------- SAVE VIDEO ----------
    video_path = f"uploads/{uuid.uuid4()}_{video.filename}"

    with open(video_path, "wb") as f:
        f.write(await video.read())

    # ---------- CONVERT AUDIO TO WAV ----------
    if raw_audio_path.lower().endswith(".wav"):
        wav_path = raw_audio_path
    else:
        wav_path = raw_audio_path.rsplit(".", 1)[0] + ".wav"

        process = subprocess.run(
            ["ffmpeg", "-y", "-i", raw_audio_path, wav_path],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="ignore",
            timeout=60
        )


        if process.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail=f"Audio conversion failed: {process.stderr}"
            )

    # ---------- TRANSCRIBE ----------
    result = whisper_model.transcribe(wav_path)
    transcript = result["text"].strip()

    # ---------- FETCH TOPIC ----------
    topic_row = db.execute(
        text("SELECT topic, keywords FROM gd_topics WHERE id = :id"),
        {"id": topic_id}
    ).fetchone()

    if not topic_row:
        raise HTTPException(status_code=400, detail="Invalid topic ID")

    topic_text = topic_row.topic

    # ---------- INSERT INITIAL ROW ----------
    insert = db.execute(
        text("""
            INSERT INTO gd_results (topic_id, user_answer)
            VALUES (:tid, :ans)
        """),
        {"tid": topic_id, "ans": transcript}
    )
    db.commit()
    # Handle both SQLAlchemy Result object versions
    if hasattr(insert, 'lastrowid'):
        gd_id = insert.lastrowid
    else:
        # Fallback for some SQLAlchemy configurations
        gd_id_result = db.execute(text("SELECT LAST_INSERT_ID()")).fetchone()
        gd_id = gd_id_result[0] if gd_id_result else None

    # ---------- CAMERA EVALUATION ----------
    try:
        camera_evaluator = CameraEvaluator()
        camera_results = camera_evaluator.analyze_video(video_path)
        print(f"DEBUG: Camera Results: {camera_results}")
        camera_score = camera_results.get("camera_score", 5.0)
        camera_feedback = camera_results.get("camera_feedback", "Normal")
    except Exception as e:
        print(f"Camera Evaluation Error: {e}")
        camera_score = 5.0
        camera_feedback = "Analysis failed"

    # ---------- FETCH KEYWORDS ----------
    keywords_str = topic_row.keywords or ""
    keywords_list = [k.strip() for k in keywords_str.split(",") if k.strip()]

    # ---------- AI EVALUATION ----------
    evaluation = evaluate_gd(
        topic=topic_text,
        transcript=transcript,
        audio_path=wav_path,
        camera_score=camera_score,
        target_keywords=keywords_list
    )

    # Append Camera Feedback to AI Feedback
    evaluation["feedback"] = evaluation.get("feedback", "") + f"\n\n{camera_feedback}"

    # ---------- CLEANUP FILES ----------
    for path in [raw_audio_path, wav_path, video_path]:
        if os.path.exists(path):
            os.remove(path)

    # ---------- UPDATE DB ----------
    db.execute(
        text("""
            UPDATE gd_results
            SET content_score = :cs,
                communication_score = :coms,
                camera_score = :cams,
                voice_score = :vs,
                overall_score = :os,
                content_audit = :audit,
                found_keywords = :found,
                missing_keywords = :missing,
                feedback = :fb,
                ideal_answer = :ideal
            WHERE id = :id
        """),
        {
            "id": gd_id,
            "cs": evaluation["content_score"],
            "coms": evaluation["communication_score"],
            "cams": evaluation["camera_score"],
            "vs": evaluation["voice_score"],
            "os": evaluation["overall_score"],
            "audit": json.dumps(evaluation.get("content_audit", {})),
            "found": ",".join(evaluation.get("found_keywords", [])),
            "missing": ",".join(evaluation.get("missing_keywords", [])),
            "fb": evaluation["feedback"],
            "improved": evaluation.get("improved_answer", ""),
            "ideal": evaluation.get("ideal_answer", ""),
            "strategy": evaluation.get("strategy_note", ""),
        }
    )
    db.commit()
    
    print("FINAL OUTPUT:", evaluation)

    # ---------- RESPONSE ----------
    return {
        "topic": topic_text,
        "transcript": transcript,
        "content_score": evaluation["content_score"],
        "communication_score": evaluation["communication_score"],
        "camera_score": evaluation["camera_score"],
        "voice_score": evaluation["voice_score"],
        "overall_score": evaluation["overall_score"],
        "found_keywords": evaluation.get("found_keywords", []),
        "missing_keywords": evaluation.get("missing_keywords", []),
        "content_audit": evaluation.get("content_audit", {}),
        "feedback": evaluation["feedback"],
        "camera_feedback": camera_feedback,
        "improved_answer": evaluation.get("improved_answer", ""),
        "ideal_answer": evaluation.get("ideal_answer", ""),
        "strategy_note": evaluation.get("strategy_note", ""),
    }



