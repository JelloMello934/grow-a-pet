--!strict
-- JarvisManifest: live config for the JarvisSync Studio plugin.
-- The plugin fetches this file on every Studio open and uses it INSTEAD of
-- its hardcoded settings. Editing this file on GitHub changes what the plugin
-- syncs and where it reports — with NO plugin re-paste. This is how the
-- workflow stays at zero pasting: the plugin only ever needs installing once.
return {
	-- Error-report inbox. Rotated 2026-10-06 after the old URL was found
	-- public in this repo. Rotate again by changing this line only.
	REPORT_URL = "https://webhook.site/6b30d732-b824-4643-8cba-36227d03469c",

	-- Game scripts the plugin syncs into the Studio place.
	-- name/class/parent must match the instance the game expects.
	FILES = {
		{ name = "GardenManager",  parent = "ServerScriptService",    class = "ModuleScript",
			url = "https://raw.githubusercontent.com/JelloMello934/grow-a-pet/main/GardenManager.lua" },
		{ name = "WildSystem",     parent = "ServerScriptService",    class = "ModuleScript",
			url = "https://raw.githubusercontent.com/JelloMello934/grow-a-pet/main/WildSystem.lua" },
		{ name = "MainServer",     parent = "ServerScriptService",    class = "Script",
			url = "https://raw.githubusercontent.com/JelloMello934/grow-a-pet/main/MainServer.lua" },
		{ name = "ClientMain",     parent = "StarterPlayerScripts",   class = "LocalScript",
			url = "https://raw.githubusercontent.com/JelloMello934/grow-a-pet/main/ClientMain.lua" },
		{ name = "JarvisReporter", parent = "ReplicatedStorage",      class = "ModuleScript",
			url = "https://raw.githubusercontent.com/JelloMello934/grow-a-pet/main/JarvisReporter.lua" },
		{ name = "PetData",        parent = "ReplicatedStorage/Shared", class = "ModuleScript",
			url = "https://raw.githubusercontent.com/JelloMello934/grow-a-pet/main/PetData.lua" },
		{ name = "BattleSystem",   parent = "ServerScriptService",    class = "ModuleScript",
			url = "https://raw.githubusercontent.com/JelloMello934/grow-a-pet/main/BattleSystem.lua" },
	},
}
