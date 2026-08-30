-- Module owner: CompatibilityRuntime
-- Internal compatibility/provider discovery, ownership resolution, evidence, and
-- public compatibility projections. Gameplay policy remains with its owning subsystems.
return function(mod, deps)
  deps = deps or {}
  local H = assert(deps.H, "compatibility runtime requires helper namespace")
  local compatPublicCopy = assert(deps.compatPublicCopy,
      "compatibility runtime requires compatPublicCopy")
  assert(type(deps.currentGame) == "function",
      "compatibility runtime requires live currentGame getter")
  assert(type(deps.getActive) == "function",
      "compatibility runtime requires live active getter")
  assert(type(deps.getDefaultRuleValue) == "function",
      "compatibility runtime requires live default-rule getter")
  assert(type(deps.getCatchDeniedReason) == "function",
      "compatibility runtime requires live catch-policy getter")

  ---------------------------------------------------------------------
  -- INTER-MOD COMPATIBILITY / PROVIDER REGISTRY
  -- Capability-based only; never match mod names/descriptions.
  -- Providers are discovered from active loaded mods and revalidated with
  -- mod.find() at point of use, so disabled/failed mods do not interfere.
  -- Supported capabilities: level_caps, postgame_caps, escape, encounters, npc_talk,
  -- npc_behavior, npc_visibility, npc_movement. NPC capabilities are optional
  -- ownership declarations; vanilla NPC behavior remains ours unless another
  -- mod explicitly exports a provider.
  ---------------------------------------------------------------------
  local COMPAT_PROVIDERS = {
      level_caps = nil, postgame_caps = nil, escape = nil, encounters = nil,
      npc_talk = nil, npc_behavior = nil, npc_visibility = nil, npc_movement = nil,
      wonder_trade = nil, pokemon_identity = nil, species_metadata = nil,
      battle_stats = nil, stat_growth = nil, identity_dvs = nil,
      move_category_model = nil, species_evolutions = nil,
      -- 2.8.33: presentation is a diagnostic/ownership capability only.
      -- It never grants gameplay authority; renderers may own world/battle
      -- composition while Nuzlocke keeps challenge state and semantic actions.
      presentation = nil,
  }
  -- 2.7.64: retain every live provider candidate, not only the first one.
  -- MOD COMPAT can then pin a capability to AUTO, Nuzlocke/Engine, or a
  -- specific installed provider without inventing ownership that the provider
  -- did not actually advertise. Preferences are save-local and fail open.
  local COMPAT_PROVIDER_CANDIDATES = {}

  local function compatOwnerPreference(capability)
      local prefs = mod.save:get("compat_owner_preferences", {})
      local value = type(prefs) == "table" and prefs[tostring(capability)] or nil
      value = tostring(value or "auto")
      return value ~= "" and value or "auto"
  end

  local function setCompatOwnerPreference(capability, value)
      capability = tostring(capability or "")
      if capability == "" then return false end
      local current = mod.save:get("compat_owner_preferences", {})
      local prefs = {}
      for k, v in pairs(type(current) == "table" and current or {}) do prefs[k] = v end
      value = tostring(value or "auto")
      if value == "auto" then prefs[capability] = nil else prefs[capability] = value end
      mod.save:set("compat_owner_preferences", prefs)
      return true
  end
  local COMPAT_CAPABILITIES = {
      "level_caps", "postgame_caps", "escape", "encounters",
      "npc_talk", "npc_behavior", "npc_visibility", "npc_movement", "wonder_trade",
      "pokemon_identity", "species_metadata",
      -- beta.27.3: compatibility negotiation also advertises the shared engine
      -- surfaces most likely to be wrapped by other gameplay/UI mods. These are
      -- metadata/handshake capabilities; merely discovering one does not give a
      -- third-party mod ownership of Nuzlocke policy.
      "item_use", "shopping", "healing", "battle_finish", "trainer_card", "party_menu",
      "start_menu_items", "screens", "static_encounters", "gambling",
      "encounter_area_projection", "trainer_party", "boss_level_caps",
      "battle_classification", "movement_speed", "starter_randomization",
      -- 2.8.33: provider-neutral renderer/presentation ownership. No Nuzlocke
      -- gameplay path delegates through this capability; it exists so MOD COMPAT
      -- and future presentation mods can describe composition without screen-id
      -- heuristics or direct renderer replacement.
      "presentation",
      -- 2.4.34 internal mechanics dimensions. These are still private
      -- compatibility signals; exposing a stable third-party registration
      -- contract is intentionally deferred until the model has runtime proof.
      "battle_stats", "stat_growth", "identity_dvs",
      "move_category_model", "species_evolutions",
      -- 2.7.65: optional mechanic-presence contracts. These do not grant
      -- challenge-policy ownership; they only make otherwise N/A rules eligible.
      "overworld_encounters", "safari_zone", "gym_guide_rare_candy", "starter_trio", "pokegear_radio", "cherrygrove_tour",
  }

  -- COMPATIBILITY LAYERS (beta.27.4)
  -- Keep engine-version compatibility separate from inter-mod cooperation.
  -- This namespace is deliberately hung from the existing beta export table so
  -- the giant main chunk does not accumulate another batch of long-lived locals.
  mod.exports.__beta26.compat = {
      Engine = {
          audited = mod.exports.__beta26.recompCompatAudited,
          active_profile = mod.exports.__beta26.recompCompatAudited,
          profiles = {
              ["0.1.78"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Published compatibility floor; protected historical runtime behavior.",
              },
              ["0.1.79"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Protected audited profile for the first expanded Gold compatibility build.",
              },
              ["0.1.80"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Gold Pack, battle replacement, naming, mart, and movement update profile.",
              },
              ["0.1.81"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Protected audited profile; public hooks/events and guarded Gold transaction seams verified.",
              },
              ["0.1.82"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; protected battle, item, shop, save, and Gold script seams remain available.",
              },
              ["0.1.83"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Historical audited profile; Mod API/save format are preserved and Gold mapOverview is additive.",
              },
              ["0.1.94"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Historical audited profile; version-aware mod conflicts and opt-in postLog infrastructure added without changing Nuzlocke gameplay seams.",
              },
              ["0.1.98"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Historical source-audited profile; shared mod.battle snapshots/intents, contextual mod.world field actions, expanded Gold field items, native Gold starter nickname flow, and Gold battle/encounter fixes reviewed.",
              },
              ["0.1.99"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Historical source-audited profile; public Gen 1 item.use dispatch, shared battle HUD visibility hooks, the current Gen 2 compatibility matrix, and 0.1.99 engine/mod documentation reviewed.",
              },
              ["0.2.0"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited release profile; Gold catch.rate now receives the live battle, target mon, and species definition, while protected Nuzlocke transaction seams remain retained and composed.",
              },
              ["0.2.1"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Historical source-audited profile; 0.2.1 is a launcher-only hotfix over 0.2.0 with no mod-runtime source changes in the release delta.",
              },
              ["0.2.2"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; Gold adds shared battle.move_grid_navigation while protected Nuzlocke battle/UI seams remain unchanged.",
              },
              ["0.2.3"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; Gold mod.battle snapshots gain Ball inventory/catch previews and catching registry plumbing without changing Nuzlocke enforcement ownership.",
              },
              ["0.2.4"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; link/session security hardening does not change Mod API 2, Save Format 4, or Nuzlocke rule seams.",
              },
              ["0.2.5"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; audio, Switch/cache, Gold world, evolution and skin work does not require a Nuzlocke adapter change.",
              },
              ["0.2.6"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; Gold mart/UI/world and launcher updates retain the transaction and script surfaces used by Nuzlocke.",
              },
              ["0.2.7"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Historical source-audited profile; Gold TimeFishGroups/day-night fishing extends the encounters registry while render/audio/platform changes retain Mod API 2, Save Format 4, and Nuzlocke protected seams.",
              },
              ["0.2.8"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; launcher/platform, save/runtime, status, skin, sync, and Gold UI/world changes retain Mod API 2 and the protected Nuzlocke transaction seams.",
              },
              ["0.2.9"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; skin/importer follow-up changes retain Mod API 2, Save Format 4, and the protected Nuzlocke hook/event surfaces.",
              },
              ["0.2.10"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Current source-audited release profile; battle-message lifecycle, Runtime/Loader attribution, TextBox, Game/Game2, save, sync, and launcher changes retain the existing Nuzlocke enforcement seams. Runtime smoke test remains required.",
              },
              ["0.2.11"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Current source-audited release profile; Silver/GameVersion, SaveData/Gen2 Save, Game/Game2, Gen2 World, manifest targeting, and launcher/build changes retain Mod API 2 and the protected Red/Blue/Yellow/Gold Nuzlocke seams. Silver is a declared beta target sharing the Gen 2 engine path with Gold; edition-specific parity remains runtime-test-required.",
              },
              ["0.2.12"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; sync/platform fixes retain Mod API 2, Save Format 4, exact-edition identity, and Nuzlocke's protected gameplay transaction seams.",
              },
              ["0.2.13"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited and runtime-booted profile; upstream gameplay/UI fixes retain Mod API 2 and Nuzlocke's protected rule/transaction seams. Nuzlocke package-source introspection is intentionally fail-soft on this engine family.",
              },
              ["0.2.14"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Current source-audited and exact-runtime-booted profile; the 0.2.13 to 0.2.14 delta is Android packaging and iOS app-repository metadata only, with no Nuzlocke-facing Mod API or Lua runtime contract change.",
              },
              ["0.2.15"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; launcher mod update/sync and presentation fixes retain Mod API 2, Save Format 4, and Nuzlocke gameplay transaction seams. Exact-runtime Nuzlocke smoke test remains required.",
              },
              ["0.2.16"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; adds shared battle.charge_required plus streamed required-import/install-cache support and substantial launcher/Gen2 fixes. Nuzlocke uses no required_imports, needs no manifest migration, and keeps its existing gameplay hooks; exact-runtime smoke test remains required.",
              },
              ["0.2.17"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; the 0.2.16 to 0.2.17 delta is Skin Studio/UI presentation only and does not change Mod API, Loader, battle, save, registry, hook, or Gen 2 compatibility contracts.",
              },
              ["0.2.18"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Historical source-audited profile; the 0.2.17 to 0.2.18 delta is touch-skin, launcher presentation, Playfield/Renderer, UI-kit viewport, and associated test work only. Nuzlocke-facing Mod API 2, Loader, battle, save, registry, hook, Gen 2, and required-import contracts are unchanged.",
              },
              ["0.2.19"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; the 17-commit 0.2.18 to 0.2.19 delta rewrites substantial Gen 2 battle/EXP and Bill's PC presentation/behavior while preserving Nuzlocke-owned doWithdraw/checkSpaceInDestination/askRelease semantic seams, and improves SaveData, Loader/Gen2Compat, inventory, overworld, and Gold/Silver import paths.",
              },
              ["0.2.20"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Source-audited profile; stronger in-process session teardown and Gold/Silver label-keyed ROM text require no Nuzlocke API/schema migration. Exact-edition runtime smoke remains required.",
              },
              ["0.2.21"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true },
                  note = "Historical source-audited profile; added mod.developer, isModOptions propagation, broader Gen2 translation/text support, field_residual (Gen1 only), lifecycle/Custom Cart/world-link additions, and the first upstream Crystal targeting groundwork.",
              },
              ["0.2.24"] = {
                  api = 2, save_format = 4,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Historical aggregate source/documentation audit through the 0.2.24-era line. Upstream now treats Crystal as a sixth playable edition and gen2 target; Nuzlocke intentionally opts Crystal in as ALPHA. New public seams include activeBlockAt/map.occupancy_allowed, battle.field_residual (Gen1 only), mod.developer, expanded Gen2 translation, Custom Carts and stronger in-process session lifecycle. Exact-edition runtime certification remains required.",
              },
              ["0.2.25"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Historical source/documentation audit. 0.2.25 preserves Mod API 2 and adds read-only mod.datasets imported-version views plus substantial Gen2 VM/battle/save/world work. Nuzlocke keeps active-game rule authority on mod.content, uses semantic Gen2 script/map identity for service and opening-clock gates, and treats datasets as a future read-only compatibility/randomizer data source rather than changing protected runtime transactions without certification.",
              },
              ["0.2.26"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Historical source-audited profile; Gen II native shiny.roll/mon.shiny and ROM-extracted palette ownership are retained alongside the existing Nuzlocke transaction seams. Crystal shiny presentation still requires the narrow send-out safety workaround and exact-edition runtime evidence.",
              },
              ["0.2.27"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Historical source/documentation-audited profile. Adds public R/B/Y catch.nickname and battle.style rule seams, palette-aware Gen II Chrome/UI infrastructure, revised battle presentation, launcher/input/platform work, and broad engine tests while retaining Mod API 2, Save Format 4, shiny.roll, protected Nuzlocke gameplay transactions, and the existing Gen II shiny-flash event. Shiny Pokemon 1.2.7 is the explicit external shiny target; Gen1Recomp alone owns COLORS-transition Renderer/Assets invalidation. Exact-edition runtime certification remains required.",
              },
              ["0.2.28"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source-audited compatibility profile. Relative to 0.2.27, upstream changes are confined to HostShell subprocess command construction plus iOS release metadata. No battle, Pokemon, mod-hook, Strings, Chrome, Gen-II gameplay, save, shiny, or registry seam used by Nuzlocke changed. Existing Nuzlocke gameplay integration remains valid; exact-edition runtime evidence is still independent.",
              },
              ["0.2.29"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Historical source-audited profile. Relative to 0.2.28, upstream changes are launcher/input/importer UI focused. Protected Nuzlocke seams remain available; upstream Save Format is 5.",
              },
              ["0.2.30"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source/documentation-audited profile. Broad Gen-I/Gen-II battle, UI, world and save parity work retains the protected Nuzlocke seams; exact-edition runtime smoke remains required.",
              },
              ["0.2.31"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source-identical release tag to 0.2.30; inherits its source/documentation audit and pending exact-edition runtime evidence.",
              },
              ["0.2.32"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source/documentation-audited profile. Gen-II save conversion is a future tooling opportunity. Public pokemon.level_visible is available for a future Gen-I Blind Levels/No Level Info feature and remains distinct from Randomizer BLIND INFO.",
              },
              ["0.2.33"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Historical source/documentation-audited profile. ONLINE arena intentionally disables ordinary content mods through disableAll/cartOnly; Nuzlocke does not bypass that policy. Ordinary modded or LAN link remains affects_link=true. Runtime smoke remains required.",
              },
              ["0.2.34"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source/documentation-audited profile on the 0.2.33-0.2.36 release line. Runtime certification remains edition-specific.",
              },
              ["0.2.35"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source/documentation-audited profile on the 0.2.33-0.2.36 release line. Runtime certification remains edition-specific.",
              },
              ["0.2.36"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Historical source/documentation-audited profile. Upstream 0.2.36 is published at fc56b9b05f01c559610c71f801355abfa4ae920f; ONLINE/tournament/remote-trade UI and lifecycle work did not grant Nuzlocke new gameplay ownership.",
              },
              ["0.2.37"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source/documentation-audited profile at release commit 16f30120f5839b05f7317c2ff457f55c7d85e58f. Launcher/save tooling expands, including Gen-II cartridge save import/export and launcher workflows; Mod API 2 and Save Format 5 remain stable. Nuzlocke does not claim ownership of launcher-side save conversion.",
              },
              ["0.2.38"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Current source/documentation/launcher-audited profile at release commit 73d004d47ecf7966c2546d8b475e7007038b29da. The launcher reads manifests without executing mod entry code, supports GitHub-backed mod update/version workflows, per-game targeting and compatibility status, and preserves the real loader as boot authority. Nuzlocke's manifest already declares api 2, game_version, category/profile, GitHub repo, six games, affects_link, and engine_internals permission consistently with this contract. Exact-edition runtime smoke remains required.",
              },
              ["0.2.39"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source/documentation-audited profile at release commit f90c3370e8c2a2116dbe31201af6adc2dea46471. The release adds cross-platform PresentSync/PresentProbe and refines VSync, FrameCap and FixedStep pacing. Presentation timing remains engine-owned and explicitly separate from deterministic fixed-step game logic. Mod API 2, Save Format 5, shared Gen-I/Gen-II mod vocabulary, provider/registry contracts and Nuzlocke-critical gameplay seams remain compatible by source review. Exact-edition runtime smoke remains required.",
              },
              ["0.2.40"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source/documentation-audited profile at release commit 0cf543d597ce84e4d847b2aba782f1bf2799fde0. Mod API 2 and Save Format 5 are unchanged. The release materially revises Gen-I and Gen-II battle presentation/timing plus Gen-II party-item/evolution stack and music restoration behavior while preserving the public mod vocabulary and loader contracts. Nuzlocke keeps engine timing engine-owned; exact-edition runtime revalidation is required for Gen-II party items/Rare Candy and focused battle flows.",
              },
              ["0.2.41"] = {
                  api = 2, save_format = 5,
                  generation = { gen1 = true, gold = true, crystal = true },
                  note = "Source-reviewed at release commit 3d3a9ba4b66832b8c70ac26e1e88dbae612efcd0. Mod API 2, Link Protocol 2, Save Format 5 and ROM cache v5 are unchanged. The 0.2.41 delta is dominated by platform/launcher work, presentation pacing hardening, and Gen-II save export map-context support. FixedStep/PresentSync remain engine-owned; Nuzlocke does not wrap or mutate them. No Nuzlocke-critical public mod contract break was found by source review; exact-edition runtime smoke remains required.",
              },
          },
          seams = {
              presentation_pacing = { generation = "all", module = "src.core.PresentSync",
                  member = "status", mode = "engine_owned_read_only",
                  note = "0.2.39 PresentSync/PresentProbe, VSync, FrameCap and FixedStep remain engine-owned. Nuzlocke may inspect status for diagnostics but never wraps or mutates pacing." },
              item_use = { generation = "gen1", module = "src.inventory.ItemEffects", member = "use", mode = "compose" },
              field_item_visible = { generation = "gen1", hook = "world.talk", mode = "compose",
                  note = "Random Field Items transform only native visible item-ball payloads and restore authored object data after the downstream call." },
              field_item_visible_gen2 = { generation = "gen2", module = "src.world.gen2.HiddenItems",
                  member = "ballPickupScript", mode = "compose" },
              battle_finish = { generation = "gen1", module = "src.battle.BattleState", member = "finish", mode = "compose" },
              gold_battle_finish = { generation = "gold", module = "src.ui.gen2.BattleState", member = "finishBattle", mode = "compose" },
              trainer_card = { generation = "gen1", module = "src.ui.TrainerCard", mode = "compose" },
              gold_trainer_card = { generation = "gold", module = "src.ui.gen2.TrainerCard", mode = "deprecated_for_nuz_status" },
              start_menu_items = { generation = "shared", hook = "ui.start_menu.items", mode = "compose" },
              pokemon_caught = { generation = "shared", event = "pokemon.caught", mode = "observe" },
              script_command = { generation = "shared", hook = "script.command", mode = "compose" },
              screens = { generation = "shared", registry = "screens", mode = "augment" },
              battle_snapshot = { generation = "shared", api = "mod.battle:snapshot", mode = "observe" },
              battle_intents = { generation = "shared", api = "mod.battle:submit", mode = "observe_only_by_nuzlocke" },
              contextual_field_actions = { generation = "shared", api = "mod.world:availableFieldActions/useFieldAction", mode = "transitive_native_guard" },
              item_use_dispatch = { generation = "gen1", hook = "item.use", mode = "available_not_authoritative" },
              gold_catch_rate = { generation = "gold", hook = "catch.rate", mode = "public_context_parity_0_2_0_plus" },
              battle_bottom_ui = { generation = "shared", hook = "battle.bottom_ui_visible", mode = "coexist" },
              battle_status_hud = { generation = "shared", hook = "battle.status_hud_visible", mode = "coexist" },
              battle_move_grid_navigation = { generation = "shared", hook = "battle.move_grid_navigation", mode = "available_not_owned" },
              battle_charge_required = { generation = "shared", hook = "battle.charge_required", mode = "available_not_owned_0_2_16_plus" },
              pokemon_level_visible = {
                  generation = "gen1", hook = "pokemon.level_visible",
                  mode = "available_not_owned_0_2_32_plus",
                  contexts = { "battle.enemy", "battle.player", "party", "summary" },
                  note = "Future Blind Levels/No Level Info opportunity; separate from Randomizer BLIND INFO.",
              },
          },
          online_arena = {
              since = "0.2.33", ordinary_content_mods = "disabled",
              loader_policies = { disableAll = true, cartOnly = true },
              bypass = false, ordinary_link_affects_link = true,
          },
          -- beta.27.5: ask Gen1Recomp's own Gen2Compat table what a private
          -- Gen 1 module/member really means on Gold. This is diagnostic and
          -- capability-reporting only; it does not auto-rewrite protected hooks.
          gen2 = {
              coverage = function(name)
                  local ok, compat = pcall(require, "src.mods.Gen2Compat")
                  if not ok or type(compat) ~= "table"
                      or type(compat.coverage) ~= "function" then
                      return nil
                  end
                  local row = compat.coverage(name)
                  if type(row) == "table" then
                      row.coverageVersion = compat.COVERAGE_VERSION
                  end
                  return row
              end,
              memberStatus = function(name, member)
                  local ok, compat = pcall(require, "src.mods.Gen2Compat")
                  if not ok or type(compat) ~= "table"
                      or type(compat.memberStatus) ~= "function" then
                      return nil
                  end
                  return compat.memberStatus(name, member)
              end,
              modules = function()
                  local ok, compat = pcall(require, "src.mods.Gen2Compat")
                  if not ok or type(compat) ~= "table"
                      or type(compat.modules) ~= "function" then
                      return {}
                  end
                  return compat.modules()
              end,
          },
          environments = {
              gameplay = { runtime_patches = true, save_bound = true },
              save_editor = {
                  runtime_patches = false,
                  save_bound = false,
                  note = "Editor loader is data/catalog-only for Nuzlocke; skip direct runtime monkey patches so editor closures cannot leak into gameplay.",
              },
          },
          state = {},
      },
      Mods = {
          supported_relationships = {
              compose = true,
              delegate = true,
              exclusive = true,
              observe = true,
              incompatible = true,
          },
          defaults = {
              level_caps = "delegate",
              postgame_caps = "delegate",
              escape = "delegate",
              encounters = "compose",
              npc_talk = "compose",
              npc_behavior = "compose",
              npc_visibility = "compose",
              npc_movement = "compose",
              wonder_trade = "observe",
              pokemon_identity = "delegate",
              species_metadata = "delegate",
              item_use = "compose",
              shopping = "compose",
              healing = "compose",
              battle_finish = "compose",
              trainer_card = "compose",
              party_menu = "compose",
              start_menu_items = "compose",
              screens = "compose",
              static_encounters = "compose",
              gambling = "compose",
              encounter_area_projection = "compose",
              trainer_party = "compose",
              boss_level_caps = "compose",
              battle_classification = "observe",
              movement_speed = "compose",
              starter_randomization = "compose",
              presentation = "compose",
              battle_stats = "delegate",
              stat_growth = "delegate",
              identity_dvs = "compose",
              move_category_model = "observe",
              species_evolutions = "compose",
          },
          relationships = {},
          -- Audited local adapters for mods that do not currently publish
          -- nuzlocke_compat metadata themselves. These are intentionally
          -- descriptive: they do not seize ownership of the other mod.
          adapters = {
              indigo_conference = {
                  tested = "1.1.0",
                  game = "GOLD",
                  trainer_party = "compose",
                  battle_finish = "compose",
                  healing = "compose_survivors",
                  battle_classification = "observe",
                  note = "IPC owns its Colosseum staging/CANLOSE/elimination flow and may heal living survivors; Nuzlocke retains death/rule ownership and its late post-battle prune keeps nuzlockeDead Pokemon unusable.",
              },
              kanto_ascendant = {
                  tested = "6.5.17",
                  games = "GEN1",
                  status = "explicit_conflict_do_not_combine",
                  defensive_composition_only = true,
                  note = "Kanto Ascendant 6.5.17 explicitly conflicts with standalone nuzlocke and includes its own ASC RUN Nuzlocke system. Nuzlocke no longer declares it as an optional dependency or claims supported coexistence. Historical defensive difficulty/presentation detection is retained only for a forced/legacy stack; it is not a compatibility certification.",
              },
              ["kanto-reforged"] = {
                  tested = "1.5.3",
                  games = "GEN1+GEN2",
                  trainer_party = "compose",
                  species_metadata = "compose",
                  move_category_model = "delegate_explicit_live",
                  held_items = "capability_compose",
                  level_caps = "co_owner_stricter",
                  encounters = "curated_compose_random_modes_delegate",
                  static_encounters = "source_provenance",
                  dungeons = "content_compose",
                  status_mechanics = "compose",
                  daycare = "deposit_guard_compose",
                  note = "Kanto Reforged 1.5.3 keeps ownership of expanded Gen-I/Gen-II content, abilities/weather, trainer redesign, encounter generation, and its optional candy-enabled soft cap. Nuzlocke composes challenge legality, uses the stricter active cap, delegates KR Full/Pure spawn randomization, recognizes KR fixed statics, exposes No Held Items on Gen1 while KR supplies held items, and registers restored Gold Viridian Forest through the dungeon-content contract.",
              },
              delta_type = {
                  tested = "1.2.0",
                  games = "GEN1+GOLD",
                  encounters = "compose",
                  species_metadata = "compose",
                  note = "Concrete mon.types is authoritative for Type Locke once Delta Type stamps a transformed wild; species metadata remains the fallback before a mon exists.",
              },
              dex_overflow = {
                  tested = "0.1.1",
                  games = "GOLD",
                  encounters = "compose",
                  species_metadata = "compose",
                  source_status = "legacy_reviewed_not_currently_resolved",
                  note = "Dex Overflow 0.1.1 remains a legacy reviewed target because the current public index/source surface did not resolve a newer/current package during the 2.8.97 audit. Indexless string-id species may participate in runtime encounter randomization only when their final merged Gold record is battle-safe; byte-addressed script/link paths remain outside this allowance. Generic expanded-species support should use the species_metadata/species_evolutions provider contracts rather than Dex Overflow-specific assumptions.",
              },
              safari_all = {
                  tested = "1.1.0",
                  games = "GEN1+GOLD",
                  encounters = "compose",
                  scoped = { encounters = "safari_or_national_park_delegate" },
                  source_status = "legacy_reviewed_not_currently_indexed",
                  note = "Safari All 1.1.0 remains a legacy reviewed target. It is not present in the current public mod-index snapshot, so 2.8.97 does not invent a newer version or new private seam. The retained contract is scoped: Safari All may own final species replacement only in Safari/National Park scope; Nuzlocke still evaluates the resulting encounter and never delegates global encounter legality merely because the mod is installed.",
              },
              wonder_trade = {
                  tested = "1.2.1",
                  games = "GEN1+GOLD",
                  wonder_trade = "observe",
                  acquisition_timing = "post_mutation_observe_only",
                  note = "Wonder Trade emits pokemon.received/trade.completed after swapping. Nuzlocke observes provenance only; Wonderlocke remains disabled until a safe pre-transaction cooperation seam exists. Post-mutation observation is not a safe veto/rollback seam.",
              },
              modern_party_ui = {
                  tested = "0.4.0",
                  games = "GEN1",
                  party_presentation = "external",
                  party_controller = "engine_owned",
                  party_target_items = "engine_owned",
                  forced_battle_switch = "engine_owned",
                  field_moves = "engine_owned",
                  held_items = "observe",
                  note = "Modern Party UI 0.4.0 explicitly keeps provider/native controllers intact while replacing Party/Summary/Naming/Relearn presentation. Nuzlocke must not infer gameplay ownership from that screen replacement: item/TM targeting, trades, forced battle switches and field moves remain controller-owned. Nuzlocke's Gen-II party routing is unaffected because this target is Gen-I only. Combined runtime certification remains required.",
              },
              HGSS_SPRITES = {
                  tested = "1.0.2",
                  games = "YELLOW",
                  presentation = "external",
                  overworld_render = "external",
                  party_presentation = "external_optional",
                  pc_presentation = "external_optional",
                  battle_art = "external",
                  trainer_party = "nuzlocke_or_engine_owned",
                  shiny_identity = "observe",
                  voxel_presentation = "compose",
                  note = "HGSS Visual Overhaul 1.0.2 is source-reviewed as a Yellow presentation target. Its PartyMenu/ListMenu and BattleState wrappers are presentation-scoped and chain the previously installed implementation. Nuzlocke retains trainer-party/randomizer authority, challenge legality, provenance, tracker state and gameplay transactions. Combined runtime certification is required, especially with Random Trainers, HGSS Party/PC presentation, Shiny, and one voxel renderer.",
              },
              hgss_sprites = { alias = "HGSS_SPRITES" },
              qol_toggles = {
                  tested = "1.30.8",
                  games = "GEN1+GEN2",
                  escape = "compose",
                  item_use = "compose",
                  healing = "compose",
                  shopping = "compose",
                  gambling = "compose",
                  movement_speed = "compose",
                  note = "QoL Toggles 1.30.8 option-aware adapter. Nuzlocke restrictions remain authoritative over convenience behavior; RUN (HOLD B) may own duplicate running QoL when enabled, and POISON SAVE cannot preempt a Nuzlocke Permadeath field-poison faint.",
              },
              ["vanilla-plus"] = {
                  tested = "0.3.0",
                  games = "GEN1",
                  encounters = "compose",
                  trainer_party = "compose",
                  healing = "compose_survivors",
                  movement_speed = "compose",
                  quest_content = "external",
                  note = "VanillaPlus 0.3.0 current source revalidated in 2.8.97. It owns quests/NPCs/maps, badge-scaled Rocket ambushes, captain pre-battle healing, and random post-battle rewards. Nuzlocke recognizes only its Bulbasaur Lv12 Viridian Forest, Squirtle Lv18 Route 25, and Charmander Lv12 Rock Tunnel B1F story captures as progression-required fixed sources; incidental ambushes and guardian Starmie receive no exception. Captain healing cannot revive a durable nuzlockeDead mon because Nuzlocke reasserts zero HP at battle start. Random rewards are acquisitions, not permission to use otherwise-banned items. Random Starter remains a warned semantic conflict because VanillaPlus branches from vanilla EVENT_CHOSE_* flags.",
              },
              ["the_world"] = {
                  tested = "6.54.15",
                  games = "GEN1+GEN2",
                  trainer_party = "compose",
                  boss_level_caps = "compose",
                  battle_classification = "observe",
                  species_metadata = "compose",
                  move_category_model = "observe",
                  encounters = "compose",
                  wonder_trade = "observe",
                  held_items = "compose",
                  healing = "compose_survivors",
                  acquisition_policy = "compose",
                  note = "The World 6.54.15 is a broad living-world/multi-region overhaul across Gen I and Gen II. It now embeds Wonder Trader, Kanto Reforged, Weather FX, AI Rivals, National Dex, GameShark, and Double Battles. Nuzlocke composes live trainer parties, merged species facts, challenge legality, and provider-owned encounter policy without guessing hidden package state. The embedded Wonder Trader remains observe-only unless a safe pre-transaction cooperation seam is exposed.",
              },
              ["the-world"] = { alias = "the_world" },
              SHINY_POKEMON = {
                  tested = "Stone fork 1.2.41",
                  games = "GEN1+GEN2",
                  shiny_identity = "compose",
                  shiny_generation = "external",
                  presentation = "external",
                  palette_transition = "engine_owned",
                  note = "Explicit maintained-fork shiny-provider target through 1.2.41. Prefer the public provider/API surfaces and consume Shiny's own Nuzlocke integration validation when available; retain the inherited direct-export probe for legacy builds. Shiny 1.2.41 preserves API v1 identity/presentation ownership while adding provider lifecycle fingerprints, exact-edition/provider certification, capability-first engine selection, seam classification, voxel/provider ownership and cross-project audit freshness. When active, SHINY_POKEMON owns shiny generation/presentation for the edition and Nuzlocke becomes a rules/tracker consumer only. Gen1Recomp exclusively owns renderer/resource invalidation during COLORS transitions; Nuzlocke never flushes engine Assets/Renderer state for shiny palette changes.",
              },
              shiny_pokemon = { alias = "SHINY_POKEMON" },
              PokePCFollowers_VoxelMerge = {
                  tested = "0.5.1",
                  games = "GEN1",
                  presentation = "external",
                  follower_identity = "observe",
                  note = "Explicit shared Shiny-ecosystem target. PokéPC Followers owns follower sprite selection/render presentation on Red/Blue/Yellow. Nuzlocke observes ordinary party/Pokémon identity only and does not replace follower rendering, sprite resolution, or movement ownership. Combination runtime certification remains separate.",
              },
              FOLLOWERS_EX = {
                  tested = "1.0.19",
                  games = "GEN1",
                  presentation = "external",
                  follower_identity = "observe",
                  overworld_encounters = "compose",
                  note = "Explicit shared Shiny-ecosystem target. Followers EX owns trainer/Pokémon control, pack/trailer presentation and its Wilds/PokéPC follower composition. Nuzlocke retains encounter legality, provenance and challenge policy and does not take follower-render/control ownership. Combination runtime certification remains separate.",
              },
              DRAMATIC_SHAPE = {
                  tested = "1.9.0",
                  games = "GEN1",
                  presentation = "external",
                  overworld_render = "external",
                  battle_classification = "observe",
                  note = "Reviewed maintained DRAMATIC_SHAPE continuation at scottcandy34/DramaticShapeVoxelMod-latest. Dramatic Shape owns its 3D diorama/voxel rendering pipeline and presentation hotkeys. It is treated as its own mutually exclusive renderer identity rather than as an alias for Battle Art, Dramaless, PotatoVoxel, Terrarium, or Voxel Ascendant. Nuzlocke retains challenge semantics, encounter/capture legality, progression, tracker state and gameplay transactions. Native generation-specific battle presentation remains engine/provider-owned. Gen-II Runtime PASS is not implied. Background/prebuild work is treated as render-data work, not map traversal or encounter progression.",
              },
              dramatic_shape = { alias = "DRAMATIC_SHAPE" },
              potato_voxel = {
                  tested = "1.9.6",
                  games = "GEN1+GEN2",
                  presentation = "compose",
                  screens = "compose",
                  battle_classification = "observe",
                  note = "PotatoVoxel owns voxel world/battle presentation and may wrap native battle drawing or the Gen2BattleState screen. Nuzlocke keeps challenge state/actions, does not own render.compose or Gen2BattleState, and composes through native/public gameplay seams. Cache prebuild is treated as render-data work, not map traversal or encounter progression.",
              },
              BATTLE_ART_VOXEL_FORK = {
                  tested = "1.10.0", games = "GEN1",
                  presentation = "external", shiny_source = "provider_owned_battle_art",
                  shiny_identity = "observe",
                  note = "Reviewed Battle Art Voxel Fork 1.10.0. Battle Art is an independent renderer/presentation owner and explicitly conflicts with the other mutually exclusive voxel-renderer identities. Nuzlocke retains challenge semantics and must not second-recolor provider-owned art.",
              },
              VOXEL_ASCENDANT = {
                  tested = "2.0.2", games = "GEN1",
                  presentation = "external", shiny_source = "provider_owned",
                  shiny_identity = "observe",
                  note = "Shiny 1.2.41 reviewed provider. Establish shiny identity before source creation, then yield renderer/source ownership.",
              },
              TERRARIUM = {
                  tested = "1.27.0-mobile", games = "GEN1+GEN2",
                  presentation = "external", shiny_source = "provider_owned",
                  shiny_identity = "observe",
                  note = "Shiny 1.2.41 reviewed Gen-I/Gen-II provider. Terrarium owns live billboard/voxel source presentation; Nuzlocke avoids a second bake.",
              },
              DRAMALESS_SHAPE = {
                  tested = "2.0.3", games = "GEN1",
                  presentation = "external", shiny_source = "provider_owned",
                  shiny_identity = "observe",
                  note = "Shiny 1.2.41 reviewed legacy voxel provider; Nuzlocke yields provider-owned render state.",
              },
              BATTLE_CINEMATICS = {
                  tested = "1.2.4", games = "GEN1+GEN2",
                  presentation = "external", battle_camera = "external",
                  shiny_identity = "observe",
                  note = "Reviewed Battle Cinematics 1.2.4. Camera/director ownership remains external, including its provider-aware composition with live voxel arenas and secondary views. Renderer/environment ownership remains with the selected voxel or Stadium provider; Nuzlocke observes presentation and retains challenge semantics.",
              },
              VOXEL_3D_POKEDEX = {
                  tested = "1.0.0", games = "GEN1+GEN2",
                  presentation = "external", pokedex_models = "external",
                  shiny_identity = "observe",
                  note = "Shiny 1.2.41 coexistence target. 3D Pokedex/model presentation remains external.",
              },
              FLYING_OVERHAUL = {
                  tested = "1.2.1", games = "GEN1+GEN2",
                  movement = "external", presentation = "external",
                  shiny_identity = "observe",
                  note = "Shiny 1.2.41 coexistence target. Movement/camera stays external.",
              },
              KANTO_DYNAMIC_WEATHER = {
                  tested = "1.0.3", games = "GEN1",
                  presentation = "external", environment_fx = "external",
                  shiny_identity = "observe",
                  note = "Shiny 1.2.41 coexistence target. Weather/post-processing remains external.",
              },
              DRAMATIC_SKY_RIDE = {
                  tested = "0.2.18", games = "GEN1",
                  movement = "external", presentation = "external",
                  shiny_identity = "observe",
                  note = "Shiny 1.2.41 composite ride coexistence target; support composes through reviewed dependencies.",
              },
              level_match = {
                  tested = "0.7.0",
                  games = "GEN2",
                  trainer_party = "compose_by_dimension",
                  trainer_species = "nuzlocke_when_random_trainers_enabled",
                  trainer_levels = "external_compose",
                  trainer_moves = "external_compose",
                  trainer_party_size = "external_compose",
                  wild_species = "compose",
                  wild_levels = "external_compose",
                  roamers = "external_persistent_level",
                  note = "Level Match 0.7.0 scales Gen-II trainer and wild levels, may rebuild trainer moves/evolutions and pad boss teams, and may persistently raise roamer levels. Nuzlocke Random Trainers consumes the composed incoming trainer.party and changes only species identity while preserving the incoming roster cardinality, levels and trainer-safe state; it must not reconstruct vanilla party size or levels after a legitimate external transform. Level Caps should observe the effective composed ace where available. Combined runtime certification is required for Random Trainers, caps, padded bosses, wild scaling and roamers.",
              },
              modern_start_menu_ui = {
                  tested = "0.1.14",
                  games = "GEN1+GEN2",
                  start_menu_presentation = "external",
                  start_menu_items = "compose",
                  semantic_ids = "nuzlocke_owned_rows",
                  note = "Modern Start Menu UI 0.1.14 consumes the final ui.start_menu.items result and preserves engine/mod callbacks. Nuzlocke owns only its semantic START action and supplies a stable id so presentation/localization mods never need to recognize the rendered label. No dependency or bilateral detection is required. Combined runtime certification is required on Gen I and Gen II.",
              },
              ["gen1-better-menus"] = {
                  tested = "1.0.32",
                  games = "GEN1",
                  presentation = "compose",
                  screens = "compose",
                  options_marker = "isModOptions",
                  note = "Gen1BetterMenus 1.0.32 owns widescreen presentation for shared engine UI classes. Nuzlocke keeps gameplay legality outside replacement UI and marks its semantic options/configuration screens with the dependency-free isModOptions=true contract. Nuzlocke does not detect or require Gen1BetterMenus for that marker. Combination runtime TEST REQUIRED.",
              },
              next_encounter_spawner = {
                  tested = "1.2.2",
                  games = "GEN2",
                  encounters = "compose",
                  encounter_transform = "external_intentional_final_candidate",
                  shiny_identity = "observe",
                  note = "Gold Next Encounter Spawner 1.2.2 intentionally replaces the next wild/sweet-scent encounter candidate through encounter.species after ordinary encounter resolution and consumes one-shot state only after battle.started confirms a wild battle. Nuzlocke Random Encounters remains a registry projection and must not repaint the intentionally selected final candidate; catch/acquisition legality evaluates the actual final species encountered. Runtime certification is required for Gold/Silver/Crystal, one-shot/repeat/cancel, shiny identity, Random Encounters, Colorlocke/Alphabetlocke/Type Locke/Dupes and provenance.",
              },
              pokeball_colors = {
                  tested = "0.1.33",
                  games = "GEN1+GEN2",
                  presentation = "external",
                  ball_presentation = "external",
                  catch_legality = "nuzlocke",
                  note = "Pokeball Colors 0.1.33 owns Poké Ball toss/heal-machine coloration and explicitly arbitrates ball-art ownership with other presentation mods. Nuzlocke owns catch/ball legality only and must not infer legality from ball palette/artwork or claim ball-presentation ownership. No dedicated dependency/API is required because Nuzlocke does not color balls. Combination runtime TEST REQUIRED.",
              },
              quality_of_life = {
                  tested = "1.3.0",
                  games = "GEN1+GOLD",
                  field_moves = "compose",
                  item_use = "compose",
                  presentation = "compose",
                  note = "Easy Interactions remains external QoL. Gen1 shortcut entry is conservatively suppressed while Travel Restrictions or Dungeon Lock-In are active; Gold stays on native field-move permission paths. Repels continue through Nuzlocke item policy/native Gold refusal paths.",
              },
              useful_bag = { tested = "2.6.3", games = "GEN1", inventory_storage = "compose", bag_presentation = "external", item_use = "native", note = "Canonical inventory remains save.inventory/Bag.order; pockets/capacity/presentation are external while native item controllers retain use semantics." },
              modern_bag_ui = { tested = "0.4.5", games = "GEN1", inventory_storage = "compose", bag_presentation = "external", item_use = "native", note = "Owns Bag/PC presentation and expanded capacity; current docs preserve native owning controllers for item use, party targeting, battle turns and TMs/HMs." },
              bag_sort = { tested = "0.1.0", games = "GEN1", inventory_order = "external", item_use = "native", note = "Order-only compatibility target; sorting never grants gameplay ownership." },
              double_battles = {
                  tested = "0.6.1",
                  games = "GEN1+GEN2",
                  encounters = "compose",
                  trainer_party = "compose",
                  battle_finish = "compose",
                  battle_classification = "observe",
                  party_menu = "compose",
                  item_use = "compose",
                  note = "Double Battles 0.6.1 owns its multi-battler turn loop, target selection, partner/refill state, and double-battle presentation. Nuzlocke retains challenge legality, durable death/permadeath state, catch/ball/item restrictions, encounter provenance, and post-battle history. The mod publishes isDoubleBattle plus partner/ally/veto seams; 2.9.26 records the ownership boundary without taking over its private turn loop. Combined Gen-I/Gen-II runtime certification is required, especially catches, switching, item denial, faint/death handling, whiteout, trainer completion, and Random Trainers composition.",
              },
              blackjack_corner = {
                  tested = "0.8.2",
                  games = "GEN1",
                  acquisition_policy = "compose",
                  economy = "compose",
                  shiny_identity = "compose",
                  trainer_party = "compose",
                  world_building = "compose",
                  note = "Blackjack Corner 0.8.2 is a high-overlap Game Corner/content target: starters and prize Pokemon/items, casino economy, shiny presentation/provider composition, trainer content, and progression/world presentation remain externally owned. Nuzlocke retains challenge legality and provenance where cooperative pre-transaction seams are used; post-mutation observations never justify destructive rollback. Source/Compatibility Reviewed; combined runtime certification required.",
              },
              free_fly = {
                  tested = "1.8.0",
                  games = "GEN1+GEN2",
                  party_menu = "compose",
                  movement_speed = "compose",
                  encounters = "compose",
                  pokemon_identity = "compose",
                  acquisition_policy = "compose",
                  note = "Free Fly 1.8.0 owns airborne movement, landing/story/badge gates, FREEFLY party action, aerial interception, and flight lifecycle. Nuzlocke must not infer ordinary route traversal or encounter consumption merely from airborne movement. Its optional quick-start gift remains an acquisition subject to Nuzlocke gift/species/provenance policy where a safe acquisition event is observable; no destructive rollback is allowed. Free Fly exposes isFlying/altitude/mount and takeoff/landed events, which are observational seams rather than Nuzlocke movement ownership. Combined Gen-I/Gen-II runtime certification is required for lock-ins/travel restrictions, field-move legality, aerial encounters, blackout/permadeath, and the quick-start gift.",
              },
              ["g9-battle-engine"] = {
                  tested = "1.2.3", games = "GEN2", battle_stats = "exclusive", stat_growth = "exclusive", identity_dvs = "compose", species_metadata = "compose", species_evolutions = "compose", move_category_model = "observe", battle_lifecycle = "observe", held_items = "observe", battle_status = "observe",
                  note = "Published G9 Battle Engine 1.2.3 is an experimental Gen-II battle framework. It owns modern IV/EV/Nature battle-stat growth; native DVs remain meaningful for identity traits. Modern moves/abilities/weather/double battles/held items widen battle lifecycle risk, so Nuzlocke observes those surfaces rather than claiming an unproven private integration contract.",
              },
              ["g9-battle-engine-beta"] = {
                  tested = "2.0.2", games = "GEN2", battle_stats = "exclusive", stat_growth = "exclusive", identity_dvs = "compose", species_metadata = "compose", species_evolutions = "compose", move_category_model = "observe", battle_lifecycle = "observe", held_items = "observe", battle_status = "observe",
                  note = "Current Gen9Dex source identifies its combat-only development line as g9-battle-engine-beta 2.0.2. It depends on national_dex and owns the modern combat pipeline while excluding sprites/overworld/followers. Treat it as the same modern-stat ownership family but as a separate mod id; battle lifecycle compatibility remains TEST REQUIRED.",
              },
          },
          discovered = {},
      },
  }

  -- 2.3.0: report only supported public engine facades. This is diagnostic;
  -- Nuzlocke enforcement continues to use its established veto/event seams.
  mod.exports.__beta26.enginePublicFeatures = function()
      local battle = mod.battle
      local world = mod.world
      return {
          battle_snapshot = type(battle) == "table"
              and type(battle.snapshot) == "function" or false,
          battle_submit = type(battle) == "table"
              and type(battle.submit) == "function" or false,
          contextual_field_actions = type(world) == "table"
              and type(world.availableFieldActions) == "function"
              and type(world.useFieldAction) == "function" or false,
      }
  end

  -- Normalize only declarative metadata. Discovery never executes another
  -- mod's callbacks simply to decide whether we can coexist.
  mod.exports.__beta26.compat.Mods.normalizeRelationship = function(value)
      if type(value) == "table" then
          value = value.relationship or value.mode or value.policy
      end
      local key = tostring(value or ""):lower()
      if mod.exports.__beta26.compat.Mods.supported_relationships[key] then
          return key
      end
      return nil
  end

  mod.exports.__beta26.compat.Mods.inspectRelationship = function(exports, capability)
      -- 2.5.63: malformed/partial compatibility metadata must never turn a
      -- maintenance action into a table[nil] exception. A missing capability
      -- has no ownership claim, so compose is the safe neutral relationship.
      if capability == nil then return "compose", "missing_capability" end
      local layer = type(exports) == "table" and exports.nuzlocke_compat or nil
      if type(layer) ~= "table" and type(exports) == "table" then
          layer = exports.compat
      end
      if type(layer) == "table" then
          local rels = layer.relationships or layer.compatibility_relationships
          local declared = type(rels) == "table" and rels[capability] or nil
          if declared == nil and type(rels) == "table" and type(rels.defaults) == "table" then
              declared = rels.defaults[capability]
          end
          if declared == nil and type(rels) == "table" and type(rels.capabilities) == "table" then
              declared = rels.capabilities[capability]
          end
          local relation = mod.exports.__beta26.compat.Mods.normalizeRelationship(declared)
          if relation then return relation, "declared" end

          local ownership = layer.ownership
          if type(ownership) == "table" and ownership[capability] ~= nil then
              relation = mod.exports.__beta26.compat.Mods.normalizeRelationship(ownership[capability])
              if relation then return relation, "ownership" end
              if ownership[capability] == true then return "exclusive", "ownership" end
          end

          local cooperation = layer.cooperation
          local allows = type(cooperation) == "table" and cooperation.allows_wrapping or nil
          if type(allows) == "table" then
              for _, allowed in ipairs(allows) do
                  if tostring(allowed) == tostring(capability) then
                      return "compose", "allows_wrapping"
                  end
              end
          end
      end

      -- Backward-compatible provider metadata also participates in the new
      -- relationship report. This honors the pre-v11 `exclusive = true`
      -- convention without requiring another mod to adopt our exact table shape.
      if type(exports) == "table" then
          local providers = exports.nuzlocke_provider
          local provider = type(providers) == "table" and providers[capability]
              or exports[capability]
          if type(provider) == "table" then
              local relation = mod.exports.__beta26.compat.Mods.normalizeRelationship(
                  provider.relationship or provider.mode or provider.policy)
              if relation then return relation, "provider" end
              if provider.exclusive == true then return "exclusive", "provider" end
          end
      end
      return mod.exports.__beta26.compat.Mods.defaults[capability] or "compose", "default"
  end

  mod.exports.__beta26.compat.Mods.relationshipFor = function(modId, capability)
      -- 2.5.64: partial provider metadata may omit either side of the lookup.
      -- Missing ownership metadata is neutral compose, never a table-key write/read
      -- assumption that maintenance UI can trip over.
      if modId == nil or capability == nil then return "compose" end
      local rows = mod.exports.__beta26.compat.Mods.relationships[modId]
      return type(rows) == "table" and rows[capability]
          or mod.exports.__beta26.compat.Mods.defaults[capability]
          or "compose"
  end

  -- 2.8.39: compatibility fallback inventory.  These rows are diagnostic
  -- only; retaining a fallback never makes it authoritative over a newer
  -- public seam.  Removal requires raising the supported engine/provider
  -- floor or proving the legacy consumer is unreachable.
  mod.exports.__beta26.compat.Mods.fallbacks = {
      { id="catch_nickname_legacy", preferred="catch.nickname",
        fallback="battle.nickname + naming-screen enforcement",
        required_for="Gen1Recomp 0.2.24-0.2.26", status="retained" },
      { id="shiny_direct_exports", preferred="provider registry / shiny_compat API",
        fallback="direct isShiny/rollShiny exports",
        required_for="older Shiny Pokemon builds", status="retained" },
      { id="legacy_provider_metadata", preferred="public Interop provider registry",
        fallback="nuzlocke_provider / compatibility relationship metadata",
        required_for="pre-registry compatibility providers", status="retained" },
      { id="automatic_legacy_adapters", preferred="explicit provider registration",
        fallback="capability inference adapters",
        required_for="supported mods without provider registration", status="retained" },
  }

  mod.exports.__beta26.compat.Mods.fallbackInventory = function()
      return compatPublicCopy(mod.exports.__beta26.compat.Mods.fallbacks)
  end

  -- 2.9.40: compatibility evidence classification is diagnostic metadata,
  -- never ownership authority. A live contract proves only that another loaded
  -- mod publishes a cooperation surface; source review proves only that the
  -- recorded adapter was reviewed; combined-runtime-required means coexistence
  -- still needs exact-edition stack evidence before Runtime PASS.
  local COMPAT_EVIDENCE_CLASSES = {
      live_contract = true,
      source_reviewed = true,
      combined_runtime_required = true,
  }

  local function compatibilityEvidenceFor(id, discoveredRow)
      local adapters = mod.exports.__beta26.compat.Mods.adapters or {}
      local adapter = adapters[id]
      if type(adapter) == "table" and type(adapter.alias) == "string" then
          adapter = adapters[adapter.alias] or adapter
      end
      local evidence = {}
      if type(discoveredRow) == "table" and discoveredRow.has_compat_layer == true then
          evidence.live_contract = true
      end
      if type(adapter) == "table" then
          evidence.source_reviewed = true
          local status = tostring(adapter.status or "")
          if status ~= "explicit_conflict_do_not_combine" then
              evidence.combined_runtime_required = true
          end
      end
      return evidence
  end

  mod.exports.__beta26.compatibilityEvidenceReport = function()
      local mods = mod.exports.__beta26.compat.Mods
      local report = { api = 1, classes = compatPublicCopy(COMPAT_EVIDENCE_CLASSES), rows = {} }
      local seen = {}
      for id, adapter in pairs(mods.adapters or {}) do
          local canonical = id
          if type(adapter) == "table" and type(adapter.alias) == "string" then
              canonical = adapter.alias
          end
          if not seen[canonical] then
              seen[canonical] = true
              report.rows[canonical] = {
                  evidence = compatibilityEvidenceFor(canonical, (mods.discovered or {})[canonical]),
                  discovered = (mods.discovered or {})[canonical] ~= nil,
              }
          end
      end
      for id, discovered in pairs(mods.discovered or {}) do
          if not report.rows[id] then
              report.rows[id] = { evidence = compatibilityEvidenceFor(id, discovered), discovered = true }
          else
              report.rows[id].discovered = true
              report.rows[id].evidence = compatibilityEvidenceFor(id, discovered)
          end
      end
      return compatPublicCopy(report)
  end

  mod.exports.__beta26.compat.Mods.report = function()
      return {
          supported_relationships = compatPublicCopy(
              mod.exports.__beta26.compat.Mods.supported_relationships),
          defaults = compatPublicCopy(mod.exports.__beta26.compat.Mods.defaults),
          relationships = compatPublicCopy(
              mod.exports.__beta26.compat.Mods.relationships),
          discovered = compatPublicCopy(mod.exports.__beta26.compat.Mods.discovered),
          evidence = mod.exports.__beta26.compatibilityEvidenceReport(),
          stack_warnings = compatPublicCopy(mod.exports.__beta26.compat.Mods.stack_warnings or {}),
          fallbacks = mod.exports.__beta26.compat.Mods.fallbackInventory(),
      }
  end

  local function providerValue(exports, capability)
      if type(exports) ~= "table" or capability == nil then return nil end
      local providers = exports.nuzlocke_provider
      if type(providers) == "table" and providers[capability] ~= nil then return providers[capability] end
      return exports[capability]
  end

  H.providerIsActive = function(provider, game, battle)
      if not provider then return false end
      if type(provider) == "table" then
          if provider.enabled == false or provider.active == false
              or provider.disabled == true then return false end
      end
      if type(provider) == "table" and type(provider.is_active) == "function" then
          local ok, result = mod.exports.__beta26.Dev.pguard(
              "provider_is_active", provider.is_active, game, battle)
          return ok and result == true
      end
      return true
  end

  local function refreshPublicCompatSnapshots()
      local public = mod.exports.nuzlocke_compat
      if type(public) ~= "table" then return end
      public.engine_compat = compatPublicCopy(mod.exports.__beta26.compat.Engine)
      public.mod_compat = compatPublicCopy(mod.exports.__beta26.compat.Mods)
      public.relationships = {
          supported = compatPublicCopy(mod.exports.__beta26.compat.Mods.supported_relationships),
          defaults = compatPublicCopy(mod.exports.__beta26.compat.Mods.defaults),
      }
  end

  local function compatIdentityToken(value)
      if value == nil then return "nil" end
      return tostring(value)
  end

  local function compatProviderFingerprint(other, value)
      if type(other) ~= "table" then return nil end
      return table.concat({
          compatIdentityToken(other), compatIdentityToken(other.exports),
          compatIdentityToken(value),
          compatIdentityToken(other.registration or other.registered),
          compatIdentityToken(other.hooks or other.spriteHooks or other.renderHooks),
          tostring(other.version or ""),
      }, "|")
  end

  local function shinyIntegrationValidation(other)
      if type(other) ~= "table" or type(other.exports) ~= "table" then return nil end
      local api = other.exports.shiny_pokemon or other.exports.shiny_compat
      local integrations = type(api) == "table" and api.integrations or nil
      if type(integrations) ~= "table" or type(integrations.validate) ~= "function" then
          return { available=false, status="legacy_or_unavailable", compatible=nil }
      end
      local ok, result = pcall(integrations.validate, "nuzlocke")
      if not ok or type(result) ~= "table" then
          return { available=true, status="degraded", compatible=false,
              reason=ok and "invalid_validation_result" or tostring(result) }
      end
      return { available=true, schema=integrations.schema, status=result.status,
          compatible=result.compatible, reason=result.reason }
  end

  local SHINY_AUDIT_FRESHNESS = {
      target="SHINY_POKEMON", reviewed_version="1.2.41",
      reviewed_release_date="2026-08-29", evidence="source_reviewed_cross_project",
      runtime_certified=false, compatibility_relevant_release_metadata=true,
  }
  mod.exports.__beta26.shinyAuditFreshness = function()
      local out = {}
      for k,v in pairs(SHINY_AUDIT_FRESHNESS) do out[k]=v end
      return out
  end

  local COMPAT_SEAM_REGISTRY = {
      { id="shiny_provider_registry", kind="provider", owner="compatibility",
        surface="nuzlocke.interop.getProvider", public=true },
      { id="shiny_api", kind="provider", owner="SHINY_POKEMON",
        surface="exports.shiny_pokemon/exports.shiny_compat", public=true },
      { id="shiny_roll", kind="public_hook", owner="engine",
        surface="shiny.roll", public=true },
      { id="pokemon_sprite", kind="public_hook", owner="engine",
        surface="pokemon.sprite", public=true },
      { id="pokemon_icon", kind="public_hook", owner="engine",
        surface="pokemon.icon", public=true },
      { id="battle_overlay", kind="public_hook", owner="engine",
        surface="battle.overlay", public=true },
      { id="gen2_shiny_flash_queue", kind="direct_bounded", owner="engine",
        surface="src.ui.gen2.BattleState.advanceQueue",
        public=false, reason="No equivalent public seam currently exposes safe removal of only the broken shiny-flash presentation event." },
      { id="palettefx_read", kind="direct_readonly", owner="engine",
        surface="src.render.PaletteFX", public=false,
        reason="Read-only palette signature input; renderer/resource invalidation remains engine-owned." },
  }
  mod.exports.__beta26.compatSeamRegistry = function()
      local out = {}
      for i,row in ipairs(COMPAT_SEAM_REGISTRY) do
          local copy = {}
          for k,v in pairs(row) do copy[k]=v end
          out[i]=copy
      end
      return out
  end

  local SHINY_PROVIDER_SOURCE_IDS = {
      BATTLE_ART_VOXEL_FORK=true, VOXEL_ASCENDANT=true, TERRARIUM=true,
      DRAMATIC_SHAPE=true, DRAMALESS_SHAPE=true, potato_voxel=true,
  }
  mod.exports.__beta26.shinyPresentationSourcePolicy = function(ctx)
      if type(ctx) ~= "table" then return "nuzlocke_owned_or_engine" end
      if ctx.providerOwnedSource == true or ctx.provider_owned_source == true
          or ctx.voxelProviderOwned == true then
          return "provider_owned"
      end
      local providerId = tostring(ctx.providerId or ctx.provider_id or ctx.rendererProvider or "")
      if providerId ~= "" and SHINY_PROVIDER_SOURCE_IDS[providerId] then
          return "provider_owned"
      end
      return "nuzlocke_owned_or_engine"
  end

  -- 2.9.60: Gen1Recomp 0.2.39 presentation pacing is engine-owned.
  -- This diagnostic is deliberately read-only: no FrameCap/VSync/FixedStep
  -- writes, no present waits, no reprobe/reset calls.
  mod.exports.__beta26.presentSyncStatus = function()
      local ok, PresentSync = pcall(require, "src.core.PresentSync")
      if not ok or type(PresentSync) ~= "table" or type(PresentSync.status) ~= "function" then
          return { available=false, audited="0.2.39", ownership="engine" }
      end
      local okStatus, status = pcall(PresentSync.status)
      local out = { available=okStatus and type(status)=="table",
          audited="0.2.39", ownership="engine", read_only=true }
      if okStatus and type(status)=="table" then
          for _, key in ipairs({ "driver", "nest", "gamescope", "gated",
              "strategy", "needsSoftwareCap", "probeCount" }) do
              out[key] = status[key]
          end
      end
      return out
  end

  H.discoverCompatProviders = function(loader)
      for _, capability in ipairs(COMPAT_CAPABILITIES) do
          COMPAT_PROVIDERS[capability] = nil
          COMPAT_PROVIDER_CANDIDATES[capability] = {}
      end
      mod.exports.__beta26.compat.Mods.relationships = {}
      mod.exports.__beta26.compat.Mods.discovered = {}
      mod.exports.__beta26.compat.Mods.stack_warnings = {}
      if not loader or type(loader.status) ~= "function" then
          refreshPublicCompatSnapshots()
          return
      end
      local ok, status = mod.exports.__beta26.Dev.pguard(
          "compat_loader_status", function() return loader:status() end)
      if not ok or type(status) ~= "table" or type(status.loaded) ~= "table" then
          refreshPublicCompatSnapshots()
          return
      end
      for _, manifest in ipairs(status.loaded) do
          local id = manifest and manifest.id
          if id and id ~= "nuzlocke" then
              local foundOk, other = mod.exports.__beta26.Dev.pguard(
                  "compat_find:" .. tostring(id), mod.find, id)
              if foundOk and other and other.exports then
                  local compatLayer = type(other.exports.nuzlocke_compat) == "table"
                      and other.exports.nuzlocke_compat
                      or (type(other.exports.compat) == "table" and other.exports.compat or nil)
                  mod.exports.__beta26.compat.Mods.discovered[id] = {
                      version = other.version or (manifest and manifest.version),
                      compat_api = compatLayer and compatLayer.version or nil,
                      has_compat_layer = compatLayer ~= nil,
                      handle_identity = compatIdentityToken(other),
                      exports_identity = compatIdentityToken(other.exports),
                      registration_identity = compatIdentityToken(other.registration or other.registered),
                      hook_identity = compatIdentityToken(other.hooks or other.spriteHooks or other.renderHooks),
                  }
                  local upperId = tostring(id):upper()
                  if upperId == "SHINY_POKEMON" or tostring(id):lower() == "shiny_pokemon"
                      or tostring(id):lower() == "gen1recomp_shiny_pokemon" then
                      mod.exports.__beta26.compat.Mods.discovered[id].integration_validation =
                          shinyIntegrationValidation(other)
                      mod.exports.__beta26.compat.Mods.discovered[id].audit_freshness =
                          SHINY_AUDIT_FRESHNESS
                  end
                  mod.exports.__beta26.compat.Mods.relationships[id] = {}
                  local adapter = mod.exports.__beta26.compat.Mods.adapters[id]
                  if type(adapter) == "table" and type(adapter.alias) == "string" then
                      adapter = mod.exports.__beta26.compat.Mods.adapters[adapter.alias] or adapter
                  end
                  -- 2.6.46: The World release packaging may expose a manifest
                  -- id variant while keeping the human-readable name stable.
                  -- Match the exact display name rather than guessing at its
                  -- internal systems; this only selects descriptive relationship
                  -- metadata and never invokes hidden mod code.
                  if type(adapter) ~= "table" and manifest then
                      local display = tostring(manifest.name or ""):upper():gsub("[^A-Z0-9]", "")
                      if display == "THEWORLD" then
                          adapter = mod.exports.__beta26.compat.Mods.adapters.the_world
                      end
                  end
                  if type(adapter) == "table" then
                      mod.exports.__beta26.compat.Mods.discovered[id].adapter = true
                      mod.exports.__beta26.compat.Mods.discovered[id].adapter_tested = adapter.tested
                      mod.exports.__beta26.compat.Mods.discovered[id].adapter_note = adapter.note
                      mod.exports.__beta26.compat.Mods.discovered[id].adapter_scoped = adapter.scoped
                  end
                  mod.exports.__beta26.compat.Mods.discovered[id].evidence =
                      compatibilityEvidenceFor(id, mod.exports.__beta26.compat.Mods.discovered[id])
                  for _, capability in ipairs(COMPAT_CAPABILITIES) do
                      local relationship, source = mod.exports.__beta26.compat.Mods.inspectRelationship(
                          other.exports, capability)
                      if source == "default" and type(adapter) == "table" then
                          local adapted = mod.exports.__beta26.compat.Mods.normalizeRelationship(
                              adapter[capability])
                          if adapted then
                              relationship, source = adapted, "adapter"
                          end
                      end
                      mod.exports.__beta26.compat.Mods.relationships[id][capability] = relationship
                      if relationship ~= "incompatible" then
                          local value = providerValue(other.exports, capability)
                          if value ~= nil then
                              local candidate = {
                                  id=id, version=other.version, value=value,
                                  relationship=relationship, source=source,
                                  fingerprint=compatProviderFingerprint(other, value),
                                  handle_identity=compatIdentityToken(other),
                                  exports_identity=compatIdentityToken(other.exports),
                                  registration_identity=compatIdentityToken(other.registration or other.registered),
                                  hook_identity=compatIdentityToken(other.hooks or other.spriteHooks or other.renderHooks),
                              }
                              local list = COMPAT_PROVIDER_CANDIDATES[capability]
                              list[#list + 1] = candidate
                              if not COMPAT_PROVIDERS[capability] then
                                  COMPAT_PROVIDERS[capability] = candidate
                              end
                          end
                      end
                  end
              end
          end
      end
      -- 2.8.97: current The World embeds its own Wonder Trader and declares
      -- standalone wonder_trade a conflict. Diagnostics only: do not disable
      -- either mod or infer gameplay ownership from installation alone.
      local discovered = mod.exports.__beta26.compat.Mods.discovered or {}
      local worldInstalled = discovered.the_world or discovered["the-world"]
      if not worldInstalled then
          for id, row in pairs(discovered) do
              local okFind, other = pcall(mod.find, id)
              local name = okFind and type(other) == "table"
                  and (other.name or (other.manifest and other.manifest.name)) or nil
              if tostring(name or ""):upper():gsub("[^A-Z0-9]", "") == "THEWORLD" then
                  worldInstalled = row
                  break
              end
          end
      end
      if worldInstalled and discovered.wonder_trade then
          local warnings = mod.exports.__beta26.compat.Mods.stack_warnings
          warnings[#warnings + 1] = {
              code = "THE_WORLD_STANDALONE_WONDER_TRADE",
              severity = "warning",
              mods = { "The World", "wonder_trade" },
              message = "The World 6.54.15 embeds Wonder Trader and declares standalone Wonder Trade conflicting; use one Wonder Trader implementation at a time.",
          }
      end
      local ascendantInstalled = discovered.kanto_ascendant or discovered["kanto-ascendant"] or discovered.kantoascendant
      if ascendantInstalled then
          local warnings = mod.exports.__beta26.compat.Mods.stack_warnings
          warnings[#warnings + 1] = {
              code = "KANTO_ASCENDANT_STANDALONE_NUZLOCKE",
              severity = "warning",
              mods = { "Kanto Ascendant", "nuzlocke" },
              message = "Kanto Ascendant 6.5.17 explicitly conflicts with standalone Nuzlocke and includes ASC RUN; this forced stack is unsupported.",
          }
      end
      refreshPublicCompatSnapshots()
  end

  local function firstMatchingCandidate(candidates, predicate)
      if type(predicate) ~= "function" then return nil, nil end
      for _, row in ipairs(type(candidates) == "table" and candidates or {}) do
          local matched = predicate(row)
          if matched then return row, matched end
      end
      return nil, nil
  end

  mod.exports.__beta26.compatAutoProviderSelectionAudit = function()
      local rows = {
          { id="inactive_first", active=false },
          { id="active_second", active=true },
      }
      local selected = firstMatchingCandidate(rows, function(row)
          return type(row) == "table" and row.active == true
      end)
      return {
          ok = type(selected) == "table" and selected.id == "active_second",
          selected = selected and selected.id or nil,
          contract = "AUTO selects first live candidate, not first advertised candidate",
      }
  end

  local function activeCompatProvider(capability, game, battle)
      if capability == nil then return nil end
      capability = tostring(capability)
      local preference = compatOwnerPreference(capability)
      -- Explicit Nuzlocke/Engine ownership means do not delegate this
      -- capability. The caller's native path remains authoritative.
      if preference == "nuzlocke" or preference == "engine" then return nil end
      local provider = nil
      local candidates = COMPAT_PROVIDER_CANDIDATES[capability] or {}
      if preference ~= "auto" then
          for _, row in ipairs(candidates) do
              if tostring(row.id) == preference then provider = row break end
          end
          if not provider then
              setCompatOwnerPreference(capability, "auto")
              preference = "auto"
          end
      end
      local function liveCandidate(row)
          if type(row) ~= "table" then return nil end
          local ok, other = mod.exports.__beta26.Dev.pguard(
              "provider_find:" .. tostring(row.id), mod.find, row.id)
          if not ok or not other or not other.exports then return nil end
          local value = providerValue(other.exports, capability)
          if value == nil or not H.providerIsActive(value, game, battle) then
              return nil
          end
          local liveFingerprint = compatProviderFingerprint(other, value)
          row.evidence_stale = row.fingerprint ~= nil and liveFingerprint ~= nil
              and row.fingerprint ~= liveFingerprint
          row.fingerprint = liveFingerprint
          row.value = value
          row.version = other.version
          row.handle_identity = compatIdentityToken(other)
          row.exports_identity = compatIdentityToken(other.exports)
          row.registration_identity = compatIdentityToken(other.registration or other.registered)
          row.hook_identity = compatIdentityToken(other.hooks or other.spriteHooks or other.renderHooks)
          return row
      end

      if provider then
          local live = liveCandidate(provider)
          if live then return live end
          if preference ~= "auto" then
              setCompatOwnerPreference(capability, "auto")
              preference = "auto"
          end
      end

      if preference == "auto" then
          local _, live = firstMatchingCandidate(candidates, function(row)
              return liveCandidate(row)
          end)
          return live
      end
      return nil
  end

  -- 2.8.39: one diagnostic vocabulary for contract-backed providers.
  -- Detection, advertisement and actual selection are intentionally distinct
  -- so MOD COMPAT can explain why Nuzlocke uses its native path even when a
  -- compatible mod is installed. This never invokes provider mechanic callbacks.
  mod.exports.__beta26.compat.Mods.capabilityStatus = function(capability, game, battle)
      capability = tostring(capability or "")
      local preference = compatOwnerPreference(capability)
      local candidates = COMPAT_PROVIDER_CANDIDATES[capability] or {}
      local selected = activeCompatProvider(capability, game, battle)
      local rows = {}
      for _, candidate in ipairs(candidates) do
          rows[#rows + 1] = {
              id = candidate.id, version = candidate.version,
              relationship = candidate.relationship, source = candidate.source,
              advertised = true,
          }
      end
      local state = "nuzlocke_fallback"
      local degraded = false
      if preference == "nuzlocke" or preference == "engine" then
          state = "native_selected"
      elseif selected then
          state = "external_selected"
      elseif #rows > 0 then
          state = "detected_not_active"
          degraded = preference ~= "auto"
      end
      return {
          capability = capability, preference = preference,
          detected = #rows > 0, advertised = #rows > 0,
          candidate_count = #rows, candidates = rows,
          selected = selected and { id=selected.id, version=selected.version,
              relationship=selected.relationship, source=selected.source } or nil,
          state = state, degraded = degraded,
      }
  end

  mod.exports.__beta26.compatOwnerPreference = compatOwnerPreference
  mod.exports.__beta26.setCompatOwnerPreference = setCompatOwnerPreference
  mod.exports.__beta26.compatOwnerChoices = function(capability, nativeOwner)
      capability = tostring(capability or "")
      local out = {
          { id="auto", name="AUTO" },
          { id=(nativeOwner == "Engine" and "engine" or "nuzlocke"),
            name=tostring(nativeOwner or "Nuzlocke") },
      }
      local seen = { auto=true, engine=nativeOwner == "Engine", nuzlocke=nativeOwner ~= "Engine" }
      for _, provider in ipairs(COMPAT_PROVIDER_CANDIDATES[capability] or {}) do
          local id = tostring(provider.id or "")
          if id ~= "" and not seen[id] then
              local displayName = id
              local okFind, other = pcall(mod.find, id)
              if okFind and type(other) == "table" then
                  displayName = tostring(other.name
                      or (other.manifest and other.manifest.name) or id)
              end
              out[#out + 1] = { id=id, name=displayName,
                  version=provider.version }
              seen[id] = true
          end
      end
      return out
  end

  local function providerContext(provider, game, battle)
      local value=provider and provider.value
      if type(value)~="table" or type(value.get_context)~="function" then return nil end
      local ok, context = mod.exports.__beta26.Dev.pguard(
          "provider_context", value.get_context, game, battle)
      return ok and type(context)=="table" and context or nil
  end

  H.providerRecover = function(provider, save, mon)
      local value=provider and provider.value
      if type(value)~="table" or type(value.recover)~="function" then return nil end
      local ok, result = mod.exports.__beta26.Dev.pguard(
          "provider_recover", value.recover, save, mon)
      return ok and type(result)=="table" and result or nil
  end

  -- 2.4.34: internal mechanics-capability resolver. This deliberately
  -- starts as a read-only/private layer so we can prove capability semantics
  -- with real mods before bumping the public compatibility API. A local
  -- adapter may describe an installed mod even when that mod does not export
  -- our provider vocabulary.
  mod.exports.__beta26.mechanicsCapability = function(capability, game)
      local provider = activeCompatProvider(capability, game, nil)
      if provider then
          return { supplied=true, id=provider.id, version=provider.version,
              relationship=mod.exports.__beta26.compat.Mods.relationshipFor(
                  provider.id, capability), source=provider.source or "provider" }
      end
      for id, adapter in pairs(mod.exports.__beta26.compat.Mods.adapters or {}) do
          if type(adapter) == "table" and type(adapter.alias) == "string" then
              adapter = mod.exports.__beta26.compat.Mods.adapters[adapter.alias] or adapter
          end
          local declared = type(adapter) == "table" and adapter[capability] or nil
          if declared ~= nil then
              local okFind, other = pcall(mod.find, id)
              if okFind and type(other) == "table" then
                  local goldOnly = adapter.games == "GOLD" or adapter.game == "GOLD"
                  if not goldOnly or mod.exports.__beta26.runtimeIsGen2(game or deps.currentGame() or mod.game) then
                      return { supplied=true, id=id, name=other.name or (other.manifest and other.manifest.name),
                          version=other.version or (other.manifest and other.manifest.version),
                          relationship=mod.exports.__beta26.compat.Mods.normalizeRelationship(declared) or tostring(declared),
                          source="adapter" }
                  end
              end
          end
      end
      return { supplied=false }
  end

  mod.exports.__beta26.findTheWorld = function()
      for _, id in ipairs({"the_world", "the-world", "world"}) do
          local ok, other = pcall(mod.find, id)
          if ok and type(other) == "table" then return other, id end
      end
      local liveGame = deps.currentGame()
      local loader = liveGame and liveGame.mods
      if loader and type(loader.status) == "function" then
          local ok, status = pcall(loader.status, loader)
          if ok and type(status) == "table" then
              for _, manifest in ipairs(status.loaded or {}) do
                  local display = tostring(manifest and manifest.name or ""):upper():gsub("[^A-Z0-9]", "")
                  if display == "THEWORLD" and manifest.id then
                      local okFind, other = pcall(mod.find, manifest.id)
                      if okFind and type(other) == "table" then return other, manifest.id end
                  end
              end
          end
      end
      return nil
  end

  -- Providers can explicitly declare a mechanic exclusive. The default is
  -- composable: touching the same engine subsystem is not the same thing as
  -- owning the Nuzlocke behavior. Mods may modify or observe NPC systems
  -- without owning the Gym Guide or Nuzlocke encounter rules.
  local function providerExclusive(capability, game, battle)
      local provider = activeCompatProvider(capability, game, battle)
      local value = provider and provider.value
      if not provider then return false end
      local relationship = mod.exports.__beta26.compat.Mods.relationshipFor(provider.id, capability)
      return relationship == "exclusive"
          or (type(value) == "table" and value.exclusive == true)
  end

  -- The engine's talk registry can tell us whether a callable talk entry came
  -- from a mod. This is safer than guessing from a mod name or description,
  -- and uses the registry provenance metadata rather than guessing from names.
  -- Instruction-list entries are data and are safe to inspect; third-party
  -- closures are code and must never be executed merely for compatibility or
  -- migration analysis.
  local function talkEntryIsExternal(mapId, textId, entry)
      if type(entry) ~= "function" then return false end
      if not (mapId and textId) then return false end
      local ok, MapScripts = pcall(require, "src.script.MapScripts")
      if not ok or type(MapScripts) ~= "table"
          or type(MapScripts.talkSource) ~= "function" then
          return false
      end
      local okSource, source = pcall(MapScripts.talkSource, mapId, textId)
      return okSource and type(source) == "table" and source.modId ~= nil
  end

  -- Trainer-ness is a property of the map object, never of the sprite. This
  -- prevents mods that reuse trainer sprites for ordinary civilians from being
  -- mistaken for battles or trainer-owned NPCs.
  local function isTrainerDefinition(def)
      if type(def) ~= "table" then return false end
      return def.trainerClass ~= nil
          or def.trainerParty ~= nil
          or def.trainer ~= nil
  end

  mod.exports.__beta26.compatCapabilityVersions = {}
  for _, capability in ipairs(COMPAT_CAPABILITIES or {}) do
      mod.exports.__beta26.compatCapabilityVersions[capability] = 1
  end

  -- 2.6.92: publish the historical Beta.26 compatibility wording as an
  -- explicit read-only alias for older cooperating mods. __beta26 remains the
  -- internal implementation namespace; consumers should prefer nuzlocke_compat.
  mod.exports.mod_Compat = mod.exports.mod_Compat or {}
  mod.exports.mod_Compat.Beta_26 = mod.exports.mod_Compat.Beta_26 or {}
  mod.exports.mod_Compat.Beta_26.tag = "mod_Compat Beta_26"
  mod.exports.mod_Compat.Beta_26.namespace = "__beta26"
  mod.exports.mod_Compat.Beta_26.relationships = compatPublicCopy(mod.exports.__beta26.compat.Mods)

  mod.exports.nuzlocke_compat = {
      version = mod.exports.__beta26.compatibilityApi,
      compatible_from = 10,
      legacy_compat = {
          tag = "mod_Compat Beta_26",
          namespace = "__beta26",
          status = "supported_alias",
          note = "Historical Beta.26 wording/namespace alias; prefer nuzlocke_compat capability/provider contracts for new integrations.",
      },
      audited_recomp = mod.exports.__beta26.recompCompatAudited,
      runtime_environment = mod.exports.__beta26.runtimeEnvironment(),
      save_editor = {
          detection = "package.loaded.App:getState",
          runtime_patches = false,
          contract = "Nuzlocke runtime monkey patches are not installed by the Save Editor ModLoader; gameplay rebinds them in the gameplay loader session.",
      },
      gold = {
          status_surface = "start_menu_screen",
          status_screen_id = "NuzlockeGoldStatusScreen",
          native_trainer_card_preserved = true,
          catch_observer = "pokemon.caught",
          gift_transaction_hook = "script.command",
          forced_nickname = "native_starter_plus_deferred_gifts",
          field_item_use_rules = "native_policy_gate_test_required",
          battle_item_rules = "shared_item_policy_exposed_test_required",
          healing_service_rules = "shared_service_policy_exposed_test_required",
          parity_surface = "2.4.79",
      },
      capabilities = compatPublicCopy(COMPAT_CAPABILITIES),
      -- API 28 introduces per-capability contract versions. Existing API-27
      -- capability names/meanings remain compatible, while consumers can now
      -- negotiate one compatibility surface at a time. Future capability
      -- revisions can advance an individual entry without forcing unrelated
      -- consumers to treat every compatibility surface as new.
      capability_versions = (function()
          local out = {}
          for key, value in pairs(mod.exports.__beta26.compatCapabilityVersions) do
              out[key] = value
          end
          return out
      end)(),
      getCapabilityVersion = function(capability)
          local key = tostring(capability or ""):lower():gsub("[^a-z0-9]+", "_")
              :gsub("^_+", ""):gsub("_+$", "")
          return mod.exports.__beta26.compatCapabilityVersions[key]
      end,
      getEngineProfile = function(version)
          local engine = mod.exports.__beta26.compat and mod.exports.__beta26.compat.Engine
          local profiles = engine and engine.profiles or {}
          local key = tostring(version or (engine and engine.active_profile) or "")
          local row = profiles[key]
          return row and compatPublicCopy(row) or nil
      end,
      getCompatibilitySummary = function()
          local engine = mod.exports.__beta26.compat and mod.exports.__beta26.compat.Engine
          return {
              version = mod.exports.__beta26.compatibilityApi,
              compatible_from = 10,
              audited_recomp = mod.exports.__beta26.recompCompatAudited,
              active_engine_profile = engine and engine.active_profile or nil,
              engine_profile = engine and engine.profiles
                  and compatPublicCopy(engine.profiles[engine.active_profile]) or nil,
              capability_versions = compatPublicCopy(mod.exports.__beta26.compatCapabilityVersions),
          }
      end,
      internal_mechanics_capabilities = { version = 1, public_registration = false },
      engine_compat = compatPublicCopy(mod.exports.__beta26.compat.Engine),
      mod_compat = compatPublicCopy(mod.exports.__beta26.compat.Mods),
      relationships = {
          supported = compatPublicCopy(mod.exports.__beta26.compat.Mods.supported_relationships),
          defaults = compatPublicCopy(mod.exports.__beta26.compat.Mods.defaults),
      },
      cooperation = {
          -- We are intentionally chain-friendly on these shared seams. Mods
          -- wrapping them should call their previous/next implementation rather
          -- than replacing it silently.
          allows_wrapping = {
              "item_use", "shopping", "healing", "battle_finish",
              "trainer_card", "party_menu", "npc_talk", "encounters",
              "start_menu_items", "screens", "warp.destination",
              "fieldmove.eligibility", "trainer.party", "exp.gain",
          },
          requires_next = {
              "item_use", "shopping", "healing", "battle_finish",
              "trainer_card", "party_menu", "npc_talk",
              "start_menu_items",
          },
          silent_overwrite = false,
      },
      ownership = {
          encounter_tracking = true,
          nuz_info = true,
          encounter_area_projection = true,
          static_encounter_policy = true,
          game_corner_policy = true,
          gym_guide_rare_candy = true,
          pokemon_fields = {
              "nuzlockeId", "nuzlockeDead", "nuzlockeOrigin",
              "nuzlockeEncounterType", "nuzlockeEncounterSource",
              "nuzlockeEncounterMapId",
              "nuzlockeEncounterProvider", "nuzlockeEncounterProviderVersion",
              "nuzlockeEncounterContext", "nuzlockeExternalIdentity",
              "nuzlockeIdentityProvider", "nuzlockeIdentityDuplicateOf",
              "nuzlockeNeedsNickname", "nuzlockeNicknameRequired",
              "nuzlockeInvalidAcquisition", "nuzlockeTrackerRegistered",
              "nuzlockeRivalForgiven", "nuzlockeBankedExp",
              "nuzlockeDifficultyProfile", "nuzlockeDifficultyAI",
              "nuzlockeDifficultyStatExp", "nuzlockeDifficultyPerfectIV",
              "nuzlockeGlitch", "nuzlockeMissingNo", "nuzlockeRawSpecies",
              "nuzlockeWonderTradeOrigin", "nuzlockeWorldCapNotified",
              "deathLocation", "deathCause", "deathCauseText",
              "deathEncounterType", "deathOpponentSpecies", "deathMove",
              "deathCritical", "deathStatusCondition",
          },
      },
      wonderlocke = {
          status = "WIP",
          enabled = false,
          capability = "wonder_trade",
          contract = "Reserved for future Wonderlocke integration. This beta does not consume, replace, remove, block, or otherwise alter Wonder Trade transactions.",
      },
      battle_classifier = {
          api = 1,
          capability = "battle_classification",
          contract = "Read-only, generation-neutral classification. It inspects battle provenance and never changes rule state, encounter slots, parties, or story flow.",
      },
      pokemon_identity = {
          capability = "pokemon_identity",
          contract = "Optional provider for mods that recreate/extend Pokemon objects. Expose get_id(mon, game), get_identity(mon, game), or get_pokemon_id(mon, game) and return a stable string/number for the same Pokemon across saves/evolution.",
      },
      species_metadata = {
          capability = "species_metadata",
          contract = "Optional provider for merged species classification and BST. Expose get_metadata(game, species), metadata(game, species), or get_species_metadata(game, species); return legendary/mythical flags and optionally bst/baseStats metadata.",
      },
      getSpeciesBST = function(game, species)
          return mod.exports.__beta26.getSpeciesBST(game, species)
      end,
      getMaximumBST = function()
          return mod.exports.__beta26.getMaximumBST()
      end,
      getGlitchSpeciesInfo = function(game, species)
          return mod.exports.__beta26.getGlitchSpeciesInfo(game, species)
      end,
      isGlitchSpecies = function(game, species)
          return mod.exports.__beta26.getGlitchSpeciesInfo(game, species).isGlitch
      end,
      isRivalBattle = function(battle)
          return mod.exports.__beta26.isRivalBattle(battle)
      end,
      isFirstRivalForgivenessActive = function(game, battle)
          return mod.exports.__beta26.isFirstRivalForgivenessActive(game, battle)
      end,
      isStaticEncounter = function(game, battle)
          return mod.exports.__beta26.isStaticEncounter(game, battle)
      end,
      classifyBattle = function(game, battle, species)
          if type(mod.exports.__beta26.classifyBattle) ~= "function" then
              return { api = 1, kind = "unknown", flags = { unknown = true } }
          end
          return mod.exports.__beta26.classifyBattle(game, battle, species)
      end,
      canGamble = function(game)
          return not mod.exports.__beta26.ruleActive(game, "no_gambling")
      end,
      isActive = function(game, battle)
          local activeFn = deps.getActive()
          if type(activeFn) ~= "function" then return false end
          return activeFn(game or deps.currentGame() or mod.game, battle)
      end,
      isRuleActive = function(game, key, battle)
          return mod.exports.__beta26.ruleActive(game or deps.currentGame() or mod.game,
              key, battle)
      end,
      getRuleValue = function(key, fallback)
          return mod.save:get(key, fallback)
      end,
      getEffectiveRuleValue = function(key, fallback)
          if key == "random_species_generation"
              and type(mod.exports.__beta26.effectiveRandomSpeciesGeneration) == "function" then
              return mod.exports.__beta26.effectiveRandomSpeciesGeneration()
          end
          if key == "random_learnset_generation"
              and type(mod.exports.__beta26.effectiveRandomLearnsetGeneration) == "function" then
              return mod.exports.__beta26.effectiveRandomLearnsetGeneration()
          end
          local defaultResolver = deps.getDefaultRuleValue()
          if fallback == nil and type(defaultResolver) == "function" then
              fallback = defaultResolver(key)
          end
          return mod.save:get(key, fallback)
      end,
      getMigrationWarnings = function()
          local warnings = {}
          if mod.save:get("no_catching_legacy_ambiguous_29313", false) == true then
              warnings[#warnings + 1] = {
                  id = "no_catching_legacy_ambiguous_29313",
                  rule = "no_catching",
                  message = "Legacy Ball-ban migration may have enabled No Catching. Review the rule; it was not changed automatically because explicit player intent cannot be distinguished safely.",
              }
          end
          return warnings
      end,
      getTypeLockAllowedTypes = function()
          local out = {}
          for i, value in ipairs(mod.exports.__beta26.typeLockAllowedTypes()) do
              out[i] = value
          end
          return out
      end,
      typeLockAllowsSpecies = function(game, species)
          return mod.exports.__beta26.typeLockAllowsSpecies(game, species)
      end,
      typeLockAllowsPokemon = function(game, mon)
          return mod.exports.__beta26.typeLockAllowsPokemon(game, mon)
      end,
      getForgivenessTokens = function()
          return type(mod.exports.__beta26.forgivenessTokens) == "function"
              and mod.exports.__beta26.forgivenessTokens() or 0
      end,
      projectEncounterArea = function(mapId, safari, x, y, width, height)
          return mod.exports.__beta26.projectEncounterArea(
              mapId, safari, x, y, width, height)
      end,
      getEncounterSplitModes = function()
          -- `routes` is retained as a compatibility field but the old blanket
          -- Route 1-25 cardinal mode is retired. The three named route flags
          -- are now independently selectable.
          return {
              routes = 0,
              route_2 = mod.exports.__beta26.routeSplitActive("route_2_split") and 1 or 0,
              route_10 = mod.exports.__beta26.routeSplitActive("route_10_split") and 1 or 0,
              route_20 = mod.exports.__beta26.routeSplitActive("route_20_split") and 1 or 0,
              mt_moon = math.max(0, math.min(1,
                  math.floor(tonumber(mod.save:get("mt_moon_splits", 0)) or 0))),
              safari = type(mod.exports.__beta26.safariClauseMode) == "function"
                  and mod.exports.__beta26.safariClauseMode()
                  or math.max(0, math.min(3, math.floor(tonumber(
                      mod.save:get("safari_zone_splits", 0)) or 0))),
              gold_time = mod.save:get("gold_time_split", false) == true and 1 or 0,
              gold_headbutt = mod.save:get("gold_headbutt_split", false) == true and 1 or 0,
          }
      end,
      canCapture = function(game, battle, species)
          local catchPolicy = deps.getCatchDeniedReason()
          if type(catchPolicy) ~= "function" then return true end
          local okPolicy, reason = pcall(catchPolicy, game, battle, species)
          if not okPolicy then
              mod.exports.__beta26.lastAcquisitionPolicyError =
                  "public_can_capture: " .. tostring(reason)
              return false, "policy_error", { error = tostring(reason) }
          end
          if reason == "bst" then
              return false, reason, {
                  bst = mod.exports.__beta26.getSpeciesBST(game, species),
                  maximum = mod.exports.__beta26.getMaximumBST(),
              }
          elseif reason == "glitch" then
              return false, reason,
                  mod.exports.__beta26.getGlitchSpeciesInfo(game, species)
          end
          return reason == nil, reason
      end,
      -- Wonderlocke remains a visible WIP placeholder only. Keep the capability
      -- name reserved so future provider work can resume without interfering with
      -- installed Wonder Trade mods today.
   -- These helpers are intentionally behavioral rather than name based.
      -- Other mods may use them to decide whether a Nuzlocke feature should
      -- compose with their own NPC systems.
      isTrainerDefinition = isTrainerDefinition,
      talkEntryIsExternal = talkEntryIsExternal,

      -- API 27: read-only presentation data so party-menu/summary mods can
      -- compose with NUZ INFO without scraping screen internals.
      getNuzInfoPages = function()
          local out = {}
          if mod.save:get("catch_info", true) == true then out[#out + 1] = "catch" end
          if mod.save:get("stat_info", true) == true then out[#out + 1] = "stat" end
          if mod.save:get("move_info", true) == true then out[#out + 1] = "move" end
          return out
      end,
      getPokemonNuzInfo = function(game, mon)
          if type(mon) ~= "table" then return nil end
          game = game or deps.currentGame() or mod.game
          local stats, dvs, statExp = {}, {}, {}
          for k, v in pairs(type(mon.stats) == "table" and mon.stats or {}) do
              stats[k] = v
          end
          for k, v in pairs(type(mon.dvs) == "table" and mon.dvs or {}) do
              dvs[k] = v
          end
          for k, v in pairs(type(mon.statExp) == "table" and mon.statExp or {}) do
              statExp[k] = v
          end
          local moves = {}
          for i, move in ipairs(type(mon.moves) == "table" and mon.moves or {}) do
              local id = type(move) == "table" and move.id or move
              local def = game and game.data and game.data.moves
                  and game.data.moves[id] or nil
              moves[i] = {
                  id = id,
                  name = def and def.name or tostring(id or "?"),
                  type = def and def.type or nil,
                  power = def and def.power or nil,
                  accuracy = def and def.accuracy or nil,
                  pp = type(move) == "table" and move.pp or nil,
                  maxPp = (type(move) == "table" and move.maxPp)
                      or (def and def.pp) or nil,
              }
          end
          local compat21 = mod.exports.__beta26.compat21
          local legality, provenance
          if compat21 and type(compat21.pokemonLegality) == "function" then
              local ok, value = pcall(compat21.pokemonLegality, game, mon)
              if ok then legality = value end
          end
          if compat21 and type(compat21.pokemonProvenance) == "function" then
              local ok, value = pcall(compat21.pokemonProvenance, game, mon)
              if ok then provenance = value end
          end
          -- 2.3.27: this public API is defined before the later local
          -- Identity module enters lexical scope. Calling Identity.isShiny
          -- here therefore resolved a nil global and forced ordinary R/B/Y
          -- NUZ INFO into DETAIL SAFE MODE. Keep this early read-only model
          -- self-contained instead of depending on the later module.
          local shiny = false
          if type(mon.isShiny) == "boolean" then
              shiny = mon.isShiny
          elseif type(mon.shiny) == "boolean" then
              shiny = mon.shiny
          elseif type(mon.is_shiny) == "boolean" then
              shiny = mon.is_shiny
          elseif type(mon.dvs) == "table" then
              local Stats = mod.exports.__beta26.getStatsModule
                  and mod.exports.__beta26.getStatsModule() or nil
              if Stats and type(Stats.isShiny) == "function" then
                  local okShiny, shinyValue = pcall(Stats.isShiny, mon.dvs)
                  if okShiny then shiny = shinyValue == true end
              end
          end
          return {
              catch = {
                  location = mon.catchLocation,
                  encounterType = mon.encounterType
                      or mon.nuzlockeEncounterType,
                  origin = mon.nuzlockeOrigin,
                  dead = mon.nuzlockeDead == true,
                  shiny = shiny,
                  cause = mon.deathCauseText or mon.deathCause,
                  legality = legality,
                  provenance = provenance,
              },
              stats = {
                  level = mon.level,
                  hp = mon.hp,
                  maxHp = mon.maxHp or (mon.stats and mon.stats.hp),
                  values = stats,
                  dvs = dvs,
                  statExp = statExp,
              },
              moves = moves,
          }
      end,

      getCompatibilityReport = function()
          local versions = {}
          for key, value in pairs(mod.exports.__beta26.compatCapabilityVersions or {}) do
              versions[key] = value
          end
          return {
              api = mod.exports.__beta26.compatibilityApi,
              compatible_from = 10,
              capability_versions = versions,
              environment = mod.exports.__beta26.runtimeEnvironment(),
              audited_recomp = mod.exports.__beta26.recompCompatAudited,
              engine = compatPublicCopy(mod.exports.__beta26.compat.Engine),
              engine_features = mod.exports.__beta26.enginePublicFeatures(),
              mods = mod.exports.__beta26.compat.Mods.report(),
              fallbacks = mod.exports.__beta26.compat.Mods.fallbackInventory(),
          }
      end,
      getCapabilityStatus = function(capability, game, battle)
          return compatPublicCopy(
              mod.exports.__beta26.compat.Mods.capabilityStatus(
                  capability, game, battle))
      end,
      getModRelationship = function(modId, capability)
          return mod.exports.__beta26.compat.Mods.relationshipFor(modId, capability)
      end,
      getGen2Coverage = function(moduleName)
          return mod.exports.__beta26.compat.Engine.gen2.coverage(moduleName)
      end,
      getGen2MemberStatus = function(moduleName, member)
          return mod.exports.__beta26.compat.Engine.gen2.memberStatus(moduleName, member)
      end,
  }
  -- Machine-readable ownership declaration for compatibility-aware mods.
  -- Keep it as the same table exposed inside nuzlocke_compat so the two
  -- contracts cannot drift.
  -- Public compatibility metadata must never alias the mutable tables used by
  -- Nuzlocke's own provider/relationship resolver.  Consumers are free to
  -- annotate their local snapshots without changing enforcement ownership.
  mod.exports.nuzlocke_compat.ownership =
      compatPublicCopy(mod.exports.nuzlocke_compat.ownership)
  mod.exports.owns = compatPublicCopy(mod.exports.nuzlocke_compat.ownership)

  mod.events:on("mods.loaded", function(ev)
      H.discoverCompatProviders(ev and ev.loader)
      -- Dynamic trainer.party observations belong to the active composition,
      -- not the save. Clear them whenever the loader rebuilds the mod set so
      -- disabling or replacing a trainer overhaul cannot leave stale caps.
      if mod.exports.__beta26.levelCapBosses then
          mod.exports.__beta26.levelCapBosses.observed = {}
      end
  end)


  return {
      COMPAT_CAPABILITIES = COMPAT_CAPABILITIES,
      providerValue = providerValue,
      refreshPublicCompatSnapshots = refreshPublicCompatSnapshots,
      activeCompatProvider = activeCompatProvider,
      providerContext = providerContext,
      providerExclusive = providerExclusive,
      isTrainerDefinition = isTrainerDefinition,
  }
end
