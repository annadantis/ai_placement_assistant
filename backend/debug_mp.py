import traceback
try:
    import mediapipe as mp
    mp_face_mesh = mp.solutions.face_mesh
    print("mp.solutions.face_mesh imported OK:", mp_face_mesh)
    mesh = mp_face_mesh.FaceMesh(refine_landmarks=True, min_detection_confidence=0.5)
    print("FaceMesh instance created successfully!")
    mesh.close()
    print("ALL GOOD - MediaPipe will work in main.py")
except Exception as e:
    print("FAILED:")
    traceback.print_exc()
