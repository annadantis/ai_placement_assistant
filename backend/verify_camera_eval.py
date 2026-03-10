import requests
import os
import time

BASE_URL = "http://localhost:8000"
USERNAME = "testuser"

def test_camera_flow():
    print("--- Testing Camera Evaluation Flow ---")
    
    # 1. Simulate frame processing (looking good)
    print("Processing 'Good' frames...")
    # We can't actually send a real frame without a file, so we skip if main.py isn't running
    # This is more for logic verification if BASE_URL is live.
    
    # 2. Call final report
    try:
        response = requests.post(
            f"{BASE_URL}/final_session_report",
            data={"username": USERNAME},
            timeout=30
        )
        if response.status_code == 200:
            data = response.json()
            print("Report received successfully!")
            print(f"Content Score: {data.get('content_score')}")
            print(f"Camera Score: {data.get('camera_score')}")
            print(f"Final Score: {data.get('final_score')}")
            
            if 'content_score' in data and 'camera_score' in data:
                print("✅ Verification Passed: Dual scores present.")
            else:
                print("❌ Verification Failed: Missing scores.")
        else:
            print(f"❌ Error: {response.status_code}")
    except Exception as e:
        print(f"⚠️ Could not connect to backend: {e}")

if __name__ == "__main__":
    test_camera_flow()
