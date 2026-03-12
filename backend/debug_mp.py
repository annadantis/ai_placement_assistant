import os
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import traceback

print("--- Checking MediaPipe Tasks API ---")
try:
    model_path = os.path.join(os.path.dirname(__file__), 'face_landmarker.task')
    if not os.path.exists(model_path):
        print(f"ERROR: Model file missing at {model_path}")
        exit(1)
        
    base_options = python.BaseOptions(model_asset_path=model_path)
    options = vision.FaceLandmarkerOptions(
        base_options=base_options,
        output_face_blendshapes=False,
        output_facial_transformation_matrixes=False,
        num_faces=1)
    
    detector = vision.FaceLandmarker.create_from_options(options)
    print("SUCCESS: MediaPipe FaceLandmarker created successfully!")
    detector.close()
    print("ALL GOOD - MediaPipe Tasks will work in camera_eval.py")
except Exception as e:
    print("FAILED during Tasks API check:")
    traceback.print_exc()
