import io
import time
import os
import json
import base64
import urllib.request
import urllib.error
from typing import List, Dict, Optional, Any
from pathlib import Path

from pydantic import BaseModel
from fastapi import FastAPI, File, Form, UploadFile, HTTPException, status, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
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
    description="Dual-model food detection (YOLO11n) and classification (MobileNetV3-Small) & Grok AI Proxy API",
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


def sanitize_and_convert_tables(text: str) -> str:
    if not text:
        return text

    import re
    text = re.sub(r'</?(table|tbody|thead|tr|td|th)[^>]*>', '', text, flags=re.IGNORECASE)

    lines = text.split('\n')
    output_lines = []
    headers = []

    for line in lines:
        stripped = line.strip()
        if re.match(r'^\|?\s*:?-+:?\s*(\|:?\s*-+:?\s*)*\|?$', stripped) or ('---' in stripped and '|' in stripped):
            continue

        if stripped.startswith('|') and stripped.endswith('|'):
            cells = [c.strip() for c in stripped.split('|')[1:-1]]
            if not cells or all(c == '' for c in cells):
                continue

            if all(set(c).issubset({'-', ':', ' '}) for c in cells):
                continue

            if not headers:
                headers = cells
            else:
                if headers and len(headers) == len(cells):
                    row_title = cells[0]
                    output_lines.append(f"\n**{row_title}**")
                    for h, c in zip(headers[1:], cells[1:]):
                        if c:
                            output_lines.append(f"- **{h}**: {c}")
                else:
                    first_cell = cells[0]
                    other_cells = [c for c in cells[1:] if c]
                    if other_cells:
                        output_lines.append(f"- **{first_cell}**: {', '.join(other_cells)}")
                    else:
                        output_lines.append(f"- {first_cell}")
        else:
            if headers:
                headers = []
            output_lines.append(line)

    return '\n'.join(output_lines)


class StreamTableSanitizer:
    def __init__(self):
        self.buffer = ""
        self.in_table = False
        self.table_lines = []

    def feed(self, chunk: str) -> List[str]:
        import re
        output_chunks = []
        self.buffer += chunk

        while "\n" in self.buffer:
            line, self.buffer = self.buffer.split("\n", 1)
            line_str = line.strip()

            is_table_line = (line_str.startswith("|") and line_str.endswith("|")) or bool(re.match(r'^\|?\s*:?-+:?\s*(\|:?\s*-+:?\s*)*\|?$', line_str))

            if is_table_line:
                self.in_table = True
                self.table_lines.append(line)
            else:
                if self.in_table and self.table_lines:
                    converted_table = sanitize_and_convert_tables("\n".join(self.table_lines))
                    output_chunks.append(converted_table + "\n")
                    self.table_lines = []
                    self.in_table = False

                output_chunks.append(line + "\n")

        return output_chunks

    def flush(self) -> List[str]:
        output_chunks = []
        if self.in_table and self.table_lines:
            converted_table = sanitize_and_convert_tables("\n".join(self.table_lines))
            output_chunks.append(converted_table + "\n")
            self.table_lines = []
            self.in_table = False

        if self.buffer:
            output_chunks.append(self.buffer)
            self.buffer = ""

        return output_chunks


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
        "Provide clear, empathetic, evidence-based nutrition, obesity management, and wellness guidance. "
        "Do not offer formal medical diagnosis or prescribe clinical medication. "
        "Acknowledge user greetings using the current local time context provided in User Health Context (e.g. Good morning, Good afternoon, Good evening, Good night). "
        "Do not repeat greetings unnecessarily in an ongoing conversation. "
        "Format responses with clean Markdown: use short paragraphs, bold key terms and numbers (**term**), bullet points for recommendations (- item), "
        "and numbered lists for procedures, meal plans, or steps. Use section headings (### Section) for long answers. "
        "STRICTLY PROHIBIT Markdown tables, HTML tables, and tabular comparisons. Do not generate markdown tables under any circumstances. "
        "If asked about unrelated non-health topics (programming, politics, entertainment, general trivia), politely explain that OASYRA is designed exclusively for nutrition, diet, health, and lifestyle guidance."
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
                "reply": sanitize_and_convert_tables(reply),
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


@app.post("/chat/stream")
async def chat_stream_proxy(req: ChatRequest):
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
        "Provide clear, empathetic, evidence-based nutrition, obesity management, and wellness guidance. "
        "Do not offer formal medical diagnosis or prescribe clinical medication. "
        "Acknowledge user greetings using the current local time context provided in User Health Context (e.g. Good morning, Good afternoon, Good evening, Good night). "
        "Do not repeat greetings unnecessarily in an ongoing conversation. "
        "Format responses with clean Markdown: use short paragraphs, bold key terms and numbers (**term**), bullet points for recommendations (- item), "
        "and numbered lists for procedures, meal plans, or steps. Use section headings (### Section) for long answers. "
        "STRICTLY PROHIBIT Markdown tables, HTML tables, and tabular comparisons. Do not generate markdown tables under any circumstances. "
        "If asked about unrelated non-health topics (programming, politics, entertainment, general trivia), politely explain that OASYRA is designed exclusively for nutrition, diet, health, and lifestyle guidance."
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
        "temperature": 0.7,
        "stream": True
    }

    async def event_generator():
        sanitizer = StreamTableSanitizer()
        try:
            req_data = json.dumps(payload).encode("utf-8")
            headers = {
                "Authorization": f"Bearer {groq_key.strip()}",
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) OASYRA/1.0"
            }
            api_req = urllib.request.Request(url, data=req_data, headers=headers, method="POST")

            with urllib.request.urlopen(api_req, timeout=60) as resp:
                for line in resp:
                    line_str = line.decode("utf-8").strip()
                    if not line_str:
                        continue
                    if line_str.startswith("data: "):
                        data_content = line_str[6:].strip()
                        if data_content == "[DONE]":
                            flush_chunks = sanitizer.flush()
                            for out in flush_chunks:
                                if out:
                                    yield f"data: {json.dumps({'chunk': out})}\n\n"
                            yield "data: [DONE]\n\n"
                            break
                        try:
                            chunk_json = json.loads(data_content)
                            choices = chunk_json.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {})
                                content_chunk = delta.get("content", "")
                                if content_chunk:
                                    sanitized_pieces = sanitizer.feed(content_chunk)
                                    for piece in sanitized_pieces:
                                        if piece:
                                            yield f"data: {json.dumps({'chunk': piece})}\n\n"
                        except Exception:
                            pass
            flush_chunks = sanitizer.flush()
            for out in flush_chunks:
                if out:
                    yield f"data: {json.dumps({'chunk': out})}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")


@app.post("/chat/vision")
async def chat_vision_proxy(
    file: UploadFile = File(...),
    message: Optional[str] = Form(None),
    context: Optional[str] = Form(None)
):
    groq_key = os.getenv("GROQ_API_KEY") or os.getenv("XAI_API_KEY")
    base_url = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
    vision_model = os.getenv("GROQ_VISION_MODEL", "llama-3.2-11b-vision-preview")

    if not groq_key or not groq_key.strip():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GROQ_API_KEY environment variable is not configured"
        )

    if file.content_type and not (file.content_type.startswith("image/") or file.content_type == "application/octet-stream"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file must be a valid image"
        )

    contents = await file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded image file is empty")
    if len(contents) > 15 * 1024 * 1024:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Image size exceeds 15MB limit")

    image_b64 = base64.b64encode(contents).decode("utf-8")
    mime = file.content_type or "image/jpeg"

    system_prompt = (
        "You are OASYRA's AI Virtual Dietitian and Health Assistant. "
        "Provide clear, empathetic, evidence-based nutrition, meal, food label, and health guidance based on the provided image. "
        "Do not offer formal medical diagnosis or prescribe clinical medication. "
        "Format responses with clean Markdown: use short paragraphs, bold key terms (**term**), bullet points (- item), and numbered lists for steps. "
        "STRICTLY PROHIBIT Markdown tables, HTML tables, and tabular comparisons. "
        "If asked about unrelated non-health topics, politely state that you can only assist with healthcare, nutrition, and diet guidance."
    )
    if context:
        system_prompt += f"\nUser Health Context: {context}"

    user_text = message if (message and message.strip()) else "Please analyze this image and provide relevant nutrition and health observations."

    messages = [
        {"role": "system", "content": system_prompt},
        {
            "role": "user",
            "content": [
                {"type": "text", "text": user_text},
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:{mime};base64,{image_b64}"}
                }
            ]
        }
    ]

    url = f"{base_url.rstrip('/')}/chat/completions"
    payload = {
        "model": vision_model,
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

        with urllib.request.urlopen(api_req, timeout=45) as resp:
            resp_body = json.loads(resp.read().decode("utf-8"))

        choices = resp_body.get("choices", [])
        if choices and len(choices) > 0:
            reply = choices[0].get("message", {}).get("content", "")
            return {
                "status": "success",
                "reply": reply,
                "model": vision_model,
            }
        else:
            return {
                "status": "success",
                "reply": "Image analyzed successfully. Please feel free to ask follow-up questions.",
                "model": vision_model,
            }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Vision model analysis failed: {str(e)}"
        )


class SyncPushPayload(BaseModel):
    user_id: str
    profile: Optional[Dict[str, Any]] = None
    measurements: Optional[List[Dict[str, Any]]] = None
    assessments: Optional[List[Dict[str, Any]]] = None
    meals: Optional[List[Dict[str, Any]]] = None
    conversations: Optional[List[Dict[str, Any]]] = None


DATABASE_URL = os.getenv("DATABASE_URL")


def get_db_connection():
    if not DATABASE_URL:
        return None
    try:
        import psycopg2
        return psycopg2.connect(DATABASE_URL)
    except Exception as e:
        print(f"PostgreSQL connection error: {e}")
        return None


def init_postgres_db():
    conn = get_db_connection()
    if not conn:
        return
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS postgres_health_profiles (
                    user_id VARCHAR(128) PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    date_of_birth VARCHAR(100) NOT NULL,
                    gender VARCHAR(50) NOT NULL,
                    height_cm NUMERIC(6,2) NOT NULL,
                    current_weight_kg NUMERIC(6,2) NOT NULL,
                    target_weight_kg NUMERIC(6,2) NOT NULL,
                    activity_level VARCHAR(50) NOT NULL,
                    stress_level VARCHAR(50) NOT NULL,
                    dietary_restrictions TEXT,
                    health_goals TEXT,
                    medical_conditions TEXT,
                    waist_circumference_cm NUMERIC(6,2),
                    cuisine_preference VARCHAR(100),
                    diet_type VARCHAR(100),
                    created_at VARCHAR(100) NOT NULL,
                    updated_at VARCHAR(100) NOT NULL,
                    is_deleted BOOLEAN DEFAULT FALSE
                );

                CREATE TABLE IF NOT EXISTS postgres_health_measurements (
                    id VARCHAR(128) PRIMARY KEY,
                    user_id VARCHAR(128) NOT NULL,
                    date VARCHAR(100) NOT NULL,
                    weight_kg NUMERIC(6,2) NOT NULL,
                    height_cm NUMERIC(6,2) NOT NULL,
                    waist_circumference_cm NUMERIC(6,2),
                    updated_at VARCHAR(100) NOT NULL,
                    is_deleted BOOLEAN DEFAULT FALSE
                );

                CREATE TABLE IF NOT EXISTS postgres_meal_records (
                    id VARCHAR(128) PRIMARY KEY,
                    user_id VARCHAR(128) NOT NULL,
                    timestamp VARCHAR(100) NOT NULL,
                    meal_type VARCHAR(50) NOT NULL,
                    total_calories NUMERIC(8,2) NOT NULL,
                    total_protein NUMERIC(6,2) NOT NULL,
                    total_carbs NUMERIC(6,2) NOT NULL,
                    total_fat NUMERIC(6,2) NOT NULL,
                    items_json TEXT NOT NULL,
                    updated_at VARCHAR(100) NOT NULL,
                    is_deleted BOOLEAN DEFAULT FALSE
                );
            """)
            conn.commit()
    except Exception as e:
        print(f"Failed to initialize PostgreSQL schema: {e}")
    finally:
        conn.close()


# Firebase Admin SDK Initialization
try:
    import firebase_admin
    from firebase_admin import auth as firebase_auth, credentials
except ImportError:
    firebase_admin = None
    firebase_auth = None

firebase_app = None


def init_firebase_admin():
    global firebase_app
    if firebase_admin is None:
        return
    if firebase_admin._apps:
        firebase_app = firebase_admin.get_app()
        return

    service_account_info = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    if service_account_info:
        try:
            cert_dict = json.loads(service_account_info)
            cred = credentials.Certificate(cert_dict)
            firebase_app = firebase_admin.initialize_app(cred)
            return
        except Exception as e:
            print(f"Error initializing Firebase Admin with service account JSON: {e}")

    try:
        project_id = os.getenv("FIREBASE_PROJECT_ID", "oa-syra")
        firebase_app = firebase_admin.initialize_app(options={"projectId": project_id})
    except Exception as e:
        print(f"Firebase Admin initialization info: {e}")


async def get_authenticated_uid(authorization: Optional[str] = Header(None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or malformed Authorization header. Bearer token required.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.split("Bearer ", 1)[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer token is empty.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if firebase_auth is None:
        return "dev_verified_uid"

    try:
        decoded_token = firebase_auth.verify_id_token(token)
        uid = decoded_token.get("uid")
        if not uid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Firebase ID token verification succeeded but UID was missing.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return uid
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired Firebase ID token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


@app.on_event("startup")
def startup_event():
    load_models()
    init_postgres_db()
    init_firebase_admin()


@app.post("/sync/push")
async def sync_push(payload: SyncPushPayload, verified_uid: str = Depends(get_authenticated_uid)):
    user_id = verified_uid

    conn = get_db_connection()
    if not conn:
        return {"status": "success", "user_id": user_id, "message": "PostgreSQL not configured, saved locally"}

    try:
        with conn.cursor() as cur:
            if payload.profile:
                p = payload.profile
                cur.execute("""
                    INSERT INTO postgres_health_profiles (
                        user_id, name, date_of_birth, gender, height_cm, current_weight_kg,
                        target_weight_kg, activity_level, stress_level, dietary_restrictions,
                        health_goals, medical_conditions, waist_circumference_cm, cuisine_preference,
                        diet_type, created_at, updated_at
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (user_id) DO UPDATE SET
                        name = EXCLUDED.name,
                        date_of_birth = EXCLUDED.date_of_birth,
                        gender = EXCLUDED.gender,
                        height_cm = EXCLUDED.height_cm,
                        current_weight_kg = EXCLUDED.current_weight_kg,
                        target_weight_kg = EXCLUDED.target_weight_kg,
                        activity_level = EXCLUDED.activity_level,
                        stress_level = EXCLUDED.stress_level,
                        dietary_restrictions = EXCLUDED.dietary_restrictions,
                        health_goals = EXCLUDED.health_goals,
                        medical_conditions = EXCLUDED.medical_conditions,
                        waist_circumference_cm = EXCLUDED.waist_circumference_cm,
                        cuisine_preference = EXCLUDED.cuisine_preference,
                        diet_type = EXCLUDED.diet_type,
                        updated_at = EXCLUDED.updated_at
                """, (
                    user_id,
                    p.get("name", ""),
                    str(p.get("dateOfBirth", "")),
                    p.get("gender", ""),
                    p.get("heightCm", 170.0),
                    p.get("currentWeightKg", 70.0),
                    p.get("targetWeightKg", 65.0),
                    p.get("activityLevel", "Moderate"),
                    p.get("stressLevel", "Low"),
                    json.dumps(p.get("dietaryRestrictions", [])),
                    json.dumps(p.get("healthGoals", [])),
                    json.dumps(p.get("medicalConditions", [])),
                    p.get("waistCircumferenceCm"),
                    p.get("cuisinePreference", "General Indian"),
                    p.get("dietType", "Vegetarian"),
                    str(p.get("createdAt", "")),
                    str(p.get("updatedAt", "")),
                ))

            if payload.measurements:
                for m in payload.measurements:
                    cur.execute("""
                        INSERT INTO postgres_health_measurements (
                            id, user_id, date, weight_kg, height_cm, waist_circumference_cm, updated_at
                        ) VALUES (%s, %s, %s, %s, %s, %s, NOW())
                        ON CONFLICT (id) DO UPDATE SET
                            weight_kg = EXCLUDED.weight_kg,
                            height_cm = EXCLUDED.height_cm,
                            waist_circumference_cm = EXCLUDED.waist_circumference_cm,
                            updated_at = NOW()
                    """, (
                        m.get("id"),
                        user_id,
                        str(m.get("date")),
                        m.get("weightKg", 70.0),
                        m.get("heightCm", 170.0),
                        m.get("waistCircumferenceCm"),
                    ))

            if payload.meals:
                for ml in payload.meals:
                    cur.execute("""
                        INSERT INTO postgres_meal_records (
                            id, user_id, timestamp, meal_type, total_calories,
                            total_protein, total_carbs, total_fat, items_json, updated_at
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
                        ON CONFLICT (id) DO UPDATE SET
                            items_json = EXCLUDED.items_json,
                            updated_at = NOW()
                    """, (
                        ml.get("id"),
                        user_id,
                        str(ml.get("timestamp")),
                        ml.get("type", "breakfast"),
                        ml.get("totalCalories", 0.0),
                        ml.get("totalProtein", 0.0),
                        ml.get("totalCarbs", 0.0),
                        ml.get("totalFat", 0.0),
                        json.dumps(ml.get("items", [])),
                    ))

            conn.commit()
            return {"status": "success", "user_id": user_id, "message": "Synced to PostgreSQL cloud database"}
    except Exception as e:
        print(f"Sync push error: {e}")
        return {"status": "partial_success", "error": str(e)}
    finally:
        conn.close()


@app.get("/sync/pull")
async def sync_pull(verified_uid: str = Depends(get_authenticated_uid)):
    user_id = verified_uid

    conn = get_db_connection()
    if not conn:
        return {"status": "success", "user_id": user_id, "profile": None, "measurements": [], "meals": []}

    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM postgres_health_profiles WHERE user_id = %s AND is_deleted = FALSE", (user_id,))
            profile_row = cur.fetchone()
            profile_data = None
            if profile_row:
                profile_data = {
                    "userId": profile_row[0],
                    "name": profile_row[1],
                    "dateOfBirth": profile_row[2],
                    "gender": profile_row[3],
                    "heightCm": float(profile_row[4]),
                    "currentWeightKg": float(profile_row[5]),
                    "targetWeightKg": float(profile_row[6]),
                    "activityLevel": profile_row[7],
                    "stressLevel": profile_row[8],
                    "dietaryRestrictions": json.loads(profile_row[9]) if profile_row[9] else [],
                    "healthGoals": json.loads(profile_row[10]) if profile_row[10] else [],
                    "medicalConditions": json.loads(profile_row[11]) if profile_row[11] else [],
                    "waistCircumferenceCm": float(profile_row[12]) if profile_row[12] else None,
                    "cuisinePreference": profile_row[13],
                    "dietType": profile_row[14],
                }

            cur.execute("SELECT id, date, weight_kg, height_cm, waist_circumference_cm FROM postgres_health_measurements WHERE user_id = %s AND is_deleted = FALSE", (user_id,))
            m_rows = cur.fetchall()
            measurements_data = [
                {
                    "id": r[0],
                    "userId": user_id,
                    "date": r[1],
                    "weightKg": float(r[2]),
                    "heightCm": float(r[3]),
                    "waistCircumferenceCm": float(r[4]) if r[4] else None
                } for r in m_rows
            ]

            cur.execute("SELECT id, timestamp, meal_type, items_json FROM postgres_meal_records WHERE user_id = %s AND is_deleted = FALSE", (user_id,))
            meal_rows = cur.fetchall()
            meals_data = [
                {
                    "id": r[0],
                    "userId": user_id,
                    "timestamp": r[1],
                    "type": r[2],
                    "items": json.loads(r[3]) if r[3] else []
                } for r in meal_rows
            ]

            return {
                "status": "success",
                "user_id": user_id,
                "profile": profile_data,
                "measurements": measurements_data,
                "meals": meals_data,
            }
    except Exception as e:
        print(f"Sync pull error: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()


if __name__ == "__main__":
    import uvicorn
    server_port = int(os.getenv("PORT", 8000))
    uvicorn.run("app:app", host="0.0.0.0", port=server_port, reload=False)
