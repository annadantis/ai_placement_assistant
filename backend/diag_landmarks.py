import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import os
import numpy as np

def diagnose_video(video_path):
    model_path = os.path.join(os.getcwd(), 'backend', 'face_landmarker.task')
    if not os.path.exists(model_path):
        print(f"ERROR: Model file not found at {model_path}")
        return

    print(f"Analyzing Iris Centering in: {video_path}")
    
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print("ERROR: Could not open video.")
        return

    base_options = python.BaseOptions(model_asset_path=model_path)
    options = vision.FaceLandmarkerOptions(
        base_options=base_options,
        output_face_blendshapes=False,
        output_facial_transformation_matrixes=False,
        num_faces=1)
    
    detector = vision.FaceLandmarker.create_from_options(options)
    
    frame_count = 0
    faces_found = 0
    IRIS_L = 468
    IRIS_R = 473
    
    while cap.isOpened() and faces_found < 10:
        success, frame = cap.read()
        if not success:
            break
        
        frame_count += 1
        if frame_count % 5 != 0: continue
        
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
        
        results = detector.detect(mp_img)
        
        if results.face_landmarks:
            faces_found += 1
            mesh = results.face_landmarks[0]
            
            # Left Eye: 362 (inner), 263 (outer)
            x_362, x_263 = mesh[362].x, mesh[263].x
            l_min, l_max = min(x_362, x_263), max(x_362, x_263)
            
            # Right Eye: 33 (outer), 133 (inner)
            x_33, x_133 = mesh[33].x, mesh[133].x
            r_min, r_max = min(x_33, x_133), max(x_33, x_133)

            rel_l = -1
            rel_r = -1
            
            if (l_max - l_min) > 0.001:
                rel_l = (mesh[IRIS_L].x - l_min) / (l_max - l_min)
            
            if (r_max - r_min) > 0.001:
                rel_r = (mesh[IRIS_R].x - r_min) / (r_max - r_min)
                
            in_range_l = 0.30 < rel_l < 0.70
            in_range_r = 0.30 < rel_r < 0.70
            
            print(f"Frame {frame_count}: L_Rel: {rel_l:.3f} ({in_range_l}), R_Rel: {rel_r:.3f} ({in_range_r})")
        
    detector.close()
    cap.release()

if __name__ == "__main__":
    video_dir = os.path.join(os.getcwd(), 'backend', 'uploads')
    videos = [f for f in os.listdir(video_dir) if f.endswith('.mp4')]
    if videos:
        # Sort by name to be consistent
        videos.sort()
        diagnose_video(os.path.join(video_dir, videos[0]))
    else:
        print("No mp4 videos found in uploads.")
