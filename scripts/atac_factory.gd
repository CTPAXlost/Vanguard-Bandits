class_name AtacFactory
extends RefCounted

const MultiViewAtac = preload("res://scripts/multiview_atac.gd")
const RealModelAtac = preload("res://scripts/real_model_atac.gd")
const SkeletalAtac = preload("res://scripts/skeletal_atac.gd")


static func create_atac(slug: String, render_context: String = "auto") -> Node3D:
	var normalized: String = slug.to_lower()
	# Tactical battles always use the full-body PS1 silhouette sheets. Segmented
	# Skeleton3D skins are kept for gallery / smoke tooling, but they visibly
	# fracture shoulders and weapons on the map and no longer drive combat.
	if render_context == "tactical":
		return _create_multiview(normalized)
	if render_context == "skeletal":
		if SkeletalAtac.supports(normalized):
			var skeletal_root: SkeletalAtac = SkeletalAtac.new()
			skeletal_root.configure(normalized)
			return skeletal_root
		return _create_multiview(normalized)
	if render_context == "arena":
		# Arena 3D duel mode remains optional / experimental only.
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
