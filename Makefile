all: qigan.love

qigan.love: main.lua title.lua field.lua gameState.lua object.lua polygons.lua window.lua
	zip qigan.love *.lua
