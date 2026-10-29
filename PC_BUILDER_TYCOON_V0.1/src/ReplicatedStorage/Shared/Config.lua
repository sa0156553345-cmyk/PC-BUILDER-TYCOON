-- Config.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "Config")
-- PURE: no Roblox types, so the test suite can load it. Values marked PLACEHOLDER are starting guesses.

local Config = {}

Config.Version = "0.1.4"
Config.DefaultLanguage = "en"

-- Reach and placement (the server enforces these; the client uses the snap values for preview)
Config.MaxInteractDistance = 18        -- PLACEHOLDER studs. Raised from 14 to fit the workshop layout.
Config.InstallReachStuds = 3           -- PLACEHOLDER studs: proposed pose to socket
Config.SnapRadiusStuds = 2.5           -- PLACEHOLDER: preview magnet range
Config.SnapAngleDegrees = 15           -- PLACEHOLDER: allowed misalignment for snap and install
Config.BenchHalfExtents = { x = 20, y = 20, z = 20 }   -- PLACEHOLDER: parts stay inside this box around the origin
Config.WorkshopSpacing = 80            -- PLACEHOLDER studs between per-player workshops
Config.BinSpacing = 3                  -- used only by the legacy template path

-- Drag and pickup timing (client). PLACEHOLDER values.
Config.PlacementTimeoutSec = 3         -- how long a pending placement may wait for the server
Config.ConfirmDistanceStuds = 0.15     -- the real part counts as arrived within this distance
Config.DragThresholdPixels = 8         -- movement at or below this is a tap (select only)
Config.PickupTimeoutSec = 2            -- no pickup answer in time: the local drag is cancelled

-- Maximum requests per player per action per second (server)
Config.RateLimit = {
	PickUp = 5,
	ProposePlacement = 6,
	ReleaseHold = 10,
	RequestUninstall = 4,
	TightenScrew = 8,
	RequestBoot = 2,
}

Config.RemoteFolderName = "AssemblyRemotes"
Config.RemoteNames = {
	"PickUp",
	"ProposePlacement",
	"ReleaseHold",
	"RequestUninstall",
	"TightenScrew",
	"RequestBoot",
	"Feedback",
}

return Config
