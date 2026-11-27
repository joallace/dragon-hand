class_name ArenaCatalog
extends RefCounted
## The stages a match can be played on. `MatchConfig.arena_id` holds one of
## IDS; an unknown id (an older or newer peer's config) plays on the default.
## Stages are visual only: the play area is always the circle of
## MatchDirector.arena_radius, so the sim never reads this.

const DEFAULT: StringName = &"default"
const BEACH_BAR: StringName = &"beach_bar"
const TIMES_SQUARE: StringName = &"times_square"
const GREAT_WALL: StringName = &"great_wall"

## Lobby order.
const IDS: Array[StringName] = [DEFAULT, BEACH_BAR, TIMES_SQUARE, GREAT_WALL]
const NAMES: Dictionary = {
	DEFAULT: "Stone Ring",
	BEACH_BAR: "Beach Bar",
	TIMES_SQUARE: "Times Square",
	GREAT_WALL: "Great Wall",
}


static func display_name(id: StringName) -> String:
	return NAMES.get(id, NAMES[DEFAULT])
