import os
import sys

from pie_data import PIE

REQUIRED_SUBDIRECTORIES = [
    "annotations",
    "annotations_attributes",
    "annotations_vehicle",
    "PIE_clips",
]


def validate_dataset_root(pie_path):
    missing = [name for name in REQUIRED_SUBDIRECTORIES
               if not os.path.isdir(os.path.join(pie_path, name))]
    if missing:
        sys.exit("Missing directories under {}: {}".format(pie_path, ", ".join(missing)))


def main():
    pie_path = os.environ.get("PIE_PATH")
    if not pie_path:
        sys.exit("PIE_PATH is not set. Run: source scripts/set_env.sh")

    validate_dataset_root(pie_path)

    imdb = PIE(data_path=pie_path)
    imdb.extract_and_save_images(extract_frame_type="annotated")


if __name__ == "__main__":
    main()