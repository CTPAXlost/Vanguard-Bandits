class_name AtacFactory
extends RefCounted

const MultiViewAtac = preload("res://scripts/multiview_atac.gd")
const RealModelAtac = preload("res://scripts/real_model_atac.gd")
const SkeletalAtac = preload("res://scripts/skeletal_atac.gd")
const FULL_BODY_TACTICAL_SLUGS: Array[String] = [
	"alba", "altagrave", "amphisia", "archangel", "barazaph", "crimson",
	"eigol", "haurol", "rahabar", "ratatosk", "roaring_lion", "serata",
	"snow_soldier", "toreadore", "vedocorban",
]


static func create_atac(slug: String, render_context: String = "auto") -> Node3D:
	var normalized: String = slug.to_lower()
	# V1.7.1: every tactical ATAC uses its original illustrated armour skin,
	# segmented into articulated layers on a real Skeleton3D. The guarded
	# multiview fallback remains only for unknown slugs.
	if render_context == "tactical":
		# Mission-VI machines use clean, transparent full-body views. Their former
		# segmented rigs visibly cut shoulders, legs and weapons into floating parts.
		if normalized in FULL_BODY_TACTICAL_SLUGS:
			return _create_multiview(normalized)
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
