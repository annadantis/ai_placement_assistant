import cv2
import mediapipe as mp
import numpy as np

class CameraEvaluator:
    def __init__(self):
        # Resilient initialization: check multiple possible paths for solutions
        try:
            try:
                from mediapipe.solutions import face_mesh as mp_face_mesh
            except (ImportError, AttributeError):
                try:
                    from mediapipe.python.solutions import face_mesh as mp_face_mesh
                except (ImportError, AttributeError):
                    import mediapipe as mp
                    mp_face_mesh = mp.solutions.face_mesh
            
            self.mp_face_mesh = mp_face_mesh
        except Exception as e:
            print(f"⚠️  CameraEvaluator: MediaPipe init failed: {e}")
            self.mp_face_mesh = None
        # Landmark Indices
        self.LEFT_EYE = [362, 385, 386, 263, 374, 380]
        self.RIGHT_EYE = [33, 160, 158, 133, 153, 144]
        self.IRIS_L = 468
        self.IRIS_R = 473
        self.NOSE_TIP = 1
        self._neutral_pitch = 0.5 # Default fallback

    def _calculate_ear(self, landmarks, eye_indices):
        """Calculates Eye Aspect Ratio (EAR) for blink detection."""
        try:
            # Vertical distances
            v1 = np.linalg.norm(np.array([landmarks[eye_indices[1]].x, landmarks[eye_indices[1]].y]) - 
                                np.array([landmarks[eye_indices[5]].x, landmarks[eye_indices[5]].y]))
            v2 = np.linalg.norm(np.array([landmarks[eye_indices[2]].x, landmarks[eye_indices[2]].y]) - 
                                np.array([landmarks[eye_indices[4]].x, landmarks[eye_indices[4]].y]))
            # Horizontal distance
            h = np.linalg.norm(np.array([landmarks[eye_indices[0]].x, landmarks[eye_indices[0]].y]) - 
                               np.array([landmarks[eye_indices[3]].x, landmarks[eye_indices[3]].y]))
            return (v1 + v2) / (2.0 * h)
        except:
            return 0.3 # Default stable EAR

    def analyze_video(self, video_path):
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS) or 30
        
        # Performance Trackers
        frames = 0
        face_detected = 0
        eye_contact = 0
        blinks = 0
        looking_down = 0
        baseline_pitch_list = []
        
        blink_active = False
        ear_threshold = 0.23  # Slightly more sensitive threshold (was 0.21)

        with self.mp_face_mesh.FaceMesh(
            refine_landmarks=True, 
            min_detection_confidence=0.6,
            min_tracking_confidence=0.6
        ) as face_mesh:
            
            while cap.isOpened():
                success, frame = cap.read()
                if not success: break
                
                frames += 1
                results = face_mesh.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                
                if results.multi_face_landmarks:
                    face_detected += 1
                    mesh = results.multi_face_landmarks[0].landmark
                    
                    # 1. BLINK DETECTION (EAR)
                    avg_ear = (self._calculate_ear(mesh, self.LEFT_EYE) + 
                               self._calculate_ear(mesh, self.RIGHT_EYE)) / 2.0
                    
                    if avg_ear < ear_threshold:
                        if not blink_active:
                            blinks += 1
                            blink_active = True
                    else:
                        blink_active = False

                    # ADAPTIVE CALIBRATION & MIRROR-SAFE TRACKING
                    eye_dist = np.linalg.norm(np.array([mesh[33].x, mesh[33].y]) - 
                                             np.array([mesh[263].x, mesh[263].y]))
                    
                    eye_y_avg = (mesh[33].y + mesh[263].y) / 2.0
                    nose_eye_v_dist = mesh[self.NOSE_TIP].y - eye_y_avg

                    # 1. POSTURE CALIBRATION (First 30 frames of face detection)
                    if face_detected <= 30:
                        baseline_pitch_list.append(nose_eye_v_dist)
                    else:
                        # Establish neutral baseline if not already done
                        if self._neutral_pitch == 0.5:
                            if baseline_pitch_list:
                                self._neutral_pitch = sum(baseline_pitch_list) / len(baseline_pitch_list)

                        # EXTREME STRICT READING DETECTION (Relative to Baseline)
                        # Flag as reading if nose drops > 35% below their specific neutral point
                        if nose_eye_v_dist > (self._neutral_pitch * 1.35):
                            looking_down += 1

                    # 2. EYE CONTACT (Robust Dual-Iris Centering)
                    # Left Eye
                    l_min, l_max = min(mesh[362].x, mesh[263].x), max(mesh[362].x, mesh[263].x)
                    l_width = l_max - l_min
                    # Right Eye
                    r_min, r_max = min(mesh[33].x, mesh[133].x), max(mesh[33].x, mesh[133].x)
                    r_width = r_max - r_min
                    
                    # VALID TRACKING CHECK: Only count if eye measurements are physically possible
                    if l_width > 0.001 and r_width > 0.001:
                        l_relative = (mesh[self.IRIS_L].x - l_min) / l_width
                        r_relative = (mesh[self.IRIS_R].x - r_min) / r_width
                        avg_relative = (l_relative + r_relative) / 2.0
                        
                        # EXTREME STRICT RANGE: 0.42 - 0.58
                        if 0.42 < avg_relative < 0.58:
                            eye_contact += 1
                    else:
                        avg_relative = 0.0 # Force low score if tracking is flaky

                    # Frame-level Diagnostics (Combined)
                    if face_detected <= 10:
                        print(f"DIAG [F{face_detected}]: rel={avg_relative:.2f}, n-e_dist={nose_eye_v_dist:.3f}, ear={avg_ear:.3f}, scale={eye_dist:.3f}")
                    elif face_detected == 31:
                         print(f"DIAG: Baseline Established: {self._neutral_pitch:.3f}")

        cap.release()

        # --- SCORE CALCULATION ---
        if frames == 0:
            return {"camera_score": 0, "error": "No frames processed"}

        duration_sec = float(frames) / float(fps)
        face_visibility = (float(face_detected) / float(frames)) * 100.0
        eye_contact_pct = (float(eye_contact) / float(max(1, face_detected))) * 100.0
        reading_pct = (float(looking_down) / float(max(1, face_detected))) * 100.0
        blink_rate = (float(blinks) / (duration_sec / 60.0)) if duration_sec > 0 else 0.0

        # Mathematical Scoring (Deterministic)
        # Weightage: 60% Eye Contact, 30% Posture, 10% Visibility
        base_score = (eye_contact_pct * 0.06) + (max(0, 100 - reading_pct) * 0.03) + (face_visibility * 0.01)
        
        # EXTREME STRICT PENALTIES
        if blink_rate > 25: base_score -= 2.5 
        if reading_pct > 25: base_score -= 3.0 
        if face_visibility < 50: base_score -= 5.0 

        final_score = round(max(0, min(10, base_score)), 1)

        return {
            "camera_score": final_score,
            "metrics": {
                "total_frames": frames,
                "face_detected_frames": face_detected,
                "eye_contact_percent": round(eye_contact_pct, 1),
                "blink_rate_per_min": round(blink_rate, 1),
                "reading_likelihood_pct": round(reading_pct, 1),
                "face_visibility_pct": round(face_visibility, 1)
            },
            "camera_feedback": f"Face detected in {face_visibility:.1f}% of frames. Eye contact at {eye_contact_pct:.1f}%."
        }

# Usage Example:
# evaluator = CameraEvaluator()
# result = evaluator.analyze_video("user_gd_video.mp4")
# print(result)
