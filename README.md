### Development branch structure
	Live Branch
	Merge Branch
	Developer Branches

### Team development guide - for when your code additions are ready
* Push to your branch
* Checkout to the merge branch
* Pull all developer branches including your own
* Resolve all conflicts with your fellow developers
* Once all conflicts are resolved push to the live branch
* Pull the live branch into your own branch

### Front-end and Back-end features
* Data saving
* Knit framework
* Simple gui interface system
* Multiplayer up to 10 players
* Sound system
* TestEZ setup with test cases for nearly all services/controllers to some extent
* Refreshed UI

### Gameplay features
* Auto collect gamepass (automatically collects your paycheck)
* Time travel developer product  (gives you 12 hours of paychecks)
* Functionality to the existing ship (you can pilot it around to other islands)
* Ship thrusters gamepass (makes your ship faster)
* Blunderbuss gun (a shotgun style weapon that applies tons of knockback to the hit player and tons of spread to encourage players trying to knock each other off of their ships / tycoon islands)
* Physics based animations for the paycheck machine / gears / product pads / various elements around the world for liveliness
* Simple toolbar system
* Automatic pad billboard gui
* Notifications system (for when you unlock a new building or your paycheck increases or even as a gameplay tip)
* Kills counter

### Additional feature propositions
* Flag conquest in the center of the tycoons
* More steampunk / medivial themed assets and a better overall environment
* Blunderbuss weapon upgrades
* Additional TestEZ test cases (for the client side)
* Expansion to the toolbar system to allow for the users to roleplay
* Loading screen (to separate the users perception of other less effort tycoons from ours early on)
* Ticket shop menu gui which could include cosmetics etc or be a hub for your tycoon (say if we took more actions to making players fight such as defense systems or cannons on your ship)
* Non-programmer adjustable algorithms for the paycheck increases and all other balancing areas
* Plugin to visualize dependencies between pads so that its less of a headache to add more builds / change the progression paths😅 (simple arrow lines)
* Leaderboards for kills and highest kill streak
* Adding a GitHub Action to run the TestEZ cases with [Lemur](https://github.com/LPGhatguy/lemur) in case a developer forgets to run them in VSC
* Additional sfx for the ship and equipping/unequipping the gun
* Multi-dependency requirements for the pads (because I'll admit technically the ticket cabin won't always be the last one depending on how you go about buying the pads)
* SFX for not having enough money to buy a pad

## Quick start guide

Recommended extensions and tools:
* DataStore Editor Roblox Studio Plugin
* Reclass Roblox Studio Plugin
* Selene CLI and VSC Extension
* Knit + Roblox LSP VSC Extension (I recommend the Roblox Studio Plugin as well)
	* Its a modification by me of the original specifically for my style of knit structuring and it'll allow you to move across related parts of the codebase instantly plus understanding it will be easier with cross-file types/decorations
* Rojo VSC Extension
* Separators VSC Extension
* TestEZ Companion VSC Extension
* GitLens VSC Extension
* GitGraph VSC Extension