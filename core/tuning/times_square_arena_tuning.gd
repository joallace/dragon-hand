class_name TimesSquareArenaTuning
extends ArenaTuning
## The Times Square stage (presentation only, like ArenaTuning, whose sky and
## light values it overrides in _init): a night in the pedestrian plaza at
## the middle of the bowtie. The avenues run along Z on both sides (+X and
## -X), the glowing red steps stand at +Z, the screen-clad tower with the ball
## at -Z. Every gap is measured from the play radius, so the layout follows
## co-op's bigger arenas. Keep anything taller than a café table beyond
## Tuning.camera.radius_margin, or the camera walks through it.
## Edit data/tuning/arena_times_square.tres.

@export_group("Layout")
## Distance from the play circle to the curb between the plaza and the
## avenue on each side (lamp posts stand on it).
@export var plaza_margin: float = 9.0
## Avenue width, curb to curb.
@export var road_width: float = 11.0
@export var lane_count: int = 3
## Sidewalk between the avenue and the building faces.
@export var sidewalk_width: float = 5.0
## Distance from the play circle to the near side of the two cross streets
## (at +Z and -Z), and their width.
@export var cross_gap: float = 21.0
@export var cross_width: float = 10.0
## The red steps: distance from the play circle to their lowest tread, size.
@export var steps_gap: float = 10.0
@export var steps_width: float = 15.0
@export var steps_depth: float = 8.0
@export var steps_height: float = 4.6
@export var steps_count: int = 11
## The tower with the ball: distance from the play circle to its face.
@export var tower_gap: float = 36.0
@export var tower_size: Vector3 = Vector3(16.0, 112.0, 12.0)
@export var ball_radius: float = 2.2
## Barricades around the play circle.
@export var barricade_height: float = 1.05
@export var barricade_length: float = 2.3

@export_group("Plaza")
## One ring of café tables per entry, at this distance from the play circle;
## tables that would leave the plaza are dropped.
@export var table_row_gaps: PackedFloat32Array = PackedFloat32Array([2.6, 5.6])
@export var table_spacing: float = 3.6
@export_range(0.0, 1.0) var table_skip_chance: float = 0.2
@export_range(0.0, 1.0) var chair_missing_chance: float = 0.2
@export_range(0.0, 1.0) var chair_toppled_chance: float = 0.12
## Planters along the plaza's curbs.
@export var planter_spacing: float = 9.0

@export_group("Traffic")
## Cars and buses parked in the jam, spacing along a lane.
@export var car_spacing: float = 7.5
@export_range(0.0, 1.0) var car_gap_chance: float = 0.25
@export_range(0.0, 1.0) var bus_chance: float = 0.1
## How far along Z the jam goes on each side of the play circle.
@export var traffic_span: float = 150.0
@export var lamp_spacing: float = 16.0

@export_group("Buildings")
## The canyon of facades along both avenues, from z = 0 (+Z and -Z).
@export var facade_span: float = 300.0
@export var facade_min_width: float = 14.0
@export var facade_max_width: float = 30.0
@export var facade_min_height: float = 34.0
@export var facade_max_height: float = 150.0
## Ground floor shop windows.
@export var storefront_height: float = 4.5
## Skyscrapers behind the facades.
@export var tower_count: int = 140
@export var skyline_depth: float = 260.0
@export var skyline_min_height: float = 50.0
@export var skyline_max_height: float = 240.0

@export_group("Screens")
## Screens on each facing building face: up to this many, stacked from
## screen_base, each between these heights.
@export var screens_per_building: int = 3
@export var screen_base: float = 6.0
@export var screen_min_height: float = 6.0
@export var screen_max_height: float = 20.0
## Brightness of the screens (above 1 blooms).
@export var screen_energy: float = 2.2
## Brightness of lamps, headlights, cab signs and the steps.
@export var light_energy: float = 3.0
@export var screen_colors: PackedColorArray = PackedColorArray([
	Color(1.0, 0.18, 0.45), Color(0.15, 0.75, 1.0), Color(1.0, 0.72, 0.1), Color(0.55, 0.25, 1.0),
	Color(0.2, 1.0, 0.55), Color(1.0, 0.35, 0.12), Color(0.95, 0.95, 1.0),
])
## Fictional brands only: wordmarks on some screens.
@export var brands: PackedStringArray = PackedStringArray([
	"KI COLA", "TENKAICHI", "VANISH", "GOLDEN FIST", "ZENKAI BANK", "NOODLE KING",
	"DRAGON HAND", "SUPER KI SODA", "IRON PALM GYM", "TURBO TV",
])
## Wordmarks are dark with a bright outline, to read on any screen.
@export var wordmark_color: Color = Color(0.04, 0.03, 0.06)
@export var wordmark_outline: Color = Color(1.0, 1.0, 1.0)
## How many wordmarks at most (each is a node).
@export var max_wordmarks: int = 18

@export_group("Colors")
@export var paver_light: Color = Color(0.4, 0.39, 0.4)
@export var paver_dark: Color = Color(0.24, 0.24, 0.26)
@export var asphalt: Color = Color(0.11, 0.11, 0.13)
@export var lane_paint: Color = Color(0.85, 0.85, 0.8)
@export var curb_color: Color = Color(0.62, 0.6, 0.58)
@export var sidewalk_color: Color = Color(0.4, 0.39, 0.38)
@export var barricade_color: Color = Color(0.12, 0.27, 0.62)
@export var barricade_stripe: Color = Color(0.92, 0.92, 0.9)
@export var table_color: Color = Color(0.72, 0.1, 0.1)
@export var planter_color: Color = Color(0.3, 0.32, 0.34)
@export var shrub_color: Color = Color(0.14, 0.32, 0.15)
@export var steps_glow: Color = Color(1.0, 0.1, 0.12)
@export var taxi_color: Color = Color(0.98, 0.72, 0.05)
@export var car_colors: PackedColorArray = PackedColorArray([
	Color(0.15, 0.15, 0.17), Color(0.75, 0.76, 0.78), Color(0.45, 0.06, 0.08), Color(0.1, 0.18, 0.35),
])
## Share of the jam that's taxis.
@export_range(0.0, 1.0) var taxi_share: float = 0.6
@export var bus_color: Color = Color(0.2, 0.35, 0.7)
@export var steel_color: Color = Color(0.28, 0.29, 0.3)
@export var lamp_color: Color = Color(1.0, 0.82, 0.55)
@export var headlight_color: Color = Color(1.0, 0.95, 0.82)
@export var taillight_color: Color = Color(1.0, 0.08, 0.05)
@export var window_lit: Color = Color(1.0, 0.8, 0.5)
@export var storefront_color: Color = Color(1.0, 0.86, 0.62)
@export var facade_colors: PackedColorArray = PackedColorArray([
	Color(0.32, 0.3, 0.32), Color(0.25, 0.26, 0.3), Color(0.38, 0.33, 0.3),
	Color(0.2, 0.22, 0.26), Color(0.42, 0.4, 0.4),
])
@export var ball_color: Color = Color(0.85, 0.9, 1.0)

@export_group("Night light")
## The key light (in place of the sun): the screens and lamps overhead.
@export var key_light_color: Color = Color(0.82, 0.84, 1.0)
## Ambient from the city, not the dark sky.
@export var ambient_color: Color = Color(0.34, 0.32, 0.42)

@export_group("Screen spill")
## Coloured lights on each side, as if the screens lit the fighters. Off on
## the Compatibility renderer (web), where each light is another pass.
@export var spill_color_left: Color = Color(1.0, 0.3, 0.6)
@export var spill_color_right: Color = Color(0.3, 0.7, 1.0)
@export var spill_energy: float = 1.6
@export var spill_range: float = 60.0
@export var spill_height: float = 14.0

@export_group("Renderer")
## Sun and ambient multiplier on the Compatibility renderer (the web build).
@export var compatibility_light_scale: float = 0.8

@export_group("Night sky")
@export var city_glow: Color = Color(0.55, 0.28, 0.4)
@export var cloud_lit: Color = Color(0.38, 0.24, 0.32)
@export_range(0.0, 1.0) var cloud_cover: float = 0.5
@export var cloud_scale: float = 2.2


func _init() -> void:
	sky_top_color = Color(0.02, 0.03, 0.08)
	sky_horizon_color = Color(0.3, 0.16, 0.3)
	sun_energy = 0.75
	sun_pitch_deg = -55.0
	sun_yaw_deg = 20.0
	ambient_energy = 0.9
	tonemap_mode = Environment.TONE_MAPPER_ACES
	tonemap_exposure = 1.0
	glow_enabled = true
	shadow_max_distance = 60.0
	fog_density = 0.0035
	outer_ground_size = 1000.0
