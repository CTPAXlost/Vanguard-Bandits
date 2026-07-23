class_name AtacFactory
extends RefCounted

const MultiViewAtac = preload("res://scripts/multiview_atac.gd")
const RealModelAtac = preload("res://scripts/real_model_atac.gd")


static func create_atac(slug: String, render_context: String = "auto") -> Node3D:
	var normalized: String = slug.to_lower()
	# The tactical map deliberately uses the stable multi-view rig. The imported
	# static GLB meshes are reserved for the close-up arena and model gallery so
	# a malformed scale/import cannot make a unit disappear on the grid.
	if render_context == "tactical":
		return _create_multiview(normalized)
	if render_context == "arena":
		if RealModelAtac.supports(normalized):
			var arena_model: RealModelAtac = RealModelAtac.new()
			arena_model.configure(normalized)
			return arena_model
		return _create_multiview(normalized)
	if CampaignState.experimental_3d_enabled and RealModelAtac.supports(normalized):
		var real_root: RealModelAtac = RealModelAtac.new()
		real_root.configure(normalized)
		return real_root
	return _create_multiview(normalized)


static func _create_multiview(normalized: String) -> MultiViewAtac:
	var root: MultiViewAtac = MultiViewAtac.new()
	root.configure(normalized)
	return root
