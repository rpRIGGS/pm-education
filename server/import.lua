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
    local encoded=json.encode(payload)
    if not encoded or #encoded>100000 then return false end
    local exists=MySQL.scalar.await(
        'SELECT id FROM pm_education_catalog WHERE institution_id=? AND content_type=? AND content_key=? LIMIT 1',
        {institution,kind,key})
    if exists then return false end
    local id=MySQL.insert.await(
        "INSERT INTO pm_education_catalog (institution_id,content_type,content_key,revision,status,payload_json,source_kind,created_by) VALUES (?,?,?,1,'draft',?,'development','system')",
        {institution,kind,key,encoded})
    if not id then return false end
    MySQL.insert.await(
        'INSERT INTO pm_education_catalog_audit (catalog_id,institution_id,actor_citizenid,action,notes) VALUES (?,?,?,?,?)',
        {id,institution,'system','import','Initial development template'})
    return true
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
