-- Module owner: Forgiveness
return function(mod, deps)
  deps = deps or {}
  local Strings = assert(deps.Strings, "forgiveness requires Strings")
  local Identity = assert(deps.Identity, "forgiveness requires Identity")
  local ROUTE_ORDER = assert(deps.ROUTE_ORDER, "forgiveness requires ROUTE_ORDER")
  local areaKey = assert(deps.areaKey, "forgiveness requires areaKey")
  local caughtAreas = assert(deps.caughtAreas, "forgiveness requires caughtAreas")
  local defaultRuleValue = assert(deps.defaultRuleValue, "forgiveness requires defaultRuleValue")
  local ensurePokemonIdentity = assert(deps.ensurePokemonIdentity, "forgiveness requires ensurePokemonIdentity")
  local getDisplayRoutes = assert(deps.getDisplayRoutes, "forgiveness requires getDisplayRoutes")
  local isTrackedArea = assert(deps.isTrackedArea, "forgiveness requires isTrackedArea")
  local marqueeText = assert(deps.marqueeText, "forgiveness requires marqueeText")
  local pokemonIdentity = assert(deps.pokemonIdentity, "forgiveness requires pokemonIdentity")
  local routeKey = assert(deps.routeKey, "forgiveness requires routeKey")
  local routeName = assert(deps.routeName, "forgiveness requires routeName")
  local syncCaughtAreasFromLog = assert(deps.syncCaughtAreasFromLog, "forgiveness requires syncCaughtAreasFromLog")
  local trackerLog = assert(deps.trackerLog, "forgiveness requires trackerLog")
  local wrapText = assert(deps.wrapText, "forgiveness requires wrapText")
  local getCurrentGame = assert(deps.getCurrentGame, "forgiveness requires getCurrentGame")
  local getCurrentSave = assert(deps.getCurrentSave, "forgiveness requires getCurrentSave")
  local engineBoxConstants = assert(deps.engineBoxConstants, "forgiveness requires engineBoxConstants")
  ---------------------------------------------------------------------
  -- FORGIVENESS TOKEN ITEM / REVIVAL ARCHIVE (2.5.40)
  --
  -- Route Forgiveness is now player-directed inventory rather than an
  -- automatic failed-encounter prompt or Mart purchase. A carried F. TOKEN
  -- can reopen the CURRENT area's FAILED encounter slot, or revive one
  -- Pokemon whose exact record was archived when Permadeath removed it.
  ---------------------------------------------------------------------
  mod.exports.__beta26.forgivenessDeadArchive = function()
      local archive = mod.save:get("route_forgiveness_dead_archive", {})
      if type(archive) ~= "table" then
          archive = {}
          mod.save:set("route_forgiveness_dead_archive", archive)
      end
      return archive
  end

  mod.exports.__beta26.archiveForgivenessDeath = function(game, mon)
      if type(mon) ~= "table" or mon.nuzlockeDead ~= true
          or not mod.exports.__beta26.canWriteNuzlockeSave(game) then
          return false
      end
      local id = Identity.ensurePokemonIdentity(mon,
          game and game.save or getCurrentSave(), mon.nuzlockeOrigin or "NORMAL")
      if id == nil then return false end
      local archive = mod.exports.__beta26.forgivenessDeadArchive()
      -- Snapshot plain save data instead of retaining the live battle object.
      -- This prevents later faint/cleanup code from mutating the archived
      -- revival record after Permadeath has removed the Pokemon from play.
      local function snapshot(value, seen)
          if type(value) ~= "table" then
              return type(value) == "function" and nil or value
          end
          seen = seen or {}
          if seen[value] then return nil end
          seen[value] = true
          local out = {}
          for key, item in pairs(value) do
              if type(key) ~= "function" and type(item) ~= "function" then
                  local copiedKey = snapshot(key, seen)
                  local copiedValue = snapshot(item, seen)
                  if copiedKey ~= nil then out[copiedKey] = copiedValue end
              end
          end
          seen[value] = nil
          return out
      end
      archive[tostring(id)] = {
          pokemonId = id,
          name = mon.nickname,
          species = mon.species,
          -- Persist the exact record before Permadeath removes it. This keeps
          -- level, DVs/IVs, moves/PP, held item, Stat EXP, OT and all
          -- generation-specific fields rather than reconstructing a species.
          mon = snapshot(mon),
      }
      mod.save:set("route_forgiveness_dead_archive", archive)
      return true, id
  end

  mod.exports.__beta26.forgivenessDeadRows = function(game)
      local archive = mod.exports.__beta26.forgivenessDeadArchive()
      local rows, seen = {}, {}
      local function add(mon, id, record)
          if type(mon) ~= "table" or mon.nuzlockeDead ~= true then return end
          id = id or Identity.pokemonIdentity(mon)
              or Identity.ensurePokemonIdentity(mon,
                  game and game.save or getCurrentSave(),
                  mon.nuzlockeOrigin or "NORMAL")
          if id == nil or seen[tostring(id)] then return end
          seen[tostring(id)] = true
          rows[#rows + 1] = {
              pokemonId = id,
              name = tostring(mon.nickname or mon.species or "POKEMON"),
              species = tostring(mon.species or "UNKNOWN"),
              level = tonumber(mon.level),
              mon = mon,
              record = record,
          }
      end
      for key, record in pairs(archive) do
          if type(record) == "table" then
              add(record.mon, record.pokemonId or key, record)
          end
      end
      local save = game and game.save
      if type(save) == "table" then
          for _, mon in ipairs(save.party or {}) do add(mon) end
          mod.exports.__beta26.forEachExistingSaveBox(save, function(box)
              for _, mon in ipairs(box) do add(mon) end
          end)
      end
      table.sort(rows, function(a, b)
          local an, bn = tostring(a.name), tostring(b.name)
          if an == bn then return tostring(a.pokemonId) < tostring(b.pokemonId) end
          return an < bn
      end)
      return rows
  end

  mod.exports.__beta26.forgivenessAreaEligible = function(game, requestedKey)
      game = game or getCurrentGame() or mod.game
      local key = routeKey(requestedKey) or requestedKey
      if not key or key == "UNKNOWN" or not isTrackedArea(key) then
          return false, Strings("There is no encounter slot to reroll there.")
      end
      syncCaughtAreasFromLog()
      if caughtAreas()[key] ~= nil then
          return false, Strings("This area's catch is already complete.")
      end
      local states = mod.exports.__beta26.encounterStates()
      local state = states[key]
      if type(state) ~= "table" or state.status ~= "FAILED" then
          return false, Strings("This area's encounter is already open.")
      end
      return true, nil, key
  end

  mod.exports.__beta26.forgivenessAreaRows = function(game)
      game = game or getCurrentGame() or mod.game
      if type(mod.exports.__beta26.ensureEncounterProjection) == "function" then
          pcall(mod.exports.__beta26.ensureEncounterProjection)
      end
      syncCaughtAreasFromLog()
      local rows, seen = {}, {}
      for _, area in ipairs(getDisplayRoutes(game) or {}) do
          local key = area and (routeKey(area.id) or area.id)
          if key and not seen[key] then
              local ok = mod.exports.__beta26.forgivenessAreaEligible(game, key)
              if ok then
                  seen[key] = true
                  rows[#rows + 1] = {
                      key = key,
                      name = tostring(area.name or routeName(key)),
                  }
              end
          end
      end
      -- Defensive fallback for projected FAILED rows that are valid tracker
      -- areas but are not currently present in getDisplayRoutes().
      local states = mod.exports.__beta26.encounterStates()
      for key, state in pairs(states) do
          if type(state) == "table" and state.status == "FAILED"
              and not seen[key] and isTrackedArea(key)
              and caughtAreas()[key] == nil then
              seen[key] = true
              rows[#rows + 1] = { key = key, name = tostring(routeName(key)) }
          end
      end
      table.sort(rows, function(a, b)
          local ao, bo = ROUTE_ORDER[a.key] or 999999, ROUTE_ORDER[b.key] or 999999
          if ao == bo then return tostring(a.name) < tostring(b.name) end
          return ao < bo
      end)
      return rows
  end

  mod.exports.__beta26.reopenFailedEncounterWithForgiveness = function(game, requestedKey)
      game = game or getCurrentGame() or mod.game
      local rewards = mod.exports.__beta26.TrainerRewards
      if not (rewards and rewards.forgivenessEnabled
          and rewards.forgivenessEnabled(game, nil)) then
          return false, Strings("Route Forgiveness is not active.")
      end
      if rewards.forgivenessTokens() <= 0 then
          return false, Strings("You have no F. TOKEN.")
      end
      local key = requestedKey
      if key == nil then
          key = areaKey(game, nil)
      end
      key = routeKey(key) or key
      local eligible, reason, normalized =
          mod.exports.__beta26.forgivenessAreaEligible(game, key)
      if not eligible then return false, reason end
      key = normalized or key

      -- FAILED state is projected from a physical-map ledger. Forgiveness
      -- spends against the SELECTED logical encounter slot. If disabled area
      -- splits merge several physical rows into that one logical slot, clear
      -- every FAILED row projecting into it so the slot truly reopens and
      -- cannot re-close after a reproject/load.
      local states = mod.exports.__beta26.encounterStates()
      local ledger = mod.save:get("encounter_area_state_ledger", {})
      if type(ledger) ~= "table" then ledger = {} end
      for ledgerKey, row in pairs(ledger) do
          if type(row) == "table" and row.status == "FAILED" then
              local physical = routeKey(row.encounterMapId)
                  or routeKey(ledgerKey) or row.encounterMapId
              local base = mod.exports.__beta26.projectEncounterArea(physical)
                  or physical
              local projected = mod.exports.__beta26.projectGoldEncounterArea(
                  game, base, row) or base
              if (routeKey(projected) or projected) == key then
                  ledger[ledgerKey] = nil
              end
          end
      end
      states[key] = nil
      mod.save:set("encounter_states", states)
      mod.save:set("encounter_area_state_ledger", ledger)
      local last = mod.save:get("last_failed_encounter", {})
      if type(last) == "table"
          and (routeKey(last.area) or last.area) == key then
          mod.save:set("last_failed_encounter", {})
      end
      pcall(mod.exports.__beta26.reprojectEncounterAreas)
      rewards.setForgivenessTokens(rewards.forgivenessTokens() - 1)
      pcall(mod.exports.__beta26.RunHistory.recordForgivenessUse, game, "area", key, {
          tokens = rewards.forgivenessTokens(), source = "bag",
      })
      return true, Strings("F. TOKEN used.\n%s is open again.", routeName(key))
  end

  mod.exports.__beta26.reviveWithForgiveness = function(game, pokemonId)
      game = game or getCurrentGame() or mod.game
      local rewards = mod.exports.__beta26.TrainerRewards
      if not (rewards and rewards.forgivenessEnabled
          and rewards.forgivenessEnabled(game, nil)) then
          return false, Strings("Route Forgiveness is not active.")
      end
      if rewards.forgivenessTokens() <= 0 then
          return false, Strings("You have no F. TOKEN.")
      end
      local wanted = tostring(pokemonId or "")
      local archive = mod.exports.__beta26.forgivenessDeadArchive()
      local record = archive[wanted]
      local mon = type(record) == "table" and record.mon or nil
      local save = game and game.save
      if type(save) ~= "table" then
          return false, Strings("The save is unavailable.")
      end

      -- Prefer a physical dead record if another compatible system retained
      -- it in storage; otherwise use the full Permadeath archive snapshot.
      local physical, physicalBox, physicalPartyIndex = nil, nil, nil
      local function same(candidate)
          if type(candidate) ~= "table" then return false end
          local id = Identity.pokemonIdentity(candidate)
          return id ~= nil and tostring(id) == wanted
      end
      for index, candidate in ipairs(save.party or {}) do
          if same(candidate) then
              physical, physicalPartyIndex = candidate, index
              break
          end
      end
      if not physical then
          mod.exports.__beta26.forEachExistingSaveBox(save,
              function(box, boxIndex)
                  for _, candidate in ipairs(box) do
                      if same(candidate) then
                          physical, physicalBox = candidate, boxIndex
                          return false
                      end
                  end
              end)
      end
      mon = physical or mon
      if type(mon) ~= "table" or mon.nuzlockeDead ~= true then
          return false, Strings("That fallen Pokemon cannot be restored.")
      end

      local party = save.party or {}
      local limit = math.max(1, math.min(6, math.floor(tonumber(
          mod.save:get("party_size_limit",
              defaultRuleValue("party_size_limit"))) or 6)))

      -- A compatible provider may retain a dead Pokemon physically in the
      -- party. If Party Size Limit was lowered after that death, reviving in
      -- place must not reactivate a party that is already above the cap. Move
      -- that retained record to legal PC storage before clearing nuzlockeDead.
      if physicalPartyIndex ~= nil and #party > limit then
          local destination, destinationBox
          if mod.exports.__beta26.runtimeIsGen2(game) then
              local okBoxes, Boxes = pcall(require, "src.core.gen2.Boxes")
              if not okBoxes or type(Boxes) ~= "table" then
                  return false, Strings("No PC storage is available.")
              end
              local layout = engineBoxConstants(game, Boxes)
              local count, capacity = layout.count, layout.capacity
              for i = 1, count do
                  local box = type(Boxes.box) == "function" and Boxes.box(save, i)
                      or (save.boxes and save.boxes[i])
                  if type(box) == "table" and #box < capacity then
                      destination, destinationBox = i, box
                      break
                  end
              end
          else
              local okBoxes, Boxes = pcall(require, "src.pokemon.Boxes")
              if not okBoxes or type(Boxes) ~= "table"
                  or type(Boxes.ensure) ~= "function" then
                  return false, Strings("No PC storage is available.")
              end
              local boxes = Boxes.ensure(save)
              local layout = engineBoxConstants(game, Boxes)
              local count, capacity = layout.count, layout.capacity
              for i = 1, count do
                  if type(boxes[i]) == "table" and #boxes[i] < capacity then
                      destination, destinationBox = i, boxes[i]
                      break
                  end
              end
          end
          if not destination or type(destinationBox) ~= "table" then
              return false, Strings("The PC is full. No token was spent.")
          end
          table.remove(party, physicalPartyIndex)
          destinationBox[#destinationBox + 1] = mon
          save.party = party
          physicalBox = destination
          physicalPartyIndex = nil
      end

      -- If Permadeath removed the mon completely, put the archived full record
      -- back into the run. Party Size Limit is respected; a full/capped party
      -- sends the revival to the first PC box with room instead.
      if not physical then
          if #party < limit then
              party[#party + 1] = mon
              save.party = party
          elseif mod.exports.__beta26.runtimeIsGen2(game) then
              local okBoxes, Boxes = pcall(require, "src.core.gen2.Boxes")
              if not okBoxes or type(Boxes) ~= "table" then
                  return false, Strings("No PC storage is available.")
              end
              local layout = engineBoxConstants(game, Boxes)
              local count, capacity = layout.count, layout.capacity
              local destination
              for i = 1, count do
                  local box = type(Boxes.box) == "function" and Boxes.box(save, i)
                      or (save.boxes and save.boxes[i])
                  if type(box) == "table" and #box < capacity then
                      destination = i
                      break
                  end
              end
              if not destination then
                  return false, Strings("The PC is full. No token was spent.")
              end
              local box = type(Boxes.box) == "function" and Boxes.box(save, destination)
                  or (save.boxes and save.boxes[destination])
              if type(box) ~= "table" or #box >= capacity then
                  return false, Strings("The PC is full. No token was spent.")
              end
              box[#box + 1] = mon
              physicalBox = destination
          else
              local okBoxes, Boxes = pcall(require, "src.pokemon.Boxes")
              if not okBoxes or type(Boxes) ~= "table"
                  or type(Boxes.ensure) ~= "function" then
                  return false, Strings("No PC storage is available.")
              end
              local boxes = Boxes.ensure(save)
              local layout = engineBoxConstants(game, Boxes)
              local count, capacity = layout.count, layout.capacity
              local destination
              for i = 1, count do
                  if type(boxes[i]) == "table" and #boxes[i] < capacity then
                      destination = i
                      break
                  end
              end
              if not destination then
                  return false, Strings("The PC is full. No token was spent.")
              end
              boxes[destination][#boxes[destination] + 1] = mon
              physicalBox = destination
          end
      end

      local maxHp = math.max(1, math.floor(tonumber(mon.maxHp)
          or tonumber(mon.stats and mon.stats.hp) or 1))
      mon.hp = math.max(1, math.floor(maxHp / 2))
      mon.nuzlockeDead = nil
      mon.status = nil
      mon.statusTurns = nil
      mon.toxicCounter = nil
      mon.deathLocation = nil
      mon.deathCause = nil
      mon.deathCauseText = nil
      mon.deathEncounterType = nil
      mon.deathOpponentSpecies = nil
      mon.deathMove = nil
      mon.deathCritical = nil
      mon.deathStatusCondition = nil

      local history = mod.save:get("nuzlocke_history", {})
      if type(history) == "table" then
          for _, row in ipairs(history) do
              if type(row) == "table" and row.pokemonId ~= nil
                  and tostring(row.pokemonId) == wanted
                  and row.status == "DEAD" then
                  row.status = "REVIVED"
                  row.revivedByForgiveness = true
              end
          end
          mod.save:set("nuzlocke_history", history)
      end
      local log = trackerLog()
      for _, entries in pairs(log) do
          if type(entries) == "table" then
              for _, catch in ipairs(entries) do
                  if type(catch) == "table" and catch.pokemonId ~= nil
                      and tostring(catch.pokemonId) == wanted then
                      catch.dead = nil
                      catch.status = catch.isShiny and "SHINY" or "CAUGHT"
                      catch.deathCause = nil
                      catch.deathLocation = nil
                      catch.deathOpponentSpecies = nil
                      catch.deathMove = nil
                      catch.deathCritical = nil
                      catch.deathStatusCondition = nil
                  end
              end
          end
      end
      mod.save:set("tracker_log", log)
      if type(mod.exports.__beta26.syncTrackerDeathProjection) == "function" then
          pcall(mod.exports.__beta26.syncTrackerDeathProjection)
      end
      archive[wanted] = nil
      mod.save:set("route_forgiveness_dead_archive", archive)
      rewards.setForgivenessTokens(rewards.forgivenessTokens() - 1)
      pcall(mod.exports.__beta26.RunHistory.recordForgivenessUse, game, "revive", wanted, {
          tokens = rewards.forgivenessTokens(), source = "bag",
      })
      local name = tostring(mon.nickname or mon.species or "Pokemon")
      local suffix = physicalBox and Strings("\nSent to PC Box %d.", physicalBox)
          or ""
      return true, Strings("F. TOKEN used.\n%s was revived!", name) .. suffix
  end

  mod.content.screens:register("NuzlockeForgivenessArea", {
      new = function(game, ctx)
          ctx = ctx or {}
          local self = {
              game = game,
              screenId = "NuzlockeForgivenessArea",
              isOpaque = true,
              uiModLayout = "classic",
              keepClassicUi = true,
              rows = mod.exports.__beta26.forgivenessAreaRows(game),
              index = 1,
              scroll = 0,
              phase = "list",
              confirmChoice = 0, -- deliberately no YES/NO default
              notice = nil,
              ctx = ctx,
          }
          self.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(self)
          self.presentationRole = "forgiveness_area"
          self.presentationStateOwner = "nuzlocke"
          self.presentationNativeFallback = true
          self.__nuzlockeOwnsForgivenessLayout = true

          local function clamp()
              local count = #self.rows
              if count <= 0 then self.index, self.scroll = 1, 0; return end
              self.index = math.max(1, math.min(self.index, count))
              if self.index <= self.scroll then self.scroll = self.index - 1 end
              if self.index > self.scroll + 6 then self.scroll = self.index - 6 end
              self.scroll = math.max(0, math.min(self.scroll, math.max(0, count - 6)))
          end
          local function selected()
              return self.rows[self.index]
          end
          local function beginConfirm(row)
              if not row then return end
              local ok, reason = mod.exports.__beta26.forgivenessAreaEligible(game, row.key)
              if not ok then
                  self.notice = reason
                  self.rows = mod.exports.__beta26.forgivenessAreaRows(game)
                  clamp()
                  return
              end
              self.phase = "confirm"
              self.confirmChoice = 0
          end
          if ctx.initialKey then
              local wanted = routeKey(ctx.initialKey) or ctx.initialKey
              for i, row in ipairs(self.rows) do
                  if row.key == wanted then self.index = i; break end
              end
              clamp()
              if ctx.confirmImmediately == true and selected() then
                  beginConfirm(selected())
              end
          end

          function self:update(_dt)
              if self.notice then
                  if game.input:wasPressed("a") or game.input:wasPressed("b") then
                      self.notice = nil
                      if self.ctx.closeAfterNotice == true then game.stack:pop() end
                  end
                  return
              end
              if self.phase == "confirm" then
                  if game.input:wasPressed("b") then
                      if self.ctx.confirmImmediately == true then
                          game.stack:pop()
                      else
                          self.phase = "list"
                          self.confirmChoice = 0
                      end
                      return
                  end
                  local chooseYes = game.input:wasPressed("left") or game.input:wasPressed("up")
                  local chooseNo = game.input:wasPressed("right") or game.input:wasPressed("down")
                  if chooseYes or chooseNo then
                      if self.confirmChoice == 0 then
                          self.confirmChoice = chooseYes and 1 or 2
                      else
                          self.confirmChoice = self.confirmChoice == 1 and 2 or 1
                      end
                      return
                  end
                  if game.input:wasPressed("a") then
                      if self.confirmChoice == 0 then return end
                      if self.confirmChoice == 2 then
                          if self.ctx.confirmImmediately == true then
                              game.stack:pop()
                          else
                              self.phase = "list"
                              self.confirmChoice = 0
                          end
                          return
                      end
                      local row = selected()
                      local ok, message
                      if row then
                          ok, message = mod.exports.__beta26.reopenFailedEncounterWithForgiveness(
                              game, row.key)
                      else
                          ok, message = false, Strings("No reroll area is selected.")
                      end
                      self.notice = message
                      if ok then
                          if type(self.ctx.onSpent) == "function" then pcall(self.ctx.onSpent, row.key) end
                          self.rows = mod.exports.__beta26.forgivenessAreaRows(game)
                          self.phase = "list"
                          self.confirmChoice = 0
                          self.ctx.closeAfterNotice = self.ctx.closeAfterSpend == true
                          clamp()
                      end
                      return
                  end
                  return
              end
              if game.input:wasPressed("b") then game.stack:pop(); return end
              if #self.rows == 0 then return end
              if game.input:wasPressed("up") then
                  self.index = self.index == 1 and #self.rows or self.index - 1
                  clamp()
              elseif game.input:wasPressed("down") then
                  self.index = self.index == #self.rows and 1 or self.index + 1
                  clamp()
              elseif game.input:wasPressed("a") then
                  beginConfirm(selected())
              end
          end

          function self:draw()
              local rewards = mod.exports.__beta26.TrainerRewards
              local tokens = rewards and rewards.forgivenessTokens
                  and rewards.forgivenessTokens() or 0
              local row = selected()
              local areaName = row and row.name or "?"
              if mod.exports.__beta26.runtimeIsGen2(game) then
                  local Chrome = require("src.ui.gen2.Chrome")
                  Chrome.clear(); Chrome.box(0,0,20,18)
                  Chrome.print(Strings("REROLL AREA"), 4, 1)
                  if self.notice then
                      Chrome.printWrapped(self.notice, 2, 5, 16, 6)
                      Chrome.print(Strings("A/B:BACK"), 5, 15)
                      return
                  end
                  if self.phase == "confirm" then
                      Chrome.printWrapped(Strings("Are you sure? This will spend your F. TOKEN on %s.", areaName), 2, 4, 16, 6)
                      if self.confirmChoice == 1 then Chrome.cursor(4, 12) end
                      if self.confirmChoice == 2 then Chrome.cursor(11, 12) end
                      Chrome.print(Strings("YES"), 5, 12)
                      Chrome.print(Strings("NO"), 12, 12)
                      Chrome.print(Strings("MOVE:CHOOSE A:OK"), 2, 15)
                      Chrome.print(Strings("B:CANCEL"), 6, 16)
                      return
                  end
                  if #self.rows == 0 then
                      Chrome.printWrapped(Strings("No failed encounter areas are available to reroll."), 2, 5, 16, 5)
                  else
                      for slot=1,6 do
                          local i=self.scroll+slot; local r=self.rows[i]
                          if not r then break end
                          local ty=3+(slot-1)*2
                          if i==self.index then Chrome.cursor(1,ty) end
                          Chrome.print(marqueeText(Strings(r.name), 15, 0), 2, ty)
                      end
                  end
                  Chrome.print(Strings("TOKENS %d", tokens), 2, 15)
                  Chrome.print(Strings("A:SELECT B:BACK"), 7, 16)
                  return
              end
              local Font = mod.ui.Font
              local Theme = require("src.ui.Theme")
              love.graphics.setColor(1,1,1,1)
              love.graphics.rectangle("fill",0,0,160,144)
              Font.drawBox(0,0,20,18)
              Font.draw(Strings("REROLL AREA"), 36, 10)
              if self.notice then
                  local lines=wrapText(tostring(self.notice),16); local y=34
                  for i=1,math.min(#lines,6) do Font.draw(lines[i],16,y); y=y+12 end
                  Font.draw(Strings("A/B:BACK"),48,122)
                  return
              end
              if self.phase == "confirm" then
                  local prompt = Strings("Are you sure? This will spend your F. TOKEN on %s.", areaName)
                  local lines=wrapText(tostring(prompt),17); local y=28
                  for i=1,math.min(#lines,6) do Font.draw(lines[i],12,y); y=y+12 end
                  if self.confirmChoice == 1 then Font.drawCode(Theme.cursor, 34, 94) end
                  if self.confirmChoice == 2 then Font.drawCode(Theme.cursor, 98, 94) end
                  Font.draw(Strings("YES"),50,94)
                  Font.draw(Strings("NO"),114,94)
                  Font.draw(Strings("MOVE:CHOOSE"),28,112)
                  Font.draw(Strings("A:OK B:CANCEL"),24,124)
                  return
              end
              if #self.rows == 0 then
                  local lines=wrapText(Strings("No failed encounter areas are available to reroll."),16)
                  local y=42; for i=1,#lines do Font.draw(lines[i],16,y); y=y+12 end
              else
                  for slot=1,6 do
                      local i=self.scroll+slot; local r=self.rows[i]
                      if not r then break end
                      local y=28+(slot-1)*14
                      if i==self.index then Font.drawCode(Theme.cursor,12,y) end
                      Font.draw(marqueeText(Strings(r.name),15,0),30,y)
                  end
              end
              Font.draw(Strings("TOKENS %d",tokens),48,108)
              Font.draw(Strings("A:SELECT B:BACK"),20,124)
          end
          return self
      end,
  })

  mod.content.screens:register("NuzlockeForgivenessItem", {
      new = function(game, ctx)
          local self = {
              game = game,
              screenId = "NuzlockeForgivenessItem",
              isOpaque = true,
              uiModLayout = "classic",
              keepClassicUi = true,
              cursor = 1,
              ctx = ctx or {},
              notice = nil,
          }
          self.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(self)
          self.presentationRole = "forgiveness"
          self.presentationStateOwner = "nuzlocke"
          self.presentationNativeFallback = true
          self.__nuzlockeOwnsForgivenessLayout = true
          function self:update(dt)
              if self.notice then
                  if game.input:wasPressed("a") or game.input:wasPressed("b") then
                      self.notice = nil
                  end
                  return
              end
              if game.input:wasPressed("up") or game.input:wasPressed("down")
                  or game.input:wasPressed("left") or game.input:wasPressed("right") then
                  self.cursor = self.cursor == 1 and 2 or 1
              elseif game.input:wasPressed("b") then
                  game.stack:pop()
              elseif game.input:wasPressed("a") then
                  if self.cursor == 1 then
                      local rows = mod.exports.__beta26.forgivenessAreaRows(game)
                      if #rows == 0 then
                          self.notice = Strings("No failed encounter areas are available to reroll.")
                      else
                          mod.ui.push(game, "NuzlockeForgivenessArea", {
                              onSpent = self.ctx.onSpent,
                          })
                      end
                  else
                      local rows = mod.exports.__beta26.forgivenessDeadRows(game)
                      if #rows == 0 then
                          self.notice = Strings("No fallen Pokemon are available to revive.")
                      else
                          mod.ui.push(game, "NuzlockeForgivenessRevive", {
                              parent = self, rows = rows,
                              onSpent = self.ctx.onSpent,
                          })
                      end
                  end
              end
          end
          function self:draw()
              local rewards = mod.exports.__beta26.TrainerRewards
              local tokens = rewards and rewards.forgivenessTokens
                  and rewards.forgivenessTokens() or 0
              if mod.exports.__beta26.runtimeIsGen2(game) then
                  local Chrome = require("src.ui.gen2.Chrome")
                  Chrome.clear(); Chrome.box(0, 0, 20, 18)
                  Chrome.print(Strings("F. TOKEN"), 6, 2)
                  if self.notice then
                      Chrome.printWrapped(self.notice, 2, 5, 16, 6)
                      Chrome.print(Strings("A/B:BACK"), 5, 15)
                      return
                  end
                  Chrome.printWrapped(Strings("Choose how to spend it."), 2, 5, 16, 2)
                  if self.cursor == 1 then Chrome.cursor(2, 8) end
                  if self.cursor == 2 then Chrome.cursor(2, 10) end
                  Chrome.print(Strings("REROLL ENCOUNTER"), 3, 8)
                  Chrome.print(Strings("REVIVE POKEMON"), 3, 10)
                  Chrome.print(Strings("TOKENS %d", tokens), 4, 13)
                  Chrome.print(Strings("B:CANCEL"), 4, 15)
                  return
              end
              local Font = mod.ui.Font
              -- 2.5.48: use the exact full-page R/B/Y pattern already proven
              -- by Nuzlocke Config/Status/Loadout screens. Font.drawBox takes
              -- TILE coordinates, not pixels; the old (8,10,18,15) call was
              -- therefore drawing the box in the lower-right of the screen.
              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.rectangle("fill", 0, 0, 160, 144)
              Font.drawBox(0, 0, 20, 18)
              Font.draw(Strings("F. TOKEN"), 48, 10)
              if self.notice then
                  local lines = wrapText(tostring(self.notice), 16)
                  local y = 34
                  for i = 1, math.min(#lines, 6) do
                      Font.draw(lines[i], 16, y)
                      y = y + 12
                  end
                  Font.draw(Strings("A/B:BACK"), 48, 122)
              else
                  Font.draw(Strings("Choose how to"), 24, 34)
                  Font.draw(Strings("spend it."), 40, 46)
                  local Theme = require("src.ui.Theme")
                  if self.cursor == 1 then Font.drawCode(Theme.cursor, 12, 70) end
                  if self.cursor == 2 then Font.drawCode(Theme.cursor, 12, 86) end
                  Font.draw(Strings("REROLL ENCOUNTER"), 30, 70)
                  Font.draw(Strings("REVIVE POKEMON"), 30, 86)
                  Font.draw(Strings("TOKENS %d", tokens), 48, 108)
                  Font.draw(Strings("B:CANCEL"), 48, 122)
              end
          end
          return self
      end,
  })

  mod.content.screens:register("NuzlockeForgivenessRevive", {
      new = function(game, ctx)
          local self = {
              game = game,
              screenId = "NuzlockeForgivenessRevive",
              isOpaque = true,
              uiModLayout = "classic",
              keepClassicUi = true,
              ctx = ctx or {},
              rows = (ctx and ctx.rows) or {},
              index = 1,
              scroll = 0,
              notice = nil,
          }
          self.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(self)
          self.presentationRole = "forgiveness_revive"
          self.presentationStateOwner = "nuzlocke"
          self.presentationNativeFallback = true
          self.__nuzlockeOwnsForgivenessLayout = true
          function self:update(dt)
              if self.notice then
                  if game.input:wasPressed("a") or game.input:wasPressed("b") then
                      game.stack:pop()
                      if self.ctx.parent then self.ctx.parent.notice = self.notice end
                  end
                  return
              end
              local count = #self.rows
              if game.input:wasPressed("up") and count > 0 then
                  self.index = self.index <= 1 and count or self.index - 1
              elseif game.input:wasPressed("down") and count > 0 then
                  self.index = self.index >= count and 1 or self.index + 1
              elseif game.input:wasPressed("b") then
                  game.stack:pop()
              elseif game.input:wasPressed("a") and self.rows[self.index] then
                  local ok, message = mod.exports.__beta26.reviveWithForgiveness(
                      game, self.rows[self.index].pokemonId)
                  self.notice = message
                  if ok and type(self.ctx.onSpent) == "function" then
                      pcall(self.ctx.onSpent)
                  end
              end
              if self.index <= self.scroll then self.scroll = self.index - 1 end
              if self.index > self.scroll + 5 then self.scroll = self.index - 5 end
          end
          function self:draw()
              if mod.exports.__beta26.runtimeIsGen2(game) then
                  local Chrome = require("src.ui.gen2.Chrome")
                  Chrome.clear(); Chrome.box(0,0,20,18)
                  Chrome.print(Strings("REVIVE WHO?"), 5, 2)
                  if self.notice then
                      Chrome.printWrapped(self.notice,2,5,16,6)
                      Chrome.print(Strings("A/B:BACK"),5,15)
                      return
                  end
                  for n=1,5 do
                      local i=self.scroll+n; local row=self.rows[i]
                      if row then
                          if i==self.index then Chrome.cursor(1,4+n*2) end
                          Chrome.print(string.format("%s L%s", row.name,
                              row.level and tostring(math.floor(row.level)) or "?"),
                              2,4+n*2)
                      end
                  end
                  Chrome.print(Strings("B:CANCEL"),5,16)
                  return
              end
              local Font=mod.ui.Font
              love.graphics.setColor(1,1,1,1)
              love.graphics.rectangle("fill",0,0,160,144)
              Font.drawBox(0,0,20,18)
              Font.draw(Strings("REVIVE WHO?"),36,10)
              if self.notice then
                  local lines = wrapText(tostring(self.notice), 16)
                  local y = 34
                  for i = 1, math.min(#lines, 6) do
                      Font.draw(lines[i], 16, y); y = y + 12
                  end
                  Font.draw(Strings("A/B:BACK"),48,122)
              else
                  for n=1,5 do
                      local i=self.scroll+n; local row=self.rows[i]
                      if row then
                          local y = 38 + n * 14
                          if i == self.index then
                              Font.drawCode((require("src.ui.Theme")).cursor, 12, y)
                          end
                          local label=string.format("%s L%s", row.name,
                              row.level and tostring(math.floor(row.level)) or "?")
                          Font.draw(label,30,y)
                      end
                  end
                  Font.draw(Strings("B: CANCEL"),48,122)
              end
              love.graphics.setColor(1,1,1,1)
          end
          return self
      end,
  })


  return true
end
