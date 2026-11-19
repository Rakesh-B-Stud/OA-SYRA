import io
import time
import os
import json
import urllib.request
import urllib.error
from typing import List, Dict, Optional
from pathlib import Path

from pydantic import BaseModel
from fastapi import FastAPI, File, UploadFile, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import torch
import torch.nn as nn
import torchvision.transforms as transforms
import torchvision.models as models
from ultralytics import YOLO

BASE_DIR = Path(__file__).resolve().parent
env_file = BASE_DIR / ".env"
if env_file.exists():
    with open(env_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip()

try:
    from dotenv import load_dotenv
    load_dotenv(env_file)
except ImportError:
    pass

app = FastAPI(
    title="OASYRA ML Inference Service",
    description="Dual-model food detection (YOLO11n) and classification (MobileNetV3-Small) & Groq AI Proxy API",
    version="1.0.0",
)

# Enable CORS for public cloud deployment and mobile HTTPS clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

YOLO_WEIGHTS_PATH = BASE_DIR / "weights" / "best.pt"
MOBILENET_WEIGHTS_PATH = BASE_DIR / "weights" / "mobilenetv3_small_sih_best.pth"

yolo_model: Optional[YOLO] = None
mobilenet_model: Optional[nn.Module] = None
mobilenet_classes: List[str] = []
yolo_classes: Dict[int, str] = {}
mobilenet_transforms: Optional[transforms.Compose] = None


def compute_iou(box1: List[int], box2: List[int]) -> float:
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])

    inter_area = max(0, x2 - x1) * max(0, y2 - y1)
    if inter_area == 0:
        return 0.0

    box1_area = (box1[2] - box1[0]) * (box1[3] - box1[1])
    box2_area = (box2[2] - box2[0]) * (box2[3] - box2[1])
    union_area = box1_area + box2_area - inter_area

    return inter_area / float(union_area) if union_area > 0 else 0.0


def load_models():
    global yolo_model, mobilenet_model, mobilenet_classes, yolo_classes, mobilenet_transforms

    if not YOLO_WEIGHTS_PATH.exists():
        raise FileNotFoundError(f"YOLO weights file not found: {YOLO_WEIGHTS_PATH}")
    yolo_model = YOLO(str(YOLO_WEIGHTS_PATH))
    yolo_classes = {int(k): str(v) for k, v in yolo_model.names.items()}

    if not MOBILENET_WEIGHTS_PATH.exists():
        raise FileNotFoundError(f"MobileNet weights file not found: {MOBILENET_WEIGHTS_PATH}")

    pth = torch.load(str(MOBILENET_WEIGHTS_PATH), map_location="cpu", weights_only=True)
    if isinstance(pth, dict) and "class_names" in pth and "model_state_dict" in pth:
        mobilenet_classes = pth["class_names"]
        num_classes = len(mobilenet_classes)

        model = models.mobilenet_v3_small(weights=None)
        in_features = model.classifier[3].in_features
        model.classifier[3] = nn.Linear(in_features, num_classes)
        model.load_state_dict(pth["model_state_dict"], strict=True)
        model.eval()
        mobilenet_model = model
    else:
        raise ValueError("Invalid MobileNet checkpoint format")

    mobilenet_transforms = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        ),
    ])


@app.on_event("startup")
def startup_event():
    load_models()


@app.get("/health")
def health_check():
    models_ready = yolo_model is not None and mobilenet_model is not None
    return {
        "status": "healthy" if models_ready else "degraded",
        "models_loaded": models_ready,
        "yolo_classes_count": len(yolo_classes) if yolo_classes else 0,
        "mobilenet_classes_count": len(mobilenet_classes) if mobilenet_classes else 0,
    }


@app.get("/readiness")
def readiness_check():
    models_ready = yolo_model is not None and mobilenet_model is not None
    groq_key = os.getenv("GROQ_API_KEY") or os.getenv("XAI_API_KEY")
    groq_ready = bool(groq_key and groq_key.strip())

    is_ready = models_ready and groq_ready
    return {
        "status": "ready" if is_ready else "not_ready",
        "models_loaded": models_ready,
        "groq_configured": groq_ready,
    }


@app.post("/predict_meal")
async def predict_meal(file: UploadFile = File(...)):
    if yolo_model is None or mobilenet_model is None or mobilenet_transforms is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="ML Models are not initialized"
        )

    if file.content_type and not (file.content_type.startswith("image/") or file.content_type == "application/octet-stream"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file must be a valid image"
        )

    try:
        contents = await file.read()
        if len(contents) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded file is empty"
            )
        if len(contents) > 15 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Image size exceeds 15MB limit"
            )

        buf = io.BytesIO(contents)
        verify_img = Image.open(buf)
        verify_img.verify()

        buf.seek(0)
        image = Image.open(buf).convert("RGB")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to decode image file: File is not a valid image"
        )

    start_time = time.time()
    width, height = image.size

    try:
        results = yolo_model.predict(image, verbose=False)
        detections = []

        if results and len(results) > 0:
            raw_boxes = results[0].boxes
            parsed_boxes = []

            for box in raw_boxes:
                xyxy = box.xyxy[0].tolist()
                yolo_conf = float(box.conf[0])
                yolo_class_id = int(box.cls[0])
                yolo_label = yolo_classes.get(yolo_class_id, "unknown")

                x1, y1, x2, y2 = map(int, xyxy)
                x1 = max(0, x1)
                y1 = max(0, y1)
                x2 = min(width, x2)
                y2 = min(height, y2)

                if (x2 - x1) <= 0 or (y2 - y1) <= 0:
                    continue

                parsed_boxes.append({
                    "bbox": [x1, y1, x2, y2],
                    "yolo_conf": yolo_conf,
                    "yolo_label": yolo_label,
                })

            parsed_boxes.sort(key=lambda x: x["yolo_conf"], reverse=True)

            filtered_boxes = []
            for b in parsed_boxes:
                keep = True
                for existing in filtered_boxes:
                    if b["yolo_label"] == existing["yolo_label"]:
                        iou = compute_iou(b["bbox"], existing["bbox"])
                        if iou > 0.65:
                            keep = False
                            break
                if keep:
                    filtered_boxes.append(b)

            for item in filtered_boxes:
                x1, y1, x2, y2 = item["bbox"]
                yolo_label = item["yolo_label"]
                yolo_conf = item["yolo_conf"]

                cropped_img = image.crop((x1, y1, x2, y2))
                if cropped_img.width == 0 or cropped_img.height == 0:
                    continue

                tensor_crop = mobilenet_transforms(cropped_img).unsqueeze(0)
                with torch.inference_mode():
                    logits = mobilenet_model(tensor_crop)
                    probs = torch.softmax(logits, dim=1)[0]
                    top_idx = int(torch.argmax(probs))
                    mobilenet_conf = float(probs[top_idx])
                    mobilenet_label = mobilenet_classes[top_idx]

                has_disagreement = (yolo_label.strip().lower() != mobilenet_label.strip().lower())
                is_uncertain = (yolo_conf < 0.60 and mobilenet_conf < 0.70)

                if yolo_conf >= 0.60:
                    canonical_label = yolo_label
                elif yolo_label.strip().lower() == mobilenet_label.strip().lower():
                    canonical_label = yolo_label
                elif mobilenet_conf >= 0.70:
                    canonical_label = mobilenet_label
                else:
                    canonical_label = yolo_label

                detections.append({
                    "canonical_label": canonical_label,
                    "bbox": [x1, y1, x2, y2],
                    "has_disagreement": has_disagreement,
                    "is_uncertain": is_uncertain,
                    "yolo_class_name": yolo_label,
                    "yolo_confidence": round(yolo_conf, 4),
                    "mobilenet_class_name": mobilenet_label,
                    "mobilenet_confidence": round(mobilenet_conf, 4),
                })

        inference_time_ms = round((time.time() - start_time) * 1000, 2)

        return {
            "status": "success",
            "image_size": [width, height],
            "detection_count": len(detections),
            "inference_time_ms": inference_time_ms,
            "detections": detections,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Inference failed: {str(e)}"
        )


class ChatRequest(BaseModel):
    message: str
    history: Optional[List[Dict[str, str]]] = None
    context: Optional[str] = None


@app.post("/chat")
async def chat_proxy(req: ChatRequest):
    groq_key = os.getenv("GROQ_API_KEY") or os.getenv("XAI_API_KEY")
    base_url = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
    model = os.getenv("GROQ_MODEL", "openai/gpt-oss-120b")

    if not groq_key or not groq_key.strip():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GROQ_API_KEY environment variable is not configured in oasyra_ml/.env"
        )

    system_prompt = (
        "You are OASYRA's AI Virtual Dietitian and Health Assistant. "
        "Provide clear, empathetic, evidence-based nutrition and wellness guidance. "
        "Do not offer formal medical diagnosis."
    )
    if req.context:
        system_prompt += f"\nUser Health Context: {req.context}"

    messages = [{"role": "system", "content": system_prompt}]
    if req.history:
        for msg in req.history:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            if role in ["user", "assistant", "system"] and content:
                messages.append({"role": role, "content": content})

    messages.append({"role": "user", "content": req.message})

    url = f"{base_url.rstrip('/')}/chat/completions"
    payload = {
        "model": model,
        "messages": messages,
        "temperature": 0.7
    }

    try:
        req_data = json.dumps(payload).encode("utf-8")
        headers = {
            "Authorization": f"Bearer {groq_key.strip()}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) OASYRA/1.0"
        }
        api_req = urllib.request.Request(url, data=req_data, headers=headers, method="POST")

        with urllib.request.urlopen(api_req, timeout=30) as resp:
            resp_body = json.loads(resp.read().decode("utf-8"))

        choices = resp_body.get("choices", [])
        if choices and len(choices) > 0:
            reply = choices[0].get("message", {}).get("content", "")
            return {
                "status": "success",
                "reply": reply,
                "model": model,
            }
        else:
            return {
                "status": "success",
                "reply": "I am here to help with your health and nutrition queries. How can I assist you today?",
                "model": model,
            }

    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8") if e.fp else str(e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Groq API Error ({e.code}): {err_msg}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to communicate with Groq backend: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    server_port = int(os.getenv("PORT", 8000))
    uvicorn.run("app:app", host="0.0.0.0", port=server_port, reload=False)
