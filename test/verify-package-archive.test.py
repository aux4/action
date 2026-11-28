import json
from pathlib import Path
import runpy
import tempfile
import unittest
import zipfile


verify = runpy.run_path(str(Path(__file__).resolve().parents[1] / "scripts/verify-package-archive.py"))["verify"]


class ArchiveVerification(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.manifest = dict(scope="aux4", name="files", version="1.0.0", type="cloud", cloud={"deployment":"new-vm"}, repository="public", private=False)
        (self.root / ".aux4").write_text(json.dumps(self.manifest))
        (self.root / "plans.json").write_bytes(b'{}')
        (self.root / "terms.md").write_bytes(b'# Terms')

    def build(self, changes=None, plans=b'{}', terms=b'# Terms', nested=False):
        manifest = self.manifest | (changes or {})
        prefix = "aux4/files/package/" if nested else "aux4/files/"
        with zipfile.ZipFile(self.root / "aux4_files_1.0.0.zip", "w") as archive:
            archive.writestr(prefix + ".aux4", json.dumps({k:v for k,v in manifest.items() if v is not None}))
            if plans is not None:
                archive.writestr(prefix + "plans.json", plans)
            if terms is not None:
                archive.writestr(prefix + "terms.md", terms)

    def test_accepts_both_layouts_and_omitted_false_privacy(self):
        for nested in [False, True]:
            self.build({"private":None}, nested=nested)
            verify(self.root, self.root)

    def test_rejects_lost_identity_or_terms(self):
        for changes in [{"type":None}, {"cloud":None}, {"private":True}, {"repository":None}]:
            self.build(changes)
            with self.assertRaises(ValueError):
                verify(self.root, self.root)
        for options in [{"plans":None}, {"terms":b'changed'}]:
            self.build(**options)
            with self.assertRaises(ValueError):
                verify(self.root, self.root)


if __name__ == "__main__":
    unittest.main()
