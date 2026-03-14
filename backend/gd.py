from database import SessionLocal, get_db
from gd_evaluator import evaluate_gd
from camera_eval import CameraEvaluator
from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException, WebSocket, WebSocketDisconnect
import asyncio
import subprocess
import whisper
import os
import uuid
import json
from typing import List, Dict, Optional, Any
import ollama  # <--- Added for model interaction
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel

async def analyze_single_response(response_text: str, topic: str, bot_context: str) -> dict:
    """
    Generates an improved + ideal answer for a single user response turn.
    Called once per user audio chunk after transcription.
    """
    prompt = (
        f"You are a GD coach. The topic is: '{topic}'.\n"
        f"The conversation so far:\n{bot_context}\n\n"
        f"The user said: \"{response_text}\"\n\n"
        "Respond ONLY with valid JSON (no extra text):\n"
        "{\n"
        "  \"improved\": \"<rewrite the user's response more professionally and clearly, max 60 words>\",\n"
        "  \"ideal\": \"<what an ideal candidate would have said on this point, max 300 words>\"\n"
        "}"
    )
    try:
        client = ollama.AsyncClient()
        resp = await client.generate(
            model='llama3',
            prompt=prompt,
            options={"num_predict": 200, "temperature": 0.5}
        )
        raw = resp['response'].strip()
        # Extract JSON safely
        import re as _re
        match = _re.search(r'\{.*\}', raw, _re.DOTALL)
        if match:
            return json.loads(match.group())
    except Exception as e:
        print(f"Per-response analysis error: {e}")
    return {"improved": response_text, "ideal": ""}

async def generate_bot_response(persona: str, topic: str, current_history: list, is_intro: bool = False):

    """
    Generates a persona-specific response using Ollama.
    """
    # System Prompts for distinct personalities
    if persona == "Thomas" or persona == "Moderator":
        name = "Thomas"
        if is_intro:
            system_instr = (
                f"You are {name}, a participant in a Group Discussion about '{topic}'. "
                "Strategy: You are starting the discussion. Do not just introduce the topic, but immediately state your opinion and give the first substantive point on the topic. "
                "Rules: Professional, neutral, and encouraging. MAX 40 WORDS."
            )
        else:
            system_instr = (
                f"You are {name}, a participant in a Group Discussion about '{topic}'. "
                "Strategy: Summarize points and provide a new perspective or thought-provoking question. "
                "Rules: Professional, neutral, and encouraging. MAX 40 WORDS."
            )
    elif persona == "Challenger":
        name = "Aravind"
        system_instr = (
            f"You are {name}, a critical candidate in a Group Discussion about '{topic}'. "
            "Strategy: You are AGAINST the primary idea. Disagree politely, point out flaws in logic, or mention risks. Explicitly state you are against or have critical concerns. "
            "Rules: Stay in character. Use professional tone. MAX 35 WORDS."
        )
    else:
        name = "George"
        system_instr = (
            f"You are {name}, a collaborative candidate in a Group Discussion about '{topic}'. "
            "Strategy: You are FOR the primary idea. Agree with others, build on their points, and find consensus. Explicitly state you are for or agree with the idea. "
            "Rules: Stay in character. Use encouraging tone. MAX 35 WORDS."
        )

    # Format the last 4 exchanges for context to give bots better memory
    context = "\n".join(current_history[-4:])
    full_prompt = (
        f"SYSTEM: {system_instr}\n"
        f"IMPORTANT: You are {name}. Speak in first person as {name}. "
        f"Do NOT prefix your reply with your name or a colon. Just say what {name} would say naturally.\n\n"
        f"CONVERSATION:\n{context}\n\n"
        f"{name}:"
    )

    try:
        # Using Llama3 with options to prevent rambling (faster response)
        client = ollama.AsyncClient()
        response = await client.generate(
            model='llama3', 
            prompt=full_prompt,
            options={
                "num_predict": 80,   # Enough for a full sentence, not a truncated one
                "temperature": 0.8,
                "stop": [".", "!", "?"]  # Stop cleanly at sentence end
            }
        )
        raw = response['response'].strip().replace('"', '')
        
        # Ensure the response ends with proper punctuation (complete sentence)
        if raw and raw[-1] not in '.!?':
            raw += '.'
        
        return raw
    except Exception as e:
        print(f"Ollama Error: {e}")
        return "I see your point, but we should consider the practical implementation challenges."

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

# =================================================
# 1️⃣ FETCH RANDOM GD TOPIC
# =================================================
@router.get("/gd/topic")
def get_gd_topic(db: Session = Depends(get_db)):
    # The user specifies topics are in gd_topics_extra which has question_id and question columns
    count_res = db.execute(text("SELECT COUNT(*) FROM gd_topics_extra")).scalar()
    
    # Try to fetch with aliases. Using COALESCE for keywords if the column is missing
    # Since DESCRIBE showed question_id and question, we map them to topic_id and topic.
    result = db.execute(
        text("SELECT question_id, question FROM gd_topics_extra ORDER BY RAND() LIMIT 1")
    ).fetchone()

    if not result:
        raise HTTPException(status_code=404, detail="No GD topics found in gd_topics_extra")

    return {
        "topic_id": result[0],
        "topic": result[1],
        "keywords": "" # Default to empty if gd_topics_extra doesn't have keywords
    }

# =================================================
# 2️⃣ LIVE MEETING ROOM MODERATOR (WEBSOCKET)
# =================================================
@router.websocket("/ws/gd_meeting/{topic_id}")
async def gd_meeting_stream(websocket: WebSocket, topic_id: str, db: Session = Depends(get_db)):
    print(f"GD: New WebSocket connection for topic_id: {topic_id}")
    await websocket.accept()
    
    # Fetch topic details from user-specified table
    topic_row = db.execute(
        text("SELECT question as topic FROM gd_topics_extra WHERE question_id = :id"), {"id": topic_id}
    ).fetchone()
    
    if not topic_row:
        await websocket.close(code=4004)
        return

    # Structured state for shared access
    class GDState:
        def __init__(self):
            self.hand_raised = False
            self.user_wants_to_speak = False
            self.tts_completed = True # True initially so the first bot can speak
            self.active_speaker = "Bot_Mod"
            self.session_transcript: List[str] = []
            self.should_exit = False

    state = GDState()

    async def socket_listener():
        try:
            while not state.should_exit:
                data = await websocket.receive_json()
                print(f"GD: Received message: {data}")
                
                if data.get("type") == "RAISE_HAND":
                    state.user_wants_to_speak = True
                    # Do NOT grant the floor immediately. Wait for current speaker to finish.
                    print("GD: User raised hand. Waiting for current speaker to finish TTS.")
                elif data.get("type") == "LOWER_HAND":
                    state.hand_raised = False
                    state.user_wants_to_speak = False
                    # Switch turn back to the bot that WASN'T the last one to speak
                    # The transcript now records human names ("Aravind", "Sneha", "Thomas")
                    last_speaker = state.session_transcript[-1] if state.session_transcript else ""
                    state.active_speaker = "Bot_B" if "Aravind" in last_speaker else "Bot_A"
                elif data.get("type") == "TTS_COMPLETED":
                    print("GD: TTS Completed signal received.")
                    state.tts_completed = True
        except WebSocketDisconnect:
            state.should_exit = True
        except Exception as e:
            print(f"GD: Listener Error: {e}")
            state.should_exit = True

    # Use the LLM to generate Thomas's first substantive answer
    starting_bot = "Bot_Mod" # Thomas
    
    welcome_msg = await generate_bot_response("Thomas", topic_row.topic, state.session_transcript, is_intro=True)
    print(f"GD: Bot 'Bot_Mod' ('Thomas') generated starting response: {welcome_msg}")
    
    state.tts_completed = False # Wait for this welcome to finish
    await websocket.send_json({
        "type": "BOT_SAYS",
        "speaker": "Bot_Mod",
        "text": welcome_msg
    })
    state.session_transcript.append(f"Thomas: {welcome_msg}")
    state.active_speaker = "Bot_A" # Pass floor to Aravind next

    # Start the listener in the background
    listener_task = asyncio.create_task(socket_listener())

    try:
        turn_count = 0
        while not state.should_exit:
            
            # Wait until TTS has finished speaking the last utterance before doing ANYTHING
            if not state.tts_completed:
                await asyncio.sleep(0.1)
                continue

            # If TTS is completed and the user wants to speak, grant them the floor NOW.
            if state.user_wants_to_speak and not state.hand_raised:
                state.hand_raised = True
                state.active_speaker = "User"
                await websocket.send_json({
                    "type": "STATUS",
                    "command": "GRANT_FLOOR",
                    "msg": "Floor granted. Listening..."
                })
                continue # Let user speak

            # 2. Turn-Taking Logic: AI Bot Turn
            if not state.hand_raised:
                speaker = state.active_speaker
                if speaker == "Bot_Mod":
                    persona = "Thomas"
                else:
                    persona = "Challenger" if speaker == "Bot_A" else "Supporter"
                
                bot_msg = await generate_bot_response(persona, topic_row.topic, state.session_transcript)
                
                if state.should_exit:
                    break

                print(f"GD: Bot '{speaker}' ('{persona}') generated response: {bot_msg}")
                try:
                    # If it's a normal bot (not Thomas's first turn), have them raise their hand first
                    if turn_count > 0:
                        await websocket.send_json({
                            "type": "BOT_RAISE_HAND",
                            "speaker": speaker
                        })
                        await asyncio.sleep(1.5) # Wait 1.5s to simulate raising hand before speaking
                    
                    state.tts_completed = False # Block loop until client says TTS done
                    await websocket.send_json({
                        "type": "BOT_SAYS",
                        "speaker": speaker,
                        "text": bot_msg
                    })
                except Exception:
                    # WebSocket likely closed by client
                    state.should_exit = True
                    break
                
                name_map = {"Bot_Mod": "Thomas", "Bot_A": "Aravind", "Bot_B": "George"}
                friendly_name = name_map.get(speaker, speaker)
                state.session_transcript.append(f"{friendly_name}: {bot_msg}")
                turn_count += 1
                
                # Logic to rotate bots, or occasionally insert moderator
                if speaker == "Bot_Mod":
                    state.active_speaker = "Bot_A"
                elif turn_count % 6 == 0:
                    # Moderator steps in every 6 bot turns to keep discussion structured
                    state.active_speaker = "Bot_Mod"
                else:
                    state.active_speaker = "Bot_B" if speaker == "Bot_A" else "Bot_A"
            
            else:
                # If User is speaking, backend idles and waits for LOWER_HAND
                await asyncio.sleep(0.5)

    except Exception as e:
        print(f"WS Error: {e}")
    finally:
        state.should_exit = True
        listener_task.cancel()
        # Notify the client that the session has ended so it can submit for evaluation
        try:
            await websocket.send_json({"type": "SESSION_END"})
        except Exception:
            pass
        print(f"GD Session ended for topic {topic_id}")

# =================================================
# 3️⃣ SUBMIT FINAL EVALUATION
# =================================================
@router.post("/submit")
async def submit_gd(
    topic_id: str = Form(...), 
    bot_context: str = Form(""),  # <--- This matches your Flutter logic
    username: str = Form("Anonymous"),  # <--- Accept username from Flutter
    audio: List[UploadFile] = File(default=[]),
    video: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    os.makedirs("uploads", exist_ok=True)
    unique_id = uuid.uuid4()
    video_path = f"uploads/{unique_id}_{video.filename}"
    with open(video_path, "wb") as f: f.write(await video.read())

    # Fetch Topic FIRST so topic_text is available during audio processing
    topic_query = text("SELECT question, '' as keywords FROM gd_topics_extra WHERE question_id = :id")
    topic_row = db.execute(topic_query, {"id": topic_id}).fetchone()
    if not topic_row:
        raise HTTPException(status_code=400, detail="Invalid topic ID")
    topic_text = topic_row[0]
    keywords_raw = topic_row[1] or ""
    keywords_list = [k.strip() for k in keywords_raw.split(",") if k.strip()]

    user_responses = []        # raw transcribed text per turn
    response_breakdown = []   # {turn, improved, ideal} per turn
    wav_path = f"uploads/{unique_id}_combined.wav"
    audio_paths_to_cleanup = []

    if not audio:
        subprocess.run(["ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=16000:cl=mono", "-t", "1", wav_path], capture_output=True)
        user_transcript = ""
    else:
        for idx, audio_file in enumerate(audio):
            raw_audio_path = f"uploads/{unique_id}_{idx}_{audio_file.filename}"
            audio_paths_to_cleanup.append(raw_audio_path)
            with open(raw_audio_path, "wb") as f: f.write(await audio_file.read())

            chunk_wav_path = raw_audio_path.rsplit(".", 1)[0] + ".wav"
            subprocess.run(["ffmpeg", "-y", "-i", raw_audio_path, "-ar", "16000", "-ac", "1", chunk_wav_path], capture_output=True)
            audio_paths_to_cleanup.append(chunk_wav_path)

            try:
                result = whisper_model.transcribe(chunk_wav_path)
                transcript_text = result["text"].strip()
                if transcript_text:
                    user_responses.append(transcript_text)
            except Exception as e:
                print(f"Transcription Error (Chunk {idx}): {e}")

        if not user_responses:
            user_transcript = ""
        else:
            user_transcript = "\n\n".join([f"Response {i+1}:\n{resp}" for i, resp in enumerate(user_responses)])

            # Per-response improved/ideal — run all Ollama calls in parallel
            async def _analyze(i, resp_text):
                try:
                    per = await analyze_single_response(resp_text, topic_text, bot_context)
                    return {"turn": i + 1, "response": resp_text,
                            "improved": per.get("improved", resp_text),
                            "ideal": per.get("ideal", "")}
                except Exception:
                    return {"turn": i + 1, "response": resp_text, "improved": resp_text, "ideal": ""}

            response_breakdown = list(await asyncio.gather(*[_analyze(i, r) for i, r in enumerate(user_responses)]))

        concat_txt = f"uploads/{unique_id}_concat.txt"
        with open(concat_txt, "w") as f:
            for p in audio_paths_to_cleanup:
                if p.endswith(".wav"):
                    abs_p = os.path.abspath(p).replace('\\', '/')
                    f.write(f"file '{abs_p}'\n")
        audio_paths_to_cleanup.append(concat_txt)
        subprocess.run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", concat_txt, "-c", "copy", wav_path], capture_output=True)

    # 4. Topic already fetched above — skip duplicate fetch

    # 5. Advanced AI Evaluation (Includes Camera & Voice Analysis)
    try:
        evaluation = evaluate_gd(
            topic=topic_text,
            transcript=user_transcript,
            audio_path=wav_path,
            video_path=video_path,
            target_keywords=keywords_list,
            bot_context=bot_context
        )
    except Exception as eval_exc:
        import traceback
        print(f"❌ evaluate_gd crashed unexpectedly: {eval_exc}")
        traceback.print_exc()
        evaluation = {"error": "evaluate_gd exception", "details": str(eval_exc)}

    # 6.5 Safe Fallback if LLM evaluation failed
    if "error" in evaluation:
        err_detail = evaluation.get("details", evaluation["error"])
        print(f"⚠️ GD Evaluator Failed: {err_detail}")
        evaluation = {
            "content_score": 0.0,
            "communication_score": 0.0,
            "voice_score": 0.0,
            "overall_score": 0.0,
            "content_audit": {"error": f"Evaluation failed: {err_detail}"},
            "found_keywords": [],
            "missing_keywords": keywords_list,
            "feedback": f"The AI evaluation encountered an error and could not complete.\nDetails: {err_detail}",
            "improved_answer": "Validation failed - No improved answer available.",
            "ideal_answer": "Validation failed - No ideal answer available.",
            "strategy_note": "Try to speak clearly and address the topic keywords."
        }

    # 7. Database Persistence (best-effort — don't block if DB insert fails)
    result_id = None
    try:
        # 7a. First insert a row into the `results` table so GD appears in all report screens
        overall_score = float(evaluation.get("overall_score", 0))
        # overall_score is 0-100, results.score is expected 0-10
        score_out_of_10 = round(overall_score / 10, 2)

        from sqlalchemy import text as _text
        results_insert = db.execute(_text("""
            INSERT INTO results (username, category, score, total_questions, area, timestamp)
            VALUES (:u, 'GD', :sc, 10, :area, NOW())
        """), {
            "u": username.strip(),
            "sc": score_out_of_10,
            "area": topic_text[:100] if topic_text else "Group Discussion"
        })
        db.commit()
        result_id = results_insert.lastrowid

        # 7b. Insert detailed GD data into `gd_results`, linked via result_id
        insert_query = text("""
            INSERT INTO gd_results (
                topic_id, username, user_answer, content_score, communication_score, camera_score, 
                voice_score, overall_score, final_score, content_audit, found_keywords, missing_keywords, 
                feedback, improved_answer, ideal_answer, strategy_note, result_id
            )
            VALUES (
                :tid, :u, :ans, :cs, :coms, :cams, :vs, :os, :fs, :audit, :found, :missing, :fb, :improved, :ideal, :strategy, :rid
            )
        """)
        db.execute(insert_query, {
            "tid": topic_id,
            "u": username.strip(),
            "ans": user_transcript, 
            "cs": evaluation.get("content_score", 0),
            "coms": evaluation.get("communication_score", 0), 
            "cams": evaluation.get("camera_score", 0.0),
            "vs": evaluation.get("voice_score", 0), 
            "os": overall_score,
            "fs": overall_score,  # final_score same as overall
            "audit": json.dumps(evaluation.get("content_audit", {})),
            "found": ",".join(evaluation.get("found_keywords", [])),
            "missing": ",".join(evaluation.get("missing_keywords", [])),
            "fb": f"{evaluation.get('feedback', '')}\n\nCamera: {evaluation.get('camera_feedback', '')}",
            "improved": evaluation.get("improved_answer", ""),
            "ideal": evaluation.get("ideal_answer", ""),
            "strategy": evaluation.get("strategy_note", ""),
            "rid": result_id
        })
        db.commit()
    except Exception as db_exc:
        print(f"⚠️ GD DB insert failed (non-fatal): {db_exc}")
        db.rollback()

    # 8. Cleanup & Response
    for path in audio_paths_to_cleanup + [wav_path, video_path]:
        if os.path.exists(path): os.remove(path)

    # 8. Interleave user responses into MoM for a natural flow
    # bot_context typically has bot lines. Let's interleave user turns.
    bot_lines = [line.strip() for line in bot_context.split("\n") if line.strip()]
    mom_interleaved = []
    
    # Usually Moderator starts (1-2 lines), then user turns interleave with bot turns
    bot_ptr = 0
    user_ptr = 0
    
    # Add first 1-2 lines (Moderator intro) if they exist
    while bot_ptr < 2 and bot_ptr < len(bot_lines):
        mom_interleaved.append(bot_lines[bot_ptr])
        bot_ptr += 1
        
    while bot_ptr < len(bot_lines) or user_ptr < len(user_responses):
        if user_ptr < len(user_responses):
            mom_interleaved.append(f"You: {user_responses[user_ptr]}")
            user_ptr += 1
        if bot_ptr < len(bot_lines):
            mom_interleaved.append(bot_lines[bot_ptr])
            bot_ptr += 1
            
    mom = "\n\n".join(mom_interleaved) if mom_interleaved else bot_context

    # 9. Return structured data to Flutter
    return {
        "topic": topic_text,
        "transcript": user_transcript,
        "minutes_of_meeting": mom,
        "response_breakdown": response_breakdown,
        "content_score": float(evaluation.get("content_score", 0.0)),
        "communication_score": float(evaluation.get("communication_score", 0.0)),
        "camera_score": float(evaluation.get("camera_score", 0.0)),
        "voice_score": float(evaluation.get("voice_score", 0.0)),
        "overall_score": float(evaluation.get("overall_score", 0.0)),
        "found_keywords": evaluation.get("found_keywords", []),
        "missing_keywords": evaluation.get("missing_keywords", []),
        "content_audit": evaluation.get("content_audit", {}),
        "feedback": evaluation.get("feedback", ""),
        "camera_feedback": evaluation.get("camera_feedback", ""),
        "improved_answer": evaluation.get("improved_answer", ""),
        "ideal_answer": evaluation.get("ideal_answer", ""),
        "strategy_note": evaluation.get("strategy_note", "")
    }



