class_name CookProfile
extends Resource
## How an item changes while exposed to a heat source.
## Progress rises at `rate` per second. Stages are ordered; each stage lasts
## until its `stage_ends` value. Quality 0 means "ruined" (customers refuse it).

@export var heat: StringName = &"grill"          ## Which heat sources cook this item.
@export var rate := 0.1                           ## Progress per second.
@export var stage_names: PackedStringArray = []
@export var stage_ends: PackedFloat32Array = []   ## Upper bound of each stage.
@export var stage_quality: PackedFloat32Array = []
@export var stage_colors: PackedColorArray = []   ## Multiplied onto the model.
@export var perfect_stage := 2                    ## Stage that triggers the "ding".
@export var smoke_from := 1.1                     ## Progress where it starts smoking.
@export var fire_at := 1.7                        ## Progress where it ignites (<=0: never).


func stage_index(progress: float) -> int:
	for i in stage_ends.size():
		if progress < stage_ends[i]:
			return i
	return stage_ends.size() - 1


func stage_name(progress: float) -> String:
	return stage_names[stage_index(progress)] if not stage_names.is_empty() else ""


func quality(progress: float) -> float:
	return stage_quality[stage_index(progress)] if not stage_quality.is_empty() else 1.0


## Smoothly interpolated colour across stage boundaries.
func color_at(progress: float) -> Color:
	if stage_colors.is_empty():
		return Color.WHITE
	var i := stage_index(progress)
	var start := 0.0 if i == 0 else stage_ends[i - 1]
	var end := stage_ends[i]
	var t := clampf((progress - start) / maxf(end - start, 0.001), 0.0, 1.0)
	var a := stage_colors[i]
	var b := stage_colors[mini(i + 1, stage_colors.size() - 1)]
	return a.lerp(b, smoothstep(0.55, 1.0, t))
