# Claude implementation prompt — Avatar PvP for macOS

Build a native macOS 1v1 elemental-bending arena game for me and my sibling to play on two separate MacBooks.

Act as a game designer, gameplay programmer, multiplayer engineer, and technical artist. Implement a playable game from this brief. Preserve the specified creative choices, use the proposed defaults for missing details, and make the balance values easy to tune.

## 1. Platform and scope

Use a current stable Godot 4 release, GDScript, and native macOS exports. State the exact engine version used.

The game must be free to run for two people. Use one Mac as the host and the other as the joining player over the same Wi-Fi or local network. Game assets and settings live locally.

Each player begins a round controlling one character belonging to one of four elements.

- Fire
- Water
- Earth
- Air

Both players can choose the same element. Give them distinct player markers and outlines so mirror matches remain readable.

The core experience is direct real-time combat, movement, cover, and elemental interaction in a compact arena. During each round, a contested Raava event gives one player the opportunity to become the Avatar and bend all four elements for the rest of that round.

Throughout this brief, a **fight** means one round. A **match** is a best-of-three sequence by default.

## 2. Visual direction

Use the Kingdom Rush franchise as the visual reference. [Kingdom Rush](https://www.kingdomrush.com/)

Aim for its illustrated fantasy aesthetic, expressive characters, strong silhouettes, chunky environmental shapes, rich colors, and readable effects at a small scale.

Use an elevated, angled overhead camera. Players should see the ground and the fronts of characters, with enough depth to understand walls, trees, rocks, jumping, and flying.

Build this with 2D sprites, layered scenery, ground shadows, and simulated height. Keep the full playable arena visible during a duel, with a consistent gameplay viewport across both Macs.

Create original character and environmental artwork that fits this direction.

Include the following visual and audio features.

- Directional idle, movement, attack, jump, hit, and defeat animations.
- Clear anticipation before powerful attacks.
- Ground shadows that show the actual position of jumping or flying characters.
- Correct depth sorting around scenery.
- Foliage or foreground objects that fade when they obscure the local player.
- Water ripples, splashes, restrained reflections, and shoreline detail.
- Material-specific impacts for stone, water, ice, wood, and metal.
- Distinct sound cues for each element and major ability.
- Adjustable particles, shadows, screen shake, and audio.

Elemental effects should have different visual identities.

- Fire uses curling orange-red flames, embers, and brief warm illumination.
- Water uses flowing blue shapes, foam, droplets, and cool highlights.
- Earth uses angular stone, dust, fragments, and substantial impacts.
- Air uses translucent curved streaks, swirling leaves or dust, and visible pressure waves.

Effects must communicate their actual area of impact. Preserve visibility of opponents, projectiles, and attack warnings during large specials and the Avatar transformation.

## 3. Arenas and terrain

Create four compact arena themes inspired by the Avatar nations.

- Earth Kingdom courtyard with stone, greenery, and shallow ponds.
- Water Tribe training ground with snow, shallow channels, and exposed rock.
- Fire Nation courtyard with volcanic stone and shallow water channels.
- Air Temple garden with stone terraces, vegetation, and shallow pools.

Every arena must contain accessible water and bendable earth or rock.

Vary the proportions and placement to change positioning and tactics. Use these suggested starting coverage values, measured across traversable ground.

| Arena | Water | Exposed earth or rock | Neutral ground |
| --- | --- | --- | --- |
| Water Tribe | 40% | 25% | 35% |
| Earth Kingdom | 15% | 60% | 25% |
| Fire Nation | 20% | 55% | 25% |
| Air Temple | 25% | 40% | 35% |

All playable water is ankle-deep to knee-deep. Characters can wade through it, jump over narrow channels, and fight while standing in it.

Place rocks, pillars, walls, trees, and other objects that players can move around and use as cover. Distinguish solid cover, low obstacles, decorative objects, and bendable resources in both visuals and collision rules.

Give both spawn positions comparable access to useful terrain. Include multiple routes around cover and enough open space to dodge. Avoid spawn positions with an immediate attack advantage.

For the first version, Create Arena means choosing a supplied arena and match settings.

Water and earth characters carry a small reusable supply for basic attacks. Their heavier terrain-based techniques require an appropriate nearby source. Show when a source is available and draw the effect from its actual position.

Use four character-widths as the initial source-access radius. Sources behind solid walls are inaccessible. Resource access should encourage movement around the arena.

Keep main environmental resource areas reusable during a match. Temporary walls, ice, and lava expire or break so the map remains playable.

Place a few clearly marked bendable metal objects in every arena for metal specialization. Give the metal specialist visible metal equipment as a source for personal defense.

Provide predefined, reachable neutral positions for the Raava beam. Keep these positions clear of solid obstacles and make them accessible from both sides of the arena.

## 4. Movement and controls

Use these default bindings.

| Input | Action |
| --- | --- |
| W, A, S, D | Move up, left, down, and right |
| Mouse position | Aim independently of movement |
| Space | Jump |
| Left mouse | Attack 1 |
| Right mouse | Attack 2 |
| E | Attack 3 |
| Q | Activate the equipped special |
| Hold Q inside the Raava beam | Channel the merge with Raava |
| 1, 2, 3, 4 while the Avatar | Select Fire, Water, Earth, and Air respectively |
| Escape | Open the match menu |

Simultaneous directional keys allow diagonals at the same total speed.

Support remapping every action, including keyboard alternatives for both mouse attacks and the Avatar's element-selection keys. The Raava merge uses the remapped special button. Save settings locally.

Jumping must affect gameplay. Separate ground position from height, and use height-aware collision rules.

A jump can clear low obstacles, ground sweeps, and ground hazards during the airborne portion. Ordinary projectiles can still hit according to their height and hit volume. Jumping has a brief recovery so constant jumping has a cost.

Start with about 0.6 seconds airborne and a 1-second cooldown measured from landing. Keep these values configurable.

## 5. Three regular attacks per element

Give every element three distinct regular attacks.

- Attack 1 is quick and reliable.
- Attack 2 is stronger, has a readable wind-up, and commits the player.
- Attack 3 controls space, interrupts, or displaces.

Use these initial move sets.

| Element | Attack 1 | Attack 2 | Attack 3 |
| --- | --- | --- | --- |
| Fire | Quick fire bolt | Charged flame burst | Sweeping flame arc |
| Water | Water lash | Ice projectile | Pushing wave that briefly slows |
| Earth | Stone projectile | Heavy boulder | Ground shockwave |
| Air | Air jab | Compressed gust | Sweeping knockback blast |

Water and earth heavy attacks and terrain controls use nearby matching resources. Basic attacks remain available through carried supplies.

Air should cause meaningful damage as well as displacement. Give its knockback a clear direction and limits.

Use aimable attacks, visible travel, wind-up, recovery, and collision. Choose initial values that produce a readable duel rather than instant defeat.

For every move, define its damage, range, speed, wind-up, recovery, cooldown, resource requirement, hit height, and interaction tags in editable data.

## 6. Health, longer fights, and round rules

The depleting bar I described as XP is health. Label it HP.

Start each fighter at **300 HP**, regardless of their chosen element. Taking damage reduces the defender's HP. At zero HP, the player loses the round.

A successful attack does not itself remove the attacker's HP.

Start with best-of-three rounds. Each round resets HP, terrain changes, temporary effects, cooldowns, and Avatar status.

Allow fresh stat allocation between rounds.

Use a configurable **4-minute round timer**. If it expires, higher remaining HP wins. Equal HP produces a draw and replay.

The host resolves both players' actions for a simulation tick before deciding victory, so simultaneous lethal hits can produce a draw.

Aim for typical evenly matched rounds lasting approximately **2–4 minutes**, including movement, cover, missed attacks, and the Raava contest. Treat this as a playtesting target.

Use these initial damage guidelines before stat modifiers.

| Attack category | Starting damage guideline |
| --- | --- |
| Quick attacks | 8–12 HP |
| Heavy attacks | 18–25 HP |
| Control attacks | 6–10 HP plus their control effect |
| High-damage specials | 35–50 HP when fully landed |

Persistent effects have explicit total-damage budgets and per-target hit intervals.

Tune shield durability and armor capacity against these HP and damage values. Confirm that successful attacks produce visible progress toward victory and that evenly matched fights usually last long enough for the Raava event to matter.

## 7. Stat allocation

Before each round, give both players **8 upgrade points**.

Three stats begin at 0 and each has a maximum of 5.

- Attack
- Defense
- Mobility

Players can distribute all 8 points. This budget allows at most one maximized stat.

Use these initial stat effects.

- Each Attack point adds 5% damage.
- Each Defense point adds 4 percentage points of damage reduction.
- Each Mobility point adds 4% movement speed.

Keep base HP at 300 for every element.

Use 50% as the initial cap on combined damage reduction from stats and temporary effects. Keep shields and armor durability separately visible.

The build screen must show available points, resulting values, and the specialization unlocked at 5 points.

Allocations apply to the upcoming round and can be changed before Ready. The host validates them and locks both builds for the round.

Becoming the Avatar preserves the original allocation and its bonuses.

## 8. Random specials and specialization choice

Use one special-attack key, Q.

For each round, offer each player one randomly selected standard special from their element's pool. Show its description before Ready.

Use these initial standard special pools.

| Element | Possible standard specials |
| --- | --- |
| Fire | Revolving fire rings or an outward fire wave |
| Water | An octopus stance with surrounding water tentacles or an ice barrier |
| Air | A surrounding tornado or a radial repulsion burst |
| Earth | Earth armor or a powerful radial ground slam |

The four signature abilities must be visually recognizable.

- Fire rings rotate around the fighter and damage nearby enemies.
- Water tentacles surround the fighter, intercept a limited number of attacks, and strike nearby targets.
- The tornado surrounds the fighter, deflects light projectiles, and pushes opponents away.
- Earth armor visibly builds around the fighter and absorbs a limited amount of damage.

If a player maximizes a stat, unlock the corresponding specialization from the next section. The player chooses either that specialization or the randomly offered standard special for their Q slot.

Each player enters the round with three regular attacks and one equipped special.

Random offers are generated by the host and remain fixed for that round. Changing Ready status or revisiting character selection preserves the existing offer for each element.

Give standard specials approximately 3–5 seconds of duration where applicable and 18–25 seconds of cooldown. Begin cooldown after the effect ends. Display its remaining time clearly.

Inside the Raava beam, Q takes priority as the merge action. Becoming the Avatar preserves the equipped special and its existing cooldown.

## 9. Stat-based specializations

Preserve these requested unlock mappings even where they are custom game design.

### Fire

- Maximum Attack unlocks lightning generation. An aimed, high-damage strike with a visible charge and a narrow attack path.
- Maximum Mobility unlocks forehead combustionbending. An aimed explosive shot with a visible forehead charge, a clear impact warning, and a recovery period.
- Maximum Defense unlocks a flame guard. A temporary directional defense that absorbs limited incoming force and can be broken.

### Water

- Maximum Attack unlocks bloodbending. A short-range, interruptible hold with clear warning and a strict maximum duration.
- Maximum Defense unlocks a healing stance. Q activates slow regeneration for a limited duration while the fighter remains vulnerable to damage and defeat.
- Maximum Mobility unlocks a water surge. A directed movement burst using a ribbon of water, with stronger reach when starting near a water source.

### Earth

- Maximum Attack unlocks lavabending. Create a small, telegraphed lava area that damages and denies space before cooling.
- Maximum Defense unlocks metalbending. Pull metal into a temporary defensive shell and use its activation to interrupt nearby attackers.
- Maximum Mobility unlocks earth surfing. Ride a moving slab along accessible ground, with clear steering and collision limits.

### Air

- Maximum Mobility unlocks temporary flight supported visually by a rotating air sphere. The player can fly over low cover and glide around the arena.
- Maximum Attack unlocks a spirit form. The fighter becomes briefly intangible and attacks pass through them.
- Maximum Defense unlocks a compressed air barrier that deflects a limited amount of incoming force.

### Ability limits

- Bloodbending initially holds for at most 1 second. The caster channels, cannot attack during the hold, and can be interrupted. Solid cover blocks targeting. Apply a short period of control immunity after release.
- Healing restores **6 HP per second for 6 seconds**, capped at maximum HP. Damage remains active throughout, and incoming damage can exceed the healing rate.
- Spirit form lasts around 2 seconds. The fighter can reposition but cannot deal damage during it. Keep arena boundaries and solid-cover collision active.
- Flight lasts around 5 seconds. Ranged attacks can still hit the flying fighter. Show height and landing position, and resolve landing safely.
- Lava occupies a limited area and expires. It cannot permanently seal every route across the arena.
- Lightning and combustion have obvious attack preparation and opportunities to dodge or interrupt.

Start specialization cooldowns around 25–35 seconds, adjusted to their impact. These are initial tuning values, not claims of proven balance.

## 10. Avatar lore and custom rules

Use the animated Avatar universe for the identity of each element and its recognizable techniques. Include relevant techniques from The Legend of Korra where this brief requires them.

Water is fluid, adaptive, and dependent on available water. Earth emphasizes rooted movement, timing, material, and decisive force. Fire emphasizes breath, energy, pressure, and controlled aggression. Air emphasizes circular movement, evasion, displacement, and freedom.

The following are intentional game adaptations.

- Spending points to unlock rare bending skills.
- Unlocking combustionbending through Mobility.
- Unlocking spirit form through Attack.
- Turning the fighter intangible during spirit form.
- Making bloodbending available through a build without a full-moon requirement.
- Activating regeneration as a repeatable combat ability.
- Using bounded durations and cooldowns for balance.
- Allowing a fighter to claim Raava during a round and gain access to all four elements until that round ends.

Describe them accurately in development notes while keeping the requested mechanics.

## 11. Elemental interactions

Create explicit, consistent interaction rules based on the individual moves and materials involved. Give each ability tags for elemental type, force, height, projectile behavior, and shield interaction.

Implement these starting relationships.

- Water can extinguish smaller flames and remove burning effects.
- Strong fire can melt temporary ice and create brief steam when it hits water.
- Earth walls intercept attacks until their durability is exhausted.
- Water and earth controls can create a temporary muddy slow zone.
- Air can deflect light projectiles and disperse steam. Heavy boulders exceed ordinary air deflection strength.
- Fire passing through a particular air attack can be redirected or enlarged according to that move's defined rule.
- Lightning striking shallow water creates a small, clearly telegraphed conductive area.
- Lava meeting water produces steam and a temporary cooled stone patch.
- Armor reduces or absorbs damage according to its capacity and remains breakable.

Conductive areas must remain local to the impact. A connected water body must not become a map-wide unavoidable hit.

Avoid automatic damage based solely on the two players' chosen elements. Position, timing, resource access, and the actual moves should decide the interaction.

Give hard control a short duration and temporary resistance after release. Use per-target hit intervals for persistent rings, tentacles, and hazards so damage does not depend on frame rate.

Define whether a move can hurt its caster. Use consistent visuals for any self-damaging hazards.

Apply the same interaction rules to the Avatar's attacks.

## 12. Becoming the Avatar during a round

Introduce a mid-round event where one player can merge with Raava and gain access to all four elements for the remainder of that round.

### Event timing and appearance

- At 50 seconds, announce that Raava is approaching.
- At 60 seconds, a glowing spirit descends inside a vertical beam of light.
- Choose a reachable, neutral location from predefined arena positions. Keep the location clear of solid obstacles.
- Show the upcoming location during the warning so both players can approach.
- Use an unmistakable ground circle, spiritual particles, and a distinct sound.
- The beam remains until someone claims it.
- Each round has one Raava event and allows one successful transformation.

### Claiming Raava

- A player enters the beam and holds Q, their special button, for 1.5 seconds.
- Inside the beam, Q takes priority as the merge action. Outside it, Q activates the equipped special normally.
- Merging is available even while the ordinary special is cooling down.
- The player must remain grounded and stationary while channeling.
- Moving, taking damage, attacking, jumping, or an opponent entering the circle resets the channel.
- While both players occupy the circle, neither can progress.
- Show claim progress to both players.
- The host validates the claim and awards the transformation exactly once.

### Transformation

- Play a short fusion animation with Raava entering the character, glowing eyes, and four elemental effects.
- Keep the arena and opponent visible throughout.
- The transformed player becomes the Avatar for the rest of the current round.
- Remove the beam after the successful claim.
- Preserve the player's current HP, maximum HP, allocated stats, and existing cooldowns.
- The transformation itself provides no healing or damage immunity.

### Controlling all four elements

- Keys 1, 2, 3, and 4 select Fire, Water, Earth, and Air.
- Make these bindings remappable.
- The three normal attack buttons now use the currently selected element's move set.
- Clearly show the active element on the HUD and character.
- Allow switching while moving, with a brief 0.3-second switch recovery.
- Switching must respect committed attack animations.
- Share cooldowns across corresponding attack slots so changing elements cannot bypass recovery or enable unlimited heavy attacks.
- Preserve the original equipped Q special after merging.
- Keep specialization unlocks tied to the player's original pre-round build.
- Water and earth abilities continue to respect their material requirements.

### Avatar combat identity

- Reward combinations such as pushing an enemy away with air, creating space with earth, then attacking with fire.
- Give the opponent readable attack cues for the Avatar's currently selected element.
- Retain the Avatar's normal vulnerability to damage, interruption, and defeat.
- The transformation provides versatility through four complete base move sets.
- Keep every elemental interaction consistent with the existing combat rules.

### Round and network behavior

- Reset Avatar status at the beginning of the next round.
- Pause the event timer and claim progress whenever the match is paused.
- Synchronize the spawn location, claim progress, successful merge, active element, and Avatar status through the host.
- Show the winner's Avatar status on the round-results screen.

## 13. Menus and multiplayer flow

### Main menu

- Create Arena
- Join Arena
- Settings
- Controls
- Quit

### Create Arena

- Select the arena.
- Set round count and timer, defaulting to best-of-three and 4 minutes per round.
- Display the host's local IP address and port.
- Wait for the other player.

### Join Arena

- Enter the host's local IP address and port.
- Show connecting, connected, failed, and disconnected states with useful messages.

### Lobby

- Display both players.
- Select element and character appearance.
- Allocate stats.
- View and equip the offered special or unlocked specialization.
- Show Ready status.
- Start a synchronized countdown after both players are ready.

### Match HUD

- Both HP bars.
- Element and player identity.
- Round score and timer.
- Three attack icons and their cooldowns.
- Equipped special, its active duration, and cooldown.
- Relevant resource-access and status indicators.
- Raava's arrival warning and claim progress during the event.
- Avatar status and the active element, with element-switching bindings for the transformed player.

### Match menu

- Resume
- Request Pause
- Settings
- Controls
- Leave Match

Opening a menu leaves the match running. A pause request freezes the duel only after the other player accepts. Freeze simulation, damage, healing, durations, cooldowns, the round timer, the Raava event timer, and claim progress together while maintaining the network connection.

Resume when both players are ready.

At round end, show the result and allow changes before the next round. At match end, offer Rematch and Return to Menu.

If either player disconnects, stop the active duel and show a clear result or recovery screen. Both players must be able to start another connection without restarting the app.

## 14. Networking and performance

Use Godot's high-level multiplayer API with ENet.

The hosting Mac also participates as a player. It owns the authoritative simulation for positions, collisions, HP, cooldowns, terrain, random special offers, the Raava event, Avatar status, active elements, and round outcomes.

The joining Mac sends player inputs. Validate input ownership, build values, ability availability, movement, casting conditions, element switching, and Raava claim eligibility on the host.

Use reliable messages for lobby changes, round transitions, and important events such as the successful Raava merge. Use appropriate sequenced updates for frequent movement snapshots.

Make local movement feel responsive with prediction and reconciliation where needed. Smooth remote movement with interpolation.

Synchronize terrain changes and ability activation so both players see the same fight. Keep visual particles client-side where they do not affect gameplay.

Use a fixed simulation step. Target 60 FPS on the actual Mac hardware used for testing, and state the machine and settings when reporting performance.

Support two app instances on one Mac for development testing, followed by a real two-Mac test.

Document local network permission and firewall prompts that may appear. For private sharing, provide a free export and signing approach appropriate to Godot and macOS.

## 15. Implementation and delivery

Build in working stages.

1. A playable arena with movement, aiming, jumping, and collision.
2. Host and Join functionality with synchronized movement and a real attack.
3. All four base elements and three attacks per element.
4. HP, victory, round reset, and rematch using the 300 HP and 4-minute defaults.
5. Stat allocation, random special offers, and all specializations.
6. The Raava event, contested merging, Avatar transformation, and synchronized element switching.
7. Terrain interactions, remaining arena themes, visuals, audio, and settings.

Each stage should extend the same project. Keep ability values and arena definitions editable.

If finished art is unavailable, use coherent temporary assets and clearly identify what remains to be replaced.

Deliver the following.

- The complete Godot project.
- A native macOS build when export tools are available.
- Instructions to build, export, host, join, and remap controls.
- A short explanation of the multiplayer architecture.
- A balance table for attacks, specials, stats, and Avatar event settings.
- A record of what was actually tested and any remaining limitations.

Verify the full path from launching two instances through joining, selecting builds, fighting, contesting Raava, transforming, switching elements, pausing, ending a round, rematching, disconnecting, and hosting again.

Check mirror matches, all specializations, jumping and flight collisions, terrain interactions, and overlapping attacks.

Test contested and interrupted Raava claims, claiming while the ordinary special is cooling down, shared attack cooldowns across elements, and Avatar status resetting between rounds. Confirm that both clients agree on the successful claimant.

Test both ordinary duels and Avatar-versus-single-element duels. Confirm that fights usually last long enough for the Raava event to matter, while successful attacks still produce visible progress toward victory.

Clearly distinguish same-Mac testing from a completed test on two physical Macs. Report technical blockers and continue with the parts that can be completed.

## References

- [Kingdom Rush visual reference](https://www.kingdomrush.com/)
- [Avatar Wiki](https://avatar.fandom.com/wiki/Avatar_Wiki)
- [Avatar specialized bending](https://avatar.fandom.com/wiki/Specialized_bending_techniques)
- [Avatar spiritual projection](https://avatar.fandom.com/wiki/Spiritual_projection)
- [Godot multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [Godot macOS export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)
- [Riot's discussion of visual clarity](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
- [Riot's discussion of counterplay](https://www.leagueoflegends.com/en-us/news/dev/quick-gameplay-thoughts-may-14/)
