-- Console-only export of current catalog records for offline development review.
-- Exports JSON, including answer keys, to the server resource data directory.
-- Never expose this file through NUI or a client callback.
RegisterCommand('pm_education_export', function(source, args)
    if source ~= 0 then return end
    local institutionId = args and args[1]
    if type(institutionId) ~= 'string' or not institutionId:match('^[%w_%-]+$') or
        #institutionId > 80 or not Config.Institutions[institutionId] then
        print('[pm-education] Usage: pm_education_export <configured_institution_id>')
        return
    end
    local ok, rows = pcall(MySQL.query.await,
        'SELECT content_type, content_key, revision, status, payload_json, source_kind, created_at, published_at FROM pm_education_catalog WHERE institution_id = ? ORDER BY content_type, content_key, revision',
        {institutionId})
    if not ok or not rows then
        print('[pm-education] Export failed: catalog database unavailable')
        return
    end
    local output = {institutionId = institutionId, exportedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'), revisions = {}}
    for _, row in ipairs(rows) do
        local decoded, payload = pcall(json.decode, row.payload_json)
        if not decoded or type(payload) ~= 'table' then
            print('[pm-education] Export stopped: invalid payload for catalog revision '..tostring(row.revision))
            return
        end
        output.revisions[#output.revisions + 1] = {
            type = row.content_type, key = row.content_key, revision = row.revision,
            status = row.status, source = row.source_kind, payload = payload
        }
    end
    local filename = ('export_%s.json'):format(institutionId)
    local encoded = json.encode(output)
    if not encoded or not SaveResourceFile(GetCurrentResourceName(), filename, encoded, #encoded) then
        print('[pm-education] Export write failed: '..filename)
        return
    end
    print(('[pm-education] Exported %d revisions to %s (SERVER ONLY; contains answer keys)'):format(#output.revisions, filename))
end, true)
