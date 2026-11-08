-- PM Education institution catalog: server-only authoring API.
-- Requires sql/pm_education_catalog.sql. Existing exam delivery remains unchanged
-- until the version-aware delivery migration is implemented.
local Core = exports['qb-core']:GetCoreObject()

local function authorized(src, institutionId)
    if type(institutionId) ~= 'string' then return false end
    local institution = Config.Institutions[institutionId]
    if not institution or institution.enabled == false then return false end
    local player = Core.Functions.GetPlayer(src)
    if not player then return false end
    local job = player.PlayerData.job
    local rule = job and institution.credentialAdminJobs and institution.credentialAdminJobs[job.name]
    if not rule or (tonumber(job.grade and job.grade.level) or -1) < (rule.minGrade or 0) then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local position = GetEntityCoords(ped)
    for _, desk in ipairs(institution.management or {}) do
        if desk.coords and #(position - vector3(desk.coords.x, desk.coords.y, desk.coords.z)) <= 5.0 then
            return true, player.PlayerData.citizenid
        end
    end
    return false
end

local function validKey(value)
    return type(value) == 'string' and #value > 0 and #value <= 80 and value:match('^[%w_%-]+$') ~= nil
end

local function validPayload(kind, payload)
    if type(payload) ~= 'table' or type(payload.label) ~= 'string' or
        #payload.label < 1 or #payload.label > 160 then return false end
    if kind == 'exam' then
        if type(payload.questions) ~= 'table' or #payload.questions > 200 then return false end
        for _, q in ipairs(payload.questions) do
            if type(q) ~= 'table' or type(q.question) ~= 'string' or #q.question < 1 or #q.question > 2000 or
                type(q.answers) ~= 'table' or #q.answers < 2 or #q.answers > 8 or
                type(q.correct) ~= 'number' or q.correct % 1 ~= 0 or q.correct < 1 or q.correct > #q.answers then return false end
            for _, a in ipairs(q.answers) do
                if type(a) ~= 'string' or #a < 1 or #a > 500 then return false end
            end
        end
    elseif kind == 'course' then
        if type(payload.passPercent) ~= 'number' or payload.passPercent < 0 or payload.passPercent > 100 then return false end
    elseif kind ~= 'credential' then
        return false
    end
    return true
end

-- Read-only draft/revision listing for authorized institution leadership.
lib.callback.register('pm-education:server:catalogList', function(src, institutionId)
    if not authorized(src, institutionId) then return {} end
    local ok, rows = pcall(MySQL.query.await,
        'SELECT id, content_type, content_key, revision, status, created_at, published_at FROM pm_education_catalog WHERE institution_id = ? ORDER BY content_type, content_key, revision DESC LIMIT 500',
        {institutionId})
    return ok and rows or {}
end)

lib.callback.register('pm-education:server:catalogRead', function(src, institutionId, catalogId)
    if not authorized(src, institutionId) or type(catalogId) ~= 'number' or catalogId % 1 ~= 0 then return nil end
    local ok, row = pcall(MySQL.single.await,
        'SELECT id, content_type, content_key, revision, status, payload_json FROM pm_education_catalog WHERE institution_id = ? AND id = ?',
        {institutionId, catalogId})
    if not ok or not row then return nil end
    local decoded, payload = pcall(json.decode, row.payload_json)
    if not decoded then return nil end
    row.payload_json = nil
    row.payload = payload
    return row
end)

-- Create a fresh draft from in-game UI or controlled developer import.
-- Editing a published item always creates a new revision.
lib.callback.register('pm-education:server:catalogCreateDraft', function(src, institutionId, kind, key, payload)
    local allowed, actor = authorized(src, institutionId)
    if not allowed or not validKey(key) or not validPayload(kind, payload) then return nil end
    local encoded = json.encode(payload)
    if not encoded or #encoded > 100000 then return nil end
    local ok, id = pcall(function()
        return MySQL.transaction.await({
            {query = [[INSERT INTO pm_education_catalog
                (institution_id, content_type, content_key, revision, status, payload_json, source_kind, created_by)
                SELECT ?, ?, ?, COALESCE(MAX(revision), 0) + 1, 'draft', ?, 'ingame', ?
                FROM pm_education_catalog
                WHERE institution_id = ? AND content_type = ? AND content_key = ?]],
             values = {institutionId, kind, key, encoded, actor, institutionId, kind, key}}
        })
    end)
    if not ok or not id then return nil end
    return true
end)
