-- I LOVE LERP
local lerp = {}

lerp.cache = {}


lerp.new = function(Name)
    lerp.cache[Name] = 0
end

lerp.lerp = function(Name, LerpTo, Speed)
    if lerp.cache[Name] == nil then
        lerp.new(Name)
    end

    lerp.cache[Name] = lerp.cache[Name] + (LerpTo - lerp.cache[Name]) * (globals.absoluteframetime() * Speed)

    return lerp.cache[Name]
end

lerp.get = function(Name)
    if lerp.cache[Name] == nil then return print("Lerp( " .. Name .. " ) does not exisit in function get") end
    return lerp.cache[Name]
end


local c_entity = require("gamesense/entity") or error("entity was not found get it from the workshop [GO GET IT FOR FUCK SAKES]")
local vector = require("vector") or error("vector was not found get it from the workshop")
local ffi = require("ffi") or error("ffi was not found get it from the workshop")
local pui = require("gamesense/pui") or error("pui was not found get it from the workshop")
local weaponsstuff = require("gamesense/csgo_weapons") or error("csgo_weapons was not found get it from the workshop")
local clipboard = require("gamesense/clipboard") or error("clipboard was not found get it from the workshop")
local base64 = require("gamesense/base64") or error("base64 was not found get it from the workshop")
local http = require("gamesense/http") or error("http was not found get it from the workshop")
local enabledluayay = false
local enablelua = pui.checkbox("AA", "Anti-Aimbot angles", " Solix AA")

local function vtable_entry(instance, index, type)
    return ffi.cast(type, (ffi.cast("void***", instance)[0])[index])
end

local function vtable_bind(module, interface, index, typestring)
    local instance = client.create_interface(module, interface) or error("invalid interface")
    local fnptr = vtable_entry(instance, index, ffi.typeof(typestring)) or error("invalid vtable")
    return function(...)
        return fnptr(tonumber(ffi.cast("void***", instance)), ...)
    end
end

local filesystem = client.create_interface("filesystem_stdio.dll", "VBaseFileSystem011")
local filesystem_class = ffi.cast(ffi.typeof("void***"), filesystem)
local filesystem_vftbl = filesystem_class[0]

local func_read_file = ffi.cast("int (__thiscall*)(void*, void*, int, void*)", filesystem_vftbl[0])
local func_write_file = ffi.cast("int (__thiscall*)(void*, void const*, int, void*)", filesystem_vftbl[1])

local func_open_file = ffi.cast("void* (__thiscall*)(void*, const char*, const char*, const char*)", filesystem_vftbl[2])
local func_close_file = ffi.cast("void (__thiscall*)(void*, void*)", filesystem_vftbl[3])

local func_get_file_size = ffi.cast("unsigned int (__thiscall*)(void*, void*)", filesystem_vftbl[7])
local func_file_exists = ffi.cast("bool (__thiscall*)(void*, const char*, const char*)", filesystem_vftbl[10])

local full_filesystem = client.create_interface("filesystem_stdio.dll", "VFileSystem017")
local full_filesystem_class = ffi.cast(ffi.typeof("void***"), full_filesystem)
local full_filesystem_vftbl = full_filesystem_class[0]

local func_add_search_path = ffi.cast("void (__thiscall*)(void*, const char*, const char*, int)", full_filesystem_vftbl[11])
local func_remove_search_path = ffi.cast("bool (__thiscall*)(void*, const char*, const char*)", full_filesystem_vftbl[12])

local func_remove_file = ffi.cast("void (__thiscall*)(void*, const char*, const char*)", full_filesystem_vftbl[20])
local func_rename_file = ffi.cast("bool (__thiscall*)(void*, const char*, const char*, const char*)", full_filesystem_vftbl[21])
local func_create_dir_hierarchy = ffi.cast("void (__thiscall*)(void*, const char*, const char*)", full_filesystem_vftbl[22])
local func_is_directory = ffi.cast("bool (__thiscall*)(void*, const char*, const char*)", full_filesystem_vftbl[23])

local func_find_first = ffi.cast("const char* (__thiscall*)(void*, const char*, int*)", full_filesystem_vftbl[32])
local func_find_next = ffi.cast("const char* (__thiscall*)(void*, int)", full_filesystem_vftbl[33])
local func_find_is_directory = ffi.cast("bool (__thiscall*)(void*, int)", full_filesystem_vftbl[34])
local func_find_close = ffi.cast("void (__thiscall*)(void*, int)", full_filesystem_vftbl[35])

local native_GetGameDirectory = vtable_bind("engine.dll", "VEngineClient014", 36, "const char*(__thiscall*)(void*)")

local MODES = {
    ["r"] = "r",
    ["w"] = "w",
    ["a"] = "a",
    ["r+"] = "r+",
    ["w+"] = "w+",
    ["a+"] = "a+",
    ["rb"] = "rb",
    ["wb"] = "wb",
    ["ab"] = "ab",
    ["rb+"] = "rb+",
    ["wb+"] = "wb+",
    ["ab+"] = "ab+",
}

local FileSystem = {}

function FileSystem.exists(file, path_id)
    return func_file_exists(filesystem_class, file, path_id)
end

function FileSystem.rename(old_path, new_path, path_id)
    func_rename_file(full_filesystem_class, old_path, new_path, path_id)
end

function FileSystem.remove(file, path_id)
    func_remove_file(full_filesystem_class, file, path_id)
end

function FileSystem.create_directory(path, path_id)
    func_create_dir_hierarchy(full_filesystem_class, path, path_id)
end

function FileSystem.is_directory(path, path_id)
    return func_is_directory(full_filesystem_class, path, path_id)
end

function FileSystem.find_first(path)
    local handle = ffi.new("int[1]")
    local file = func_find_first(full_filesystem_class, path, handle)
    if file == ffi.NULL then return nil end

    return handle, ffi.string(file)
end

function FileSystem.find_next(handle)
    local file = func_find_next(full_filesystem_class, handle)
    if file == ffi.NULL then return nil end

    return ffi.string(file)
end

function FileSystem.find_is_directory(handle)
    return func_find_is_directory(full_filesystem_class, handle)
end

function FileSystem.find_close(handle)
    func_find_close(full_filesystem_class, handle)
end

function FileSystem.add_search_path(path, path_id, type)
    func_add_search_path(full_filesystem_class, path, path_id, type)
end

function FileSystem.remove_search_path(path, path_id)
    func_remove_search_path(full_filesystem_class, path, path_id)
end

function FileSystem.get_game_dir()
    return ffi.string(native_GetGameDirectory())
end
function FileSystem.download(url, path)
    wininet.DeleteUrlCacheEntryA(url)
    urlmon.URLDownloadToFileA(nil, url, path, 0,0)
end
function FileSystem.open(file, mode, path_id)
    if not MODES[mode] then error("Invalid mode!") end
    local self = setmetatable({
        file = file,
        mode = mode,
        path_id = path_id,
        handle = func_open_file(filesystem_class, file, mode, path_id)
    }, FileSystem)

    return self
end

function FileSystem:get_size()
    return func_get_file_size(filesystem_class, self.handle)
end

function FileSystem:write(buffer)
    func_write_file(filesystem_class, buffer, #buffer, self.handle)
end

function FileSystem:read()
    local size = self:get_size()
    local output = ffi.new("char[?]", size + 1)
    func_read_file(filesystem_class, output, size, self.handle)

    return ffi.string(output)
end

function FileSystem:close()
    func_close_file(filesystem_class, self.handle)
end

contains = function(tbl, value)
    local tbl_len = #tbl

    for i=1, tbl_len do
        if tbl[i] == value then
            return true
        end
    end

    return false
end

local gsrefs = {
    enabled = pui.reference("AA", "Anti-aimbot angles", "Enabled");                                  -- [1]  Enable AA                           [29]
    pitch = {pui.reference("AA", "Anti-aimbot angles", "Pitch")};                                    -- [2]  Pitch                               [30]
    yaw_base = pui.reference("AA", "Anti-aimbot angles", "Yaw base");                                -- [3]  Yaw Base                            [31]
    yaw = { pui.reference("AA", "Anti-aimbot angles", "Yaw") },                                      -- [4]  Yaw --> drop[1], slider[2]          [32]
    yaw_jitter = { pui.reference("AA", "Anti-aimbot angles", "Yaw jitter") };                        -- [5]  Yaw Jitter                          [33]
    body_yaw = { pui.reference("AA", "Anti-aimbot angles", "Body yaw") };                            -- [6]  Body Yaw                            [34]
    freestanding_body_yaw = pui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw");      -- [7]  Freestanding Body Yaw               [35]
    edge_yaw = pui.reference("AA", "Anti-aimbot angles", "Edge yaw");                                -- [8]  Edge Yaw                            [36]
    freestand = { pui.reference("AA", "Anti-aimbot angles", "Freestanding") },                       -- [9]  Freestanding --> Ref[1], Key[2]     [37]
    roll = pui.reference("AA", "Anti-aimbot angles", "Roll");                                        -- [10] Roll                                [38]
}


local player_states = {"Global", "Standing", "Moving", "Slow-Walk", "Crouch", "Crouch Move", "In Air", "In Air+C", "Safe Head"}
local player_states_idx = {["Global"] = 1, ["Standing"] = 2, ["Moving"] = 3, ["Slow-Walk"] = 4, ["Crouch"] = 5, ["Crouch Move"] = 6, ["In Air"] = 7, ["In Air+C"] = 8, ["Safe Head"] = 9}
local reversed_player_states_idx = {}
local p_state = 0
local localdirectory = FileSystem.get_game_dir():sub(1, -6)

for key, value in pairs(player_states_idx) do
    reversed_player_states_idx[value] = key
end

local configs = {}
local Antiaim = {}
local extrasantiaim = {}

Antiaim[0] = {
    comboboxuimain = pui.combobox("AA", "Anti-aimbot angles", " ", {" Anti-Aim", " Extras", " Config"}),
    invislabel = pui.label("AA", "Anti-aimbot angles", " "),
    freestanding = pui.checkbox("AA", "Other", " Freestanding"),
    fs_key = pui.hotkey("AA", "Other", "Freestanding Bind", true),
    enableantiaim = pui.checkbox("AA", "Anti-aimbot angles", "Enable Anti-Aim"),
    conditions = pui.combobox("AA", "Anti-aimbot angles", "Condtions", {"Global", "Standing", "Moving", "Slow-Walk", "Crouch", "Crouch Move", "In Air", "In Air+C", "Safe Head"}),
}

for i = 1, 9 do
    Antiaim[i] = {
        comboboxui = pui.checkbox("AA", "Anti-aimbot angles", "Enable ["..reversed_player_states_idx[i].."]"),
        SafeHeadoptions = pui.multiselect("AA", "Anti-aimbot angles", "Safe Head", {"Zues", "Knife"}),
        Base = pui.combobox("AA", "Anti-aimbot angles", "Base", {"Local View", "At Target"}),
        Pitch = pui.combobox("AA", "Anti-aimbot angles", "Pitch", {"Disabled", "Down", "0"}),
        Yaw = pui.combobox("AA", "Anti-aimbot angles", "Yaw", {"Disabled", "Backward", "Static"}),
        YawOffset2 = pui.slider("AA", "Anti-aimbot angles", "Yaw Offset", -180, 180, 0),
        YawModifier = pui.combobox("AA", "Anti-aimbot angles", "Yaw Modifier", {"Disabled", "Center", "Offset", "Random", "Spin", "3-Way", "5-Way", "Tick Switcher", "Delay", "L&R", "L&R Center"}),
        YawOffset = pui.slider("AA", "Anti-aimbot angles", "Yaw Modifier Offset", -180, 180, 0),
        YawOffsetL = pui.slider("AA", "Anti-aimbot angles", "Left", -180, 180, 0),
        YawOffsetR = pui.slider("AA", "Anti-aimbot angles", "Right", -180, 180, 0),
        YawOffsetMax = pui.slider("AA", "Anti-aimbot angles", "Max", -180, 180, 0),
        YawOffsetMin = pui.slider("AA", "Anti-aimbot angles", "Min", -180, 180, 0),
        YawOffset1Way = pui.slider("AA", "Anti-aimbot angles", "1-Way", -180, 180, 0),
        YawOffset2Way = pui.slider("AA", "Anti-aimbot angles", "2-Way", -180, 180, 0),
        YawOffset3Way = pui.slider("AA", "Anti-aimbot angles", "3-Way", -180, 180, 0),
        YawOffset4Way = pui.slider("AA", "Anti-aimbot angles", "4-Way", -180, 180, 0),
        YawOffset5Way = pui.slider("AA", "Anti-aimbot angles", "5-Way", -180, 180, 0),
        YawOffsetTicks = pui.slider("AA", "Anti-aimbot angles", "Ticks", 0, 30, 0),
        BodyYaw = pui.checkbox("AA", "Anti-aimbot angles", "Body Yaw"),
        Desync1 = pui.slider("AA", "Anti-aimbot angles", "Desync R", 0, 60),
        Desync2 = pui.slider("AA", "Anti-aimbot angles", "Desync L", 0, 60),
        Invert = pui.checkbox("AA", "Anti-aimbot angles", "Invert"),
        Invert2 = pui.checkbox("AA", "Anti-aimbot angles", "Invert Desync System"),
        Defensive = pui.checkbox("AA", "Anti-aimbot angles", "Defensive"),
        Defensive_onlyhittable = pui.checkbox("AA", "Anti-aimbot angles", "When Hittable"),
        Defensive_Pitch = pui.combobox("AA", "Anti-aimbot angles", "Defensive Pitch", {"Disabled", "Down", "0", "57"}),
        Defensive_YawModifier = pui.combobox("AA", "Anti-aimbot angles", "Defensive Yaw Modifier", {"Disabled", "Center", "Offset", "Random", "Spin", "3-Way", "5-Way", "Tick Switcher", "Delay", "L&R", "L&R Center"}),
        Defensive_YawOffset = pui.slider("AA", "Anti-aimbot angles", "Defensive Offset", -180, 180, 0),
        Defensive_YawOffsetL = pui.slider("AA", "Anti-aimbot angles", "Defensive Left", -180, 180, 0),
        Defensive_YawOffsetR = pui.slider("AA", "Anti-aimbot angles", "Defensive Right", -180, 180, 0),
        Defensive_YawOffsetMax = pui.slider("AA", "Anti-aimbot angles", "Defensive Max", -180, 180, 0),
        Defensive_YawOffsetMin = pui.slider("AA", "Anti-aimbot angles", "Defensive Min", -180, 180, 0),
        Defensive_YawOffset1Way = pui.slider("AA", "Anti-aimbot angles", "Defensive 1-Way", -180, 180, 0),
        Defensive_YawOffset2Way = pui.slider("AA", "Anti-aimbot angles", "Defensive 2-Way", -180, 180, 0),
        Defensive_YawOffset3Way = pui.slider("AA", "Anti-aimbot angles", "Defensive 3-Way", -180, 180, 0),
        Defensive_YawOffset4Way = pui.slider("AA", "Anti-aimbot angles", "Defensive 4-Way", -180, 180, 0),
        Defensive_YawOffset5Way = pui.slider("AA", "Anti-aimbot angles", "Defensive 5-Way", -180, 180, 0),
        Defensive_YawOffsetTicks = pui.slider("AA", "Anti-aimbot angles", "Defensive Ticks", 0, 30, 0),
    }
end

extrasantiaim = {
    SideIndicators = pui.multiselect("AA", "Anti-aimbot angles", "Side Indicators", {"Defensive Status", "Condtions", "Safe Head", "Manual AA" , "Freestanding"}),
    AntiBackstab = pui.checkbox("AA", "Anti-aimbot angles", "Anti-Backstab"),
    ManualAA = pui.checkbox("AA", "Anti-aimbot angles", "Manual AA"),
    ManualAA_Left = pui.checkbox("AA", "Anti-aimbot angles", "Left"),
    ManualAA_Left_key = pui.hotkey("AA", "Anti-aimbot angles", "Left", true),
    ManualAA_Right = pui.checkbox("AA", "Anti-aimbot angles", "Right"),
    ManualAA_Right_key = pui.hotkey("AA", "Anti-aimbot angles", "Right", true),
    ManualAA_Forward = pui.checkbox("AA", "Anti-aimbot angles", "Forward"),
    ManualAA_Forward_key = pui.hotkey("AA", "Anti-aimbot angles", "Forward", true),
    invislabel1 = pui.label("AA", "Anti-aimbot angles", " "),
    invislabel2 = pui.label("AA", "Anti-aimbot angles", "Ragebot Enchantments"),
    BaimIfLethal = pui.checkbox("AA", "Anti-aimbot angles", "Baim if lethal"),
    Baimatwhathealth = pui.slider("AA", "Anti-aimbot angles", "Baim if hp lower than", 0, 100, 60),
    invislabel3 = pui.label("AA", "Anti-aimbot angles", " "),
    invislabel4 = pui.label("AA", "Anti-aimbot angles", "Visuals"),
    showdormantlastposition = pui.checkbox("AA", "Anti-aimbot angles", "Show last enemy position"),
    Ragebotlogs = pui.checkbox("AA", "Anti-aimbot angles", "Logs"),
    Logsoptions = pui.multiselect("AA", "Anti-aimbot angles", "Logs", {"Purchase", "Hit", "Miss", "Fired", "Harmed", "Molotov/Granades"}),
    animationbreaker = pui.multiselect("AA", "Anti-aimbot angles", "Animation Breaker", {"Always flashed", "Vibrator", "Moon Walk"}),
    Alwaysflashed = pui.slider("AA", "Anti-aimbot angles", "Flash animation", 0, 100, 100),
    invislabel6 = pui.label("AA", "Anti-aimbot angles", " "),

}

local configmenu = {
    mainconfigmenu = pui.listbox("AA", "Anti-aimbot angles", " ", configs),
    inputname = pui.textbox("AA", "Anti-aimbot angles", "Load", function()
        loadconfig() 
    end),
    load = pui.button("AA", "Anti-aimbot angles", "Load", function()
        loadconfig() 
    end),
    save = pui.button("AA", "Anti-aimbot angles", "Save", function ()
        saveconfig()
    end),
    create = pui.button("AA", "Anti-aimbot angles", "Create", function ()
        createconfig()
    end),
    delete = pui.button("AA", "Anti-aimbot angles", "Delete", function ()
        deleteconfig()
    end),
    import = pui.button("AA", "Anti-aimbot angles", "Import", function ()
        importconfig()
    end),
    export = pui.button("AA", "Anti-aimbot angles", "Export", function ()
        exportconfig()
    end),
}

menuhandaler = function ()
    local active_tab_string = pui.get(Antiaim[0].conditions.ref)
    local active_tab = player_states_idx[active_tab_string]
    local isEnabledantiaim = pui.get(Antiaim[0].enableantiaim.ref)
    local getactivetab = pui.get(Antiaim[0].comboboxuimain.ref)
    for i = 1, 9 do
        local isActiveTab = active_tab == i and pui.get(Antiaim[i].comboboxui.ref) and isEnabledantiaim and enabledluayay and getactivetab == " Anti-Aim"
        local isActiveTab2 = active_tab == i and enabledluayay and getactivetab == " Anti-Aim"
        local isActiveTab3 = active_tab == i and pui.get(Antiaim[i].comboboxui.ref) and isEnabledantiaim and enabledluayay and pui.get(Antiaim[i].Defensive.ref) and getactivetab == " Anti-Aim"
        pui.set_visible(Antiaim[i].comboboxui.ref, getactivetab == " Anti-Aim")
        pui.set_visible(Antiaim[0].conditions.ref, getactivetab == " Anti-Aim" and enabledluayay)
        pui.set_visible(Antiaim[0].enableantiaim.ref, getactivetab == " Anti-Aim" and enabledluayay)

        pui.set_visible(Antiaim[0].conditions.ref, getactivetab == " Anti-Aim" and isEnabledantiaim)
        pui.set_visible(Antiaim[i].comboboxui.ref, getactivetab == " Anti-Aim" and isEnabledantiaim)
        pui.set_visible(Antiaim[1].comboboxui.ref, getactivetab == " Anti-Aim" and active_tab == 1 and isEnabledantiaim)

        pui.set_visible(configmenu.delete.ref, getactivetab == " Config" and enabledluayay)
        pui.set_visible(configmenu.save.ref, getactivetab == " Config" and enabledluayay)
        pui.set_visible(configmenu.load.ref, getactivetab == " Config" and enabledluayay)
        pui.set_visible(configmenu.import.ref, getactivetab == " Config" and enabledluayay)
        pui.set_visible(configmenu.create.ref, getactivetab == " Config" and enabledluayay)
        pui.set_visible(configmenu.export.ref, getactivetab == " Config" and enabledluayay)
        pui.set_visible(configmenu.inputname.ref, getactivetab == " Config" and enabledluayay)
        pui.set_visible(configmenu.mainconfigmenu.ref, getactivetab == " Config" and enabledluayay)

        pui.set_visible(extrasantiaim.ManualAA.ref, getactivetab == " Extras" and enabledluayay)
        pui.set_visible(extrasantiaim.AntiBackstab.ref, getactivetab == " Extras" and enabledluayay)

        pui.set_visible(extrasantiaim.ManualAA.ref, getactivetab == " Extras" and enabledluayay)
        pui.set_visible(extrasantiaim.invislabel1.ref, getactivetab == " Extras" and enabledluayay)
        pui.set_visible(extrasantiaim.invislabel2.ref, getactivetab == " Extras" and enabledluayay)
        pui.set_visible(extrasantiaim.invislabel3.ref, getactivetab == " Extras" and enabledluayay)
        pui.set_visible(extrasantiaim.invislabel4.ref, getactivetab == " Extras" and enabledluayay)




        pui.set_visible(extrasantiaim.animationbreaker.ref, getactivetab == " Extras" and enabledluayay)
        pui.set_visible(extrasantiaim.Alwaysflashed.ref, getactivetab == " Extras" and enabledluayay and contains(pui.get(extrasantiaim.animationbreaker.ref), "Always flashed"))

        pui.set_visible(extrasantiaim.Ragebotlogs.ref, getactivetab == " Extras" and enabledluayay)
        pui.set_visible(extrasantiaim.Logsoptions.ref, getactivetab == " Extras" and enabledluayay and pui.get(extrasantiaim.Ragebotlogs.ref))


        pui.set_visible(extrasantiaim.showdormantlastposition.ref, getactivetab == " Extras" and enabledluayay)
        
        pui.set_visible(extrasantiaim.SideIndicators.ref, getactivetab == " Extras" and enabledluayay)

        pui.set_visible(extrasantiaim.BaimIfLethal.ref, getactivetab == " Extras" and enabledluayay)
        pui.set_visible(extrasantiaim.Baimatwhathealth.ref, getactivetab == " Extras" and enabledluayay and pui.get(extrasantiaim.BaimIfLethal.ref))

        pui.set_visible(extrasantiaim.ManualAA_Forward.ref, getactivetab == " Extras" and enabledluayay and pui.get(extrasantiaim.ManualAA.ref))
        pui.set_visible(extrasantiaim.ManualAA_Forward_key.ref, getactivetab == " Extras" and enabledluayay and pui.get(extrasantiaim.ManualAA.ref))
        pui.set_visible(extrasantiaim.ManualAA_Left.ref, getactivetab == " Extras" and enabledluayay and pui.get(extrasantiaim.ManualAA.ref))

        pui.set_visible(extrasantiaim.ManualAA_Left_key.ref, getactivetab == " Extras" and enabledluayay and pui.get(extrasantiaim.ManualAA.ref))
        pui.set_visible(extrasantiaim.ManualAA_Right.ref, getactivetab == " Extras" and enabledluayay and pui.get(extrasantiaim.ManualAA.ref))
        pui.set_visible(extrasantiaim.ManualAA_Right_key.ref, getactivetab == " Extras" and enabledluayay and pui.get(extrasantiaim.ManualAA.ref))


        pui.set_visible(Antiaim[0].comboboxuimain.ref, enabledluayay)
        pui.set_visible(Antiaim[0].invislabel.ref, enabledluayay)
        pui.set_visible(Antiaim[0].freestanding.ref, enabledluayay)
        pui.set_visible(Antiaim[0].fs_key.ref, enabledluayay)
        
        pui.set_visible(Antiaim[i].Base.ref, isActiveTab)
        pui.set_visible(Antiaim[i].Pitch.ref, isActiveTab)
        pui.set_visible(Antiaim[i].Yaw.ref, isActiveTab)
        pui.set_visible(Antiaim[i].YawModifier.ref, isActiveTab)
        pui.set_visible(Antiaim[i].BodyYaw.ref, isActiveTab)
        pui.set_visible(Antiaim[i].Desync1.ref, isActiveTab and pui.get(Antiaim[i].BodyYaw.ref))
        pui.set_visible(Antiaim[i].Desync2.ref, isActiveTab and pui.get(Antiaim[i].BodyYaw.ref))
        pui.set_visible(Antiaim[i].Invert.ref, isActiveTab and pui.get(Antiaim[i].BodyYaw.ref))
        pui.set_visible(Antiaim[i].Invert2.ref, isActiveTab and pui.get(Antiaim[i].BodyYaw.ref))
        pui.set_visible(Antiaim[i].comboboxui.ref, isActiveTab2)
        pui.set_visible(Antiaim[i].Defensive.ref, isActiveTab)
        pui.set_visible(Antiaim[i].Defensive_YawModifier.ref, isActiveTab3)
        pui.set_visible(Antiaim[i].Defensive_onlyhittable.ref, isActiveTab3)
        pui.set_visible(Antiaim[i].Defensive_Pitch.ref, isActiveTab3)

        pui.set_visible(Antiaim[i].SafeHeadoptions.ref, isActiveTab2 and i == 9 and pui.get(Antiaim[9].comboboxui.ref))

    
        local YawModifiervalue = pui.get(Antiaim[i].YawModifier.ref)
        pui.set_visible(Antiaim[i].YawOffset2.ref, isActiveTab)
        pui.set_visible(Antiaim[i].YawOffset.ref, isActiveTab and (YawModifiervalue == "Disabled" or YawModifiervalue == "Offset" or YawModifiervalue == "Center"))
        pui.set_visible(Antiaim[i].YawOffsetL.ref, isActiveTab and (YawModifiervalue == "L&R" or YawModifiervalue == "L&R Center" or YawModifiervalue == "Tick Switcher" or YawModifiervalue == "Delay"))
        pui.set_visible(Antiaim[i].YawOffsetR.ref, isActiveTab and (YawModifiervalue == "L&R" or YawModifiervalue == "L&R Center" or YawModifiervalue == "Tick Switcher" or YawModifiervalue == "Delay"))
        pui.set_visible(Antiaim[i].YawOffsetMax.ref, isActiveTab and (YawModifiervalue == "Random"))
        pui.set_visible(Antiaim[i].YawOffsetMin.ref, isActiveTab and (YawModifiervalue == "Random"))
        pui.set_visible(Antiaim[i].YawOffset1Way.ref, isActiveTab and (YawModifiervalue == "3-Way" or YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].YawOffset2Way.ref, isActiveTab and (YawModifiervalue == "3-Way" or YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].YawOffset3Way.ref, isActiveTab and (YawModifiervalue == "3-Way" or YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].YawOffset4Way.ref, isActiveTab and (YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].YawOffset5Way.ref, isActiveTab and (YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].YawOffsetTicks.ref, isActiveTab and (YawModifiervalue == "Tick Switcher" or YawModifiervalue == "Delay"))

        local Defensive_YawModifiervalue = pui.get(Antiaim[i].Defensive_YawModifier.ref)
        pui.set_visible(Antiaim[i].Defensive_YawOffset.ref, isActiveTab3 and (Defensive_YawModifiervalue == "Disabled" or Defensive_YawModifiervalue == "Offset" or Defensive_YawModifiervalue == "Center"))
        pui.set_visible(Antiaim[i].Defensive_YawOffsetL.ref, isActiveTab3 and (Defensive_YawModifiervalue == "L&R" or Defensive_YawModifiervalue == "L&R Center" or Defensive_YawModifiervalue == "Tick Switcher" or Defensive_YawModifiervalue == "Delay"))
        pui.set_visible(Antiaim[i].Defensive_YawOffsetR.ref, isActiveTab3 and (Defensive_YawModifiervalue == "L&R" or Defensive_YawModifiervalue == "L&R Center" or Defensive_YawModifiervalue == "Tick Switcher" or Defensive_YawModifiervalue == "Delay"))
        pui.set_visible(Antiaim[i].Defensive_YawOffsetMax.ref, isActiveTab3 and (Defensive_YawModifiervalue == "Random"))
        pui.set_visible(Antiaim[i].Defensive_YawOffsetMin.ref, isActiveTab3 and (Defensive_YawModifiervalue == "Random"))
        pui.set_visible(Antiaim[i].Defensive_YawOffset1Way.ref, isActiveTab3 and (Defensive_YawModifiervalue == "3-Way" or Defensive_YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].Defensive_YawOffset2Way.ref, isActiveTab3 and (Defensive_YawModifiervalue == "3-Way" or Defensive_YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].Defensive_YawOffset3Way.ref, isActiveTab3 and (Defensive_YawModifiervalue == "3-Way" or Defensive_YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].Defensive_YawOffset4Way.ref, isActiveTab3 and (Defensive_YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].Defensive_YawOffset5Way.ref, isActiveTab3 and (Defensive_YawModifiervalue == "5-Way"))
        pui.set_visible(Antiaim[i].Defensive_YawOffsetTicks.ref, isActiveTab3 and (Defensive_YawModifiervalue == "Tick Switcher" or Defensive_YawModifiervalue == "Delay"))
    end
end



local function calculate_freestand()
    local local_player = entity.get_local_player()
    local eye_pos = vector(client.eye_position())
    local yaw = vector(client.camera_angles())
    local enemy = client.current_threat()
    local frac_num = {
        ["f_left"] = 0,
        ["f_right"] = 0
    }

    for i = yaw.y - 90, yaw.y + 90, 30 do
        if i ~= yaw.y then
            local rad = math.rad(i)
            local destination = vector(eye_pos.x + 256 * math.cos(rad), eye_pos.y + 256 * math.sin(rad), eye_pos.z)
            local trace, fraction = client.trace_line(local_player, eye_pos.x, eye_pos.y, eye_pos.z, destination.x, destination.y, destination.z)
            local side = i < yaw.y and "f_left" or "f_right"
            frac_num[side] = frac_num[side] + trace
        end
    end

    -- thinking about this i would need to make soo it checks teh yaw and does math but math is not for me gg have fun HAHHAHA

    if pui.get(Antiaim[p_state].Yaw.ref) == "Disabled" then
        -- Yaw_Offset_Back = 0
        return frac_num["f_left"] > frac_num["f_right"] and 80 or -80
    elseif pui.get(Antiaim[p_state].Yaw.ref) == "Backward" then
        -- print("backwards")
        return frac_num["f_left"] > frac_num["f_right"] and -80 or 80
        -- Yaw_Offset_Back = 180
    elseif pui.get(Antiaim[p_state].Yaw.ref) == "Static" then -- no idea what to do when this happens lol
        -- Yaw_Offset_Back = 0
        return frac_num["f_left"] > frac_num["f_right"] and -80 or 80
    end
end



enablelua:set_callback(function(self)
    if self.value == true then
        enabledluayay = true
        ui.set(gsrefs.enabled.ref, false)
        for key, value in pairs(gsrefs) do
            if value[1] then
                local data = value[1]
                local hotkey = data.hotkey
                if hotkey then
                    pui.set_visible(hotkey.ref, false)
                end
            end
            if not value.ref then
                for key2, value2 in pairs(value) do
                    pui.set_visible(value2.ref, false)
                end
                if value.hotkey then
                    pui.set_visible(value.hotkey.ref, false)
                end
            else
                pui.set_visible(value.ref, false)
            end
        end
    else
        enabledluayay = false
        for key, value in pairs(gsrefs) do
            if value[1] then
                local data = value[1]
                local hotkey = data.hotkey
                if hotkey then
                    pui.set_visible(hotkey.ref, true)
                end
            end
            if not value.ref then
                for key2, value2 in pairs(value) do
                    pui.set_visible(value2.ref, true)
                end
                if value.hotkey then
                    pui.set_visible(value.hotkey.ref, true)
                end
            else
                pui.set_visible(value.ref, true)
            end
        end
    end
end)

normalizeyaw = function(Angle)
    return math.fmod(Angle + 180, 360) - 180
end


local lastThrowTime = 0
turnoffantiaim = function(cmd)
    -- if safecallforend then return end
    local me = entity.get_local_player()
    if not me then
        return false
    end

    if entity.get_prop(me, "m_MoveType") == 9 and (client.key_state(0x57) or client.key_state(0x53)) then
        return true
    end

    local team = entity.get_prop(me, "m_bIsDefusing")
    local isdefusing = entity.get_prop(me, "m_bIsDefusing") == 1
    local isgrabhostage = entity.get_prop(me, "m_bIsGrabbingHostage") == 1
    local getplayersweapon = entity.get_player_weapon(me)
    local currentTime = client.timestamp()
    local throwthre = entity.get_prop(getplayersweapon, "m_flThrowStrength")

    if throwthre ~= nil and throwthre == 1 and (cmd.in_attack == 1 or cmd.in_attack2 == 1) then
        lastThrowTime = currentTime
        return true
    end


    if isdefusing or isgrabhostage or cmd.in_use == 1 or cmd.in_attack == 1 then
        return true
    end

    if currentTime - lastThrowTime <= 210 + client.latency() then
        return true
    end

    return false
end

local Real_Angles = 0
local Backup_Angles = 0
local Load_Angles = 0
local Yaw_Offset_Back = 0
local Yaw_Offset = 0
local Yaw_Mod_Offset = 0
local desync_value = 0
local shouldinvert = false
local knifeDetected = false
local shot_choke = 0
local chokedCommands = {}
local switchtick = 0
local dablet = false
local ManaulAA_angles = 0
local defensiveyaw = 0

function recordChokedCommands(cmd)
    if cmd and cmd.choked_commands then
        local value = cmd.choked_commands


        if value == 0 or value == 1 then
            -- print("Resetting table due to value: " .. value)
            chokedCommands = {}
        else
            table.insert(chokedCommands, value)
        end
    end
end

local function get_best_target()
    local local_player = entity.get_local_player()
    if not local_player then return nil end

    local eye_x, eye_y, eye_z = client.eye_position()
    local enemies = entity.get_players(true)
    
    local best_target = nil
    local best_distance = math.huge
    local best_visible_target = nil
    local best_visible_distance = math.huge
    
    for i = 1, #enemies do
        local entindex = enemies[i]
        local head_x, head_y, head_z = entity.hitbox_position(entindex, 0)
        
        local fraction, entindex_hit = client.trace_line(local_player, eye_x, eye_y, eye_z, head_x, head_y, head_z)
        local visible = (entindex_hit == entindex or fraction == 1)
        
        local distance = math.sqrt((eye_x - head_x)^2 + (eye_y - head_y)^2 + (eye_z - head_z)^2)
        
        if visible and distance < best_visible_distance then
            best_visible_distance = distance
            best_visible_target = entindex
        elseif not best_visible_target and distance < best_distance then
            best_distance = distance
            best_target = entindex
        end
    end
    
    return best_visible_target or best_target
end

local function calculate_yaw_to_target(local_x, local_y, target_x, target_y)
    return math.deg(math.atan2(target_y - local_y, target_x - local_x))
end

local def_vars = {
    defensive = {
        cmd = 0,
        check = 0,
        defensive = 0,
    },
}

local function get_defensive_tick_state()
    local tickbase = entity.get_prop(entity.get_local_player(), "m_nTickBase")
    local shift_ticks = math.abs(tickbase - def_vars.defensive.check)
    return shift_ticks > 1 and shift_ticks < 14 and shift_ticks % 3 ~= 1
end

client.set_event_callback("predict_command", function(e)
    if e.command_number == def_vars.defensive.cmd then
        local tickbase = entity.get_prop(entity.get_local_player(), "m_nTickBase")
        
        def_vars.defensive.defensive = math.abs(tickbase - def_vars.defensive.check)
        def_vars.defensive.check = math.max(tickbase, def_vars.defensive.check or 0)
        def_vars.defensive.cmd = 0
    end
end)

get_weapon_struct = function(player)
    local wpn = entity.get_player_weapon(player)
    if wpn == nil then return end
    local wep = weaponsstuff[entity.get_prop(wpn, "m_iItemDefinitionIndex")]
    if wep == nil then return end
    return wep
end

client.set_event_callback("run_command", function(e)
    def_vars.defensive.cmd = e.command_number
end)

local function is_hittable(ent)
    ent = ent == enemy and client.current_threat() or ent

    if entity.is_dormant(ent) or not entity.is_alive(ent) then
        return end

    return bit.band(entity.get_esp_data(ent).flags, 2048) ~= 0
end

AntiAimBuild = function (cmd)
    -- if safecallforend then return end

    local me = entity.get_local_player()
    if not pui.get(Antiaim[0].enableantiaim.ref) then return end
    if turnoffantiaim(cmd) then return end

    if not Antiaim then return end
    if not Antiaim[p_state].comboboxui.ref then return end
    if not pui.get(Antiaim[p_state].comboboxui.ref) then
        p_state = 1
    end

    
    if contains(pui.get(Antiaim[9].SafeHeadoptions.ref), "Zues") and pui.get(Antiaim[9].comboboxui.ref) then
        local weapon_type = get_weapon_struct(me) ~= nil and get_weapon_struct(me).type
        if weapon_type == "taser" then
            p_state = 9
        end
    end

    if contains(pui.get(Antiaim[9].SafeHeadoptions.ref), "Knife") and pui.get(Antiaim[9].comboboxui.ref) then
        local weapon_type = get_weapon_struct(me) ~= nil and get_weapon_struct(me).type
        if weapon_type == "knife" then
            p_state = 9
        end
    end

    if pui.get(Antiaim[p_state].Defensive.ref) then
        if pui.get(Antiaim[p_state].Defensive_onlyhittable.ref) then
            local _hittable = pui.get(Antiaim[p_state].Defensive_onlyhittable.ref) and is_hittable(client.current_threat())
            if _hittable then
                dablet = true
                cmd.force_defensive = dablet
            else
                dablet = false
                cmd.force_defensive = dablet
            end
        else
            cmd.force_defensive = dablet
            dablet = true
        end


        if get_defensive_tick_state() and dablet then
            if pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "Disabled" then
                defensiveyaw = pui.get(Antiaim[p_state].Defensive_YawOffset.ref)
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "Center" then
                defensiveyaw = cmd.command_number % 6 > 3 and -pui.get(Antiaim[p_state].Defensive_YawOffset.ref) or pui.get(Antiaim[p_state].Defensive_YawOffset.ref)
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "Offset" then
                defensiveyaw = cmd.command_number % 6 > 3 and pui.get(Antiaim[p_state].Defensive_YawOffset.ref) or 0
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "Random" then
                defensiveyaw = math.random(pui.get(Antiaim[p_state].Defensive_YawOffsetMin.ref), pui.get(Antiaim[p_state].Defensive_YawOffsetMax.ref))
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "Spin" then
                defensiveyaw = math.normalize_yaw(globals.curtime * 1000)
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "3-Way" then
                defensiveyaw = globals.tickcount() % 3 == 0 and pui.get(Antiaim[p_state].Defensive_YawOffset1Way.ref) or globals.tickcount() % 3 == 1 and pui.get(Antiaim[p_state].Defensive_YawOffset2Way.ref) or globals.tickcount() % 3 == 2 and pui.get(Antiaim[p_state].Defensive_YawOffset3Way.ref) or 0
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "5-Way" then
                defensiveyaw = globals.tickcount() % 5 == 0 and pui.get(Antiaim[p_state].Defensive_YawOffset1Way.ref) or globals.tickcount() % 5 == 1 and pui.get(Antiaim[p_state].Defensive_YawOffset2Way.ref) or globals.tickcount() % 5 == 2 and pui.get(Antiaim[p_state].Defensive_YawOffset3Way.ref) or globals.tickcount() % 5 == 3 and pui.get(Antiaim[p_state].Defensive_YawOffset4Way.ref) or globals.tickcount() % 5 == 3 and pui.get(Antiaim[p_state].Defensive_YawOffset5Way.ref) or 0
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "100-Way" then
                defensiveyaw = 0
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "Tick Switcher" then
                tick = globals.tickcount() % 30 > pui.get(Antiaim[p_state].Defensive_YawOffsetTicks.ref)
                if tick then
                    defensiveyaw = pui.get(Antiaim[p_state].Defensive_YawOffsetL.ref)
                else
                    defensiveyaw = pui.get(Antiaim[p_state].Defensive_YawOffsetR.ref)
                end
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "Delay" then
                if globals.tickcount() % pui.get(Antiaim[p_state].Defensive_YawOffsetTicks.ref) == (pui.get(Antiaim[p_state].Defensive_YawOffsetTicks.ref) - 1) then
                -- if globals.tickcount() % pui.get(Antiaim[p_state].Defensive_YawOffsetTicks.ref) > pui.get(Antiaim[p_state].Defensive_YawOffsetTicks.ref) / 2 then
                -- if switchtick < globals.tickcount() then
                    shouldinvert = not shouldinvert
                    switchtick = globals.tickcount() + pui.get(Antiaim[p_state].Defensive_YawOffsetTicks.ref)
                end
        
                if shouldinvert then
                    defensiveyaw = pui.get(Antiaim[p_state].Defensive_YawOffsetR.ref)
                else
                    defensiveyaw = pui.get(Antiaim[p_state].Defensive_YawOffsetL.ref)
                end
                
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "L&R" then
                defensiveyaw = cmd.command_number % 6 > 3 and pui.get(Antiaim[p_state].Defensive_YawOffsetL.ref) or pui.get(Antiaim[p_state].Defensive_YawOffsetR.ref)
            elseif pui.get(Antiaim[p_state].Defensive_YawModifier.ref) == "L&R Center" then
                defensiveyaw = globals.tickcount() % 3 == 0 and pui.get(Antiaim[p_state].Defensive_YawOffsetL.ref) or globals.tickcount() %3 == 1 and pui.get(Antiaim[p_state].Defensive_YawOffsetR.ref) or globals.tickcount() %3 == 2 and 0
            end
            
            cmd.yaw = normalizeyaw(defensiveyaw) + cmd.yaw + 180
            
            if pui.get(Antiaim[p_state].Defensive_Pitch.ref) == "Disabled" then
                -- cmd.view_angles.x = 0
                cmd.pitch = cmd.pitch
            elseif pui.get(Antiaim[p_state].Defensive_Pitch.ref) == "Down" then
                cmd.pitch = 89
            elseif pui.get(Antiaim[p_state].Defensive_Pitch.ref) == "0" then
                cmd.pitch = 0
            elseif pui.get(Antiaim[p_state].Defensive_Pitch.ref) == "57" then
                cmd.pitch = -57
            end
            return
        end
    end

    local Targeting = 0
    local Directionslooking = cmd.yaw

    if pui.get(Antiaim[p_state].YawModifier.ref) == "Disabled" then
        Yaw_Mod_Offset = pui.get(Antiaim[p_state].YawOffset.ref)
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "Center" then
        Yaw_Mod_Offset = cmd.command_number % 6 > 3 and -pui.get(Antiaim[p_state].YawOffset.ref) or pui.get(Antiaim[p_state].YawOffset.ref)
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "Offset" then
        Yaw_Mod_Offset = cmd.command_number % 6 > 3 and pui.get(Antiaim[p_state].YawOffset.ref) or 0
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "Random" then
        Yaw_Mod_Offset = math.random(pui.get(Antiaim[p_state].YawOffsetMin.ref), pui.get(Antiaim[p_state].YawOffsetMax.ref))
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "Spin" then
        Yaw_Mod_Offset = math.normalize_yaw(globals.curtime * 1000)
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "3-Way" then
        Yaw_Mod_Offset = globals.tickcount() % 3 == 0 and pui.get(Antiaim[p_state].YawOffset1Way.ref) or globals.tickcount() % 3 == 1 and pui.get(Antiaim[p_state].YawOffset2Way.ref) or globals.tickcount() % 3 == 2 and pui.get(Antiaim[p_state].YawOffset3Way.ref) or 0
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "5-Way" then
        Yaw_Mod_Offset = globals.tickcount() % 5 == 0 and pui.get(Antiaim[p_state].YawOffset1Way.ref) or globals.tickcount() % 5 == 1 and pui.get(Antiaim[p_state].YawOffset2Way.ref) or globals.tickcount() % 5 == 2 and pui.get(Antiaim[p_state].YawOffset3Way.ref) or globals.tickcount() % 5 == 3 and pui.get(Antiaim[p_state].YawOffset4Way.ref) or globals.tickcount() % 5 == 3 and pui.get(Antiaim[p_state].YawOffset5Way.ref) or 0
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "100-Way" then
        Yaw_Mod_Offset = 0
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "Tick Switcher" then
        tick = globals.tickcount() % 30 > pui.get(Antiaim[p_state].YawOffsetTicks.ref)
        if tick then
            Yaw_Mod_Offset = pui.get(Antiaim[p_state].YawOffsetL.ref)
        else
            Yaw_Mod_Offset = pui.get(Antiaim[p_state].YawOffsetR.ref)
        end
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "Delay" then
        if globals.tickcount() % pui.get(Antiaim[p_state].YawOffsetTicks.ref) == (pui.get(Antiaim[p_state].YawOffsetTicks.ref) - 1) then
        -- if globals.tickcount() % pui.get(Antiaim[p_state].YawOffsetTicks.ref) > pui.get(Antiaim[p_state].YawOffsetTicks.ref) / 2 then
        -- if switchtick < globals.tickcount() then
            shouldinvert = not shouldinvert
            switchtick = globals.tickcount() + pui.get(Antiaim[p_state].YawOffsetTicks.ref)
        end

        if shouldinvert then
            Yaw_Mod_Offset = pui.get(Antiaim[p_state].YawOffsetR.ref)
        else
            Yaw_Mod_Offset = pui.get(Antiaim[p_state].YawOffsetL.ref)
        end
        
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "L&R" then
        Yaw_Mod_Offset = cmd.command_number % 6 > 3 and pui.get(Antiaim[p_state].YawOffsetL.ref) or pui.get(Antiaim[p_state].YawOffsetR.ref)
    elseif pui.get(Antiaim[p_state].YawModifier.ref) == "L&R Center" then
        Yaw_Mod_Offset = globals.tickcount() % 3 == 0 and pui.get(Antiaim[p_state].YawOffsetL.ref) or globals.tickcount() %3 == 1 and pui.get(Antiaim[p_state].YawOffsetR.ref) or globals.tickcount() %3 == 2 and 0
    end

    if pui.get(extrasantiaim.AntiBackstab.ref) then
        local players = entity.get_players(true)
        if players ~= nil then
            local lp_pos = vector(entity.get_prop(me, "m_vecOrigin"))
            for i, enemy in pairs(players) do
                local ent_pos = vector(entity.get_prop(enemy, "m_vecOrigin"))
                local weapon_type = get_weapon_struct(enemy) ~= nil and get_weapon_struct(enemy).type
                if weapon_type == "knife" and 250 >= ent_pos:dist(lp_pos) then
                    knifeDetected = true
                elseif weapon_type == "knife" and 250 <= ent_pos:dist(lp_pos) then
                    knifeDetected = false
                end
            end
        end
    else
        knifeDetected = false
    end

    if pui.get(Antiaim[p_state].Yaw.ref) == "Disabled" then
        Yaw_Offset_Back = 0
    elseif pui.get(Antiaim[p_state].Yaw.ref) == "Backward" then
        Yaw_Offset_Back = 180
    elseif pui.get(Antiaim[p_state].Yaw.ref) == "Static" then
        Yaw_Offset_Back = 0
    end
    
    local best_target = client.current_threat() or get_best_target()
    if pui.get(Antiaim[p_state].Base.ref) == "At Target" and best_target then
        local localp = vector(entity.get_origin(me))
        local target = vector(entity.get_origin(best_target))
        local yaw_to_target = calculate_yaw_to_target(localp.x, localp.y, target.x, target.y)
        if not yaw_to_target then 
            Targeting = nil
        end
        Targeting = yaw_to_target or cmd.yaw
        if Targeting == nil then
            if knifeDetected then
                Backup_Angles = cmd.yaw + Yaw_Offset_Back
                Real_Angles = cmd.yaw + Yaw_Offset + Yaw_Offset_Back
            else
                Backup_Angles = cmd.yaw + Yaw_Offset_Back
                Real_Angles = cmd.yaw + Yaw_Offset + Yaw_Mod_Offset + Yaw_Offset_Back
            end
        else
            if knifeDetected then
                Backup_Angles = Targeting + 180
                Real_Angles = Targeting + 180 + Yaw_Offset + Yaw_Mod_Offset + Yaw_Offset_Back
            else
                Backup_Angles = Targeting
                Real_Angles = Targeting + Yaw_Offset + Yaw_Mod_Offset + Yaw_Offset_Back
            end
        end
    else
        Backup_Angles = cmd.yaw + Yaw_Offset_Back
        Real_Angles = cmd.yaw + Yaw_Offset + Yaw_Mod_Offset + Yaw_Offset_Back
    end


    Yaw_Offset = pui.get(Antiaim[p_state].YawOffset2.ref)
    if pui.get(Antiaim[p_state].BodyYaw.ref) then
        if pui.get(Antiaim[p_state].Invert2.ref) then
            if pui.get(Antiaim[p_state].Invert.ref) then
                desync_value = -pui.get(Antiaim[p_state].Desync1.ref) *2
            else
                desync_value = pui.get(Antiaim[p_state].Desync2.ref) *2
            end
        else
            if pui.get(Antiaim[p_state].Invert.ref) then
                desync_value = pui.get(Antiaim[p_state].Desync2.ref) *2
            else
                desync_value = -pui.get(Antiaim[p_state].Desync1.ref) *2
            end
        end
    else
        desync_value = 0
    end
    



    
    if cmd.chokedcommands ~= 1 then
        cmd.allow_send_packet = false
    end
    
    if shot_choke > 0 then 
        shot_choke = shot_choke - 1
        cmd.allow_send_packet = true
    end
    

    if pui.get(Antiaim[p_state].Pitch.ref) == "Disabled" then
        -- cmd.view_angles.x = 0
    elseif pui.get(Antiaim[p_state].Pitch.ref) == "Down" then
        cmd.pitch = 89
    elseif pui.get(Antiaim[p_state].Pitch.ref) == "0" then
        cmd.pitch = 0
    end

    
    Load_Angles = Real_Angles




    if not knifeDetected then
        if pui.get(extrasantiaim.ManualAA_Forward.ref) and pui.get(extrasantiaim.ManualAA_Forward_key.ref) then
            ManaulAA_angles = 180
        elseif pui.get(extrasantiaim.ManualAA_Left.ref) and pui.get(extrasantiaim.ManualAA_Left_key.ref) then
            ManaulAA_angles = -85
        elseif pui.get(extrasantiaim.ManualAA_Right.ref) and pui.get(extrasantiaim.ManualAA_Right_key.ref) then
            ManaulAA_angles = 85
        elseif pui.get(Antiaim[0].fs_key.ref) and pui.get(Antiaim[0].freestanding.ref) then
            local freestand_angle = calculate_freestand()
            ManaulAA_angles = freestand_angle or 0
        else
            ManaulAA_angles = 0
        end
    else
        ManaulAA_angles = 0
    end


    if cmd.chokedcommands == 0 then
        cmd.yaw = normalizeyaw(Real_Angles) + normalizeyaw(desync_value)
    else
        cmd.yaw = normalizeyaw(Load_Angles) + ManaulAA_angles
    end
end

local refs = {
    sw = {ui.reference("AA", "Other", "Slow motion")},
    -- doubletap = pui.reference("AA", "Anti-aimbot angles", "Enabled");
    -- hideshots = pui.reference("AA", "Anti-aimbot angles", "Enabled");
    -- fd = {pui.reference("rage", "Other", "Duck peek assist")};
}

get_conditions = function()
    local me = entity.get_local_player()
    if not me then
        return 99
    end


    local slowmotion = pui.get(refs.sw[1]) and pui.get(refs.sw[2])
    local vec_x, vec_y, vec_z = entity.get_prop(me, "m_vecVelocity")
    local vectorofvel = vector(vec_x, vec_y, vec_z)
    local velocity = math.sqrt((vec_x * vec_x) + (vec_y * vec_y))


    if entity.get_prop(me, "m_fFlags") == 262 and entity.get_prop(me, "m_flDuckAmount") > 0.8 then
        p_state = 8 -- IN AIR + CROUCH
    elseif entity.get_prop(me, "m_fFlags") == 256 then
        p_state = 7 -- IN AIR
    elseif entity.get_prop(me, "m_flDuckAmount") > 0.8 and vectorofvel:length() > 2 then
        p_state = 6 -- Crouch + MOVING
    elseif entity.get_prop(me, "m_flDuckAmount") > 0.8 then
        p_state = 5 -- Crouch
    elseif slowmotion then
        p_state = 4 -- SLOW WALK
    elseif velocity <= 2 then
        p_state = 2 -- STANDING
    elseif velocity >= 3 then
        p_state = 3 -- MOVING
    end

    -- print(me.m_bSendPacket)
    
    -- print_dev("Player State: ", player_states[p_state])
end

function showinfo()

    if contains(pui.get(extrasantiaim.SideIndicators.ref), "Safe Head") then
        if p_state == 9 then
            renderer.indicator(0, 255, 0, 255, "Safe Head")
        end
    end
    
    if contains(pui.get(extrasantiaim.SideIndicators.ref), "Manual AA") then
        if pui.get(extrasantiaim.ManualAA_Forward.ref) and pui.get(extrasantiaim.ManualAA_Forward_key.ref) then
            renderer.indicator(255, 0, 0, 255, "Manual: Forward")
        elseif pui.get(extrasantiaim.ManualAA_Left.ref) and pui.get(extrasantiaim.ManualAA_Left_key.ref) then
            renderer.indicator(255, 0, 0, 255, "Manual: Left")
        elseif pui.get(extrasantiaim.ManualAA_Right.ref) and pui.get(extrasantiaim.ManualAA_Right_key.ref) then
            renderer.indicator(255, 0, 0, 255, "Manual: Right")
        end
    end

    if (pui.get(Antiaim[0].fs_key.ref) and pui.get(Antiaim[0].freestanding.ref)) and contains(pui.get(extrasantiaim.SideIndicators.ref), "Freestanding") then
        if (pui.get(extrasantiaim.ManualAA_Forward.ref) and pui.get(extrasantiaim.ManualAA_Forward_key.ref)) or (pui.get(extrasantiaim.ManualAA_Left.ref) and pui.get(extrasantiaim.ManualAA_Left_key.ref)) or (pui.get(extrasantiaim.ManualAA_Right.ref) and pui.get(extrasantiaim.ManualAA_Right_key.ref)) then
            renderer.indicator(255, 0, 0, 255, "FS")
        else
            renderer.indicator(0, 255, 0, 255, "FS")
        end
    end
    
    if contains(pui.get(extrasantiaim.SideIndicators.ref), "Condtions") then
        if reversed_player_states_idx[p_state] == nil then
            renderer.indicator(255, 255, 255, 255, "Condition: Loading...")

        else
            renderer.indicator(255, 255, 255, 255, "Condition: "..reversed_player_states_idx[p_state].."")
        end
    end
    if contains(pui.get(extrasantiaim.SideIndicators.ref), "Defensive Status") then
        renderer.indicator(255, 255, 255, 255, "Defensive: "..tostring(get_defensive_tick_state() and dablet).."")
    end
    renderer.indicator(255, 255, 255, 255, "")
end

local aim_fire_data = {}




client.register_esp_flag("BAIM!", 255, 0, 0, function(self) 
    if not entity.is_dormant(self) and entity.is_alive(self) then
        if pui.get(extrasantiaim.BaimIfLethal.ref) and pui.get(extrasantiaim.Baimatwhathealth.ref) >= entity.get_prop(self, "m_iHealth") then
            plist.set(self, "Override prefer body aim", "Force")
            return "BAIM!"
        else
            plist.set(self, "Override prefer body aim", "-")
        end
    end
end)

local lastlocations = {}

function Showlastpositonenemy()
    local me = entity.get_local_player()
    if me == nil then return end
    if not pui.get(extrasantiaim.showdormantlastposition.ref) then return end

    for i = 1, globals.maxplayers() do
        if entity.get_prop(i, "m_iTeamNum") == 3 or entity.get_prop(i, "m_iTeamNum") == 2 then
            if entity.is_enemy(i) then
                local x1, y1, x2, y2, alpha_multiplier = entity.get_bounding_box(i)
                local found_index = nil

                for index, data in pairs(lastlocations) do
                    if data.entity == i then
                        found_index = index
                        break
                    end
                end

                if alpha_multiplier == 1 then
                    -- Fully visible, remove from the stored list
                    if found_index then
                        table.remove(lastlocations, found_index)
                    end
                elseif alpha_multiplier > 0 then
                    local origin = vector(entity.get_origin(i))

                    if found_index then
                        -- Update the position if the entity is still valid and not fully hidden
                        if x1 and y1 and x2 and y2 and x1 ~= 0 and y1 ~= 0 then
                            lastlocations[found_index].last_origin = origin
                            lastlocations[found_index].x1 = x1
                            lastlocations[found_index].y1 = y1
                            lastlocations[found_index].x2 = x2
                            lastlocations[found_index].y2 = y2
                        end
                    else
                        -- Add the entity if not already in the list, as long as the bounding box is valid
                        if x1 and y1 and x2 and y2 and x1 ~= 0 and y1 ~= 0 then
                            table.insert(lastlocations, {
                                entity = i,
                                name = entity.get_player_name(i),
                                last_origin = origin,
                                x1 = x1,
                                y1 = y1,
                                x2 = x2,
                                y2 = y2,
                            })
                        end
                    end
                end
            end
        end
    end

    -- Draw stored locations
    for _, value in pairs(lastlocations) do
        local screen_x, screen_y = renderer.world_to_screen(value.last_origin.x, value.last_origin.y, value.last_origin.z)

        -- Only draw if we have valid coordinates from world to screen conversion
        if screen_x and screen_y then
            local width = math.abs(value.x2 - value.x1)
            local height = math.abs(value.y2 - value.y1)

            if width > 0 and height > 0 then
                -- Draw the bounding box as lines around the last known position
                renderer.line(screen_x - width / 2, screen_y - height / 2, screen_x + width / 2, screen_y - height / 2, 255, 0, 0, 255) -- Top
                renderer.line(screen_x - width / 2, screen_y + height / 2, screen_x + width / 2, screen_y + height / 2, 255, 0, 0, 255) -- Bottom
                renderer.line(screen_x - width / 2, screen_y - height / 2, screen_x - width / 2, screen_y + height / 2, 255, 0, 0, 255) -- Left
                renderer.line(screen_x + width / 2, screen_y - height / 2, screen_x + width / 2, screen_y + height / 2, 255, 0, 0, 255) -- Right

                -- Draw name above the box
                renderer.text(screen_x, screen_y - height / 2 - 15, 255, 255, 255, 255, nil, nil, value.name)
            else
                -- If the bounding box is invalid, only show the last known position as a point
                renderer.line(screen_x, screen_y, screen_x + 1, screen_y + 1, 255, 0, 0, 255) -- Single point if the box is invalid
            end
        end
    end
end


function animationbreaker()
    local me = entity.get_local_player()
    if not me then
        return 
    end

    local self_index = c_entity.new(me)
    local self_anim_overlay = self_index:get_anim_overlay(9)
    if not self_anim_overlay then
        return
    end

    if contains(pui.get(extrasantiaim.animationbreaker.ref), "Always flashed") then
        lerp.lerp("flashedanim", pui.get(extrasantiaim.Alwaysflashed.ref)/100, 5)
        self_anim_overlay.weight = lerp.get("flashedanim")
        self_anim_overlay.sequence = 224
    else
        lerp.lerp("flashedanim", 0, 3)
        self_anim_overlay.weight = lerp.get("flashedanim")
    end

    if contains(pui.get(extrasantiaim.animationbreaker.ref), "Vibrator") then
        entity.set_prop(me, "m_flPoseParameter", math.random(0, 20)/10, 6)
    end
    if contains(pui.get(extrasantiaim.animationbreaker.ref), "Moon Walk") then
        -- entity.set_prop(me, "m_flPoseParameter", math.random(0, 20)/10, 6)
        -- entity.set_prop(me, 'm_flPoseParameter', 0, 7)
        entity.set_prop(me, 'm_flPoseParameter', 1, 6)
    end
end

client.set_event_callback("setup_command", get_conditions)
client.set_event_callback("setup_command", AntiAimBuild)
client.set_event_callback("paint", Showlastpositonenemy)
client.set_event_callback("pre_render", animationbreaker)

client.set_event_callback("item_purchase", function(purchase)
    local me = entity.get_local_player()
    local meow2 = client.userid_to_entindex(purchase.userid)
    local m_iTeamNumme = entity.get_prop(me, "m_iTeamNum")
    local getplayername = entity.get_player_name(meow2)
    local weaponname = purchase.weapon:gsub("weapon_", "")
    if pui.get(extrasantiaim.Ragebotlogs.ref) and contains(pui.get(extrasantiaim.Logsoptions.ref), "Purchase") then
        if purchase.team ~= m_iTeamNumme and me ~= meow2 then
            print("[SOLIX] [Purchase]: Player:["..getplayername.."] bought:["..weaponname.."]")
        end
    end
end)


client.set_event_callback("player_hurt", function(purchase)
    local me = entity.get_local_player()
    local meow1 = client.userid_to_entindex(purchase.attacker)
    local meow2 = client.userid_to_entindex(purchase.userid)
    local m_iTeamNummeattacker = entity.get_prop(meow1, "m_iTeamNum")
    local m_iTeamNummehurt = entity.get_prop(meow2, "m_iTeamNum")
    local getplayernameattacker = entity.get_player_name(meow1)
    local getplayernamehurt = entity.get_player_name(meow2)
    local weaponname = purchase.dmg_health
    local weaponname2 = purchase.weapon:gsub("weapon_", "")
    if pui.get(extrasantiaim.Ragebotlogs.ref) and contains(pui.get(extrasantiaim.Logsoptions.ref), "Harmed") then
        if m_iTeamNummeattacker ~= m_iTeamNummehurt and me == meow2 then
            print("[SOLIX] [Harmed]: Player:["..getplayernameattacker.."] hurt you for damage:["..weaponname.."] with weapon:["..weaponname2.."]")
        end
    end
end)


local inferno_damage = {}
local inferno_timers = {}

client.set_event_callback("player_hurt", function(purchase)
    local me = entity.get_local_player()
    local meow1 = client.userid_to_entindex(purchase.attacker)
    local meow2 = client.userid_to_entindex(purchase.userid)
    local weaponname = purchase.dmg_health
    local weaponname2 = purchase.weapon:gsub("weapon_", "")
    local getplayernamehurt = entity.get_player_name(meow2)
    if pui.get(extrasantiaim.Ragebotlogs.ref) and contains(pui.get(extrasantiaim.Logsoptions.ref), "Molotov/Granades") then
        if me == meow1 and weaponname2 == "inferno" then
            if not inferno_damage[meow2] then
                inferno_damage[meow2] = 0
            end
            inferno_damage[meow2] = inferno_damage[meow2] + weaponname
            -- print("[SOLIX] [Burn]: You burned:["..getplayernamehurt.."] for damage:["..weaponname.."]")

            inferno_timers[meow2] = globals.realtime() + 1.0
        end
    end
end)

client.set_event_callback("player_hurt", function(purchase)
    local me = entity.get_local_player()
    local meow1 = client.userid_to_entindex(purchase.attacker)
    local meow2 = client.userid_to_entindex(purchase.userid)
    local weaponname = purchase.dmg_health
    local weaponname2 = purchase.weapon:gsub("weapon_", "")
    local getplayernamehurt = entity.get_player_name(meow2)
    if pui.get(extrasantiaim.Ragebotlogs.ref) and contains(pui.get(extrasantiaim.Logsoptions.ref), "Molotov/Granades") then
        if purchase.weapon:gsub("weapon_", "") == "hegrenade" then
            print("[SOLIX] [Explosion]: Exploded:["..getplayernamehurt.."] for damage:["..weaponname.."]")
        end
    end
end)

client.set_event_callback("setup_command", function()
    local current_time = globals.realtime()
    for player, expire_time in pairs(inferno_timers) do
        if current_time > expire_time then
            local getplayernamehurt = entity.get_player_name(player)
            if inferno_damage[player] then
                print("[SOLIX] [Burn]: Burned:["..getplayernamehurt.."] for total damage: ["..inferno_damage[player].."]")
                inferno_damage[player] = nil
                inferno_timers[player] = nil
            end
        end
    end
end)

local shot_data = {}
local hitgroup_names = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear"}

client.set_event_callback("aim_fire", function(e)
    if not contains(pui.get(extrasantiaim.Logsoptions.ref), "Fired") then return end

    local target_name = entity.get_player_name(e.target)
    local target_desync = aim_fire_data[e.target] and math.floor(aim_fire_data[e.target].desync) or "Unknown"
    if not aim_fire_data[e.target].enabled then
        target_desync = "?"
    else
        target_desync = aim_fire_data[e.target] and math.floor(aim_fire_data[e.target].desync) or "Unknown"
    end

    shot_data[e.id] = {
        target = e.target,
        hit_chance = math.floor(e.hit_chance),
        hitgroup = hitgroup_names[e.hitgroup + 1] or "?",
        damage = math.floor(e.damage),
        backtrack = math.floor(e.backtrack),
        boosted = e.boosted,
        high_priority = e.high_priority,
        interpolated = e.interpolated,
        extrapolated = e.extrapolated,
        teleported = e.teleported,
        tick = e.tick,
        x = e.x,
        y = e.y,
        z = e.z,
        desync = target_desync -- Store desync for the shot
    }
    print(" ")
    print("[SOLIX] [Fired]: Shot at " .. target_name .. " in " .. hitgroup_names[e.hitgroup + 1] .." for " .. math.floor(e.damage) .. " hitchance: " .. math.floor(e.hit_chance) .. " BT: " .. math.floor(e.backtrack) .. " Desync: " .. target_desync)
end)


client.set_event_callback("aim_hit", function(e)
    if not contains(pui.get(extrasantiaim.Logsoptions.ref), "Hit") then return end
    local shot = shot_data[e.id]
    if shot then
        local target_name = entity.get_player_name(shot.target)
        local hitgroupbs = hitgroup_names[e.hitgroup + 1] or "?"
        print(" ")
        if shot.hit_chance == math.floor(e.hit_chance) and shot.damage == math.floor(e.damage) and shot.hitgroup == hitgroupbs then
            print("[SOLIX] [Hit]: Shot:" .. target_name .. " in " .. hitgroupbs .." for " .. math.floor(e.damage) .. " hitchance:" .. math.floor(e.hit_chance) .." BT:" .. math.floor(shot.backtrack) .. " Desync:" .. shot.desync)
        elseif shot.hit_chance ~= math.floor(e.hit_chance) and shot.damage ~= math.floor(e.damage) and shot.hitgroup ~= hitgroupbs then
            print("[SOLIX] [Hit]: Shot:" .. target_name .. " in " .. hitgroupbs .."/" .. shot.hitgroup .. " for " .. math.floor(e.damage) .. "/" .. math.floor(shot.damage) .." hitchance:" .. math.floor(e.hit_chance) .. "/" .. math.floor(shot.hit_chance) .." BT:" .. math.floor(shot.backtrack) .. " Desync:" .. shot.desync)
        elseif shot.hit_chance ~= math.floor(e.hit_chance) and shot.damage ~= math.floor(e.damage) then
            print("[SOLIX] [Hit]: Shot:" .. target_name .. " in " .. hitgroupbs .." for " .. math.floor(e.damage) .. "/" .. math.floor(shot.damage) .." hitchance:" .. math.floor(e.hit_chance) .. "/" .. math.floor(shot.hit_chance) .." BT:" .. math.floor(shot.backtrack) .. " Desync:" .. shot.desync)
        elseif shot.hit_chance ~= math.floor(e.hit_chance) and shot.hitgroup ~= hitgroupbs then
            print("[SOLIX] [Hit]: Shot:" .. target_name .. " in " .. hitgroupbs .."/" .. shot.hitgroup .. " for " .. math.floor(e.damage) .." hitchance:" .. math.floor(e.hit_chance) .. "/" .. math.floor(shot.hit_chance) .." BT:" .. math.floor(shot.backtrack) .. " Desync:" .. shot.desync)
        elseif shot.damage ~= math.floor(e.damage) and shot.hitgroup ~= hitgroupbs then
            print("[SOLIX] [Hit]: Shot:" .. target_name .. " in " .. hitgroupbs .."/" .. shot.hitgroup .. " for " .. math.floor(e.damage) .. "/" .. math.floor(shot.damage) .." hitchance:" .. math.floor(e.hit_chance) .. " BT:" .. math.floor(shot.backtrack) .." Desync:" .. shot.desync)
        elseif shot.hit_chance ~= math.floor(e.hit_chance) then
            print("[SOLIX] [Hit]: Shot:" .. target_name .. " in " .. hitgroupbs .." for " .. math.floor(e.damage) .. " hitchance:" .. math.floor(e.hit_chance) .."/" .. math.floor(shot.hit_chance) .. " BT:" .. math.floor(shot.backtrack) .." Desync:" .. shot.desync)
        elseif shot.damage ~= math.floor(e.damage) then
            print("[SOLIX] [Hit]: Shot:" .. target_name .. " in " .. hitgroupbs .." for " .. math.floor(e.damage) .. "/" .. math.floor(shot.damage) .." hitchance:" .. math.floor(e.hit_chance) .. " BT:" .. math.floor(shot.backtrack) .." Desync:" .. shot.desync)
        elseif shot.hitgroup ~= hitgroupbs then
            print("[SOLIX] [Hit]: Shot:" .. target_name .. " in " .. hitgroupbs .."/" .. shot.hitgroup .. " for " .. math.floor(e.damage) .." hitchance:" .. math.floor(e.hit_chance) .. " BT:" .. math.floor(shot.backtrack) .." Desync:" .. shot.desync)
        end
        shot_data[e.id] = nil
    end
end)



client.set_event_callback("aim_miss", function(e)
    if not contains(pui.get(extrasantiaim.Logsoptions.ref), "Miss") then return end
    local shot = shot_data[e.id]
    if shot then
        local target_name = entity.get_player_name(shot.target)
        local reason = "?"
        if e.reason == "?" then
            reason = "Resolver"
        elseif e.reason == "?" and pui.get(extrasantiaim.ResolverAP.ref) then
            reason = "Resolver [SOLIX]"
        else
            reason = e.reason
        end
        print(" ")
        print("[SOLIX] [Hit]: Shot:"..target_name.." missed due to "..e.reason.." in "..hitgroup_names[e.hitgroup + 1] or "?".." for "..shot.damage.." hitchance:"..shot.hit_chance.." BT:"..shot.backtrack)  
        shot_data[e.id] = nil
    end
end)

catchshoit = function()
    shot_choke = 2
end
client.set_event_callback("aim_fire", catchshoit)
client.set_event_callback("paint_ui", menuhandaler)
client.set_event_callback("paint", showinfo)
local needtosave = {
    Antiaim[0],
    Antiaim[1],
    Antiaim[2],
    Antiaim[3],
    Antiaim[4],
    Antiaim[5],
    Antiaim[6],
    Antiaim[7],
    Antiaim[8],
    Antiaim[9],
    extrasantiaim,
}
local puisetup = pui.setup(needtosave)
if puisetup then
    print("")
else
    print("")
end

pui.set_callback(configmenu.mainconfigmenu.ref, function ()
    local index = pui.get(configmenu.mainconfigmenu.ref)
    if index == nil then return end  -- avoid arithmetic on nil

    local selectedIndex = index + 1
    local selectedConfig = configs[selectedIndex]
    if selectedConfig == nil then return end

    pui.set(configmenu.inputname.ref, selectedConfig)
end)

refreshconfigfolder = function()
    configs = {}
    local path = localdirectory.."/solix/Config/*"
    local handle, file = FileSystem.find_first(path)
    while file do
        if file ~= ".." then
            table.insert(configs, file)
        end
        file = FileSystem.find_next(handle[0])
    end
    
    if handle then
        FileSystem.find_close(handle[0])
    end
    pui.update(configmenu.mainconfigmenu.ref, configs)
end

createconfig = function ()
    function realstuff()
        local inputname = pui.get(configmenu.inputname.ref)
        writefile(tostring("/solix/Config/"..inputname..""), " ")
    end
    
    local s, ret = pcall(realstuff)
    if not s then
        print("Something went wrong with the config hmm? "..ret.."")
    else
        print("Config Saved!")
        refreshconfigfolder()
        client.exec("playvol  buttons/bell1.wav 1")
    end
end

saveconfig = function ()
    function realstuff()
        local config = puisetup:save()
        local encrypted = json.stringify(config)
        local inputname = pui.get(configmenu.inputname.ref)
        local selectedIndex = pui.get(configmenu.mainconfigmenu.ref) + 1
        if inputname == "nil" then return end
        writefile(tostring("/solix/Config/"..inputname..""), encrypted)
    end
    
    local s, ret = pcall(realstuff)
    if not s then
        print("Something went wrong with the config hmm? "..ret.."")
    else
        print("Config Saved!")
        refreshconfigfolder()
        client.exec("playvol  buttons/bell1.wav 1")
    end
end

deleteconfig = function ()
    function realstuff()
        local config = puisetup:save()
        local encrypted = json.stringify(config)
        local selectedIndex = pui.get(configmenu.mainconfigmenu.ref) + 1
        local inputname = pui.get(configmenu.inputname.ref)
        if inputname == "nil" then return end
        FileSystem.remove(localdirectory.."/solix/Config/"..inputname.."", encrypted)
    end

    local s, ret = pcall(realstuff)
    if not s then
        print("Something went wrong with the config hmm? "..ret.."")
    else
        print("Config Deleted!")
        refreshconfigfolder()
        client.exec("playvol  buttons/bell1.wav 1")
    end
end

loadconfig = function ()
    function realstuff()
        local config = puisetup:save()
        local encrypted = json.stringify(config)
        local selectedIndex = pui.get(configmenu.mainconfigmenu.ref) + 1
        local inputname = pui.get(configmenu.inputname.ref)
        if inputname == "nil" then return end
        local clip = readfile(tostring("/solix/Config/"..inputname..""))
        puisetup:load(json.parse(clip))
    end

    local s, ret = pcall(realstuff)
    if not s then
        print("Something went wrong with the config hmm? "..ret.."")
    else
        print("Config Loaded!")
        client.exec("playvol  buttons/bell1.wav 1")
    end
end

importconfig = function ()
    function realstuff()
        local clip = clipboard.get()
        local success, decrypted = pcall(json.parse, clip)
        if not success then
            error("JSON Parsing Error: " .. decrypted)
        end
        puisetup:load(decrypted)
    end

    local s, ret = pcall(realstuff)
    if not s then
        print("Something went wrong with the config: " .. ret)
    else
        print("Config Imported!")
        client.exec("playvol buttons/bell1.wav 1")
    end
end


exportconfig = function ()
    function realstuff()
        local config = puisetup:save()
        local encrypted = json.stringify(config)
        clipboard.set(encrypted)
    end

    local s, ret = pcall(realstuff)
    if not s then
        print("Something went wrong with the config hmm? "..ret.."")
    else
        print("Config Imported!")
        client.exec("playvol  buttons/bell1.wav 1")
    end
end

if not FileSystem.is_directory(localdirectory.."/solix/Config") then
    FileSystem.create_directory(localdirectory.."/solix/Config")
end


-- writefile(tostring("/solix/Config/default"), " ")
refreshconfigfolder()

local logo = nil
local show_logo = false
local appear_time = 0
local fade_in = 0.5
local visible = 2
local fade_out = 0.5
local doneshowing = false
local total_time = fade_in + visible + fade_out

http.get('https://raw.githubusercontent.com/asdkoawkoedkoasdo/slx/refs/heads/main/image%20(3).png', function(s, r)
    if s and r.status == 200 then
        logo = renderer.load_png(r.body, 565, 535)
        if logo then 
            show_logo = true
            appear_time = client.timestamp() + 3000
        else
            print("Failed")
        end
    end
end)

lerp.new("LogoImageAlpha")

client.set_event_callback('paint', function()
    if show_logo and logo then
        local now = client.timestamp()
        local elapsed = now - appear_time
        local alphafromlerp = math.floor(lerp.get("LogoImageAlpha"))

        if not doneshowing then
            lerp.lerp("LogoImageAlpha", 255, 1)
            if alphafromlerp > 240 then
                doneshowing = true
            end
        else
            lerp.lerp("LogoImageAlpha", 0, 1)
            if alphafromlerp < 20 then
                return
            end
        end
        
        local sw, sh = client.screen_size()
        local w, h = 565, 535
        local x = math.floor((sw - w) / 2)
        local y = math.floor((sh - h) / 2)
        renderer.texture(logo, x, y, w, h, 255, 255, 255, alphafromlerp)
        renderer.text(x + 250, y + 480, 255, 255, 255, alphafromlerp, "+", 100, "Solix AA")
    else
        show_logo = false
        logo = nil
    end
end)
