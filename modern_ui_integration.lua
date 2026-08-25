-- Optional Gen1 Modern UI presentation adapter for Nuzlocke.
--
-- Nuzlocke remains the source of truth for every row and semantic action.
-- This module never changes challenge rules, encounters, saves, or input state.
-- If the provider is absent/unsupported, native Nuzlocke screens remain intact.

return function(mod, deps)
    deps = deps or {}
    local Strings = deps.translate or function(v) return tostring(v) end


    ---------------------------------------------------------------------
    -- TYPOGRAPHY PROVIDER COMPATIBILITY
    --
    -- Nuzlocke does not own glyph advances or kerning.  Compatible font and
    -- typography mods remain authoritative; Nuzlocke presentation consumes
    -- the live Font metrics through nuzlocke_ui_system.lua.
    ---------------------------------------------------------------------

    local function confirmedGen1(game)
        if not game or type(deps.isGen2) ~= "function" then return false end
        local ok, gen2 = pcall(deps.isGen2, game)
        return ok and gen2 == false
    end

    local function provider()
        if type(mod.find) ~= "function" then return nil end
        local ok, handle = pcall(mod.find, "gen1_modern_ui")
        if not ok or type(handle) ~= "table" then return nil end
        local exports = handle.exports
        if type(exports) ~= "table"
            or type(exports.registerAdapter) ~= "function" then
            return nil
        end
        return handle
    end

    local function model(game, state)
        if not confirmedGen1(game or mod.game) then return nil end
        if type(state) ~= "table"
            or type(state.nuzlockeModernUiModel) ~= "function" then
            return nil
        end
        local ok, result = pcall(state.nuzlockeModernUiModel, state)
        if not ok or type(result) ~= "table" then return nil end
        return result
    end

    local function action(name)
        return function(game, state, payload)
            if not confirmedGen1(game or mod.game) then return false end
            if type(state) ~= "table"
                or type(state.nuzlockeModernUiAction) ~= "function" then
                return false
            end
            local ok, result = pcall(
                state.nuzlockeModernUiAction, state, name, payload)
            return ok and result == true
        end
    end

    local sharedActions = {
        up = action("up"),
        down = action("down"),
        left = action("left"),
        right = action("right"),
        select = action("select"),
        back = action("back"),
        start = action("start"),
    }

    mod.exports.gen1ModernUi = {
        apiVersion = 1,
        screens = {
            NuzlockeTrackerScreen = {
                match = function(state)
                    return type(state) == "table"
                        and state.screenId == "NuzlockeTrackerScreen"
                end,
                model = model,
                actions = sharedActions,
                layer = "screen",
                canSuppressNative = true,
            },
            NuzlockeCatchInfoScreen = {
                match = function(state)
                    return type(state) == "table"
                        and state.screenId == "NuzlockeCatchInfoScreen"
                end,
                model = model,
                actions = sharedActions,
                layer = "screen",
                canSuppressNative = true,
            },
            NuzlockeTrainerCardScreen = {
                match = function(state)
                    return type(state) == "table"
                        and state.screenId == "NuzlockeTrainerCardScreen"
                end,
                model = model,
                actions = sharedActions,
                layer = "screen",
                canSuppressNative = true,
            },
        },
    }

    mod.exports.__beta26.ModernUiIntegration =
        mod.exports.__beta26.ModernUiIntegration or {}
    local state = mod.exports.__beta26.ModernUiIntegration
    state.contract = mod.exports.gen1ModernUi

    local function noteProviderHealth(status, reason)
        local beta = mod.exports and mod.exports.__beta26
        if beta and type(beta.noteFeatureHealth) == "function" then
            pcall(beta.noteFeatureHealth, "integration.modern_ui_provider",
                status, reason, "modern_ui_integration")
        end
    end

    function state.tryRegister(gameHint)
        local game = mod.game
        if type(gameHint) == "table" then
            if type(gameHint.game) == "table" then
                game = gameHint.game
            elseif gameHint.save ~= nil and gameHint.input ~= nil then
                game = gameHint
            end
        end

        -- Unknown generation is never permission to register a Gen1-only
        -- adapter. Lifecycle events retry once the active game is known.
        if not game then
            state.active = false
            state.status = "PENDING"
            state.lastError = "game not ready"
            return false, state.lastError
        end
        if type(deps.isGen2) ~= "function" then
            state.active = false
            state.status = "DEGRADED"
            state.lastError = "generation resolver unavailable"
            return false, state.lastError
        end
        local okGen2, gen2 = pcall(deps.isGen2, game)
        if not okGen2 then
            state.active = false
            state.status = "PENDING"
            state.lastError = "generation unresolved"
            return false, state.lastError
        end
        if gen2 == true then
            -- The provider may not expose an unregister contract. Keep the
            -- historical registration marker, but make every adapter callback
            -- inert while Gen 2 is active.
            state.active = false
            state.status = "N/A"
            state.lastError = "gen1 only"
            return false, state.lastError
        end

        -- Re-discover the provider on every lifecycle retry. A successful
        -- registration is only authoritative for the exact provider handle
        -- that accepted it; provider reload/replacement must re-register.
        local ui = provider()
        if not ui then
            state.registered = false
            state.registeredProvider = nil
            state.registeredExports = nil
            state.registeredRegisterAdapter = nil
            state.active = false
            state.status = "PENDING"
            state.providerId = nil
            state.lastError = "provider unavailable"
            return false, state.lastError
        end
        local exports = ui.exports
        local registerAdapter = type(exports) == "table"
            and exports.registerAdapter or nil
        if state.registered
            and state.registeredProvider == ui
            and state.registeredExports == exports
            and state.registeredRegisterAdapter == registerAdapter then
            state.active = true
            state.status = "ACTIVE"
            state.providerId = "gen1_modern_ui"
            state.lastError = nil
            return true
        end
        state.registered = false
        state.registeredProvider = nil
        state.registeredExports = nil
        state.registeredRegisterAdapter = nil

        local ok, registered, reason = pcall(
            registerAdapter, {
                owner = mod.id or "nuzlocke",
                contract = mod.exports.gen1ModernUi,
            })
        if not ok then
            state.active = false
            state.status = "DEGRADED"
            state.providerId = nil
            state.lastError = tostring(registered)
            return false, state.lastError
        end
        -- The provider's released contract returns explicit true on success
        -- and false, reason on refusal. Treat nil/other values as failure so a
        -- provider-side early return cannot leave us reporting a phantom link.
        if registered ~= true then
            state.registered = false
            state.registeredProvider = nil
            state.registeredExports = nil
            state.registeredRegisterAdapter = nil
            state.active = false
            state.status = "DEGRADED"
            state.providerId = nil
            state.lastError = tostring(reason or "registration refused")
            return false, state.lastError
        end
        state.registered = true
        state.registeredProvider = ui
        state.registeredExports = exports
        state.registeredRegisterAdapter = registerAdapter
        state.active = true
        state.status = "ACTIVE"
        state.providerId = "gen1_modern_ui"
        state.lastError = nil
        return true
    end

    -- Retry because load order is intentionally not a dependency. Registration
    -- itself is one-shot; later lifecycle calls only refresh current activity.
    -- 2.3.12: provider registration begins at lifecycle events below.
    if mod.events and type(mod.events.on) == "function" then
        local function retryRegister(ev)
            local ok, registered, reason = pcall(state.tryRegister, ev)
            if not ok then
                state.active = false
                state.status = "DEGRADED"
                state.lastError = tostring(registered)
                noteProviderHealth("DEGRADED",
                    "provider registration exception: " .. tostring(registered))
                return false
            end
            if registered == true then
                noteProviderHealth("ACTIVE", "provider registration active")
                return true
            end
            noteProviderHealth(state.status or "DEGRADED",
                tostring(reason or state.lastError or "registration unavailable"))
            return false
        end
        mod.events:on("mods.loaded", retryRegister)
        mod.events:on("game.ready", retryRegister)
        mod.events:on("save.loaded", retryRegister)
    end
end
