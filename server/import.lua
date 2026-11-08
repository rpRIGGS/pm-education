-- Server-only development content importer.
-- Run with server console: pm_education_import
-- Never overwrites an existing draft, published revision, or in-game edit.
local templates = {
    'development/institutions/post.lua',
    'development/institutions/sandy_university.lua'
}
local function validId(s)
    return type(s)=='string' and #s>0 and #s<=80 and s:match('^[%w_%-]+$')~=nil
end
local function importOne(institution, kind, key, payload)
    if not Config.Institutions[institution] or not validId(key) or type(payload)~='table' then return false end
    if type(payload.label)~='string' or #payload.label==0 or #payload.label>160 then return false end
    if kind=='exam' and type(payload.questions)~='table' then return false end
    if kind=='course' and (type(payload.passPercent)~='number' or payload.passPercent<0 or payload.passPercent>100) then return false end
    local encoded=json.encode(payload)
    if not encoded or #encoded>100000 then return false end
    local sourceHash=tostring(GetHashKey(encoded))
    local latest=MySQL.single.await(
        'SELECT id, revision, payload_json FROM pm_education_catalog WHERE institution_id=? AND content_type=? AND content_key=? ORDER BY revision DESC LIMIT 1',
        {institution,kind,key})
    if latest then
        -- Compare against all prior development imports, not in-game edits.
        -- This avoids repeatedly creating identical drafts after staff modify a draft.
        local imported=MySQL.query.await(
            "SELECT source_hash FROM pm_education_catalog WHERE institution_id=? AND content_type=? AND content_key=? AND source_kind='development'",
            {institution,kind,key})
        if not imported then
            error('Development import history unavailable; refusing duplicate import')
        end
        for _,record in ipairs(imported) do
            if record.source_hash==sourceHash then return false end
        end
        -- Changed templates become new reviewable drafts, never overwrite live content.
    end
    -- Allocate revisions with the unique key as a concurrency backstop.
    -- Import and audit must commit together; never expose an unaudited draft.
    for attempt = 1, 3 do
        local revision = tonumber(MySQL.scalar.await(
            'SELECT COALESCE(MAX(revision), 0) FROM pm_education_catalog WHERE institution_id = ? AND content_type = ? AND content_key = ?',
            {institution,kind,key})) + 1
        local statements = {
            {
                query = "INSERT INTO pm_education_catalog (institution_id,content_type,content_key,revision,status,payload_json,source_hash,source_kind,created_by) VALUES (?,?,?,?,'draft',?,?,'development','system')",
                values = {institution,kind,key,revision,encoded,sourceHash}
            },
            {
                query = "INSERT INTO pm_education_catalog_audit (catalog_id,institution_id,actor_citizenid,action,notes) SELECT id, ?, 'system', 'import', ? FROM pm_education_catalog WHERE institution_id = ? AND content_type = ? AND content_key = ? AND revision = ?",
                values = {institution,latest and 'Updated development template; review required' or 'Initial development template',institution,kind,key,revision}
            }
        }
        local ok, committed = pcall(MySQL.transaction.await, statements)
        if ok and committed then return true end
        if not ok then
            print(('[pm-education] Import retry %d for %s/%s/%s: %s'):format(
                attempt,institution,kind,key,tostring(committed)))
        end
    end
    return false
end
RegisterCommand('pm_education_import',function(source)
    if source~=0 then return end -- console only
    local created=0
    for _,path in ipairs(templates) do
        local raw=LoadResourceFile(GetCurrentResourceName(),path)
        if raw then
            local chunk,err=load(raw,'@'..path,'t',{})
            if not chunk then print('[pm-education] Import parse error: '..tostring(err))
            else
                local ok,data=pcall(chunk)
                if ok and type(data)=='table' and validId(data.institutionId) then
                    for _,section in ipairs({{'courses','course'},{'exams','exam'},{'credentials','credential'}}) do
                        for key,payload in pairs(data[section[1]] or {}) do
                            local success,result=pcall(importOne,data.institutionId,section[2],key,payload)
                            if success and result then created=created+1
                            elseif not success then print('[pm-education] Import error '..path..': '..tostring(result)) end
                        end
                    end
                else print('[pm-education] Invalid development template: '..path) end
            end
        else print('[pm-education] Missing development template: '..path) end
    end
    print(('[pm-education] Imported %d new drafts; existing records left unchanged.'):format(created))
end,true)
