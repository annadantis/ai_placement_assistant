import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import os
import numpy as np

def diagnose_full_eyes(video_path):
    model_path = os.path.join(os.getcwd(), 'backend', 'face_landmarker.task')
    cap = cv2.VideoCapture(video_path)
    
    base_options = python.BaseOptions(model_asset_path=model_path)
    options = vision.FaceLandmarkerOptions(
        base_options=base_options,
        num_faces=1)
    
    detector = vision.FaceLandmarker.create_from_options(options)
    
    success, frame = cap.read()
    if success:
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
        results = detector.detect(mp_img)
        
        if results.face_landmarks:
            mesh = results.face_landmarks[0]
            print("\n--- EYE LANDMARK FULL DUMP ---")
            
            # Left Eye
            L_CORNERS = [362, 263, 33, 133] # Let's check both sides indices to see which is which
            R_CORNERS = [33, 133, 362, 263]
            
            def p(idx):
                lm = mesh[idx]
                return f"idx {idx}: ({lm.x:.4f}, {lm.y:.4f})"

            print(f"L_INNER (362): {p(362)}")
            print(f"L_OUTER (263): {p(263)}")
            print(f"R_INNER (133): {p(133)}")
            print(f"R_OUTER (33): {p(33)}")
            print(f"L_IRIS (468): {p(468)}")
            print(f"R_IRIS (473): {p(473)}")
            print(f"NOSE (1): {p(1)}")
            
            # Distance check
            dist_l = abs(mesh[362].x - mesh[263].x)
            dist_r = abs(mesh[133].x - mesh[33].x)
            print(f"L_EYE Width: {dist_l:.4f}")
            print(f"R_EYE Width: {dist_r:.4f}")
            
    detector.close()
    cap.release()

if __name__ == "__main__":
    video_dir = os.path.join(os.getcwd(), 'backend', 'uploads')
    videos = [f for f in os.listdir(video_dir) if f.endswith('.mp4')]
    if videos:
        diagnose_full_eyes(os.path.join(video_dir, videos[0]))
