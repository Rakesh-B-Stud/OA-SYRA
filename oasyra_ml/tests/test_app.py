import io
from PIL import Image
from fastapi.testclient import TestClient
from oasyra_ml.app import app, compute_iou


def test_health_check():
    with TestClient(app) as client:
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["models_loaded"] is True
        assert data["yolo_classes_count"] == 81
        assert data["mobilenet_classes_count"] == 81


def test_predict_meal_invalid_file_type():
    with TestClient(app) as client:
        response = client.post(
            "/predict_meal",
            files={"file": ("test.txt", b"hello world", "text/plain")}
        )
        assert response.status_code == 400
        assert "image" in response.json()["detail"].lower()


def test_predict_meal_invalid_bytes_labelled_as_image():
    with TestClient(app) as client:
        response = client.post(
            "/predict_meal",
            files={"file": ("fake.jpg", b"not an image byte array", "image/jpeg")}
        )
        assert response.status_code == 400
        assert "failed to decode image file" in response.json()["detail"].lower() or "valid image" in response.json()["detail"].lower()


def test_predict_meal_empty_file():
    with TestClient(app) as client:
        response = client.post(
            "/predict_meal",
            files={"file": ("empty.png", b"", "image/png")}
        )
        assert response.status_code == 400


def test_predict_meal_oversized_file():
    with TestClient(app) as client:
        huge_bytes = b"0" * (16 * 1024 * 1024)
        response = client.post(
            "/predict_meal",
            files={"file": ("huge.png", huge_bytes, "image/png")}
        )
        assert response.status_code == 400
        assert "exceeds" in response.json()["detail"].lower()


def test_predict_meal_valid_png_image():
    img = Image.new("RGB", (250, 250), color=(0, 255, 0))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)

    with TestClient(app) as client:
        response = client.post(
            "/predict_meal",
            files={"file": ("sample.png", buf.getvalue(), "image/png")}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["image_size"] == [250, 250]


def test_predict_meal_octet_stream_valid_jpeg():
    img = Image.new("RGB", (300, 300), color=(255, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    with TestClient(app) as client:
        response = client.post(
            "/predict_meal",
            files={"file": ("photo.tmp", buf.getvalue(), "application/octet-stream")}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["image_size"] == [300, 300]
        assert "detection_count" in data
        assert "detections" in data


def test_biryani_dataset_image_selection_policy():
    image_path = "oasyra_ml/datasets/processed/sih_food_detection_v1/valid/images/7dd0b5855c_jpg.rf.887fefdf82a6a258a5e153be33914266.jpg"
    with TestClient(app) as client:
        with open(image_path, "rb") as f:
            response = client.post("/predict_meal", files={"file": ("biryani.jpg", f, "image/jpeg")})
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "success"
            assert data["detection_count"] >= 1
            detection = data["detections"][0]
            assert detection["yolo_class_name"] == "biryani"
            assert detection["yolo_confidence"] >= 0.60
            assert detection["canonical_label"] == "biryani"
            assert detection["has_disagreement"] is True


def test_compute_iou_logic():
    box1 = [0, 0, 100, 100]
    box2 = [10, 10, 100, 100]  # High overlap
    box3 = [200, 200, 300, 300]  # No overlap

    iou_high = compute_iou(box1, box2)
    iou_zero = compute_iou(box1, box3)

    assert iou_high > 0.65
    assert iou_zero == 0.0


if __name__ == "__main__":
    test_health_check()
    test_predict_meal_invalid_file_type()
    test_predict_meal_invalid_bytes_labelled_as_image()
    test_predict_meal_empty_file()
    test_predict_meal_oversized_file()
    test_predict_meal_valid_png_image()
    test_predict_meal_octet_stream_valid_jpeg()
    test_biryani_dataset_image_selection_policy()
    test_compute_iou_logic()
    print("All backend tests passed successfully!")
