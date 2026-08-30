-- Module owner: ItemPolicy
-- Shared item-use legality, denial presentation, and engine/field-item guard installation.
-- Economy policy, battle orchestration, and unrelated challenge enforcement remain external.
return function(mod, deps)
  deps = type(deps) == "table" and deps or {}
  local Strings = assert(deps.Strings, "ItemPolicy requires Strings")
  local getCurrentGame = assert(deps.getCurrentGame, "ItemPolicy requires getCurrentGame")
  local getCurrentSave = assert(deps.getCurrentSave, "ItemPolicy requires getCurrentSave")
  local worldTier = assert(deps.worldTier, "ItemPolicy requires worldTier")
  local levelCapScope = assert(deps.levelCapScope, "ItemPolicy requires levelCapScope")
  local nextLevelCap = assert(deps.nextLevelCap, "ItemPolicy requires nextLevelCap")
  local refreshPublicCompatSnapshots = assert(deps.refreshPublicCompatSnapshots, "ItemPolicy requires refreshPublicCompatSnapshots")
  local function currentGameValue() return getCurrentGame() end
  local function currentSaveValue() return getCurrentSave() end
  local ItemPolicy
  local evaluateItemUsePolicy

  ItemPolicy = {
      fieldHealing = {
          POTION = true, SUPER_POTION = true, HYPER_POTION = true,
          MAX_POTION = true, FULL_RESTORE = true,
          REVIVE = true, MAX_REVIVE = true,
          ANTIDOTE = true, BURN_HEAL = true, ICE_HEAL = true,
          AWAKENING = true, PARLYZ_HEAL = true, PARALYZE_HEAL = true,
          FULL_HEAL = true,
          FRESH_WATER = true, SODA_POP = true, LEMONADE = true,
          MOOMOO_MILK = true,
          BERRY_JUICE = true, RAGECANDYBAR = true,
          -- Gold's medicine, herb, whole-party Sacred Ash, and held-Berry healing families.
          SACRED_ASH = true,
          ENERGYPOWDER = true, ENERGY_ROOT = true, HEAL_POWDER = true,
          REVIVAL_HERB = true,
          BERRY = true, GOLD_BERRY = true,
          BITTER_BERRY = true, MINT_BERRY = true,
          PRZCUREBERRY = true, PSNCUREBERRY = true,
          ICE_BERRY = true, BURNT_BERRY = true, MIRACLEBERRY = true,
      },
      ppRecovery = {
          ETHER = true, MAX_ETHER = true,
          ELIXER = true, MAX_ELIXER = true,
          -- Gen 1 uses PP_UP. PP_MAX is accepted for merged/later data.
          PP_UP = true, PP_MAX = true,
          -- Compatibility spellings retained for merged item datasets.
          ELIXIR = true, MAX_ELIXIR = true,
          -- Gold restores PP with MysteryBerry through the same party-target
          -- item path as Ether-family items.
          MYSTERYBERRY = true, MYSTERY_BERRY = true,
      },
      xBattle = {
          X_ATTACK = true, X_DEFEND = true, X_SPEED = true,
          X_SPECIAL = true, X_ACCURACY = true,
          DIRE_HIT = true, GUARD_SPEC = true,
      },
      repels = { REPEL = true, SUPER_REPEL = true, MAX_REPEL = true },
      fishingRods = { OLD_ROD = true, GOOD_ROD = true, SUPER_ROD = true },
      vanillaBalls = {
          POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true,
          MASTER_BALL = true, SAFARI_BALL = true,
      },
  }

  function ItemPolicy.normalize(item)
      return mod.exports.__beta26.normalizeItemPolicyKey(item)
  end

  -- A few UI/data paths may hand the item policy a display-facing name rather
  -- than the canonical data key.  For the two runtime-failing rule families,
  -- accept either representation without changing the already-confirmed PP or
  -- healing-item classification paths.
  function ItemPolicy.matchesSet(data, itemId, set)
      local id = ItemPolicy.normalize(itemId)
      if set[id] then return true end
      local record = ItemPolicy.record(data, itemId)
      if type(record) == "table" then
          local byName = ItemPolicy.normalize(record.name)
          if set[byName] then return true end
      end
      return false
  end

  function ItemPolicy.record(data, itemId)
      if type(itemId) == "table"
          and (itemId.ball ~= nil or itemId.machine ~= nil or itemId.effect ~= nil) then
          return itemId
      end
      local items = data and data.items
      if type(items) ~= "table" then return nil end
      local id = ItemPolicy.normalize(itemId)
      return items[id] or items[itemId]
  end

  function ItemPolicy.isBall(data, itemId, itemEffects)
      local id = ItemPolicy.normalize(itemId)
      if ItemPolicy.vanillaBalls[id] then return true end
      local record = ItemPolicy.record(data, itemId)
      if type(record) == "table" then
          if record.ball ~= nil and record.ball ~= false then return true end
          if ItemPolicy.normalize(record.pocket) == "BALL" then return true end
      end

      -- API-2 content mods can register custom capture devices in a dedicated
      -- merged balls registry while the item record itself stays intentionally
      -- minimal. Prefer that live registry when present so No Catching and
      -- other ball-aware policy never fall back to a hard-coded vanilla list.
      local mergedBalls = data and (data.balls or data.ballRegistry
          or data.ball_registry)
      if type(mergedBalls) == "table" then
          local entry = mergedBalls[id] or mergedBalls[itemId]
          if entry ~= nil and entry ~= false then return true end
      end

      local balls = itemEffects and itemEffects.BALLS
      return type(balls) == "table" and balls[id] ~= nil and balls[id] ~= false
  end

  function ItemPolicy.isFishingRod(data, itemId)
      local id = ItemPolicy.normalize(itemId)
      if ItemPolicy.fishingRods[id] then return true end
      local record = ItemPolicy.record(data, itemId)
      if type(record) ~= "table" then return false end
      local name = ItemPolicy.normalize(record.name)
      if ItemPolicy.fishingRods[name] then return true end
      local effect = ItemPolicy.normalize(record.effect)
      local kind = ItemPolicy.normalize(record.kind or record.type or record.category)
      return effect:find("FISH", 1, true) ~= nil or effect:find("ROD", 1, true) ~= nil
          or kind == "FISHING_ROD" or kind == "ROD"
  end

  function ItemPolicy.ballUseBlocked(data, itemId, itemEffects, forceIsBall)
      if mod.save:get("no_catching", false) ~= true then return false end
      if forceIsBall == true then return true end
      return ItemPolicy.isBall(data, itemId, itemEffects)
  end

  function ItemPolicy.isTM(data, itemId)
      local record = ItemPolicy.record(data, itemId)
      if type(record) == "table" and record.machine ~= nil then
          local machine = record.machine
          local kind
          if type(machine) == "table" then
              kind = ItemPolicy.normalize(machine.kind or machine.type)
          else
              kind = ItemPolicy.normalize(machine)
          end
          if kind == "HM" then return false end
          if kind == "TM" then return true end
      end
      local id = ItemPolicy.normalize(itemId)
      if id:match("^HM_?%d+") then return false end
      if id:match("^TM_?%d+") then return true end
      if type(record) == "table" then
          local name = ItemPolicy.normalize(record.name)
          if name:match("^HM_?%d+") then return false end
          if name:match("^TM_?%d+") then return true end
      end
      return false
  end

  function ItemPolicy.denied(code, key, plain, tier2, tier3, extra)
      local decision = {
          code = code, key = key, message = plain,
          tier2 = tier2 or plain, tier3 = tier3 or tier2 or plain,
      }
      if type(extra) == "table" then
          for k, v in pairs(extra) do decision[k] = v end
      end
      local Dev = mod.exports.__beta26.Dev
      if Dev and type(Dev.recordDecision) == "function" then
          pcall(Dev.recordDecision, "item", key or code or "item_use", "BLOCK",
              tostring(code or key or "blocked"), currentGameValue() or mod.game)
      end
      return false, decision
  end

  function ItemPolicy.deniedRule(game, code, key, fallback1, fallback2, fallback3, extra)
      local t1, t2, t3 = mod.exports.__beta26.worldRuleTriplet(
          game, key, fallback1, fallback2, fallback3)
      return ItemPolicy.denied(code, key, t1, t2, t3, extra)
  end


  -- Item-aware presentation for the three rules most often tested repeatedly
  -- from the Pack/Bag. Legality stays exactly the same; only the rejection
  -- copy changes. This gives Potion/Revive/status medicine, individual TMs,
  -- and Rare Candy more useful feedback than one repeated generic sentence.
  function ItemPolicy.deniedItemRule(game, data, code, key, itemId, target)
      local id = ItemPolicy.normalize(itemId)
      local def = ItemPolicy.record(data, itemId) or {}
      local itemName = tostring(def.name or id:gsub("_", " "))

      if key == "no_rare_candy_use" then
          local label = target and (target.nickname
              or mod.exports.__beta26.safeSpeciesLabel(game, target.species))
          local t1 = "Rare Candy use is banned."
          local t2 = label and (tostring(label)
              .. " does not get a candy level on this ruleset.")
              or "The Rare Candy stays wrapped; this run does not allow candy levels."
          local t3 = mod.exports.__beta26.runtimeIsGen2(game)
              and "The Rare Candy stays in the Pack. This challenge does not allow field candy levels."
              or "The Rare Candy stays in the Bag. This challenge does not allow field candy levels."
          return ItemPolicy.denied(code, key, Strings(t1), Strings(t2),
              Strings(t3), { item = id })
      end

      if key == "no_tm_use" then
          local teaches = def.teaches
          if not teaches and type(def.machine) == "table" then
              teaches = def.machine.move or def.machine.id
          end
          local moveDef = teaches and data and data.moves
              and data.moves[teaches] or nil
          local moveName = moveDef and moveDef.name
          local t1 = itemName .. " cannot be used to teach a move."
          local t2 = moveName
              and (itemName .. " stays sealed. " .. tostring(moveName)
                  .. " must be learned another way.")
              or (itemName .. " stays sealed. TMs are collection-only on this ruleset.")
          local t3 = mod.exports.__beta26.runtimeIsGen2(game)
              and (moveName
                  and ("The TM pocket can keep " .. itemName .. ", but Johto's rule card will not teach "
                      .. tostring(moveName) .. " from it. HMs still work.")
                  or ("The TM pocket can keep " .. itemName
                      .. ", but Johto's challenge does not allow TM teaching. HMs still work."))
              or (moveName
                  and ("The TM case can keep " .. itemName .. ", but Kanto's rule card will not teach "
                      .. tostring(moveName) .. " from it. HMs still work.")
                  or ("The TM case can keep " .. itemName
                      .. ", but Kanto's challenge does not allow TM teaching. HMs still work."))
          return ItemPolicy.denied(code, key, Strings(t1), Strings(t2),
              Strings(t3), { item = id, move = teaches })
      end

      if key == "no_field_healing" then
          local revive = id == "REVIVE" or id == "MAX_REVIVE"
          local status = id == "ANTIDOTE" or id == "BURN_HEAL"
              or id == "ICE_HEAL" or id == "AWAKENING"
              or id == "PARLYZ_HEAL" or id == "PARALYZE_HEAL"
              or id == "FULL_HEAL"
          local t1 = itemName .. " cannot be used in the field."
          local t2
          if revive then
              t2 = itemName .. " stays in the bag. A field Revive would erase the consequence this rule is preserving."
          elseif status then
              t2 = itemName .. " has to wait. Field status medicine is disabled until your rules allow healing."
          else
              t2 = itemName .. " stays corked. Roadside HP recovery is disabled on this run."
          end
          local t3
          if mod.exports.__beta26.runtimeIsGen2(game) then
              t3 = revive
                  and ("Johto's trail ledger does not accept " .. itemName
                      .. " as a roadside reset. Carry the damage forward.")
                  or status
                      and ("The Johto route ahead keeps its teeth. " .. itemName
                          .. " waits until a legal healing seam.")
                      or ("No trail-side potion stop in Johto. " .. itemName
                          .. " stays packed and the team carries its bruises onward.")
          else
              t3 = revive
                  and ("Kanto's route ledger does not accept " .. itemName
                      .. " as a roadside reset. Carry the consequence forward.")
                  or status
                      and ("The Kanto road keeps its teeth. " .. itemName
                          .. " waits until a legal healing seam.")
                      or ("No roadside potion stop in Kanto. " .. itemName
                          .. " stays packed and the team carries its bruises onward.")
          end
          return ItemPolicy.denied(code, key, Strings(t1), Strings(t2),
              Strings(t3), { item = id })
      end

      return ItemPolicy.deniedRule(game, code, key,
          tostring(itemName) .. " is blocked by your Nuzlocke rules.")
  end

  evaluateItemUsePolicy = function(game, data, save, itemId, target, context)
      context = type(context) == "table" and context or {}
      local battle = context.battle
      local inBattle = context.inBattle
      if inBattle == nil then inBattle = battle ~= nil end

      -- v0.1.79 can reach ItemEffects.use with a valid save/data pair while a
      -- convenient Game reference is absent. Legality is save-owned; presentation
      -- is the only part that needs a Game/stack. Resolve every known context but
      -- never silently allow a restricted item merely because `game` is nil.
      game = game or (battle and battle.game)
          or (context.overworld and context.overworld.game)
          or currentGameValue() or mod.game
      save = save or (game and game.save) or currentSaveValue()
      data = data or (game and game.data)
          or (currentGameValue() and currentGameValue().data)

      if mod.save:get("nuzlocke_enabled", true) == false or not save then
          return true
      end
      if battle and (battle.demo or battle.ghost) then return true end

      local id = ItemPolicy.normalize(itemId)
      if id == "" then return true end

      -- These rules prohibit USE only. Inventory acquisition, PC storage,
      -- tossing, buying, and selling remain owned by their normal/other rule paths.
      if mod.save:get("no_rare_candy_use", false) == true and id == "RARE_CANDY" then
          return ItemPolicy.deniedItemRule(game, data,
              "no_rare_candy_use", "no_rare_candy_use", itemId, target)
      end

      if mod.save:get("no_player_stat_exp_gain", false) == true then
          if mod.exports.__beta26.nativeStatVitaminSet[id] then
              return ItemPolicy.deniedRule(game,
                  "no_player_stat_exp_gain", "no_player_stat_exp_gain",
                  "Stat EXP gain is banned.")
          end
      end

      if mod.save:get("no_tm_use", false) == true and ItemPolicy.isTM(data, itemId) then
          return ItemPolicy.deniedItemRule(game, data,
              "no_tm_use", "no_tm_use", itemId, target)
      end

      if ItemPolicy.ballUseBlocked(data, itemId, context.itemEffects,
          context.isBall == true) then
          local t1, t2, t3 = mod.exports.__beta26.worldRuleTriplet(game, "no_catching")
          return ItemPolicy.denied(
              "no_catching", "no_catching", t1, t2, t3)
      end

      -- A level cap constrains level advancement, not only EXP gain.
      if id == "RARE_CANDY" and levelCapScope() > 0 and type(target) == "table" then
          local cap = nextLevelCap(save)
          local level = tonumber(target.level) or 0
          if cap < 100 and level >= cap then
              return ItemPolicy.deniedRule(game,
                  "level_cap", "level_cap_scope",
                  "The level cap blocks that Rare Candy.", nil, nil,
                  { cap = cap, level = level })
          end
      end

      if mod.save:get("no_pp_items", false) == true and ItemPolicy.matchesSet(data, itemId, ItemPolicy.ppRecovery) then
          return ItemPolicy.deniedRule(game,
              "no_pp_items", "no_pp_items", "PP items are banned.")
      end

      if not inBattle then
          if mod.save:get("no_fishing", false) == true
              and ItemPolicy.isFishingRod(data, itemId) then
              return ItemPolicy.deniedRule(game,
                  "no_fishing", "no_fishing", "Fishing is banned.")
          end
          if mod.save:get("no_repels", false) == true and ItemPolicy.matchesSet(data, itemId, ItemPolicy.repels) then
              return ItemPolicy.deniedRule(game,
                  "no_repels", "no_repels", "Repels are banned.")
          end
          if id == "ESCAPE_ROPE" and type(mod.exports.__beta26.dungeonLockActive) == "function"
              and mod.exports.__beta26.dungeonLockActive(game) then
              return ItemPolicy.deniedRule(game,
                  "dungeon_lock_in", "dungeon_lock_in",
                  "Dungeon Lock-In blocks the Escape Rope.")
          end
          if mod.save:get("no_escape_rope", false) == true and id == "ESCAPE_ROPE" then
              return ItemPolicy.deniedRule(game,
                  "no_escape_rope", "no_escape_rope", "Escape Rope is banned.")
          end
          if mod.save:get("no_field_healing", false) == true
              and ItemPolicy.matchesSet(data, itemId, ItemPolicy.fieldHealing) then
              return ItemPolicy.deniedItemRule(game, data,
                  "no_field_healing", "no_field_healing", itemId, target)
          end
          return true
      end

      -- Catch legality is separate. Dynamic ball detection prevents custom balls
      -- from being caught by the legacy combined No Items compatibility rule.
      if ItemPolicy.isBall(data, itemId, context.itemEffects) then return true end

      if mod.save:get("no_healing_items", false) == true
          and ItemPolicy.matchesSet(data, itemId, ItemPolicy.fieldHealing) then
          return ItemPolicy.deniedRule(
              game, "no_healing_items", "no_healing_items",
              "Healing items are banned in battle.", nil, nil,
              { context = "battle", source = "bag" })
      end
      if mod.save:get("no_battle_items", false) == true and ItemPolicy.matchesSet(data, itemId, ItemPolicy.xBattle) then
          return ItemPolicy.deniedRule(
              game, "no_battle_items", "no_battle_items",
              "X Items are banned in battle.", nil, nil,
              { context = "battle", source = "bag" })
      end
      return true
  end

  function ItemPolicy.present(game, decision, context)
      if type(decision) ~= "table" then return "failed", { "Item use is blocked!" } end
      game = game or currentGameValue() or mod.game
      context = type(context) == "table" and context or {}
      local tier = worldTier(game)
      local message = decision.message or "Item use is blocked!"
      if tier >= 3 then
          message = decision.tier3 or decision.tier2 or message
      elseif tier >= 2 then
          message = decision.tier2 or message
      end

      -- 2.4.95: field-item rejection text must be player-paced. The Bag's
      -- native ItemEffects result-message path advances these longer Nuzlocke
      -- strings too quickly on handheld runtime. Outside battle, present the
      -- exact same selected rule text through our blocking world paginator:
      -- 18-glyph wrapping, max two lines per page, A-driven continuation.
      -- Return an empty native result-message list when that TextBox was
      -- successfully pushed so the Bag does not flash a duplicate fast line.
      if context.inBattle ~= true and context.battle == nil then
          local shown = mod.exports.__beta26.pushWorldText(game, message)
          if shown then
              return "failed", {}
          end
      end

      -- Battle use retains the native result channel; stacking an overworld
      -- TextBox into BattleState would be unsafe and would alter turn/UI flow.
      return "failed", { mod.exports.__beta26.cleanWorldText(message) }
  end

  function ItemPolicy.installFieldActionGuards()
      if mod.exports.__beta26.isSaveEditorSession() then return true end
      if mod.exports.__beta26.runtimeIsGen2(currentGameValue() or mod.game) then
          local ok, World = pcall(require, "src.world.gen2.World")
          if not ok or type(World) ~= "table"
              or type(World.useFieldItem) ~= "function" then return false end
          local session = World.__nuzlockeFieldActionGuardSession
          if type(session) == "table" and session.owner == mod
              and World.useFieldItem == session.wrapper then return true end
          if type(session) == "table" and session.owner ~= mod
              and World.useFieldItem == session.wrapper
              and type(session.previous) == "function" then
              World.useFieldItem = session.previous
          end
          local previous = World.useFieldItem
          local wrapper = function(self, itemId, ...)
              local game = self and self.game or currentGameValue() or mod.game
              local allowed, decision = evaluateItemUsePolicy(
                  game, game and game.data, game and game.save, itemId, nil,
                  { inBattle = false, overworld = self, generation = 2 })
              if allowed == false then
                  if self then self.nuzlockeItemUseBlocked = decision and decision.code end
                  return "nowhere"
              end
              return previous(self, itemId, ...)
          end
          World.useFieldItem = wrapper
          World.__nuzlockeFieldActionGuardSession = {
              owner = mod, previous = previous, wrapper = wrapper,
          }
          return true
      end

      local ok, Overworld = pcall(require, "src.world.OverworldController")
      if not ok or type(Overworld) ~= "table"
          or type(Overworld.useFishingRod) ~= "function" then return false end
      local session = Overworld.__nuzlockeFishingGuardSession
      if type(session) == "table" and session.owner == mod
          and Overworld.useFishingRod == session.wrapper then return true end
      if type(session) == "table" and session.owner ~= mod
          and Overworld.useFishingRod == session.wrapper
          and type(session.previous) == "function" then
          Overworld.useFishingRod = session.previous
      end
      local previous = Overworld.useFishingRod
      local wrapper = function(self, rod, ...)
          local game = currentGameValue() or mod.game
          local allowed, decision = evaluateItemUsePolicy(
              game, game and game.data, game and game.save, rod, nil,
              { inBattle = false, overworld = self, generation = 1 })
          if allowed == false and decision and decision.code == "no_fishing" then
              return false
          end
          return previous(self, rod, ...)
      end
      Overworld.useFishingRod = wrapper
      Overworld.__nuzlockeFishingGuardSession = {
          owner = mod, previous = previous, wrapper = wrapper,
      }
      return true
  end

  function ItemPolicy.install()
      local engineState = mod.exports.__beta26.compat
          and mod.exports.__beta26.compat.Engine
          and mod.exports.__beta26.compat.Engine.state
      if mod.exports.__beta26.isSaveEditorSession() then
          if type(engineState) == "table" then
              engineState.item_use = { ok = true, environment = "save_editor", runtime_patch = "skipped" }
          end
          refreshPublicCompatSnapshots()
          return true
      end
      local ok, ItemEffects = pcall(require, "src.inventory.ItemEffects")
      if not ok or type(ItemEffects) ~= "table" or type(ItemEffects.use) ~= "function" then
          if type(engineState) == "table" then
              engineState.item_use = { ok = false, reason = "ItemEffects.use unavailable" }
          end
          refreshPublicCompatSnapshots()
          return false
      end

      -- Identity validation matters more than an owner string. If another mod
      -- legitimately wraps/replaces ItemEffects.use after us, a later safe
      -- lifecycle boundary composes around the *current* live function instead
      -- of assuming our old closure is still active. No per-frame rebinding.
      if ItemEffects.__nuzlockeItemRuleGateOwner == mod
          and ItemEffects.use == ItemEffects.__nuzlockeItemRuleGateFunction then
          if type(engineState) == "table" then
              engineState.item_use = { ok = true, owner = "current_session", relationship = "compose" }
          end
          refreshPublicCompatSnapshots()
          return true
      end

      if ItemEffects.__nuzlockeItemRuleGateOwner ~= nil
          and ItemEffects.__nuzlockeItemRuleGateOwner ~= mod
          and ItemEffects.use == ItemEffects.__nuzlockeItemRuleGateFunction
          and type(ItemEffects.__nuzlockeItemRuleGatePrevious) == "function" then
          ItemEffects.use = ItemEffects.__nuzlockeItemRuleGatePrevious
      end

      local previousUse = ItemEffects.use
      local gate
      gate = function(data, save, itemId, target, battle, moveIndex, ow)
          local game = (battle and battle.game) or (ow and ow.game)
              or currentGameValue() or mod.game
          local allowed, decision = evaluateItemUsePolicy(
              game, data, save, itemId, target,
              { battle = battle, inBattle = battle ~= nil, overworld = ow,
                moveIndex = moveIndex, itemEffects = ItemEffects })
          if not allowed then
              return ItemPolicy.present(game, decision, {
                  battle = battle,
                  inBattle = battle ~= nil,
                  overworld = ow,
                  itemId = itemId,
              })
          end
          return previousUse(data, save, itemId, target, battle, moveIndex, ow)
      end
      ItemEffects.use = gate
      ItemEffects.__nuzlockeItemRuleGateInstalled = true
      ItemEffects.__nuzlockeItemRuleGateOwner = mod
      ItemEffects.__nuzlockeItemRuleGateFunction = gate
      ItemEffects.__nuzlockeItemRuleGatePrevious = previousUse
      if type(engineState) == "table" then
          engineState.item_use = { ok = true, owner = "current_session", relationship = "compose" }
      end
      refreshPublicCompatSnapshots()
      return true
  end

  return {
    ItemPolicy = ItemPolicy,
    evaluateItemUsePolicy = evaluateItemUsePolicy,
  }
end
