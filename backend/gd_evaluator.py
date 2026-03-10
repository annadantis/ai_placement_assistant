import json
import re
import ollama
import librosa
import numpy as np

# ---------------------------
# SILENCE DETECTION
# ---------------------------

def is_silent_audio(audio_path: str) -> bool:
    """Check if audio file contains meaningful speech"""
    try:
        y, sr = librosa.load(audio_path, sr=None)
        intervals = librosa.effects.split(y, top_db=25)
        speech_time = sum((end - start) / sr for start, end in intervals)
        return speech_time < 1.0  # less than 1 sec speech = silent
    except Exception as e:
        print(f"Error analyzing audio: {e}")
        return True


def is_silent_transcript(transcript: str) -> bool:
    """Check if transcript contains meaningful content"""
    if not transcript:
        return True
    words = transcript.strip().split()
    return len(words) < 3


# ---------------------------
# OLLAMA RUNNER
# ---------------------------

def run_ollama(prompt: str) -> str:
    """
    Call Ollama API with the given prompt.
    Returns the model's response.
    """
    try:
        response = ollama.generate(
            model='llama3',
            prompt=prompt
        )
        return response['response'].strip()
    except Exception as e:
        print(f"Error calling Ollama: {e}")
        raise


# ---------------------------
# JSON EXTRACTION (ROBUST)
# ---------------------------

def extract_json(text: str) -> dict:
    """
    Extracts the FIRST valid JSON object from model output.
    Handles extra whitespace, newlines, or text.
    """
    match = re.search(r"\{[\s\S]*\}", text)
    if not match:
        raise ValueError(f"No JSON found in response.\nRaw output:\n{text}")

    try:
        return json.loads(match.group())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in response.\nRaw output:\n{text}") from e


# ---------------------------
# MAIN EVALUATION FUNCTION
# ---------------------------

def evaluate_gd(topic: str, transcript: str, audio_path: str, camera_score: float = 0.0, target_keywords: list = None) -> dict:
    """
    Central GD evaluation logic using Ollama with Keyword Audit and Weighted Overall Score.
    """
    if target_keywords is None:
        target_keywords = []

    # ---------------------------
    # HARD FAIL: SILENCE
    # ---------------------------
    if is_silent_audio(audio_path) or is_silent_transcript(transcript):
        return {
            "overall_score": 0,
            "transcript": transcript or "",
            "content_score": 0,
            "communication_score": 0,
            "voice_score": 0,
            "camera_score": camera_score,
            "feedback": "No meaningful speech detected. Please speak clearly.",
            "improved_answer": "",
            "ideal_answer": "",
            "strategy_note": ""
        }

    # ---------------------------
    # CALCULATE VOICE METRICS
    # ---------------------------
    try:
        y, sr = librosa.load(audio_path, sr=None)
        duration = librosa.get_duration(y=y, sr=sr)
        word_count = len(transcript.split())
        wpm = (word_count / duration) * 60 if duration > 0 else 0
        wpm_score = max(0, 10 - (abs(145 - wpm) / 10))
        
        intervals = librosa.effects.split(y, top_db=30)
        speech_time = sum((end - start) / sr for start, end in intervals)
        silence_pct = ((duration - speech_time) / duration) * 100
        silence_score = 10 if 10 <= silence_pct <= 20 else max(0, 10 - abs(15 - silence_pct) / 2)
        
        fillers = [r'\bum\b', r'\buh\b', r'\blike\b', r'\bactually\b', r'\bbasically\b']
        filler_count = sum(len(re.findall(f, transcript.lower())) for f in fillers)
        filler_score = max(0, 10 - (filler_count * 2))

        final_voice_score = round(float((wpm_score * 0.4) + (silence_score * 0.3) + (filler_score * 0.3)), 1)
    except:
        final_voice_score = 0
        wpm, silence_pct, filler_count = 0, 0, 0

    # ---------------------------
    # KEYWORD AUDIT (Ground Truth)
    # ---------------------------
    found_keywords = [k for k in target_keywords if k.lower() in transcript.lower()]
    missing_keywords = [k for k in target_keywords if k.lower() not in transcript.lower()]
    keyword_coverage = (len(found_keywords) / len(target_keywords) * 100) if target_keywords else 0

    # ---------------------------
    # OLLAMA PROMPT
    # ---------------------------
    prompt = f"""
You are a Senior Corporate HR Evaluator and Communication Coach. Your goal is to provide a strict, data-driven assessment and actionable model answers.

TOPIC: "{topic}"
USER TRANSCRIPT: "{transcript}"

--- SYSTEM DATA (FACTS) ---
1. VOICE ANALYSIS:
   - Math Voice Score: {final_voice_score}/10
   - Speed: {wpm:.1f} WPM
   - Silence: {silence_pct:.1f}%
   - Fillers: {filler_count}

2. KEYWORD AUDIT:
   - Required Industry Terms: {target_keywords}
   - Terms Actually Used: {found_keywords}
   - Keyword Coverage: {keyword_coverage:.1f}%

--- STRICT SCORING RULES ---
- RELEVANCE HARD-STOP: If transcript is unrelated to TOPIC, 'content_score' MUST be ≤ 2.
- DEPTH PENALTY: If Keyword Coverage is < 40%, 'depth' cannot exceed 5. 
- COMMUNICATION SCORE: Baseline is Mathematical Voice Score ({final_voice_score}).
- BE STRICT: Scores of 8+ are for industry-ready performances.

--- GENERATION TASKS ---
1. IMPROVED_ANSWER: Rewrite the USER TRANSCRIPT to be professional. 
   - Keep the user's original ideas but remove all {filler_count} fillers.
   - Fix grammar and enhance the vocabulary slightly. 
   - This should sound like a "better version" of the user.

2. IDEAL_ANSWER: Provide a 10/10 Master Response for the topic "{topic}".
   - Use a structured approach: Introduction -> Argument with {target_keywords} -> Conclusion.
   - Use high-level industry logic and data-driven points.

RETURN ONLY VALID JSON:
{{
  "content_score": <int 0-10>,
  "communication_score": <int 0-10>,
  "content_audit": {{
      "relevance": <0-10>,
      "depth": <0-10>,
      "structure": <0-10>,
      "vocabulary_precision": <0-10>
  }},
  "feedback": "<blunt, professional critique>",
  "improved_answer": "<the user's points, polished and professional>",
  "ideal_answer": "<the 150-word expert-level model response>",
  "strategy_note": "<one sentence explaining why the Ideal Answer is superior to the Improved one>"
}}
"""

    try:
        raw_output = run_ollama(prompt)
        result = extract_json(raw_output)
    except Exception as e:
        return {
            "error": str(e),
            "transcript": transcript,
            "overall_score": 0,
            "content_score": 0,
            "communication_score": 0,
            "voice_score": 0,
            "camera_score": camera_score,
            "feedback": f"Evaluation error: {str(e)}",
            "improved_answer": "",
            "ideal_answer": "",
            "strategy_note": ""
        }

    # Normalize and Apply Word Count/Relevance Penalty
    c_score = int(max(0, min(10, result.get("content_score", 0))))
    comm_score = int(max(0, min(10, result.get("communication_score", 0))))
    relevance_audit = result.get("content_audit", {}).get("relevance", 10)

    # 1. Short Transcript Penalty
    if len(transcript.split()) < 15:
        c_score = min(c_score, 4)
        comm_score = min(comm_score, 4)
        result["feedback"] = "Critically short. " + result.get("feedback", "")

    # 2. Relevance Hard-Stop (Programmatic Safety)
    # If AI flags low relevance OR 0 keywords used on weak content
    if relevance_audit <= 3 or (keyword_coverage == 0 and c_score > 3):
        c_score = min(c_score, 2)
        if relevance_audit <= 2: result["feedback"] = "Topic Mismatch: " + result.get("feedback", "")

    # ---------------------------
    # OVERALL SCORE CALCULATION
    # ---------------------------
    # Logic: 45% Content, 30% Communication, 25% Camera
    overall_score = round(float((c_score * 0.45) + (comm_score * 0.30) + (camera_score * 0.25)), 1)

    # Add calculated stats to final result
    result.update({
        "overall_score": overall_score,
        "transcript": transcript,
        "voice_score": final_voice_score,
        "camera_score": camera_score,
        "keyword_coverage": f"{keyword_coverage:.1f}%",
        "found_keywords": found_keywords,
        "missing_keywords": missing_keywords
    })

    return result

if __name__ == "__main__":
    test_topic = "Should artificial intelligence replace human decision-making?"
    # Industry keywords for this topic
    keywords = ["Ethical frameworks", "Algorithmic bias", "Accountability", "Human-in-the-loop", "Efficiency"]
    
    test_transcript = "AI is fast and efficient, but we need accountability. Algorithmic bias is a big risk if we don't have a human-in-the-loop."
    test_audio = "test.wav" 
    
    print("Evaluating with Keyword Audit...")
    report = evaluate_gd(test_topic, test_transcript, test_audio, target_keywords=keywords)
    print(json.dumps(report, indent=2))



