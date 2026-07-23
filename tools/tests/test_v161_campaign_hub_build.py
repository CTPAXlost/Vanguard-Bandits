from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CampaignHubBuildRegressionTests(unittest.TestCase):
    def test_status_helper_exists_before_use(self) -> None:
        script = (ROOT / "project/scripts/campaign_hub.gd").read_text(encoding="utf-8")
        self.assertIn("func _set_status(message: String) -> void:", script)
        self.assertIn("status_label.text = message", script)
        self.assertIn('_set_status("Отдельная 3D-арена удалена.', script)

    def test_campaign_hub_smoke_is_in_workflow(self) -> None:
        workflow = (ROOT / ".github/workflows/build-windows.yml").read_text(encoding="utf-8")
        self.assertIn("Runtime smoke test for campaign hub", workflow)
        self.assertIn("res://scenes/CampaignHub.tscn", workflow)


if __name__ == "__main__":
    unittest.main()
