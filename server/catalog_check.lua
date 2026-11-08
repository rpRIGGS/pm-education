-- PM Education catalog integrity diagnostics.
-- Console-only, read-only checks. Never alters student or curriculum records.
local function report(problems, level, code, details)
    problems[#problems + 1] = {level = level, code = code, details = details}
end

local function checkPayload(row, problems)
    local context = ('%s/%s/%s v%s (#%s)'):format(
        row.institution_id, row.content_type, row.content_key, row.revision, row.id)
    local ok, payload = pcall(json.decode, row.payload_json)
    if not ok or type(payload) ~= 'table' then
        report(problems, 'ERROR', 'INVALID_JSON', context)
        return
    end
    if type(payload.label) ~= 'string' or payload.label == '' or #payload.label > 160 then
        report(problems, 'ERROR', 'INVALID_LABEL', context)
    end
    if row.content_type == 'course' then
        if type(payload.passPercent) ~= 'number' or payload.passPercent < 0 or
            payload.passPercent > 100 then
            report(problems, 'ERROR', 'INVALID_PASS_PERCENT', context)
        end
        if row.status == 'published' and
            (type(payload.requireWritten) ~= 'boolean' or type(payload.practicalRequirements) ~= 'table') then
            report(problems, 'WARN', 'UNSNAPSHOTTED_PUBLISHED_COURSE',
                context .. ' inherited configuration may change historical requirements')
        end
        if payload.requireWritten ~= nil and type(payload.requireWritten) ~= 'boolean' then
            report(problems, 'ERROR', 'INVALID_WRITTEN_REQUIREMENT', context)
        end
        if payload.credentialId ~= nil and
            (type(payload.credentialId) ~= 'string' or #payload.credentialId < 1 or
             #payload.credentialId > 80 or not payload.credentialId:match('^[%w_%-]+$')) then
            report(problems, 'ERROR', 'INVALID_CREDENTIAL_LINK', context)
        end
        if payload.practicalRequirements ~= nil then
            if type(payload.practicalRequirements) ~= 'table' or #payload.practicalRequirements > 50 then
                report(problems, 'ERROR', 'INVALID_PRACTICAL_LIST', context)
            else
                local seen = {}
                for index, requirement in ipairs(payload.practicalRequirements) do
                    if type(requirement) ~= 'table' or type(requirement.id) ~= 'string' or
                        #requirement.id < 1 or #requirement.id > 80 or
                        not requirement.id:match('^[%w_%-]+$') or seen[requirement.id] or
                        type(requirement.label) ~= 'string' or #requirement.label < 1 or
                        #requirement.label > 160 then
                        report(problems, 'ERROR', 'INVALID_PRACTICAL_REQUIREMENT',
                            context .. ' item ' .. index)
                    else
                        seen[requirement.id] = true
                    end
                end
            end
        end
        if not ((Config.Institutions[row.institution_id] or {}).courses or {})[row.content_key] then
            report(problems, 'WARN', 'UNCONFIGURED_COURSE', context)
        end
    elseif row.content_type == 'exam' then
        if type(payload.questions) ~= 'table' or #payload.questions == 0 then
            if row.status == 'published' then
                report(problems, 'ERROR', 'EMPTY_PUBLISHED_EXAM', context)
            end
            return
        end
        if #payload.questions > 200 then
            report(problems, 'ERROR', 'EXAM_TOO_LONG', context)
        end
        for index, question in ipairs(payload.questions) do
            if type(question) ~= 'table' or type(question.question) ~= 'string' or
                question.question == '' or type(question.answers) ~= 'table' or
                #question.answers < 2 or #question.answers > 8 or
                type(question.correct) ~= 'number' or
                question.correct % 1 ~= 0 or question.correct < 1 or
                question.correct > #question.answers then
                report(problems, 'ERROR', 'INVALID_QUESTION', context .. ' question ' .. index)
            else
                for answerIndex, answer in ipairs(question.answers) do
                    if type(answer) ~= 'string' or answer == '' then
                        report(problems, 'ERROR', 'INVALID_ANSWER',
                            context .. ' question ' .. index .. ' answer ' .. answerIndex)
                    end
                end
            end
        end
        if not ((Config.Institutions[row.institution_id] or {}).courses or {})[row.content_key] then
            report(problems, 'WARN', 'UNCONFIGURED_EXAM', context)
        end
    elseif row.content_type ~= 'credential' then
        report(problems, 'ERROR', 'UNKNOWN_TYPE', context)
    end
end

local function audit(institutionId)
    local rows = MySQL.query.await(
        'SELECT id, institution_id, content_type, content_key, revision, status, payload_json, source_kind, source_hash FROM pm_education_catalog WHERE institution_id = ? ORDER BY content_type, content_key, revision',
        {institutionId})
    if not rows then error('Catalog query unavailable; audit cannot report a clean result') end
    local problems = {}
    local active = {}
    local revisions = {}
    local imported = {}
    for _, row in ipairs(rows) do
        local key = row.content_type .. '/' .. row.content_key
        local context = institutionId .. '/' .. key
        if row.status == 'published' then
            active[key] = (active[key] or 0) + 1
        end
        local last = revisions[key]
        if last and row.revision <= last then
            report(problems, 'ERROR', 'REVISION_ORDER', context)
        end
        revisions[key] = row.revision
        if row.source_kind == 'development' then
            if not row.source_hash or row.source_hash == '' then
                report(problems, 'WARN', 'MISSING_IMPORT_FINGERPRINT',
                    context .. ' v' .. row.revision)
            else
                local hashKey = key .. '/' .. row.source_hash
                if imported[hashKey] then
                    report(problems, 'WARN', 'DUPLICATE_IMPORT',
                        context .. ' revisions ' .. imported[hashKey] .. ' and ' .. row.revision)
                end
                imported[hashKey] = row.revision
            end
        end
        checkPayload(row, problems)
    end
    for key, count in pairs(active) do
        if count > 1 then
            report(problems, 'ERROR', 'MULTIPLE_PUBLISHED_REVISIONS',
                institutionId .. '/' .. key .. ': ' .. count)
        end
    end
    local orphanCurricula = MySQL.scalar.await(
        'SELECT COUNT(*) FROM pm_education_enrollments e LEFT JOIN pm_education_catalog c ON e.curriculum_revision_id = c.id AND c.institution_id = e.institution_id AND c.content_type = \'course\' AND c.content_key = e.course_id WHERE e.institution_id = ? AND e.curriculum_revision_id IS NOT NULL AND c.id IS NULL',
        {institutionId})
    if tonumber(orphanCurricula or 0) > 0 then
        report(problems, 'ERROR', 'ORPHAN_COURSE_REVISIONS',
            institutionId .. ': ' .. orphanCurricula .. ' enrollments')
    end
    local orphanExams = MySQL.scalar.await(
        'SELECT COUNT(*) FROM pm_education_enrollments e LEFT JOIN pm_education_catalog c ON e.exam_revision_id = c.id AND c.institution_id = e.institution_id AND c.content_type = \'exam\' AND c.content_key = e.course_id WHERE e.institution_id = ? AND e.exam_revision_id IS NOT NULL AND c.id IS NULL',
        {institutionId})
    if tonumber(orphanExams or 0) > 0 then
        report(problems, 'ERROR', 'ORPHAN_EXAM_ENROLLMENT_REVISIONS',
            institutionId .. ': ' .. orphanExams .. ' enrollments')
    end
    local duplicateCredentials = MySQL.scalar.await(
        'SELECT COUNT(*) FROM (SELECT enrollment_id, credential_id FROM pm_education_credentials WHERE institution_id = ? GROUP BY enrollment_id, credential_id HAVING COUNT(*) > 1) duplicates',
        {institutionId})
    if tonumber(duplicateCredentials or 0) > 0 then
        report(problems, 'ERROR', 'DUPLICATE_CREDENTIAL_AWARDS',
            institutionId .. ': ' .. duplicateCredentials .. ' duplicated enrollment/credential pairs')
    end
    local credentialsWithoutEnrollment = MySQL.scalar.await(
        'SELECT COUNT(*) FROM pm_education_credentials c LEFT JOIN pm_education_enrollments e ON c.enrollment_id = e.id AND c.institution_id = e.institution_id AND c.citizenid = e.citizenid WHERE c.institution_id = ? AND e.id IS NULL',
        {institutionId})
    if tonumber(credentialsWithoutEnrollment or 0) > 0 then
        report(problems, 'ERROR', 'ORPHAN_CREDENTIAL_AWARDS',
            institutionId .. ': ' .. credentialsWithoutEnrollment .. ' credential records')
    end
    local mismatchedAttempts = MySQL.scalar.await(
        "SELECT COUNT(*) FROM pm_education_attempts a JOIN pm_education_enrollments e ON a.enrollment_id = e.id WHERE e.institution_id = ? AND e.exam_revision_id IS NOT NULL AND a.passed = 1 AND (a.catalog_revision_id IS NULL OR a.catalog_revision_id <> e.exam_revision_id)",
        {institutionId})
    if tonumber(mismatchedAttempts or 0) > 0 then
        report(problems, 'WARN', 'PASSED_ATTEMPTS_OTHER_EXAM_REVISION',
            institutionId .. ': ' .. mismatchedAttempts .. ' historical attempts; not counted for pinned exam completion')
    end
    local orphanAttempts = MySQL.scalar.await(
        'SELECT COUNT(*) FROM pm_education_attempts a LEFT JOIN pm_education_catalog c ON a.catalog_revision_id = c.id WHERE a.catalog_revision_id IS NOT NULL AND c.id IS NULL AND a.enrollment_id IN (SELECT id FROM pm_education_enrollments WHERE institution_id = ?)',
        {institutionId})
    if tonumber(orphanAttempts or 0) > 0 then
        report(problems, 'ERROR', 'ORPHAN_EXAM_REVISIONS',
            institutionId .. ': ' .. orphanAttempts .. ' attempts')
    end
    local errors, warnings = 0, 0
    for _, issue in ipairs(problems) do
        if issue.level == 'ERROR' then errors = errors + 1 else warnings = warnings + 1 end
        print(('[pm-education] %s %s: %s'):format(issue.level, issue.code, issue.details))
    end
    print(('[pm-education] Catalog audit %s: %d revisions, %d errors, %d warnings'):format(
        institutionId, #rows, errors, warnings))
    return errors == 0
end

RegisterCommand('pm_education_catalog_check', function(source, args)
    if source ~= 0 then return end
    local institutionId = args and args[1]
    if not institutionId or not Config.Institutions[institutionId] then
        print('[pm-education] Usage: pm_education_catalog_check <configured_institution_id>')
        return
    end
    local ok, err = pcall(audit, institutionId)
    if not ok then
        print('[pm-education] Catalog audit failed: ' .. tostring(err))
    end
end, true)
