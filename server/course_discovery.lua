-- Server-authoritative course discovery for admissions and examination menus.
-- Only configured, enabled institutions and explicitly offered courses are visible.
-- Published catalog records can update presentation without changing fees or access.
local function availableCourses(institutionId)
    local institution = Config.Institutions[institutionId]
    if not institution or institution.enabled == false then return nil end
    local rows = MySQL.query.await(
        "SELECT content_key, payload_json FROM pm_education_catalog WHERE institution_id = ? AND content_type = 'course' AND status = 'published' ORDER BY revision DESC",
        {institutionId})
    if not rows then error('Catalog query returned no result') end
    local published = {}
    for _, row in ipairs(rows) do
        if not published[row.content_key] then
            local ok, payload = pcall(json.decode, row.payload_json)
            if not ok or type(payload) ~= 'table' or type(payload.label) ~= 'string' or
                type(payload.passPercent) ~= 'number' or payload.passPercent < 0 or payload.passPercent > 100 then
                error('Invalid published course payload for ' .. institutionId .. '/' .. row.content_key)
            end
            published[row.content_key] = payload
        end
    end
    local courses = {}
    for id, config in pairs(institution.courses or {}) do
        local override = published[id]
        courses[#courses + 1] = {
            id = id,
            label = override and override.label or config.label or id,
            enrollmentFee = config.enrollmentFee or 0,
            examFee = config.examFee or 0,
            passPercent = override and override.passPercent or config.passPercent
        }
    end
    table.sort(courses, function(a, b) return a.label < b.label end)
    return courses
end

lib.callback.register('pm-education:server:availableCourses', function(src, institutionId)
    if type(institutionId) ~= 'string' then return nil end
    local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
    if not player then return nil end
    local institution = Config.Institutions[institutionId]
    if not institution or institution.enabled == false then return nil end
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local pos = GetEntityCoords(ped)
    local nearby = false
    for _, point in ipairs(institution.admissions or {}) do
        if point.coords and #(pos - vector3(point.coords.x,point.coords.y,point.coords.z)) <= 5.0 then nearby = true break end
    end
    if not nearby then
        for _, point in ipairs(institution.examiners or {}) do
            if point.coords and #(pos - vector3(point.coords.x,point.coords.y,point.coords.z)) <= 5.0 then nearby = true break end
        end
    end
    if not nearby then return nil end
    local ok, courses = pcall(availableCourses, institutionId)
    if not ok then
        print('[pm-education] Course discovery failed: ' .. tostring(courses))
        return nil
    end
    return courses
end)
