-- PM Education institution catalog: server-only authoring API.
-- Requires sql/pm_education_catalog.sql and the attempt revision migration.
-- Published revisions are consumed by the runtime in server/server.lua.
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
    -- A single SQL statement allocates the next revision under the unique index.
    -- A duplicate-key collision is retried rather than exposing a partial draft.
    for attempt=1,3 do
        local ok, result = pcall(function()
            local latest = MySQL.scalar.await(
                'SELECT COALESCE(MAX(revision), 0) FROM pm_education_catalog WHERE institution_id = ? AND content_type = ? AND content_key = ?',
                {institutionId, kind, key})
            local nextRevision = tonumber(latest or 0) + 1
            local inserted = MySQL.insert.await(
                "INSERT INTO pm_education_catalog (institution_id, content_type, content_key, revision, status, payload_json, source_kind, created_by) VALUES (?, ?, ?, ?, 'draft', ?, 'ingame', ?)",
                {institutionId, kind, key, nextRevision, encoded, actor})
            if not inserted then return nil end
            local auditOk, auditResult = pcall(MySQL.insert.await,
                'INSERT INTO pm_education_catalog_audit (catalog_id, institution_id, actor_citizenid, action, notes) VALUES (?, ?, ?, ?, ?)',
                {inserted, institutionId, actor, 'create_draft', 'Created revision ' .. nextRevision})
            if not auditOk or not auditResult then
                print(('[pm-education] Draft #%s created without audit; administrator review required'):format(inserted))
            end
            return inserted
        end)
        if ok and result then return result end
        if not ok then
            print(('[pm-education] Catalog draft attempt %d failed for %s/%s/%s: %s'):format(
                attempt, institutionId, kind, key, tostring(result)))
        end
    end
    return nil
end)

-- Save changes only to unpublished drafts; published revisions are immutable.
lib.callback.register('pm-education:server:catalogSaveDraft', function(src, institutionId, catalogId, payload)
    local allowed, actor = authorized(src, institutionId)
    if not allowed or type(catalogId) ~= 'number' or catalogId % 1 ~= 0 then return false end
    local row = MySQL.single.await(
        'SELECT content_type FROM pm_education_catalog WHERE id = ? AND institution_id = ? AND status = ?',
        {catalogId, institutionId, 'draft'})
    if not row or not validPayload(row.content_type, payload) then return false end
    local encoded = json.encode(payload)
    if not encoded or #encoded > 100000 then return false end
    local ok, saved = pcall(MySQL.transaction.await, {
        {query = 'UPDATE pm_education_catalog SET payload_json = ? WHERE id = ? AND institution_id = ? AND status = ?',
         values = {encoded, catalogId, institutionId, 'draft'}},
        {query = 'INSERT INTO pm_education_catalog_audit (catalog_id, institution_id, actor_citizenid, action, notes) VALUES (?, ?, ?, ?, ?)',
         values = {catalogId, institutionId, actor, 'save_draft', 'Updated draft content'}}
    })
    return ok and saved == true
end)

-- Explicit publication; new exam sessions use the activated revision.
lib.callback.register('pm-education:server:catalogPublish', function(src, institutionId, catalogId)
    local allowed, actor = authorized(src, institutionId)
    if not allowed or type(catalogId) ~= 'number' or catalogId % 1 ~= 0 then return false end
    local row = MySQL.single.await(
        'SELECT content_type, content_key, payload_json FROM pm_education_catalog WHERE id = ? AND institution_id = ? AND status = ?',
        {catalogId, institutionId, 'draft'})
    if not row then return false end
    local decoded, payload = pcall(json.decode, row.payload_json)
    if not decoded or not validPayload(row.content_type, payload) then return false end
    if row.content_type == 'exam' then
        if #payload.questions == 0 then return false end
        if not (Config.Institutions[institutionId].courses or {})[row.content_key] then return false end
    elseif row.content_type == 'course' then
        if not (Config.Institutions[institutionId].courses or {})[row.content_key] then return false end
    end
    -- Retirement, activation and audit share a transaction.
    -- Cross-connection concurrent publication still needs a uniqueness constraint.
    local transactionOk, switched = pcall(MySQL.transaction.await, {
        {
            query = "UPDATE pm_education_catalog SET status = 'retired' WHERE institution_id = ? AND content_type = ? AND content_key = ? AND status = 'published'",
            values = {institutionId, row.content_type, row.content_key}
        },
        {
            query = "UPDATE pm_education_catalog SET status = 'published', published_at = NOW() WHERE id = ? AND institution_id = ? AND status = 'draft'",
            values = {catalogId, institutionId}
        },
        {
            query = "INSERT INTO pm_education_catalog_audit (catalog_id, institution_id, actor_citizenid, action, notes) VALUES (?, ?, ?, 'publish', ?)",
            values = {catalogId, institutionId, actor, 'Activated revision; previous published revision retired'}
        }
    })
    if not transactionOk or not switched then return false end
    return true
end)

-- Retire an existing published revision before activating its replacement.
lib.callback.register('pm-education:server:catalogRetire', function(src, institutionId, catalogId)
    local allowed, actor = authorized(src, institutionId)
    if not allowed or type(catalogId) ~= 'number' or catalogId % 1 ~= 0 then return false end
    local ok, retired = pcall(MySQL.transaction.await, {
        {query = "UPDATE pm_education_catalog SET status = 'retired' WHERE id = ? AND institution_id = ? AND status = 'published'",
         values = {catalogId, institutionId}},
        {query = 'INSERT INTO pm_education_catalog_audit (catalog_id, institution_id, actor_citizenid, action, notes) VALUES (?, ?, ?, ?, ?)',
         values = {catalogId, institutionId, actor, 'retire', 'Retired published revision; historical qualifications unaffected'}}
    })
    return ok and retired == true
end)

lib.callback.register('pm-education:server:catalogHistory', function(src, institutionId, catalogId)
    if not authorized(src, institutionId) or type(catalogId) ~= 'number' or catalogId % 1 ~= 0 then return {} end
    local ok, rows = pcall(MySQL.query.await,
        'SELECT actor_citizenid, action, notes, recorded_at FROM pm_education_catalog_audit WHERE institution_id = ? AND catalog_id = ? ORDER BY id DESC LIMIT 100',
        {institutionId, catalogId})
    return ok and rows or {}
end)
