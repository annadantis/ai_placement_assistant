import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import os
import numpy as np

def diagnose_landmarks(video_path):
    model_path = os.path.join(os.getcwd(), 'backend', 'face_landmarker.task')
    cap = cv2.VideoCapture(video_path)
    
    base_options = python.BaseOptions(model_asset_path=model_path)
    options = vision.FaceLandmarkerOptions(
        base_options=base_options,
        output_face_blendshapes=False,
        output_facial_transformation_matrixes=False,
        num_faces=1)
    
    detector = vision.FaceLandmarker.create_from_options(options)
    
    while cap.isOpened():
        success, frame = cap.read()
        if not success: break
        
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
        results = detector.detect(mp_img)
        
        if results.face_landmarks:
            mesh = results.face_landmarks[0]
            print("\n--- LANDMARK DIAGNOSTICS ---")
            print(f"Total landmarks: {len(mesh)}")
            
            # Key indices
            # Left Eye: 362 (inner), 263 (outer). Iris: 468
            # Right Eye: 133 (inner), 33 (outer). Iris: 473
            indices = {
                "Left Inner (362)": 362,
                "Left Outer (263)": 263,
                "Left Iris (468)": 468,
                "Right Inner (133)": 133,
                "Right Outer (33)": 33,
                "Right Iris (473)": 473,
                "Nose Tip (1)": 1
            }
            
            for name, idx in indices.items():
                if idx < len(mesh):
                    lm = mesh[idx]
                    print(f"{name}: x={lm.x:.4f}, y={lm.y:.4f}, z={lm.z:.4f}")
            
            # Check if Iris is centered
            x_362, x_263 = mesh[362].x, mesh[263].x
            l_min, l_max = min(x_362, x_263), max(x_362, x_263)
            rel_l = (mesh[468].x - l_min) / (l_max - l_min) if (l_max - l_min) > 0 else -999
            
            x_33, x_133 = mesh[33].x, mesh[133].x
            r_min, r_max = min(x_33, x_133), max(x_33, x_133)
            rel_r = (mesh[473].x - r_min) / (r_max - r_min) if (r_max - r_min) > 0 else -999
            
            print(f"Calculated Rel_L: {rel_l:.4f}")
            print(f"Calculated Rel_R: {rel_r:.4f}")
            break
            
    detector.close()
    cap.release()

if __name__ == "__main__":
    video_dir = os.path.join(os.getcwd(), 'backend', 'uploads')
    videos = [f for f in os.listdir(video_dir) if f.endswith('.mp4')]
    if videos:
        diagnose_landmarks(os.path.join(video_dir, videos[0]))
