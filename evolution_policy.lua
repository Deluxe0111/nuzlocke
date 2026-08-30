-- Module owner: EvolutionPolicy
-- Evolution Limits and Trade Evolution QoL over the shared evolution.check seam.
-- Randomizer evolution mappings, UI/config rendering, Pokemon identity, and acquisition policy remain external.
return function(mod, deps)
  deps = type(deps) == "table" and deps or {}
  local defaultRuleValue = assert(deps.defaultRuleValue, "EvolutionPolicy requires defaultRuleValue")
  local getCurrentGame = assert(deps.getCurrentGame, "EvolutionPolicy requires getCurrentGame")
  local runtimeIsGen2 = assert(deps.runtimeIsGen2, "EvolutionPolicy requires runtimeIsGen2")
  local shouldEnforce = assert(deps.shouldEnforce, "EvolutionPolicy requires shouldEnforce")

  local function evolutionLimitMode()
      return math.max(0, math.min(2, math.floor(tonumber(
          mod.save:get("evolution_limit", defaultRuleValue("evolution_limit"))) or 0)))
  end

  local function evolutionTargetId(evo)
      if type(evo) ~= "table" then return nil end
      local species = evo.species or evo.into
      if type(species) == "table" then species = species.id or species.key or species.name end
      if species == nil then return nil end
      species = tostring(species):upper()
      return species ~= "" and species or nil
  end

  mod.exports.__beta26.tradeEvolutionLevel = 40

  function mod.exports.__beta26.tradeEvolutionRow(evo)
      if type(evo) ~= "table" or evo.method == nil then return false end
      local method = tostring(evo.method):upper()
      return method == "TRADE" or method == "EVOLVE_TRADE"
  end

  function mod.exports.__beta26.evolutionHookGame(gameOrData)
      if type(gameOrData) == "table" and type(gameOrData.save) == "table" then
          return gameOrData
      end
      return getCurrentGame()
  end

  function mod.exports.__beta26.evolutionHookData(gameOrData, game)
      if type(gameOrData) == "table" and type(gameOrData.pokemon) == "table" then
          return gameOrData
      end
      return game and game.data or nil
  end

  function mod.exports.__beta26.tradeEvolutionQolEnabled()
      return mod.save:get("trade_evolutions", defaultRuleValue("trade_evolutions")) == true
  end

  function mod.exports.__beta26.tradeEvolutionByLevelAllows(gameOrData, mon, evo, trigger)
      if not mod.exports.__beta26.tradeEvolutionQolEnabled() or type(mon) ~= "table"
          or not mod.exports.__beta26.tradeEvolutionRow(evo) then return false end
      if math.floor(tonumber(mon.level) or 0) < mod.exports.__beta26.tradeEvolutionLevel then
          return false
      end

      local game = mod.exports.__beta26.evolutionHookGame(gameOrData)
      local method = type(evo) == "table" and tostring(evo.method or ""):upper() or ""
      local gold = (game and runtimeIsGen2(game)) or method == "EVOLVE_TRADE"
      trigger = type(trigger) == "table" and trigger or {}

      if trigger.kind ~= "levelup" or trigger.link or trigger.force then
          return false
      end
      if gold then
          if mon.item == "EVERSTONE" then return false end
          if evo.item ~= nil and mon.item ~= evo.item then return false end
      end
      return true
  end

  function mod.exports.__beta26.blockCompetingGoldLevelBranch(gameOrData, mon, evo, trigger)
      if not mod.exports.__beta26.tradeEvolutionQolEnabled() or type(mon) ~= "table" then
          return false
      end
      if type(evo) ~= "table" or tostring(evo.method or ""):upper() ~= "EVOLVE_LEVEL" then
          return false
      end
      trigger = type(trigger) == "table" and trigger or {}
      if trigger.kind ~= "levelup" or trigger.link or trigger.force
          or mon.item == nil then return false end
      local game = mod.exports.__beta26.evolutionHookGame(gameOrData)
      if not ((game and runtimeIsGen2(game))
          or (type(gameOrData) == "table" and type(gameOrData.pokemon) == "table")) then
          return false
      end
      local data = mod.exports.__beta26.evolutionHookData(gameOrData, game)
      local def = data and data.pokemon and data.pokemon[mon.species]
      for _, candidate in ipairs(type(def) == "table" and def.evolutions or {}) do
          if mod.exports.__beta26.tradeEvolutionRow(candidate) and candidate.item ~= nil
              and candidate.item == mon.item then
              return true
          end
      end
      return false
  end

  mod.exports.__beta26.evolutionLimitAllows = function(game, evo, mode)
      mode = math.max(0, math.min(2, math.floor(tonumber(mode) or evolutionLimitMode())))
      if mode <= 0 then return true end
      if mode >= 2 then return false end
      local target = evolutionTargetId(evo)
      local pokemon = game and game.data and game.data.pokemon
      local def = target and type(pokemon) == "table" and pokemon[target] or nil
      if type(def) ~= "table" or type(def.evolutions) ~= "table" then return true end
      local methods = game and game.data and (game.data.evolution_methods or game.data.gen2EvolutionMethods)
      if type(methods) ~= "table" then
          local okEvolution, Evolution = pcall(require, "src.pokemon.Evolution")
          methods = okEvolution and Evolution and Evolution.METHODS or nil
      end
      if type(methods) ~= "table" then return true end
      for _, nextEvo in ipairs(def.evolutions) do
          local method = type(nextEvo) == "table" and methods[nextEvo.method] or nil
          local nextTarget = evolutionTargetId(nextEvo)
          if type(method) == "table" and type(method.check) == "function"
              and nextTarget and type(pokemon[nextTarget]) == "table" then
              return true
          end
      end
      return false
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
      mod.hooks:wrap("evolution.check", function(next, gameOrData, mon, evo, trigger)
          local game = mod.exports.__beta26.evolutionHookGame(gameOrData)
          local vanilla = next(gameOrData, mon, evo, trigger)

          if vanilla == true and mod.exports.__beta26.blockCompetingGoldLevelBranch(
              gameOrData, mon, evo, trigger) then
              vanilla = false
          end

          if vanilla ~= true and mod.exports.__beta26.tradeEvolutionByLevelAllows(
              gameOrData, mon, evo, trigger) then
              vanilla = true
          end

          if vanilla ~= true or not shouldEnforce(game) then return vanilla end
          local mode = evolutionLimitMode()
          if mode <= 0 then return vanilla end
          return mod.exports.__beta26.evolutionLimitAllows(game, evo, mode) and vanilla or false
      end, 100)
  end

  return {
      evolutionLimitMode = evolutionLimitMode,
      evolutionTargetId = evolutionTargetId,
  }
end
