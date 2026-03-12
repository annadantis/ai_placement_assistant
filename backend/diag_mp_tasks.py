import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import os
import numpy as np

def diagnose():
    model_path = os.path.join(os.getcwd(), 'backend', 'face_landmarker.task')
    if not os.path.exists(model_path):
        print(f"ERROR: Model file not found at {model_path}")
        return

    print(f"Using model: {model_path}")
    
    try:
        base_options = python.BaseOptions(model_asset_path=model_path)
        options = vision.FaceLandmarkerOptions(
            base_options=base_options,
            output_face_blendshapes=False,
            output_facial_transformation_matrixes=False,
            num_faces=1)
        
        detector = vision.FaceLandmarker.create_from_options(options)
        print("Success: FaceLandmarker created.")
        
        # Create a blank image to test detection (might not find a face, but checks API)
        blank_image = np.zeros((480, 640, 3), dtype=np.uint8)
        mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=blank_image)
        
        results = detector.detect(mp_img)
        print("Success: detector.detect() called.")
        
        if not results.face_landmarks:
            print("No face detected in blank image (expected).")
            # To actually check landmark count, we need a face. 
            # But we can at least check if we can reach this point.
        
        detector.close()
        
    except Exception as e:
        print(f"FAILURE during diagnosis: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    diagnose()
