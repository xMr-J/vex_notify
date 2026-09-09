Config = Config or {}

-- ============================================================================
-- General
-- ============================================================================

Config.Debug = false

Config.ResourceName = 'vex_notify'

Config.DefaultLocale = 'en'

-- Hard upper/lower duration boundaries for caller-supplied timed UI.
Config.DurationLimits = {
    minimum = 500,
    maximum = 120000
}

-- ============================================================================
-- Default Durations
-- ============================================================================

Config.Durations = {
    toast = 4000,
    alert = 6000,
    choice = 15000,
    progress = 5000,
    overhead = 3000
}

-- ============================================================================
-- Layout
-- ============================================================================

Config.Layout = {
    toast = {
        position = 'top-right',
        maxVisible = 5,
        gap = 10,
        screenMarginX = 28,
        screenMarginY = 28
    },

    anchor = {
        position = 'top-center',
        screenMarginX = 24,
        screenMarginY = 30
    },

    alert = {
        position = 'top-center',
        screenMarginY = 38
    },

    choice = {
        position = 'center'
    },

    progress = {
        position = 'bottom-center',
        screenMarginY = 64
    }
}

-- ============================================================================
-- Western / RDR Theme
--
-- These are semantic design tokens. Lua should pass token names rather than
-- arbitrary CSS or raw HTML wherever possible.
-- ============================================================================

Config.Theme = {
    font = {
        heading = '"Rye", "Georgia", serif',
        body = '"Georgia", "Times New Roman", serif',
        ui = '"Trebuchet MS", Arial, sans-serif'
    },

    colors = {
        parchment = '#E7D7B1',
        parchmentMuted = '#C8B78E',

        ink = '#1E1914',
        inkSoft = '#33291F',

        leather = '#5A3825',
        leatherDark = '#2A1C15',

        brass = '#B98A45',
        brassLight = '#D6AD6A',

        success = '#607A49',
        error = '#8B3A32',
        warning = '#B17832',
        info = '#506B78',

        backdrop = 'rgba(12, 9, 7, 0.82)',
        panel = 'rgba(29, 21, 16, 0.96)',
        border = 'rgba(202, 164, 99, 0.55)',
        shadow = 'rgba(0, 0, 0, 0.48)',

        textPrimary = '#F0E2C4',
        textSecondary = '#CBBE9F'
    },

    radius = {
        small = 3,
        medium = 5,
        large = 8
    }
}

-- ============================================================================
-- Built-In Notification Presets
-- ============================================================================

Config.Presets = {
    default = {
        accent = 'brass',
        icon = '◆'
    },

    info = {
        accent = 'info',
        icon = 'ℹ'
    },

    success = {
        accent = 'success',
        icon = '✓'
    },

    warning = {
        accent = 'warning',
        icon = '!'
    },

    error = {
        accent = 'error',
        icon = '×'
    },

    objective = {
        accent = 'brass',
        icon = '◆'
    },

    system = {
        accent = 'parchment',
        icon = '★'
    }
}

-- ============================================================================
-- Sound
--
-- NUI sound playback is disabled by default because no licensed/custom audio
-- assets are bundled in this foundational resource.
-- ============================================================================

Config.Sound = {
    enabled = false,

    toast = false,
    alert = false,
    choice = false,
    progressComplete = false,

    volume = 0.35
}

-- ============================================================================
-- Choice Modal
-- ============================================================================

Config.Choice = {
    defaultTimeout = Config.Durations.choice,

    maxButtons = 6,

    -- Hard ceiling on how many players a single ShowChoiceModal(target, ...)
    -- call may address at once when target is a table or -1. Protects
    -- against a single call opening hundreds of concurrent vex_callback
    -- coroutines.
    maxBroadcastTargets = 32,

    defaultButtons = {
        {
            label = 'Accept',
            value = true
        },
        {
            label = 'Decline',
            value = false
        }
    }
}

-- ============================================================================
-- Progress
-- ============================================================================

Config.Progress = {
    defaultDuration = Config.Durations.progress,

    allowMoveCancellation = true,
    allowDamageCancellation = true
}

-- ============================================================================
-- World / Overhead Renderer
-- ============================================================================

Config.World = {
    enabled = true,

    defaultDuration = Config.Durations.overhead,

    defaultOffsetZ = 1.0,

    maxDistance = 35.0,

    -- Allows the world renderer to skip expensive projection work for entries
    -- outside their configured draw range.
    distanceCull = true,

    text = {
        scale = 0.30,
        alpha = 255
    }
}

-- ============================================================================
-- Logging
-- ============================================================================

function VexNotifyDebug(...)
    if not Config.Debug then
        return
    end

    local parts = {}

    for index = 1, select('#', ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end

    print(('[%s] %s'):format(
        Config.ResourceName,
        table.concat(parts, ' ')
    ))
end