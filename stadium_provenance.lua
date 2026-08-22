return function(mod, deps)
  deps = deps or {}
  local API = {
    version = 2,
    key = "stadium_prize",
    display = "STADIUM PRIZE",
  }

  local function normalizeOrigin(origin)
    local raw = tostring(origin or ""):lower()
    if raw == "stadium1" or raw == "stadium_1" or raw == "stadium 1" then return "stadium_1" end
    if raw == "stadium2" or raw == "stadium_2" or raw == "stadium 2" then return "stadium_2" end
    return nil
  end

  local function exactEdition(game)
    if type(deps.getGameVersion) == "function" then
      local ok, value = pcall(deps.getGameVersion, game)
      if ok and value ~= nil and tostring(value) ~= "" then
        return tostring(value):lower()
      end
    end
    return "unknown"
  end

  local function findLoaded(ids)
    if type(deps.findMod) ~= "function" then return nil, nil end
    for _, id in ipairs(ids) do
      local ok, found = pcall(deps.findMod, id)
      if ok and found then return found, id end
    end
    return nil, nil
  end

  local function exportsOf(found)
    return type(found) == "table" and type(found.exports) == "table"
        and found.exports or {}
  end

  -- Presentation/importer compatibility is deliberately distinct from Pokemon
  -- acquisition provenance. Loading Stadium models must never relabel ordinary
  -- party Pokemon as Stadium prizes. A real transfer/import path must call
  -- mark()/markImported() (or preserve those fields itself) for the Pokemon it
  -- actually creates.
  function API.compatibilitySnapshot(game)
    local rows = {}
    local function add(kind, found, id, origin, details)
      if not found then return end
      details = details or {}
      rows[#rows + 1] = {
        kind = kind,
        id = id,
        origin = origin,
        active = details.active ~= false,
        importer = details.importer == true,
        renderer = details.renderer == true,
        presentation_only = details.presentation_only ~= false,
        target_generation = details.target_generation,
        max_dex = details.max_dex,
      }
    end

    local stadium1, stadium1Id = findLoaded({
      "STADIUM_OVERWORLD_MODELS", "stadium_overworld_models",
    })
    if stadium1 then
      local ex = exportsOf(stadium1)
      add("stadium_overworld_models", stadium1, stadium1Id, "stadium_1", {
        importer = type(ex.chooseStadiumRom) == "function" or type(ex.romMenu) == "table",
        renderer = ex.rendererInstalled == true or type(ex.overworld) == "table",
        active = ex.active ~= false,
        max_dex = tonumber(ex.maxDex) or 151,
      })
    end

    local viewer, viewerId = findLoaded({
      "STADIUM_UI_MODEL_VIEWER", "stadium_ui_model_viewer",
    })
    if viewer then
      local ex = exportsOf(viewer)
      add("stadium_ui_model_viewer", viewer, viewerId, nil, {
        importer = false,
        renderer = ex.rendererInstalled ~= false,
        active = ex.active ~= false,
      })
    end

    local stadium2, stadium2Id = findLoaded({
      "STADIUM2_OVERWORLD_MODELS", "stadium2_overworld_models",
    })
    if stadium2 then
      local ex = exportsOf(stadium2)
      add("stadium2_overworld_models", stadium2, stadium2Id, "stadium_2", {
        importer = ex.stadium2Importer == true or type(ex.chooseStadiumRom) == "function",
        renderer = ex.rendererInstalled == true or type(ex.overworld) == "table",
        active = ex.active ~= false,
        target_generation = tonumber(ex.targetGeneration) or tonumber(ex.generation),
        max_dex = tonumber(ex.maxDex) or 251,
      })
    end

    local crystal, crystalId = findLoaded({ "CRYSTAL_251", "crystal_251" })
    if crystal then
      local ex = exportsOf(crystal)
      local bridge = ex.crystalStadium2
      add("crystal_251_stadium_bridge", crystal, crystalId,
          type(bridge) == "table" and "stadium_2" or nil, {
        importer = type(bridge) == "table",
        renderer = type(bridge) == "table",
        active = true,
        target_generation = 1, -- Crystal 251 overlays the running R/B/Y engine edition.
        max_dex = tonumber(ex.dexSize) or 251,
      })
    end

    local preferredOrigin = nil
    for _, row in ipairs(rows) do
      if row.active and row.origin == "stadium_2" then
        preferredOrigin = "stadium_2"
        break
      elseif row.active and row.origin == "stadium_1" then
        preferredOrigin = preferredOrigin or "stadium_1"
      end
    end

    return {
      version = API.version,
      edition = exactEdition(game),
      rows = rows,
      preferred_origin = preferredOrigin,
      acquisition_policy = "explicit_only",
    }
  end

  function API.mark(mon, origin, context)
    if type(mon) ~= "table" then return false, "missing_pokemon" end
    if type(deps.canWrite) == "function" and deps.canWrite() ~= true then
      return false, "persistence_blocked"
    end
    local normalized = normalizeOrigin(origin)
    -- v1 accepted unknown/missing origin while still marking the shared Stadium
    -- acquisition source. Preserve that compatibility; markImported() is the
    -- stricter helper for callers that promise a real Stadium 1/2 import.
    context = type(context) == "table" and context or {}

    deps.setPokemonOrigin(mon, "STADIUM_PRIZE")
    mon.nuzlockeEncounterSource = "STADIUM_PRIZE"
    mon.nuzlockeAcquisitionSource = "stadium_prize"
    if normalized then mon.nuzlockeAcquisitionOrigin = normalized end

    local providerId = context.provider_id or context.providerId or context.mod_id or context.modId
    if providerId ~= nil and tostring(providerId) ~= "" then
      mon.nuzlockeAcquisitionProvider = tostring(providerId)
    end
    local edition = context.edition or exactEdition(context.game)
    if edition and edition ~= "unknown" and tostring(edition) ~= "" then
      mon.nuzlockeAcquisitionEdition = tostring(edition):lower()
    end

    return true, {
      source = "stadium_prize",
      origin = normalized,
      provider_id = mon.nuzlockeAcquisitionProvider,
      edition = mon.nuzlockeAcquisitionEdition,
      display = API.display,
    }
  end

  function API.markImported(mon, context)
    context = type(context) == "table" and context or {}
    local origin = normalizeOrigin(context.origin)
    if not origin and context.use_detected_origin == true then
      local snapshot = API.compatibilitySnapshot(context.game)
      origin = normalizeOrigin(snapshot and snapshot.preferred_origin)
    end
    if not origin then return false, "stadium_origin_required" end
    return API.mark(mon, origin, context)
  end

  function API.describe(mon)
    if type(mon) ~= "table" then return nil end
    if mon.nuzlockeAcquisitionSource == "stadium_prize"
        or mon.nuzlockeOrigin == "STADIUM_PRIZE" then
      return {
        source = "stadium_prize",
        origin = normalizeOrigin(mon.nuzlockeAcquisitionOrigin),
        provider_id = mon.nuzlockeAcquisitionProvider,
        edition = mon.nuzlockeAcquisitionEdition,
        display = API.display,
      }
    end
    return nil
  end

  mod.exports.nuzlocke_acquisition_provenance = API
  mod.exports.__beta26.StadiumPrize = API
  return API
end
