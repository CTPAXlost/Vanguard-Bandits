from pathlib import Path
import json
P=Path(__file__).resolve().parents[2]/"project"
def test_mission6_content():
 d=json.loads((P/"data/maps/mission_06.json").read_text(encoding="utf-8")); assert len(d["south_starts"]["bots"])==6; assert len(d["north_starts"]["bots"])==6
 for f in ["logan.png","claire.png","shion.png","alden.png","devlin.png","barlow.png"]: assert (P/"assets/ui/portraits"/f).exists()
 for s in ["crimson","rahabar","altagrave","snow_soldier","ratatosk"]: assert (P/"assets/atac_rigged"/s/"rig.json").exists()
def test_open_gate_and_shop():
 v=(P/"scripts/campaign_battle_v18.gd").read_text(encoding="utf-8"); assert "deliberately completely open" in v
 c=(P/"scripts/campaign_state.gd").read_text(encoding="utf-8"); assert "return true" in c[c.index("func is_shop_available"):c.index("func is_item_available")]
