"""Verify the metadata on which Hub admission and Cloud billing rely before publishing."""
import json
from pathlib import Path
import sys
import zipfile


def verify(package_dir, output_dir):
    source = json.loads((package_dir / ".aux4").read_bytes())
    scope, name, version = (source[key] for key in ("scope", "name", "version"))
    archive = output_dir / f"{scope}_{name}_{version}.zip"
    with zipfile.ZipFile(archive) as built:
        prefix = f"{scope}/{name}/"
        manifests = [entry for entry in built.infolist() if entry.filename in (prefix + ".aux4", prefix + "package/.aux4")]
        if len(manifests) != 1:
            raise ValueError("Expected a single package manifest in the release archive")
        manifest = json.loads(built.read(manifests[0]))
        for field in ("scope", "name", "version", "type", "cloud", "repository"):
            if source.get(field) != manifest.get(field):
                raise ValueError(f"Release archive changed manifest field {field}")
        if source.get("private", False) != manifest.get("private", False):
            raise ValueError("Release archive changed manifest field private")

        # Hub locates plans relative to the manifest; an unrelated plans.json
        # elsewhere in the ZIP cannot establish the published plan.
        base = manifests[0].filename.removesuffix(".aux4")
        for filename in ("plans.json", "terms.md"):
            source_file = package_dir / filename
            entries = [entry for entry in built.infolist() if entry.filename == base + filename]
            if len(entries) != int(source_file.is_file()):
                raise ValueError(f"Release archive changed presence of {filename}")
            if entries and built.read(entries[0]) != source_file.read_bytes():
                raise ValueError(f"Release archive changed {filename}")


if __name__ == "__main__":
    verify(Path(sys.argv[1]), Path.cwd())
