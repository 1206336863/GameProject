extends Control
signal vector_changed(value: Vector2)
signal pressed_changed(value: bool)
var aim_pad = false
var finger = -1
var origin = Vector2.ZERO
var value = Vector2.ZERO
var deadzone = .18

func _ready():
	custom_minimum_size = Vector2(142,142)
	mouse_filter = Control.MOUSE_FILTER_STOP

func vector_for(delta):
	var fraction = clamp(delta.length()/48.0,0,1)
	if fraction<=deadzone:return Vector2.ZERO
	return delta.normalized()*(fraction-deadzone)/(1-deadzone)

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed and finger<0:
			finger=event.index;origin=size/2 if aim_pad else event.position
			pressed_changed.emit(true);value=vector_for(event.position-origin);vector_changed.emit(value)
		elif not event.pressed and event.index==finger:reset()
	elif event is InputEventScreenDrag and event.index==finger:
		value=vector_for(event.position-origin);vector_changed.emit(value)
	queue_redraw()

func reset():
	finger=-1;value=Vector2.ZERO;vector_changed.emit(value);pressed_changed.emit(false);queue_redraw()

func _draw():
	var center=size/2
	draw_circle(center,65,Color(.08,.15,.22,.66))
	draw_arc(center,65,0,TAU,48,Color(.95,.3,.58,.7) if aim_pad else Color(.3,.9,.75,.7),2)
	draw_circle(center+value*42,20,Color(.95,.3,.58,.6) if aim_pad else Color(.3,.9,.75,.6))
