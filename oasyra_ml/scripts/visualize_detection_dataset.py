from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFont
import yaml

DATASET = Path(
    r"C:\Users\Rakesh\AndroidStudioProjects\oasyara_1"
    r"\oasyra_ml\datasets\raw\sih_food_detection"
)

OUTPUT = (
    Path(r"C:\Users\Rakesh\AndroidStudioProjects\oasyara_1")
    / "oasyra_ml"
    / "evaluation"
    / "detection_preview"
)

SPLIT = "train"
NUM_IMAGES = 12

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def load_yaml():
    with open(DATASET / "data.yaml", "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def get_images():
    image_dir = DATASET / SPLIT / "images"

    return [
        p for p in image_dir.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    ]


def draw_yolo_boxes(image, label_file, class_names):

    draw = ImageDraw.Draw(image)

    width, height = image.size

    with open(label_file, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]

    for line in lines:

        parts = line.split()

        # Standard YOLO bounding box
        if len(parts) == 5:

            class_id = int(parts[0])

            cx = float(parts[1]) * width
            cy = float(parts[2]) * height
            bw = float(parts[3]) * width
            bh = float(parts[4]) * height

            x1 = int(cx - bw / 2)
            y1 = int(cy - bh / 2)
            x2 = int(cx + bw / 2)
            y2 = int(cy + bh / 2)

            draw.rectangle(
                [x1, y1, x2, y2],
                outline="red",
                width=4
            )

            label = f"{class_id}: {class_names[class_id]}"

            draw.rectangle(
                [x1, max(0, y1 - 25), x1 + 250, y1],
                fill="red"
            )

            draw.text(
                (x1 + 4, max(0, y1 - 22)),
                label,
                fill="white"
            )

        # Polygon annotation
        elif len(parts) >= 7 and (len(parts) - 1) % 2 == 0:

            class_id = int(parts[0])
            coordinates = list(map(float, parts[1:]))

            points = []

            for i in range(0, len(coordinates), 2):
                x = int(coordinates[i] * width)
                y = int(coordinates[i + 1] * height)
                points.append((x, y))

            draw.polygon(
                points,
                outline="yellow"
            )

            draw.text(
                points[0],
                f"{class_id}: {class_names[class_id]} [POLYGON]",
                fill="yellow"
            )

    return image


def main():

    config = load_yaml()

    class_names = config["names"]

    images = get_images()

    random.seed(42)

    selected = random.sample(
        images,
        min(NUM_IMAGES, len(images))
    )

    OUTPUT.mkdir(
        parents=True,
        exist_ok=True
    )

    print("Creating visual annotation previews...")
    print(f"Selected images: {len(selected)}")
    print(f"Output folder: {OUTPUT}")

    for index, image_path in enumerate(selected, start=1):

        label_path = (
            DATASET
            / SPLIT
            / "labels"
            / f"{image_path.stem}.txt"
        )

        if not label_path.exists():
            print(f"Missing label: {image_path.name}")
            continue

        image = Image.open(image_path).convert("RGB")

        image = draw_yolo_boxes(
            image,
            label_path,
            class_names
        )

        output_path = (
            OUTPUT
            / f"preview_{index:02d}_{image_path.name}"
        )

        image.save(output_path)

        print(f"Created: {output_path.name}")

    print("\nVisual verification files created successfully.")


if __name__ == "__main__":
    main()