# Civilization VI Mods

## Repository Introduction

This repository collects the [Civilization VI](https://civilization.2k.com/civ-vi/) mods I implemented. These mods can be downloaded from [Steam Workshop](https://steamcommunity.com/app/289070/workshop/), or you can clone this repository and place the mod folders you need into the corresponding Civilization VI mod folder.

The local mod folder is usually located at `%USERNAME%\Documents\My Games\Sid Meier's Civilization VI\Mods`.

## Mod Descriptions

### Additional Policy Slots

![Additional Policy Slots cover](covers/AdditionalPolicySlots.png)

Folder: `AdditionalPolicySlots`

Provides additional policy slots for human players after they have the corresponding civics:

- Having the "Military Tradition" civic: +1 Military Policy Slot.
- Having the "Foreign Trade" civic: +1 Economic Policy Slot.
- Having the "Political Philosophy" civic: +1 Diplomatic Policy Slot.
- Having the "Mysticism" civic: +1 Wildcard Policy Slot.

AI players are not affected.

### Barbarian Ward

![Barbarian Ward cover](covers/BarbarianWard.png)

Folder: `BarbarianWard`

Human combat units gain a 99 advantage when combating barbarian units.

### Movement Enhance

![Movement Enhance cover](covers/MovementEnhance.png)

Folder: `MovementEnhance`

This mod grants a global movement bonus to all units controlled by human players. Once enabled, every unit owned by a human player receives 1 Movement. AI players are not affected.

### Opening Techs and Civic Completion

![Opening Techs and Civic Completion cover](covers/OpeningTechsAndCivicCompletion.png)

Folder: `OpeningTechsAndCivicCompletion`

In Ancient Era starts, when a human major player's first turn starts after entering the game, the following opening technologies and civic are immediately completed:

- Technologies: Pottery, Animal Husbandry, Mining, Sailing, Astrology.
- Civic: Code of Laws.

This effect triggers only once and does not affect AI players. This effect does not trigger in non-Ancient Era starts.

### People's War

![People's War cover](covers/PeoplesWar.png)

Folder: `PeoplesWar`

Under the Gathering Storm ruleset, this mod grants the following effects to human major players:

- Normal and religious combat strength increase with total empire population: +1 at 1–10 population, +2 at 11–20, and so on, capped at +100.
- Each city gains ranged strike strength, city defense strength, and counter-spy levels from its own population: +1 at 1–10 population, +2 at 11–20, and so on; the bonus is capped at +10 once the city reaches 91 population.
- Conquered cities lose no population.
- Newly conquered or loyalty-joined cities may choose "Dissolve": "Dissolve this city and redistribute its entire population among your other retained cities. Any remainder is assigned one population each to the least-populous eligible cities."

AI players do not receive these effects.

### Population Yields

![人口产出](covers/PopulationYields.png)

Folder: `PopulationYields`

Under the Rise and Fall and Gathering Storm rulesets, each city gains +2 Gold, +0.5 Production, +1 Faith, +0.5 Science, and +0.5 Culture per population.

This effect applies only to human major players. AI players do not receive these effects.

### Raze Original Capital

![Raze Original Capital cover](covers/RazeOriginalCapital.png)

Folder: `RazeOriginalCapital`

By modifying the global configuration, any city can be razed, affecting both human players and AI.

### Sight Enhance

![Sight Enhance cover](covers/SightEnhance.png)

Folder: `SightEnhance`

This mod provides a global sight range bonus to human player units. All units controlled by human players will gain an additional 1 point of vision. It can stack with João III's Porta do Cerco. This effect does not affect AI players.

## License

This repository is licensed under the [Apache License 2.0](LICENSE.txt).
