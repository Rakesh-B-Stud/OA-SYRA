from pathlib import Path
from collections import Counter
from PIL import Image
import yaml

DATASET = Path(
    r"C:\Users\Rakesh\AndroidStudioProjects\oasyara_1"
    r"\oasyra_ml\datasets\raw\sih_food_detection"
)

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def get_images(folder):
    return {
        p.stem: p
        for p in folder.rglob("*")
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    }


def get_labels(folder):
    return {
        p.stem: p
        for p in folder.rglob("*.txt")
        if p.is_file()
    }


def main():

    print("=" * 70)
    print("OASYRA — COMPLETE YOLO DATASET AUDIT")
    print("=" * 70)

    yaml_file = DATASET / "data.yaml"

    if not yaml_file.exists():
        print("ERROR: data.yaml not found.")
        return

    with open(yaml_file, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    names = config.get("names", [])
    nc = config.get("nc")

    print(f"\nDeclared classes : {nc}")
    print(f"Class names      : {len(names)}")

    if nc != len(names):
        print("WARNING: nc does not match names count.")

    total_images = 0
    total_labels = 0
    total_errors = 0

    annotation_types = Counter()
    class_counts = Counter()

    for split in ["train", "valid", "test"]:

        split_path = DATASET / split

        print("\n" + "-" * 70)
        print(f"{split.upper()}")

        if not split_path.exists():
            print("Status: NOT FOUND")
            continue

        image_dir = split_path / "images"
        label_dir = split_path / "labels"

        if not image_dir.exists():
            print("ERROR: images directory missing")
            total_errors += 1
            continue

        if not label_dir.exists():
            print("ERROR: labels directory missing")
            total_errors += 1
            continue

        images = get_images(image_dir)
        labels = get_labels(label_dir)

        print(f"Images : {len(images)}")
        print(f"Labels : {len(labels)}")

        total_images += len(images)
        total_labels += len(labels)

        missing_labels = set(images) - set(labels)
        orphan_labels = set(labels) - set(images)

        if missing_labels:
            print(f"Missing labels : {len(missing_labels)}")
            total_errors += len(missing_labels)

        if orphan_labels:
            print(f"Orphan labels  : {len(orphan_labels)}")
            total_errors += len(orphan_labels)

        # ------------------------------------------------------------
        # Validate labels
        # ------------------------------------------------------------

        for stem, label_file in labels.items():

            try:
                with open(label_file, "r", encoding="utf-8") as f:
                    lines = [x.strip() for x in f if x.strip()]
            except Exception as e:
                print(f"ERROR reading {label_file.name}: {e}")
                total_errors += 1
                continue

            for line_number, line in enumerate(lines, start=1):

                parts = line.split()

                # Standard YOLO bounding box
                if len(parts) == 5:

                    annotation_types["bbox"] += 1

                    try:
                        class_id = int(parts[0])
                        x, y, w, h = map(float, parts[1:])

                    except ValueError:
                        print(
                            f"INVALID BBOX VALUES: "
                            f"{label_file.name}:{line_number}"
                        )
                        total_errors += 1
                        continue

                    if not 0 <= class_id < nc:
                        print(
                            f"INVALID CLASS ID {class_id}: "
                            f"{label_file.name}:{line_number}"
                        )
                        total_errors += 1
                    else:
                        class_counts[class_id] += 1

                    if not all(0 <= v <= 1 for v in [x, y, w, h]):
                        print(
                            f"INVALID BBOX COORDINATES: "
                            f"{label_file.name}:{line_number}"
                        )
                        total_errors += 1

                    if w <= 0 or h <= 0:
                        print(
                            f"INVALID BBOX SIZE: "
                            f"{label_file.name}:{line_number}"
                        )
                        total_errors += 1

                # Polygon / segmentation annotation
                elif len(parts) >= 7 and (len(parts) - 1) % 2 == 0:

                    annotation_types["polygon"] += 1

                    try:
                        class_id = int(parts[0])
                        coordinates = list(map(float, parts[1:]))

                    except ValueError:
                        print(
                            f"INVALID POLYGON VALUES: "
                            f"{label_file.name}:{line_number}"
                        )
                        total_errors += 1
                        continue

                    if not 0 <= class_id < nc:
                        print(
                            f"INVALID POLYGON CLASS ID {class_id}: "
                            f"{label_file.name}:{line_number}"
                        )
                        total_errors += 1
                    else:
                        class_counts[class_id] += 1

                    if not all(0 <= v <= 1 for v in coordinates):
                        print(
                            f"INVALID POLYGON COORDINATES: "
                            f"{label_file.name}:{line_number}"
                        )
                        total_errors += 1

                else:

                    annotation_types["invalid"] += 1

                    print(
                        f"INVALID ANNOTATION: "
                        f"{label_file.name}:{line_number}"
                    )

                    total_errors += 1

        # ------------------------------------------------------------
        # Validate image files
        # ------------------------------------------------------------

        corrupt_images = 0

        for image_file in images.values():

            try:
                with Image.open(image_file) as img:
                    img.verify()

            except Exception as e:

                corrupt_images += 1
                total_errors += 1

                print(
                    f"CORRUPT IMAGE: "
                    f"{image_file.name} -> {e}"
                )

        print(f"Corrupt images : {corrupt_images}")

    # ------------------------------------------------------------
    # Final report
    # ------------------------------------------------------------

    print("\n" + "=" * 70)
    print("DATASET SUMMARY")
    print("=" * 70)

    print(f"Total images          : {total_images}")
    print(f"Total label files     : {total_labels}")

    print("\nAnnotation types:")

    for annotation_type, count in annotation_types.items():
        print(f"  {annotation_type:<12}: {count}")

    print("\nClass distribution:")

    for class_id in range(nc):

        count = class_counts.get(class_id, 0)
        name = names[class_id]

        print(
            f"{class_id:2d} | "
            f"{name:<35} | "
            f"{count}"
        )

    print("\n" + "=" * 70)

    if total_errors == 0:
        print("RESULT: DATASET PASSED STRUCTURAL INTEGRITY CHECK")
    else:
        print(
            f"RESULT: {total_errors} STRUCTURAL ISSUE(S) FOUND"
        )

    print("=" * 70)


if __name__ == "__main__":
    main()