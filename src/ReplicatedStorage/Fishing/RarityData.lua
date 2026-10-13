local order = { "Common", "Rare", "UltraRare", "Legendary", "Mythical" }

local info = {
	Common = {
		displayName = "Common",
		color = Color3.fromRGB(190, 190, 190),
	},
	Rare = {
		displayName = "Rare",
		color = Color3.fromRGB(70, 160, 255),
	},
	UltraRare = {
		displayName = "Ultra Rare",
		color = Color3.fromRGB(175, 80, 230),
	},
	Legendary = {
		displayName = "Legendary",
		color = Color3.fromRGB(255, 170, 40),
	},
	Mythical = {
		displayName = "Mythical",
		color = Color3.fromRGB(255, 60, 90),
	},
}

return {
	order = order,
	info = info,
}
