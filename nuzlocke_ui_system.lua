-- Module owner: NuzlockeUiSystem
-- Experimental Nuzlocke-owned presentation system.
-- Gameplay/rule authority is intentionally out of scope: this module only
-- describes layout ownership and renders semantic chrome for screens Nuzlocke owns.

return function(mod, deps)
    deps = deps or {}
    local Strings = deps.Strings or function(v) return tostring(v) end

    local UI = {
        apiVersion = 8,
        presentationContractVersion = 1,
        inputContractVersion = 1,
        build = true,
        composition = { classic = 160, wide = 304 },
        spacing = { edge = 8, row = 16, section = 8 },
        policies = {},
    }

    -- Input semantics are descriptive contracts for Nuzlocke-owned screens.
    -- They do not intercept engine input or alter another mod's repeat timing.
    -- Consumers may use them to distinguish repeat-safe navigation/value
    -- stepping from edge-only activation and destructive confirmation.
    UI.inputModes = {
        repeat_safe = "repeat_safe",
        edge_only = "edge_only",
        disabled = "disabled",
    }

    -- Presentation ownership contract. These values describe who is allowed
    -- to render a surface; they never grant gameplay/controller authority.
    UI.presentationOwners = {
        nuzlocke = "nuzlocke",
        engine = "engine",
        external_allowed = "external_allowed",
        compose = "compose",
    }

    UI.presentationSurfaces = {
        nuzlocke_screens = {
            presentation = "nuzlocke",
            controller = "nuzlocke",
            gameplayAuthority = false,
        },
        party = {
            presentation = "external_allowed",
            controller = "engine",
            gameplayAuthority = false,
        },
        pc = {
            presentation = "external_allowed",
            controller = "engine",
            gameplayAuthority = false,
        },
        pokedex = {
            presentation = "external_allowed",
            controller = "engine",
            gameplayAuthority = false,
        },
        bag = {
            presentation = "external_allowed",
            controller = "engine",
            gameplayAuthority = false,
        },
        mart = {
            presentation = "external_allowed",
            controller = "engine",
            gameplayAuthority = false,
        },
        battle_art = {
            presentation = "external_allowed",
            controller = "engine",
            gameplayAuthority = false,
        },
        battle_hud = {
            presentation = "external_allowed",
            controller = "engine",
            gameplayAuthority = false,
        },
        overworld_render = {
            presentation = "external_allowed",
            controller = "engine",
            gameplayAuthority = false,
        },
        list_menu = {
            presentation = "compose",
            controller = "engine",
            gameplayAuthority = false,
        },
        trainer_party = {
            presentation = "external_allowed",
            controller = "engine",
            gameplayAuthority = "nuzlocke_randomizer_when_enabled",
        },
    }

    function UI.presentationPolicyFor(surface)
        local key = tostring(surface or "")
        local policy = UI.presentationSurfaces[key]
        if type(policy) ~= "table" then
            return {
                presentation = UI.presentationOwners.engine,
                controller = UI.presentationOwners.engine,
                gameplayAuthority = false,
            }
        end
        return {
            presentation = policy.presentation,
            controller = policy.controller,
            gameplayAuthority = policy.gameplayAuthority,
        }
    end

    function UI.externalPresentationAllowed(surface)
        local policy = UI.presentationPolicyFor(surface)
        return policy.presentation == UI.presentationOwners.external_allowed
            or policy.presentation == UI.presentationOwners.compose
    end

    function UI.gameplayAuthorityFor(surface)
        return UI.presentationPolicyFor(surface).gameplayAuthority
    end

    function UI.presentationOwnsGameplay(surface)
        local authority = UI.gameplayAuthorityFor(surface)
        -- This boolean helper reports only unconditional ownership. Conditional
        -- descriptors such as "nuzlocke_randomizer_when_enabled" must remain
        -- descriptive until the owning gameplay subsystem resolves its state.
        return authority == true or authority == "nuzlocke"
    end

    UI.inputProfiles = {
        navigation = {
            vertical = "repeat_safe", horizontal = "disabled",
            activate = "edge_only", back = "edge_only",
            destructive = false,
        },
        values = {
            vertical = "repeat_safe", horizontal = "repeat_safe",
            activate = "edge_only", back = "edge_only",
            destructive = false,
        },
        pager = {
            vertical = "repeat_safe", horizontal = "repeat_safe",
            activate = "edge_only", back = "edge_only",
            destructive = false,
        },
        confirmation = {
            vertical = "repeat_safe", horizontal = "disabled",
            activate = "edge_only", back = "edge_only",
            destructive = false,
        },
        destructive_confirmation = {
            vertical = "repeat_safe", horizontal = "disabled",
            activate = "edge_only", back = "edge_only",
            destructive = true,
        },
        action = {
            vertical = "disabled", horizontal = "disabled",
            activate = "edge_only", back = "edge_only",
            destructive = false,
        },
    }

    local function normalizedInputPolicy(policy)
        policy = type(policy) == "table" and policy or {}
        local requestedProfile = policy.profile and tostring(policy.profile) or "navigation"
        local profile = UI.inputProfiles[requestedProfile]
        local resolvedProfile = profile and requestedProfile or "navigation"
        profile = profile or UI.inputProfiles.navigation
        return {
            profile = resolvedProfile,
            vertical = tostring(policy.vertical or profile.vertical),
            horizontal = tostring(policy.horizontal or profile.horizontal),
            activate = tostring(policy.activate or profile.activate),
            back = tostring(policy.back or profile.back),
            destructive = policy.destructive == true
                or (policy.destructive == nil and profile.destructive == true),
        }
    end

    local function fallbackWidth(text)
        return #tostring(text or "") * 8
    end

    function UI.typography(Font)
        local T = {}
        function T.measure(text)
            text = tostring(Strings(text or ""))
            if Font and type(Font.width) == "function" then
                local ok, width = pcall(Font.width, text)
                if ok and type(width) == "number" then return width end
            end
            return fallbackWidth(text)
        end
        function T.fit(text, budget, suffix)
            text = tostring(Strings(text or ""))
            budget = math.max(0, math.floor(tonumber(budget) or 0))
            suffix = tostring(suffix == nil and "..." or suffix)
            if T.measure(text) <= budget then return text end
            if budget <= 0 then return "" end

            -- Prefer the engine glyph-span API so variable-width and multibyte
            -- translation text is never truncated at an arbitrary byte.
            if Font and type(Font.split) == "function"
                and type(Font.spansFitting) == "function" then
                local okSplit, spans = pcall(Font.split, text)
                if okSplit and type(spans) == "table" and #spans > 0 then
                    local suffixWidth = T.measure(suffix)
                    local contentBudget = math.max(0, budget - suffixWidth)
                    local okFit, count = pcall(Font.spansFitting, spans, contentBudget)
                    count = okFit and math.max(0, math.floor(tonumber(count) or 0)) or 0
                    if count <= 0 then
                        return suffixWidth <= budget and suffix or ""
                    end
                    local last = spans[math.min(#spans, count)]
                    local fitted = last and last.to and text:sub(1, last.to) or ""
                    return fitted .. suffix
                end
            end

            -- Fallback path stays UTF-8 boundary-safe when the runtime exposes
            -- Lua's utf8 library. Byte truncation is used only as a final
            -- compatibility fallback for legacy single-byte fonts.
            local function removeLastGlyph(value)
                if type(utf8) == "table" and type(utf8.offset) == "function" then
                    local okOffset, pos = pcall(utf8.offset, value, -1)
                    if okOffset and type(pos) == "number" then
                        return value:sub(1, pos - 1)
                    end
                end
                return value:sub(1, -2)
            end
            while text ~= "" and T.measure(text .. suffix) > budget do
                text = removeLastGlyph(text)
            end
            if text == "" and T.measure(suffix) > budget then return "" end
            return text .. suffix
        end
        function T.rightX(text, rightEdge)
            return math.floor((tonumber(rightEdge) or 0) - T.measure(text))
        end
        function T.centerX(text, leftEdge, rightEdge)
            leftEdge = tonumber(leftEdge) or 0
            rightEdge = tonumber(rightEdge) or leftEdge
            if rightEdge < leftEdge then
                leftEdge, rightEdge = rightEdge, leftEdge
            end
            local width = T.measure(text)
            return math.floor(leftEdge + ((rightEdge - leftEdge) - width) / 2)
        end
        function T.wrap(text, budget)
            text = tostring(Strings(text or ""))
            budget = math.max(1, math.floor(tonumber(budget) or 1))
            if T.measure(text) <= budget then return { text } end
            local words = {}
            for word in text:gmatch("%S+") do words[#words + 1] = word end
            if #words == 0 then return { "" } end
            local lines, line = {}, ""
            for _, word in ipairs(words) do
                local candidate = line == "" and word or (line .. " " .. word)
                if line == "" or T.measure(candidate) <= budget then
                    line = candidate
                else
                    lines[#lines + 1] = T.fit(line, budget, "")
                    line = word
                    if T.measure(line) > budget then
                        lines[#lines + 1] = T.fit(line, budget)
                        line = ""
                    end
                end
            end
            if line ~= "" then lines[#lines + 1] = T.fit(line, budget, "") end
            return lines
        end
        return T
    end

    local function fit(Font, text, budget)
        return UI.typography(Font).fit(text, budget)
    end

    local function edition(game)
        local Dev = mod.exports and mod.exports.__beta26 and mod.exports.__beta26.Dev
        if Dev and type(Dev.gameLabel) == "function" then
            local ok, label = pcall(Dev.gameLabel, game)
            if ok and label ~= nil then return tostring(label) end
        end
        return "UNKNOWN"
    end

    local function wideExports()
        if type(mod.find) ~= "function" then return nil end
        local ok, wide = pcall(mod.find, "wide-menus")
        if not ok or type(wide) ~= "table" or type(wide.exports) ~= "table" then
            return nil
        end
        return wide.exports
    end

    function UI.registerPolicy(screenId, policy)
        screenId = tostring(screenId or "")
        if screenId == "" then return false end
        policy = type(policy) == "table" and policy or { mode = policy }
        UI.policies[screenId] = {
            mode = tostring(policy.mode or "classic"),
            role = policy.role and tostring(policy.role) or nil,
            inheritParent = policy.inheritParent == true,
            input = normalizedInputPolicy(policy.input),
        }
        local wide = wideExports()
        if wide and type(wide.register) == "function" then
            local mode = UI.policies[screenId].mode
            if mode == "adaptive" then mode = "wide" end
            if mode ~= "wide" and mode ~= "centered" then mode = "classic" end
            pcall(wide.register, screenId, mode)
        end
        return true
    end

    function UI.policyFor(screenId)
        return UI.policies[tostring(screenId or "")] or {
            mode = "classic",
            input = normalizedInputPolicy({ profile = "navigation" }),
        }
    end

    function UI.inputPolicyFor(screenId)
        local policy = UI.policyFor(screenId)
        return policy.input or normalizedInputPolicy({ profile = "navigation" })
    end

    function UI.isRepeatSafe(screenId, axis)
        local input = UI.inputPolicyFor(screenId)
        axis = tostring(axis or ""):lower()
        if axis == "up" or axis == "down" or axis == "vertical" then
            return input.vertical == UI.inputModes.repeat_safe
        end
        if axis == "left" or axis == "right" or axis == "horizontal" then
            return input.horizontal == UI.inputModes.repeat_safe
        end
        return false
    end

    function UI.requiresEdge(screenId, action)
        local input = UI.inputPolicyFor(screenId)
        action = tostring(action or "activate"):lower()
        if action == "back" or action == "cancel" then
            return input.back == UI.inputModes.edge_only
        end
        return input.activate == UI.inputModes.edge_only
    end

    function UI.isDestructive(screenId)
        return UI.inputPolicyFor(screenId).destructive == true
    end

    function UI.applyInputContract(screen, screenId)
        if type(screen) ~= "table" then return screen end
        screenId = tostring(screenId or screen.screenId or "")
        screen.nuzInputContractVersion = UI.inputContractVersion
        screen.nuzInputPolicy = UI.inputPolicyFor(screenId)
        return screen
    end

    function UI.layoutContext(state, requestedMode, parent)
        local policy = UI.policyFor(state and state.screenId)
        local mode = tostring(requestedMode or policy.mode or "classic")
        if policy.inheritParent and parent and parent.layoutContext then
            mode = tostring(parent.layoutContext.mode or mode)
        end

        local width, height = UI.composition.classic, 144
        local wide = wideExports()
        if mode == "adaptive" or mode == "wide" then
            if wide and type(wide.size) == "function" then
                local ok, w, h = pcall(wide.size)
                if ok and tonumber(w) then
                    width, height = tonumber(w), tonumber(h) or height
                end
            end
        end
        if mode == "centered" then width = UI.composition.classic end

        local resolved = width >= UI.composition.wide and "wide" or "classic"
        return {
            mode = resolved,
            requestedMode = mode,
            logicalWidth = width,
            logicalHeight = height,
            columns = resolved == "wide" and 38 or 20,
            parentMode = parent and parent.layoutContext
                and parent.layoutContext.mode or nil,
        }
    end

    function UI.applyLayout(state, requestedMode, parent)
        if type(state) ~= "table" then return nil end
        local policy = UI.policyFor(state.screenId)
        local mode = tostring(requestedMode or policy.mode or "classic")
        if policy.inheritParent and parent and parent.layoutContext then
            mode = parent.layoutContext.mode == "wide" and "wide" or "centered"
        end
        state.layoutContext = UI.layoutContext(state, mode, parent)

        -- Wide Menus public contract. Nuzlocke screen code remains provider-
        -- agnostic: only this adapter knows the external API.
        local wide = wideExports()
        local claimMode = (mode == "adaptive" or mode == "wide")
            and (state.layoutContext.mode == "wide" and "wide" or "classic")
            or mode
        if claimMode == "wide" then
            state.uiModLayout = "wide"
            state.keepClassicUi = nil
            if wide and type(wide.claim) == "function" then pcall(wide.claim, state) end
        elseif claimMode == "centered" then
            state.uiModLayout = "centered"
            state.keepClassicUi = true
            if wide and type(wide.claimCentered) == "function" then
                pcall(wide.claimCentered, state)
            end
        else
            state.uiModLayout = "classic"
            state.keepClassicUi = true
            if wide and type(wide.refuse) == "function" then pcall(wide.refuse, state) end
        end
        return state.layoutContext
    end



    -- 2.7.61: shared frame geometry. Gen1Recomp's custom-screen contract
    -- gives mods a 160x144 state-stack surface (or a provider-owned wider
    -- logical surface). Screens must reserve regions before drawing instead of
    -- letting headers, lists, detail panes and footers choose unrelated magic Y
    -- coordinates.
    function UI.frame(width, height, opts)
        opts = type(opts) == "table" and opts or {}
        width = math.max(1, math.floor(tonumber(width) or 160))
        height = math.max(1, math.floor(tonumber(height) or 144))
        local header = math.max(0, math.floor(tonumber(opts.header) or 32))
        local footer = math.max(0, math.floor(tonumber(opts.footer) or 16))
        local detail = math.max(0, math.floor(tonumber(opts.detail) or 0))
        if header + footer + detail > height then
            detail = math.max(0, height - header - footer)
        end
        local bodyTop = header
        local footerTop = height - footer
        local detailTop = footerTop - detail
        return {
            x = 0, y = 0, width = width, height = height,
            header = { x=0, y=0, width=width, height=header,
                bottom=header },
            body = { x=0, y=bodyTop, width=width,
                height=math.max(0, detailTop-bodyTop),
                top=bodyTop, bottom=detailTop },
            detail = { x=0, y=detailTop, width=width, height=detail,
                top=detailTop, bottom=footerTop },
            footer = { x=0, y=footerTop, width=width, height=footer,
                top=footerTop, bottom=height },
        }
    end

    function UI.visibleRows(region, rowHeight, gap)
        region = type(region) == "table" and region or {}
        rowHeight = math.max(1, math.floor(tonumber(rowHeight) or 16))
        gap = math.max(0, math.floor(tonumber(gap) or 0))
        local step = rowHeight + gap
        return math.max(0, math.floor(((tonumber(region.height) or 0) + gap) / step))
    end

    function UI.gen1ScreenFrame(Font, width, opts)
        width = math.max(160, math.floor(tonumber(width) or 160))
        opts = type(opts) == "table" and opts or {}
        local frame = UI.frame(width, 144, opts)
        if opts.box ~= false and Font and type(Font.drawBox) == "function" then
            Font.drawBox(0, 0, math.floor(width / 8), 18)
        end
        return frame
    end

    function UI.gen2ScreenFrame(Chrome, opts)
        opts = type(opts) == "table" and opts or {}
        local headerRows = math.max(0, math.floor(tonumber(opts.headerRows) or 4))
        local footerRows = math.max(0, math.floor(tonumber(opts.footerRows) or 2))
        local detailRows = math.max(0, math.floor(tonumber(opts.detailRows) or 0))
        if Chrome then
            Chrome.clear()
            if opts.box ~= false then Chrome.box(0, 0, 20, 18) end
        end
        local frame = UI.frame(160, 144, {
            header = headerRows * 8,
            footer = footerRows * 8,
            detail = detailRows * 8,
        })
        frame.headerRows, frame.footerRows, frame.detailRows =
            headerRows, footerRows, detailRows
        return frame
    end

    function UI.view(surface, game, opts)
        opts = opts or {}
        return {
            surface = tostring(surface or "NUZLOCKE"),
            edition = tostring(opts.edition or edition(game)),
            mode = tostring(opts.mode or "LIVE"),
            state = opts.state and tostring(opts.state) or nil,
            position = opts.position and tostring(opts.position) or nil,
            footer = opts.footer and tostring(opts.footer) or nil,
        }
    end

    function UI.gen1Header(Font, view, width)
        width = math.max(160, math.floor(tonumber(width) or 160))
        local inner = width - 20
        local title = fit(Font,
            "NUZLOCKE " .. tostring(view.surface or ""), inner)
        -- 2.7.92: approved Nuzlocke-owned chrome: one emphasized title row.
        -- A one-pixel echo gives the native bitmap font a bold treatment
        -- without changing or shipping any font asset.
        Font.draw(title, 10, 10)
        Font.draw(title, 11, 10)
        -- Setup/Rules no longer repeats edition + NEW RUN/LIVE below it.
    end

    function UI.gen1Footer(Font, view, y, width)
        width = math.max(160, math.floor(tonumber(width) or 160))
        local footer = tostring(view.footer or "B:BACK")
        Font.draw(fit(Font, footer, width - 20), 10, math.floor(tonumber(y) or 128))
    end

    -- 2.7.79: shared Gen-2 Nuzlocke title hierarchy. Primary utility-screen
    -- titles are centered and pseudo-bold; optional subject/tab subtitles are
    -- centered at normal weight. This helper is presentation-only and must not
    -- be used to restyle native/foreign game surfaces.
    function UI.drawGen2NuzTitle(Chrome, Font, primary, subtitle, opts)
        opts = opts or {}
        local width = math.max(64, math.floor(tonumber(opts.width) or 160))
        local left = math.max(0, math.floor(tonumber(opts.left) or 8))
        local right = math.min(width, math.floor(tonumber(opts.right) or (width - 8)))
        local row = math.max(0, math.floor(tonumber(opts.row) or 1))
        local subtitleRow = math.max(row + 1,
            math.floor(tonumber(opts.subtitleRow) or (row + 2)))
        local T = UI.typography(Font)
        local inner = math.max(8, right - left)
        local title = fit(Font, tostring(Strings(primary or "NUZLOCKE")), inner)
        local titleWidth = T.measure(title)
        local x = math.max(left, math.floor((width - titleWidth) / 2))
        if Font and type(Font.draw) == "function" then
            Font.draw(title, x, row * 8)
            Font.draw(title, math.min(right - 1, x + 1), row * 8)
        else
            Chrome.print(title, math.max(1, math.floor(x / 8)), row)
        end
        if subtitle ~= nil and tostring(subtitle) ~= "" then
            local sub = fit(Font, tostring(Strings(subtitle)), inner)
            local subWidth = T.measure(sub)
            local sx = math.max(left, math.floor((width - subWidth) / 2))
            if Font and type(Font.draw) == "function" then
                Font.draw(sub, sx, subtitleRow * 8)
            else
                Chrome.print(sub, math.max(1, math.floor(sx / 8)), subtitleRow)
            end
        end
        return true
    end

    function UI.gen2Header(Chrome, Font, view)
        UI.drawGen2NuzTitle(Chrome, Font,
            "NUZLOCKE/" .. tostring(view.surface or ""), nil, { row = 1 })
    end

    function UI.gen2Footer(Chrome, Font, view, row)
        Chrome.print(fit(Font, tostring(view.footer or "B:BACK"), 16 * 8), 2,
            math.floor(tonumber(row) or 16))
    end

    function UI.statusText(label, value)
        label = tostring(label or "")
        value = tostring(value or "")
        if label == "" then return "[" .. value .. "]" end
        return label .. " [" .. value .. "]"
    end


    function UI.statusKind(value)
        value = tostring(value or ""):upper()
        if value == "PASS" or value == "ACTIVE" or value == "AVAILABLE"
            or value == "LEGAL" or value == "ON" then return "positive" end
        if value == "FAIL" or value == "FAILED" or value == "BLOCKED"
            or value == "DEAD" or value == "ERROR" then return "negative" end
        if value == "WARN" or value == "WARNING" or value == "USED"
            or value == "COUNT" then return "warning" end
        if value == "UNKNOWN" or value == "NOT TESTED" or value == "N/A"
            or value == "NOT RUN" then return "unknown" end
        return "neutral"
    end

    function UI.gen1Row(Font, Theme, row, opts)
        row, opts = row or {}, opts or {}
        local T = UI.typography(Font)
        local x = math.floor(tonumber(opts.x) or 16)
        local y = math.floor(tonumber(opts.y) or 0)
        local right = math.floor(tonumber(opts.right) or 144)
        local gap = math.max(8, math.floor(tonumber(opts.gap) or 12))
        local value = tostring(Strings(row.value or ""))
        local displayValue = value
        if value ~= "" and row.preFitted ~= true then
            -- Reserve at most roughly half of the row for a translated value,
            -- then right-align the fitted value. This prevents a long localized
            -- value from pushing its origin off-screen before fitting occurs.
            local valueBudget = math.max(8, math.floor((right - x) * 0.48))
            displayValue = T.fit(value, valueBudget)
        end
        local valueX = displayValue ~= "" and T.rightX(displayValue, right) or right
        local labelRight = displayValue ~= "" and (valueX - gap) or right
        local cursorX = x - 8
        if row.focused == true and Theme and Theme.cursor then
            Font.drawCode(Theme.cursor, cursorX, y)
        end
        local label = tostring(Strings(row.label or ""))
        if row.preFitted ~= true then
            label = T.fit(label, math.max(0, labelRight - x))
        end
        Font.draw(label, x, y)
        if displayValue ~= "" then
            Font.draw(displayValue, valueX, y)
        end
        return { label = label, value = displayValue, valueX = valueX,
            statusKind = UI.statusKind(value) }
    end

    function UI.gen2Row(Chrome, Font, row, opts)
        row, opts = row or {}, opts or {}
        local T = UI.typography(Font)
        local x = math.max(1, math.floor(tonumber(opts.x) or 2))
        local y = math.max(0, math.floor(tonumber(opts.y) or 0))
        local rightCol = math.max(x + 1, math.floor(tonumber(opts.rightCol) or 18))
        local value = tostring(Strings(row.value or ""))
        local rightPx = (rightCol + 1) * 8
        local displayValue = value
        if value ~= "" and row.preFitted ~= true then
            local availablePx = math.max(8, (rightCol - x + 1) * 8)
            local valueBudget = math.max(8, math.floor(availablePx * 0.48))
            displayValue = T.fit(value, valueBudget)
        end
        local valueX = displayValue ~= "" and T.rightX(displayValue, rightPx) or rightPx
        local valueCol = math.max(x, math.floor(valueX / 8))
        local labelCols = displayValue ~= "" and math.max(1, valueCol - x - 1)
            or math.max(1, rightCol - x + 1)
        if row.focused == true then Chrome.cursor(math.max(0, x - 1), y) end
        local label = tostring(Strings(row.label or ""))
        if row.preFitted ~= true then label = T.fit(label, labelCols * 8) end
        Chrome.print(label, x, y)
        if displayValue ~= "" then
            Chrome.print(displayValue, valueCol, y)
        end
        return { value = displayValue, valueCol = valueCol,
            statusKind = UI.statusKind(value) }
    end

    function UI.notice(kind, title, body, footer)
        return {
            kind = tostring(kind or "INFO"):upper(),
            title = tostring(Strings(title or "NUZLOCKE")),
            body = tostring(Strings(body or "")),
            footer = tostring(Strings(footer or "A/B:OK")),
        }
    end

    function UI.gen1Notice(Font, notice, width)
        width = math.max(160, math.floor(tonumber(width) or 160))
        local T = UI.typography(Font)
        local left, right = 16, width - 16
        Font.draw(T.fit(notice.kind .. " / " .. notice.title, right - left), left, 30)
        local lines = T.wrap(notice.body, right - left)
        for i = 1, math.min(5, #lines) do
            Font.draw(lines[i], left, 48 + (i - 1) * 12)
        end
        Font.draw(T.fit(notice.footer, right - left), left, 120)
    end

    function UI.gen2Notice(Chrome, Font, notice, opts)
        opts = opts or {}
        local T = UI.typography(Font)
        local x = math.max(1, math.floor(tonumber(opts.x) or 2))
        local widthCols = math.max(8, math.floor(tonumber(opts.widthCols) or 16))
        local y = math.max(1, math.floor(tonumber(opts.y) or 4))
        Chrome.print(T.fit(notice.kind .. " / " .. notice.title, widthCols * 8), x, y)
        local lines = T.wrap(notice.body, widthCols * 8)
        for i = 1, math.min(6, #lines) do
            Chrome.print(lines[i], x, y + 2 + (i - 1))
        end
        Chrome.print(T.fit(notice.footer, widthCols * 8), x,
            math.floor(tonumber(opts.footerRow) or 15))
    end

    function UI.compositionForWidth(width)
        width = tonumber(width) or 160
        if width >= UI.composition.wide then return "wide" end
        return "classic"
    end

    -- Screen policies are Nuzlocke-owned semantics, not external-mod behavior.
    -- Rich list/report surfaces may use the 304-wide logical canvas when a host
    -- provides it. Small/destructive child flows remain centered and inherit
    -- their parent's presentation context where appropriate.
    UI.registerPolicy("NuzlockeConfigScreen", {
        mode = "adaptive", role = "rules", input = { profile = "values" } })
    UI.registerPolicy("NuzlockeTrackerScreen", {
        mode = "adaptive", role = "tracker", input = { profile = "pager" } })
    UI.registerPolicy("NuzlockeDevToolsScreen", {
        mode = "centered", role = "diagnostics", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeForgivenessItem", {
        mode = "centered", role = "forgiveness", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeForgivenessArea", {
        mode = "centered", role = "forgiveness_area", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeForgivenessRevive", {
        mode = "centered", role = "forgiveness_revive", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeLoadoutConfirm", {
        mode = "centered", role = "confirmation", input = { profile = "confirmation" } })
    UI.registerPolicy("NuzlockePokemonBanScreen", {
        mode = "centered", role = "picker", input = { profile = "values" } })
    UI.registerPolicy("NuzlockeUiGalleryScreen", {
        mode = "adaptive", role = "ui_gallery", input = { profile = "pager" } })

    UI.registerPolicy("NuzlockeMenuScreen", {
        mode = "adaptive", role = "menu", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeStatusListScreen", {
        mode = "adaptive", role = "status", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeGoldStatusScreen", {
        mode = "centered", role = "status", input = { profile = "pager" } })
    UI.registerPolicy("NuzlockeTrainerCardScreen", {
        mode = "centered", role = "status", input = { profile = "pager" } })
    UI.registerPolicy("NuzlockeRunHistoryScreen", {
        mode = "adaptive", role = "history", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeGraveyardScreen", {
        mode = "adaptive", role = "graveyard", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeGraveyardMemorialScreen", {
        mode = "centered", role = "memorial", input = { profile = "pager" } })
    UI.registerPolicy("NuzlockeAlmanacScreen", {
        mode = "adaptive", role = "almanac", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeAlmanacPageScreen", {
        mode = "adaptive", role = "almanac_page", input = { profile = "pager" } })
    UI.registerPolicy("NuzlockeCatchInfoScreen", {
        mode = "centered", role = "catch_info", input = { profile = "pager" } })
    UI.registerPolicy("NuzlockeLegacyRecoveryScreen", {
        mode = "centered", role = "recovery", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeLoadoutChooser", {
        mode = "centered", role = "loadout", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeManualClock", {
        mode = "centered", role = "clock", input = { profile = "values" } })
    UI.registerPolicy("NuzlockeModCompatScreen", {
        mode = "adaptive", role = "compatibility", input = { profile = "values" } })
    UI.registerPolicy("NuzlockeRareCandyMenu", {
        mode = "centered", role = "rare_candy", input = { profile = "values" } })
    UI.registerPolicy("NuzlockeDifficultyReview", {
        mode = "adaptive", role = "difficulty_review", input = { profile = "pager" } })
    UI.registerPolicy("NuzlockeEndRunScreen", {
        mode = "centered", role = "run_lifecycle", input = { profile = "navigation" } })
    UI.registerPolicy("NuzlockeAbandonConfirmScreen", {
        mode = "centered", role = "destructive_confirmation",
        input = { profile = "destructive_confirmation" } })


    mod.exports.nuzlocke_ui_system = UI
    return UI
end
