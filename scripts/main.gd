extends Node

@onready var import_status: Label = $Center/Panel/Margin/VBox/ImportStatus
@onready var start_button: Button = $Center/Panel/Margin/VBox/StartPrototype
@onready var wallet_label: Label = $Center/Panel/Margin/VBox/Wallet


func _ready() -> void:
	start_button.pressed.connect(_start_campaign)
	$Center/Panel/Margin/VBox/MissionSelect.pressed.connect(_open_mission_select)
	$Center/Panel/Margin/VBox/OpenModelGallery.pressed.connect(_open_model_gallery)
	$Center/Panel/Margin/VBox/OpenImportFolder.pressed.connect(_show_import_help)
	$Center/Panel/Margin/VBox/Exit.pressed.connect(func(): get_tree().quit())
	_refresh_import_status()
	_refresh_campaign_button()
	wallet_label.text = "Общий фонд команды: %d монет" % CampaignState.get_coin_balance()


func _refresh_campaign_button() -> void:
	if CampaignState.mission_1_complete:
		start_button.text = "Продолжить кампанию — лагерь"
	else:
		start_button.text = "Начать кампанию — первая миссия"


func _refresh_import_status() -> void:
	var report: Dictionary = GameDatabase.get_import_report()
	if report.is_empty():
		import_status.text = "Ремастер-ресурсы загружены • оригинальная музыка и видео не используются"
		import_status.modulate = Color(0.65, 0.88, 1.0)
		return
	var blocks: int = int(report.get("epica_blocks", 0))
	var textures: int = int(report.get("decoded_tim_textures", 0))
	var models: int = int(report.get("exported_atac_models", 0))
	import_status.text = (
		"Импорт найден: %d блоков EPICA, %d текстур, %d ATAC-модели" % [blocks, textures, models]
	)
	import_status.modulate = Color(0.45, 1.0, 0.68)


func _start_campaign() -> void:
	if CampaignState.mission_1_complete:
		get_tree().change_scene_to_file("res://scenes/CampaignHub.tscn")
	else:
		CampaignState.current_mission = 1
		get_tree().change_scene_to_file("res://scenes/BattlePrototype.tscn")


func _open_model_gallery() -> void:
	get_tree().change_scene_to_file("res://scenes/ModelGallery.tscn")


func _show_import_help() -> void:
	(
		OS
		. alert(
			(
				"В корне репозитория можно запустить импортёр оригинальной копии.\n\n"
				+ "Кампания 1.3 содержит оптимизированные 2.5D-образы Alba, Barbatos, Barazaph, Vedocorban, Solarus, Sarbelas, Einlager, Amphisia, Haurol, Toreadore, Eigol и ATAC Cador, Serata и Glaive. Для Alba, Serata и Glaive доступен экспериментальный режим статических GLB-моделей. Полноценный скелетный 3D-бой будет добавляться после проверки стабильности. "
				+ "Оригинальная музыка и вступительные ролики не импортируются."
			),
			"Импорт оригинальной копии"
		)
	)


func _open_mission_select() -> void:
	CampaignState.mission_selector_return_scene = "res://scenes/Main.tscn"
	get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")
