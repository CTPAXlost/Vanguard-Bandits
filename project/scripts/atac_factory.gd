class_name AtacFactory
extends RefCounted

const MultiViewAtac = preload("res://scripts/multiview_atac.gd")
const RealModelAtac = preload("res://scripts/real_model_atac.gd")
const SkeletalAtac = preload("res://scripts/skeletal_atac.gd")


static func create_atac(slug: String, render_context: String = "auto") -> Node3D:
	var normalized: String = slug.to_lower()
	# V1.7: every tactical ATAC is a complete articulated Skeleton3D model.
	# The old camera-facing sheets remain only as a guarded fallback for an
	# unknown slug, so units cannot disappear or be cut off at camera angles.
	if render_context == "tactical":
		if SkeletalAtac.supports(normalized):
			var skeletal_root: SkeletalAtac = SkeletalAtac.new()
			skeletal_root.configure(normalized)
			return skeletal_root
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
