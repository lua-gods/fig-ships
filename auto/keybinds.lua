local KEYBINDS = {
	pan = keybinds:fromVanilla("key.use"),
	select = keybinds:fromVanilla("key.attack"),
	delete = keybinds:newKeybind("delete", "key.keyboard.x"),
	rotate = keybinds:newKeybind("rotate", "key.keyboard.r"),
	esc = keybinds:newKeybind("rotate", "key.keyboard.escape"),
	vineboom = keybinds:newKeybind("rotate", "key.keyboard.b"),
	
	forward = keybinds:fromVanilla("key.forward"),
	back = keybinds:fromVanilla("key.back"),
	left = keybinds:fromVanilla("key.left"),
	right = keybinds:fromVanilla("key.right")
}

return KEYBINDS