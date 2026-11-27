class_name GreatWallArenaTuning
extends ArenaTuning
## The Great Wall stage (presentation only, like ArenaTuning, whose sky and
## light values it overrides in _init): an autumn dawn on a wide bastion
## terrace where the wall crosses a mountain ridge. The wall leaves the
## terrace along +X and -X and snakes away over the ridge, the gate tower
## stands on the -Z side, the valley and the rising sun are on +Z. Every gap
## is measured from the play radius, so the layout follows co-op's bigger
## arenas. Keep anything taller than a wine jar beyond
## Tuning.camera.radius_margin, or the camera walks through it.
## Edit data/tuning/arena_great_wall.tres.

@export_group("Terrace")
## Distance from the play circle to the inner face of the terrace's parapet.
@export var terrace_margin: float = 10.0
## Height of the terrace above the ridge it stands on.
@export var terrace_height: float = 11.0
@export var parapet_height: float = 1.3
@export var parapet_thickness: float = 0.7
## Battlements on top of the parapets.
@export var merlon_height: float = 0.75
@export var merlon_width: float = 1.1
@export var merlon_spacing: float = 2.0
## The play boundary: short stone posts with a cord between them.
@export var post_height: float = 0.55
@export var post_spacing: float = 3.0

@export_group("Gate tower")
## Stands on the -Z side, its face flush with the parapet.
@export var gate_width: float = 18.0
@export var gate_depth: float = 11.0
## Brick storey, then a wooden pavilion with a double-eaved roof on top.
@export var gate_base_height: float = 6.5
@export var pavilion_height: float = 3.6
@export var roof_height: float = 4.2
@export var roof_eave: float = 2.0

@export_group("Props")
## One ring of low props (wine jars, brick stacks) per entry, at this
## distance from the play circle.
@export var prop_row_gaps: PackedFloat32Array = PackedFloat32Array([2.2, 4.6])
@export var prop_spacing: float = 5.5
@export_range(0.0, 1.0) var prop_skip_chance: float = 0.35
## Banner poles along the parapets, from the corners inward.
@export var banner_spacing: float = 7.0
@export var banner_height: float = 6.0

@export_group("Wall")
## Walkway width between the parapets.
@export var walkway_width: float = 6.0
## How far each branch runs from the terrace, and its sampling step.
@export var wall_length: float = 400.0
@export var wall_step: float = 4.0
## How far the wall body goes below the ridge line, to hide the terrain's
## coarse mesh.
@export var wall_footing: float = 6.0
## The branches wander across the ridge: amplitude and wavelength along X.
@export var meander_amplitude: float = 32.0
@export var meander_wavelength: float = 210.0
## The ridge climbs and dips: peak height above the terrace's ridge, distance
## between peaks, and how far from the terrace the climbing starts in full.
@export var ridge_rise: float = 40.0
@export var ridge_wavelength: float = 190.0
@export var ridge_ramp: float = 60.0
## Watchtowers along the branches.
@export var watchtower_spacing: float = 85.0
@export var watchtower_first: float = 55.0
@export var watchtower_size: Vector3 = Vector3(11.0, 6.0, 11.0)

@export_group("Terrain")
## Square heightfield of terrain_size metres, terrain_cells per side.
@export var terrain_size: float = 960.0
@export var terrain_cells: int = 104
## Flat ridge top under the wall (half width), wider at the terrace.
@export var ridge_top: float = 6.0
## How far the slopes fall off the ridge, and to what depth.
@export var ridge_width: float = 55.0
@export var valley_depth: float = 75.0
## Rolling hills off the ridge, and the far ranges on the horizon.
@export var hill_amplitude: float = 28.0
@export var hill_scale: float = 0.006
@export var far_amplitude: float = 150.0
@export var far_start: float = 220.0
@export var far_end: float = 430.0
## Trees on the slopes, kept this far from the wall.
@export var tree_count: int = 1300
@export var tree_wall_clear: float = 6.0
@export var tree_min_height: float = 4.0
@export var tree_max_height: float = 9.0
## A sea of mist in the valleys.
@export var mist_height: float = -48.0
@export var mist_color: Color = Color(0.98, 0.88, 0.82, 0.6)

@export_group("Colors")
@export var paving_light: Color = Color(0.62, 0.58, 0.52)
@export var paving_dark: Color = Color(0.46, 0.43, 0.39)
@export var moss_color: Color = Color(0.34, 0.38, 0.22)
@export var inlay_color: Color = Color(0.3, 0.27, 0.25)
@export var inlay_red: Color = Color(0.62, 0.12, 0.08)
@export var brick_color: Color = Color(0.58, 0.54, 0.47)
@export var brick_dark: Color = Color(0.44, 0.41, 0.36)
@export var mortar_color: Color = Color(0.74, 0.71, 0.64)
@export var walkway_color: Color = Color(0.52, 0.49, 0.44)
@export var lacquer_red: Color = Color(0.6, 0.1, 0.07)
@export var roof_tile: Color = Color(0.22, 0.25, 0.25)
@export var roof_trim: Color = Color(0.13, 0.36, 0.3)
@export var gold_color: Color = Color(0.85, 0.62, 0.18)
@export var cord_color: Color = Color(0.75, 0.1, 0.07)
@export var jar_color: Color = Color(0.42, 0.24, 0.14)
@export var banner_colors: PackedColorArray = PackedColorArray([
	Color(0.72, 0.1, 0.07), Color(0.88, 0.64, 0.12), Color(0.72, 0.1, 0.07), Color(0.1, 0.12, 0.14),
])
@export var grass_color: Color = Color(0.44, 0.5, 0.2)
@export var slope_color: Color = Color(0.52, 0.33, 0.15)
@export var far_color: Color = Color(0.5, 0.52, 0.6)
## Autumn: mostly reds and golds, some evergreens.
@export var tree_colors: PackedColorArray = PackedColorArray([
	Color(0.72, 0.22, 0.08), Color(0.85, 0.45, 0.1), Color(0.88, 0.66, 0.16),
	Color(0.6, 0.14, 0.1), Color(0.2, 0.32, 0.18), Color(0.28, 0.38, 0.16),
])
## Share of the trees that are evergreen cones.
@export_range(0.0, 1.0) var conifer_share: float = 0.3

@export_group("Renderer")
## Sun and ambient multiplier on the Compatibility renderer (the web build).
@export var compatibility_light_scale: float = 0.7

@export_group("Clouds")
@export var cloud_lit: Color = Color(1.0, 0.86, 0.72)
@export var cloud_shade: Color = Color(0.62, 0.5, 0.56)
@export_range(0.0, 1.0) var cloud_cover: float = 0.6
@export var cloud_scale: float = 2.2
@export var sun_glow: Color = Color(1.0, 0.62, 0.34)


func _init() -> void:
	sky_top_color = Color(0.24, 0.42, 0.7)
	sky_horizon_color = Color(0.98, 0.78, 0.62)
	sun_energy = 1.1
	# Low over the valley (+Z), so it lights the gate tower's face.
	sun_pitch_deg = -24.0
	sun_yaw_deg = 24.0
	ambient_energy = 0.55
	tonemap_mode = Environment.TONE_MAPPER_ACES
	tonemap_exposure = 0.9
	glow_enabled = false
	shadow_max_distance = 70.0
	fog_density = 0.0017
	outer_ground_size = 1000.0
	scenery_seed = 1644
	rock_color = Color(0.5, 0.48, 0.45)
