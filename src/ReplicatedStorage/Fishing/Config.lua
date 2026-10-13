return {
	MinBiteTime = 2,
	MaxBiteTime = 8,

	-- Reel minigame tick rate.
	TickRate = 1 / 20, -- 20 times per second

	-- Reel bar (0-100 scale).
	BarMax = 100,
	BarStart = 50,

	-- How fast progress fills when the indicator is inside the fish zone,
	FillRate = 28,
	DrainRate = 18,

	-- Indicator (controlled by the player holding/releasing reel input).
	IndicatorRise = 55, 
	IndicatorFall = 40, 

	-- Fish zone (the target window the indicator must stay inside).
	ZoneMinSize = 14,
	ZoneMaxSize = 24,
	ZoneSpeed = 18, 

	-- Minigame time limit (seconds) before the fish escapes regardless of progress.
	ReelTimeLimit = 20,
}
