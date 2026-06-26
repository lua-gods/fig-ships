local actionWheelID = keybinds:fromVanilla("figura.config.action_wheel_button"):getID()

events.KEY_PRESS:register(function(key, state, modifiers)
	if key == actionWheelID then
		if action_wheel:isEnabled() and state == 0 then
			toggle = not toggle
			return toggle
		end
	else
		if action_wheel:isEnabled() then
			return true
		end
	end
end)
