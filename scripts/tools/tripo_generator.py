#!/usr/bin/env python3
"""
Tripo 3D Generator & Blender Clean-up Pipeline Automation for Antigravity

Features:
1. Generate 3D models via Tripo API (Text-to-3D or Image-to-3D)
2. Batch clean-up locally placed 3D models (GLB/GLTF/OBJ) using Blender
3. Export optimized FBX/GLTF ready for Godot 4
"""

import sys
import os
import time
import subprocess
import json
import argparse
import urllib.request

BLENDER_BIN = "/Applications/Blender.app/Contents/MacOS/Blender"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLENDER_SCRIPT = os.path.join(SCRIPT_DIR, "blender_cleanup_pipeline.py")
RAW_DIR = os.path.join(os.path.dirname(os.path.dirname(SCRIPT_DIR)), "assets", "models", "raw")
FBX_DIR = os.path.join(os.path.dirname(os.path.dirname(SCRIPT_DIR)), "assets", "models", "fbx")

def cleanup_with_blender(input_path, output_path, decimate=0.5):
    """Run headless Blender cleanup script"""
    print(f"\n[Pipeline] Launching Blender cleanup: {input_path} -> {output_path}")
    cmd = [
        BLENDER_BIN,
        "-b",
        "-P", BLENDER_SCRIPT,
        "--",
        input_path,
        output_path,
        str(decimate)
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[Pipeline] Blender error:\n{res.stderr}")
        return False
    print(f"[Pipeline] Blender cleanup succeeded: {output_path}")
    return True

def generate_tripo_text(prompt, api_key, output_name):
    """Generate 3D model via Tripo Text-to-Model API"""
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    payload = json.dumps({
        "prompt": prompt,
        "model": "v3.1-20260211"
    }).encode("utf-8")

    print(f"[Tripo API] Submitting prompt: '{prompt}'...")
    req = urllib.request.Request(
        "https://openapi.tripo3d.ai/v3/generation/text-to-model",
        data=payload,
        headers=headers,
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            res_json = json.loads(response.read().decode("utf-8"))
    except Exception as e:
        print(f"[Tripo API] Error submitting task: {e}")
        return None

    if res_json.get("code") != 0:
        print(f"[Tripo API] Error response: {res_json}")
        return None

    task_id = res_json["data"]["task_id"]
    print(f"[Tripo API] Task started. Task ID: {task_id}")

    # Polling status
    status_url = f"https://openapi.tripo3d.ai/v3/tasks/{task_id}"
    while True:
        time.sleep(3)
        status_req = urllib.request.Request(status_url, headers=headers)
        with urllib.request.urlopen(status_req) as s_res:
            s_data = json.loads(s_res.read().decode("utf-8")).get("data", {})
        
        status = s_data.get("status")
        progress = s_data.get("progress", 0)
        print(f"[Tripo API] Progress: {progress}% (Status: {status})")

        if status == "success":
            model_url = s_data["output"]["model_url"]
            print(f"[Tripo API] Model generated! Downloading...")
            os.makedirs(RAW_DIR, exist_ok=True)
            raw_glb = os.path.join(RAW_DIR, f"{output_name}.glb")
            urllib.request.urlretrieve(model_url, raw_glb)
            print(f"[Tripo API] Saved raw model: {raw_glb}")
            return raw_glb
        elif status in ["failed", "cancelled"]:
            print(f"[Tripo API] Generation {status}.")
            return None

def main():
    parser = argparse.ArgumentParser(description="Tripo + Blender FBX Pipeline")
    parser.add_argument("--prompt", type=str, help="Text prompt for Tripo 3D generation")
    parser.add_argument("--name", type=str, default="asset", help="Base name of the generated asset")
    parser.add_argument("--api-key", type=str, default=os.environ.get("TRIPO_API_KEY", ""), help="Tripo API key")
    parser.add_argument("--input", type=str, help="Direct input file path to clean up in Blender")
    parser.add_argument("--batch-raw", action="store_true", help="Clean up all raw models in assets/models/raw")
    parser.add_argument("--decimate", type=float, default=0.5, help="Decimate ratio (default 0.5)")
    args = parser.parse_args()

    os.makedirs(RAW_DIR, exist_ok=True)
    os.makedirs(FBX_DIR, exist_ok=True)

    # 1. Tripo Text Generation
    if args.prompt:
        if not args.api_key:
            print("[Error] Tripo API Key is required for generation. Set TRIPO_API_KEY env var or use --api-key.")
            print("Note: If you have generated models on tripo3d.ai Web, please place the downloaded .glb/.obj into:")
            print(f"  {RAW_DIR}")
            print("and run with --batch-raw to clean up with Blender and export to FBX!")
            sys.exit(1)
        raw_model = generate_tripo_text(args.prompt, args.api_key, args.name)
        if raw_model:
            out_fbx = os.path.join(FBX_DIR, f"{args.name}.fbx")
            cleanup_with_blender(raw_model, out_fbx, args.decimate)

    # 2. Single Input Cleanup
    elif args.input:
        base_name = os.path.splitext(os.path.basename(args.input))[0]
        out_fbx = os.path.join(FBX_DIR, f"{base_name}.fbx")
        cleanup_with_blender(args.input, out_fbx, args.decimate)

    # 3. Batch Cleanup of RAW models
    elif args.batch_raw:
        files = [f for f in os.listdir(RAW_DIR) if f.lower().endswith(('.glb', '.gltf', '.obj'))]
        if not files:
            print(f"[Pipeline] No raw model files found in {RAW_DIR}")
            print("Please place .glb or .obj files from Tripo there.")
            return
        for f in files:
            in_path = os.path.join(RAW_DIR, f)
            b_name = os.path.splitext(f)[0]
            out_fbx = os.path.join(FBX_DIR, f"{b_name}.fbx")
            cleanup_with_blender(in_path, out_fbx, args.decimate)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
