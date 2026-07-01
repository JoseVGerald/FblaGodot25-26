extends SceneTree

func _init():
    var l = Label.new()
    l.text = "Hello"
    l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    print(l.position.x)
    print(l.size.x)
    quit()
