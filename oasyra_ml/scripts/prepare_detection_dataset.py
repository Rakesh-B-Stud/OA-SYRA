from pathlib import Path
import shutil
import yaml
from collections import Counter


PROJECT_ROOT = Path(
    r"C:\Users\Rakesh\AndroidStudioProjects\oasyara_1"
)

RAW_DATASET = (
    PROJECT_ROOT
    / "oasyra_ml"
    / "datasets"
    / "raw"
    / "sih_food_detection"
)

PROCESSED_DATASET = (
    PROJECT_ROOT
    / "oasyra_ml"
    / "datasets"
    / "processed"
    / "sih_food_detection_v1"
)

SPLITS = ["train", "valid", "test"]


def polygon_to_bbox(parts):
    """
    Convert YOLO polygon:
        class x1 y1 x2 y2 ...
    into YOLO bounding box:
        class cx cy width height
    """

    class_id = int(parts[0])

    coordinates = list(map(float, parts[1:]))

    xs = coordinates[0::2]
    ys = coordinates[1::2]

    min_x = min(xs)
    max_x = max(xs)

    min_y = min(ys)
    max_y = max(ys)

    center_x = (min_x + max_x) / 2
    center_y = (min_y + max_y) / 2

    width = max_x - min_x
    height = max_y - min_y

    return (
        f"{class_id} "
        f"{center_x:.10f} "
        f"{center_y:.10f} "
        f"{width:.10f} "
        f"{height:.10f}"
    )


def process_label_file(source, destination):

    output_lines = []

    with open(source, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]

    bbox_count = 0
    polygon_count = 0

    for line in lines:

        parts = line.split()

        # Standard YOLO bounding box
        if len(parts) == 5:

            output_lines.append(line)
            bbox_count += 1

        # YOLO polygon
        elif len(parts) >= 7 and (len(parts) - 1) % 2 == 0:

            bbox = polygon_to_bbox(parts)
            output_lines.append(bbox)

            polygon_count += 1

        else:

            raise ValueError(
                f"Unsupported annotation format in {source}: {line}"
            )

    destination.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    with open(destination, "w", encoding="utf-8") as f:
        f.write("\n".join(output_lines))

    return bbox_count, polygon_count


def main():

    print("=" * 70)
    print("OASYRA — DATASET PREPROCESSING")
    print("=" * 70)

    if not RAW_DATASET.exists():
        raise FileNotFoundError(
            f"Raw dataset not found:\n{RAW_DATASET}"
        )

    if PROCESSED_DATASET.exists():

        print("\nWARNING:")
        print("Processed dataset already exists:")
        print(PROCESSED_DATASET)

        answer = input(
            "\nDelete and recreate it? [y/N]: "
        ).strip().lower()

        if answer != "y":
            print("Operation cancelled.")
            return

        shutil.rmtree(PROCESSED_DATASET)

    PROCESSED_DATASET.mkdir(
        parents=True,
        exist_ok=True
    )

    # ------------------------------------------------------------
    # Read original data.yaml
    # ------------------------------------------------------------

    source_yaml = RAW_DATASET / "data.yaml"

    with open(source_yaml, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    class_names = config["names"]
    class_count = config["nc"]

    if len(class_names) != class_count:
        raise ValueError(
            "Class count mismatch in original data.yaml."
        )

    # ------------------------------------------------------------
    # Create corrected data.yaml
    # ------------------------------------------------------------

    processed_config = {
        "train": "train/images",
        "val": "valid/images",
        "test": "test/images",
        "nc": class_count,
        "names": class_names,
    }

    with open(
        PROCESSED_DATASET / "data.yaml",
        "w",
        encoding="utf-8"
    ) as f:

        yaml.safe_dump(
            processed_config,
            f,
            sort_keys=False,
            allow_unicode=True
        )

    print(f"\nClasses preserved: {class_count}")

    total_images = 0
    total_labels = 0

    total_bbox = 0
    total_polygon_converted = 0

    class_distribution = Counter()

    # ------------------------------------------------------------
    # Process each split
    # ------------------------------------------------------------

    for split in SPLITS:

        source_split = RAW_DATASET / split
        destination_split = PROCESSED_DATASET / split

        if not source_split.exists():
            print(f"\n{split}: not found — skipping")
            continue

        source_images = source_split / "images"
        source_labels = source_split / "labels"

        destination_images = destination_split / "images"
        destination_labels = destination_split / "labels"

        destination_images.mkdir(
            parents=True,
            exist_ok=True
        )

        destination_labels.mkdir(
            parents=True,
            exist_ok=True
        )

        print(f"\nProcessing {split}...")

        # --------------------------------------------------------
        # Copy images
        # --------------------------------------------------------

        images = [
            p for p in source_images.iterdir()
            if p.is_file()
        ]

        for image in images:

            shutil.copy2(
                image,
                destination_images / image.name
            )

        # --------------------------------------------------------
        # Process labels
        # --------------------------------------------------------

        labels = list(
            source_labels.glob("*.txt")
        )

        for label in labels:

            bbox_count, polygon_count = process_label_file(
                label,
                destination_labels / label.name
            )

            total_bbox += bbox_count
            total_polygon_converted += polygon_count

            # Class distribution
            with open(
                label,
                "r",
                encoding="utf-8"
            ) as f:

                for line in f:

                    parts = line.strip().split()

                    if not parts:
                        continue

                    class_id = int(parts[0])

                    class_distribution[class_id] += 1

        total_images += len(images)
        total_labels += len(labels)

        print(f"Images : {len(images)}")
        print(f"Labels : {len(labels)}")

    # ------------------------------------------------------------
    # Processing manifest
    # ------------------------------------------------------------

    manifest = PROCESSED_DATASET / "PREPROCESSING_REPORT.txt"

    with open(
        manifest,
        "w",
        encoding="utf-8"
    ) as f:

        f.write("OASYRA DATASET PREPROCESSING REPORT\n")
        f.write("=" * 60 + "\n\n")

        f.write(
            "Source:\n"
            "sih_food_detection\n\n"
        )

        f.write(
            "Processed dataset:\n"
            "sih_food_detection_v1\n\n"
        )

        f.write(
            f"Number of classes: {class_count}\n"
        )

        f.write(
            f"Total images: {total_images}\n"
        )

        f.write(
            f"Total label files: {total_labels}\n"
        )

        f.write(
            f"Original bounding-box annotations: {total_bbox}\n"
        )

        f.write(
            f"Polygon annotations converted to bounding boxes: "
            f"{total_polygon_converted}\n"
        )

        f.write(
            "\nProcessing actions:\n"
            "- Original raw dataset preserved unchanged.\n"
            "- Images copied using metadata-preserving copy.\n"
            "- Bounding-box annotations preserved.\n"
            "- Polygon annotations converted to bounding boxes.\n"
            "- data.yaml paths normalized for processed dataset.\n"
            "- All 81 classes preserved.\n"
        )

    # ------------------------------------------------------------
    # Final report
    # ------------------------------------------------------------

    print("\n" + "=" * 70)
    print("PREPROCESSING COMPLETE")
    print("=" * 70)

    print(f"Processed dataset:")
    print(PROCESSED_DATASET)

    print(f"\nTotal images       : {total_images}")
    print(f"Total labels       : {total_labels}")
    print(f"BBox annotations   : {total_bbox}")
    print(
        f"Polygon converted  : "
        f"{total_polygon_converted}"
    )

    print("\nOriginal raw dataset was NOT modified.")

    print("=" * 70)


if __name__ == "__main__":
    main()