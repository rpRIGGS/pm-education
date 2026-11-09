local QBCore = exports['qb-core']:GetCoreObject()
local activeExams = {}
local enrollmentLocks = {}
local enrollmentLockOwners = {} -- source -> citizenid; survives player object disappearing on disconnect
local credentialLocks = {}

local function getQuestions(institutionId, courseId, enrollmentId)
    local legacy = EducationQuestions and EducationQuestions[institutionId] and EducationQuestions[institutionId][courseId] or {}
    -- The catalog is authoritative once a published revision exists.
    local examRevisionId
    if enrollmentId then
        local enrollmentRow = MySQL.single.await(
            'SELECT exam_revision_id FROM pm_education_enrollments WHERE id = ? AND institution_id = ? AND course_id = ?',
            {enrollmentId, institutionId, courseId})
        if not enrollmentRow then return nil, nil, 'enrollment_missing' end
        examRevisionId = enrollmentRow.exam_revision_id
        -- NULL means this enrollment was created against the legacy question
        -- bank, not whichever exam was published later.
        if not examRevisionId then return legacy, nil end
    end
    local sql = examRevisionId
        and "SELECT id, payload_json FROM pm_education_catalog WHERE id = ? AND institution_id = ? AND content_type = 'exam' AND content_key = ?"
        or "SELECT id, payload_json FROM pm_education_catalog WHERE institution_id = ? AND content_type = 'exam' AND content_key = ? AND status = 'published' ORDER BY revision DESC LIMIT 1"
    local params = examRevisionId and {examRevisionId,institutionId,courseId} or {institutionId,courseId}
    local ok, row = pcall(MySQL.single.await, sql, params)
    if not ok then
        print('[pm-education] Catalog unavailable; refusing to silently use legacy questions')
        return nil, nil, 'catalog_unavailable'
    end
    if not row then
        if examRevisionId then return nil, nil, 'pinned_exam_missing' end
        return legacy, nil
    end
    local decoded, payload = pcall(json.decode, row.payload_json)
    if not decoded or type(payload) ~= 'table' or type(payload.questions) ~= 'table' then
        return nil, nil, 'invalid_published_exam'
    end
    return payload.questions, row.id
end

local function notify(src, message, kind)
    TriggerClientEvent('pm-education:client:notify', src, message, kind)
end

local function getCourse(institutionId, courseId, enrollmentId)
    if type(institutionId) ~= 'string' or type(courseId) ~= 'string' then return nil end
    local institution = Config.Institutions[institutionId]
    local base = institution and institution.enabled ~= false and institution.courses and institution.courses[courseId]
    if not base then return nil, institution end
    local revisionId
    if enrollmentId then
        local enrollmentRow = MySQL.single.await(
            'SELECT curriculum_revision_id FROM pm_education_enrollments WHERE id = ? AND institution_id = ? AND course_id = ?',
            {enrollmentId, institutionId, courseId})
        if not enrollmentRow then return nil, institution end
        revisionId = enrollmentRow.curriculum_revision_id
        -- Legacy enrollments must never drift to a newer published course.
        if not revisionId then return base, institution end
    end
    local query = revisionId
        and "SELECT payload_json FROM pm_education_catalog WHERE id = ? AND institution_id = ? AND content_type = 'course' AND content_key = ?"
        or "SELECT payload_json FROM pm_education_catalog WHERE institution_id = ? AND content_type = 'course' AND content_key = ? AND status = 'published' ORDER BY revision DESC LIMIT 1"
    local params = revisionId and {revisionId,institutionId,courseId} or {institutionId,courseId}
    local ok,row = pcall(MySQL.single.await,query,params)
    if not ok then return nil,institution end
    if not row then
        -- A missing pinned revision is a data-integrity failure, never a
        -- reason to substitute a different curriculum.
        if revisionId then return nil, institution end
        return base, institution
    end
    local decoded,payload = pcall(json.decode,row.payload_json)
    if not decoded or type(payload) ~= 'table' or type(payload.label) ~= 'string' or
        type(payload.passPercent) ~= 'number' or payload.passPercent < 0 or payload.passPercent > 100 then
        return nil,institution
    end
    local course={}
    for key,value in pairs(base) do course[key]=value end
    course.label=payload.label
    course.passPercent=payload.passPercent
    if payload.requireWritten ~= nil then
        if type(payload.requireWritten) ~= 'boolean' then return nil,institution end
        course.requireWritten=payload.requireWritten
    end
    if payload.practicalRequirements ~= nil then
        if type(payload.practicalRequirements) ~= 'table' or #payload.practicalRequirements>50 then return nil,institution end
        local seen,requirements={},{}
        for _,requirement in ipairs(payload.practicalRequirements) do
            if type(requirement) ~= 'table' or type(requirement.id) ~= 'string' or
                #requirement.id<1 or #requirement.id>80 or
                not requirement.id:match('^[%w_%-]+$') or seen[requirement.id] or
                type(requirement.label) ~= 'string' or #requirement.label<1 or #requirement.label>160 then
                return nil,institution
            end
            seen[requirement.id]=true
            requirements[#requirements+1]={id=requirement.id,label=requirement.label}
        end
        course.practicalRequirements=requirements
    end
    if payload.credentialId ~= nil then
        if type(payload.credentialId) ~= 'string' or #payload.credentialId<1 or #payload.credentialId>80 or
            not payload.credentialId:match('^[%w_%-]+$') then return nil,institution end
        course.credentialId=payload.credentialId
    end
    if payload.credentialLabel ~= nil then
        if type(payload.credentialLabel) ~= 'string' or #payload.credentialLabel<1 or
            #payload.credentialLabel>160 then return nil,institution end
        course.credentialLabel=payload.credentialLabel
    end
    return course,institution
end

local function nearInteraction(src, institutionId, kind, courseId)
    if type(institutionId) ~= 'string' or (kind ~= 'admissions' and kind ~= 'examiners') then return false end
    local institution = Config.Institutions[institutionId]
    if not institution or institution.enabled == false then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local position = GetEntityCoords(ped)
    for _, point in ipairs(institution[kind] or {}) do
        local allowed = kind == 'admissions'
        if kind == 'examiners' then
            for _, offered in ipairs(point.courses or {}) do
                if offered == courseId then allowed = true break end
            end
        end
        if allowed and point.coords and
            #(position - vector3(point.coords.x, point.coords.y, point.coords.z)) <= 5.0 then return true end
    end
    return false
end

local function playerFor(src)
    local player = QBCore.Functions.GetPlayer(src)
    return player, player and player.PlayerData.citizenid
end

local function enrollment(citizenid, institutionId, courseId)
    return MySQL.single.await(
        'SELECT id, status FROM pm_education_enrollments WHERE citizenid = ? AND institution_id = ? AND course_id = ? ORDER BY id DESC LIMIT 1',
        { citizenid, institutionId, courseId }
    )
end

local function validPaymentMethod(method)
    return (method == 'cash' or method == 'bank') and Config.Payment
        and Config.Payment.allowedMethods and Config.Payment.allowedMethods[method] == true
end

local function charge(player, amount, reason, method)
    if not validPaymentMethod(method) or type(amount) ~= 'number' or amount < 0 or amount % 1 ~= 0 then return false end
    if amount == 0 then return true end
    return player.Functions.RemoveMoney(method, amount, reason) == true
end

local function societyAccount(institutionId)
    local institution = Config.Institutions[institutionId]
    local name = institution and institution.society
    if type(name) ~= 'string' or name == '' or GetResourceState('qb-banking') ~= 'started' then return nil end
    local ok, account = pcall(function() return exports['qb-banking']:GetAccount(name) end)
    if not ok or not account then return nil end
    return name
end

local function paymentStatus(paymentId, status, details)
    local ok, changed = pcall(MySQL.update.await,
        'UPDATE pm_education_payments SET status = ?, details = ? WHERE id = ?',
        { status, details, paymentId })
    return ok and changed and changed > 0
end

local function paymentRefund(player, paymentId, amount, method, details)
    local ok, result = pcall(function()
        return amount == 0 or player.Functions.AddMoney(method, amount, 'PM Education Refund') == true
    end)
    if not ok then
        paymentStatus(paymentId, 'refund_failed', details .. '; refund result uncertain - inspect money logs')
        return false
    end
    local recorded = paymentStatus(paymentId, result and 'refunded' or 'refund_failed', details)
    if not recorded then
        print(('[pm-education] Refund outcome for payment #%s could not be recorded; manual reconciliation required'):format(paymentId))
        return false
    end
    return result
end

local function paymentStart(player, citizenid, institutionId, courseId, enrollmentId, paymentType, amount, method)
    if not validPaymentMethod(method) then return nil, 'Select cash or bank' end
    if type(amount) ~= 'number' or amount < 0 or amount % 1 ~= 0 then return nil, 'Invalid fee configuration' end
    local account = societyAccount(institutionId)
    if not account then return nil, 'Institution society account unavailable in qb-banking' end
    -- Pending/uncertain debits must be reconciled before charging this student
    -- again for the same course and payment purpose.
    local lookupOk, unresolved = pcall(MySQL.scalar.await,
        "SELECT id FROM pm_education_payments WHERE citizenid = ? AND institution_id = ? AND course_id = ? AND payment_type = ? AND status IN ('pending','charged','refund_failed') ORDER BY id DESC LIMIT 1",
        {citizenid, institutionId, courseId, paymentType})
    if not lookupOk then
        return nil, 'Payment ledger unavailable; no charge attempted'
    end
    if unresolved then
        return nil, ('Payment #%s requires administrator reconciliation before retrying'):format(unresolved)
    end
    local ok, paymentId = pcall(MySQL.insert.await,
        'INSERT INTO pm_education_payments (citizenid, institution_id, course_id, enrollment_id, payment_type, amount, money_type) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { citizenid, institutionId, courseId, enrollmentId, paymentType, amount, method })
    if not ok or not paymentId then return nil, 'Payment ledger unavailable' end
    local debitOk, debited = pcall(charge, player, amount, 'PM Education ' .. paymentType, method)
    if not debitOk then
        paymentStatus(paymentId, 'pending', 'Player debit result uncertain; inspect QBCore money logs before retrying')
        return nil, 'Payment status uncertain; contact an administrator before retrying'
    end
    if not debited then
        paymentStatus(paymentId, 'failed', 'Player debit rejected')
        return nil, 'Insufficient funds or payment rejected'
    end
    if not paymentStatus(paymentId, 'charged', 'Player debit accepted') then
        paymentRefund(player, paymentId, amount, method, 'Could not record debit')
        return nil, 'Payment processing error; review receipt'
    end
    return paymentId
end

local function paymentComplete(paymentId, enrollmentId, institutionId, amount)
    -- The society credit is made exactly once in this server execution path.
    -- Cross-resource credits are not atomic; an uncertain result is NOT retried.
    local account = societyAccount(institutionId)
    if not account then
        paymentStatus(paymentId, 'charged', 'Society account missing; manual reconciliation required')
        print(('[pm-education] Payment #%s charged but society account missing; manual reconciliation required'):format(paymentId))
        return false
    end
    if amount > 0 then
        local ok, credited = pcall(function()
            return exports['qb-banking']:AddMoney(account, amount, 'PM Education payment #' .. paymentId)
        end)
        if not ok or not credited then
            paymentStatus(paymentId, 'charged', 'Society credit failed or uncertain; reconcile qb-banking statements')
            print(('[pm-education] Payment #%s society credit failed or uncertain; DO NOT blindly retry'):format(paymentId))
            return false
        end
    end
    local ok, changed = pcall(MySQL.update.await,
        "UPDATE pm_education_payments SET status = 'completed', enrollment_id = COALESCE(?, enrollment_id), details = ? WHERE id = ? AND status = 'charged'",
        { enrollmentId, 'Society credited: ' .. account, paymentId })
    if not ok or not changed or changed < 1 then
        print(('[pm-education] Society credit for payment #%s needs manual ledger reconciliation; DO NOT credit again'):format(paymentId))
        return false
    end
    return true
end


-- Completion is calculated from SQL results, never client-reported progress.
local function courseProgress(enrollmentId, course, institutionId, courseId)
    local availableQuestions = {}
    if course.requireWritten ~= false then
        local catalogError
        availableQuestions, _, catalogError = getQuestions(institutionId, courseId, enrollmentId)
        if catalogError or not availableQuestions then
            error('Unable to determine course written requirements: ' .. tostring(catalogError))
        end
    end
    local writtenRequired = course.requireWritten == true or
        (course.requireWritten == nil and #availableQuestions > 0)
    local writtenPassed = false
    if writtenRequired and #availableQuestions > 0 then
        -- A pinned enrollment can only be satisfied by its assigned exam revision.
        -- Legacy NULL revision enrollments retain their historical attempt behavior.
        local examRevision = MySQL.scalar.await(
            'SELECT exam_revision_id FROM pm_education_enrollments WHERE id = ? AND institution_id = ? AND course_id = ?',
            {enrollmentId, institutionId, courseId})
        local query = examRevision
            and 'SELECT id FROM pm_education_attempts WHERE enrollment_id = ? AND catalog_revision_id = ? AND passed = 1 ORDER BY id DESC LIMIT 1'
            or 'SELECT id FROM pm_education_attempts WHERE enrollment_id = ? AND passed = 1 ORDER BY id DESC LIMIT 1'
        local params = examRevision and {enrollmentId, examRevision} or {enrollmentId}
        local attempt = MySQL.single.await(query, params)
        writtenPassed = attempt ~= nil
    end
    local practical = {}
    local rows = MySQL.query.await(
        'SELECT requirement_id, result FROM pm_education_practical_results WHERE enrollment_id = ? AND institution_id = ? AND course_id = ? ORDER BY id DESC',
        { enrollmentId, institutionId, courseId })
    if not rows then error('Practical evaluation database unavailable') end
    for _, row in ipairs(rows) do
        if practical[row.requirement_id] == nil then practical[row.requirement_id] = row.result end
    end
    local requiredCount, passedCount = 0, 0
    for _, requirement in ipairs(course.practicalRequirements or {}) do
        requiredCount = requiredCount + 1
        if practical[requirement.id] == 'pass' then passedCount = passedCount + 1 end
    end
    local hasRequirements = writtenRequired or requiredCount > 0
    local complete = hasRequirements and (not writtenRequired or writtenPassed) and passedCount == requiredCount
    return {
        writtenRequired = writtenRequired,
        writtenPassed = writtenPassed,
        practicalPassed = passedCount,
        practicalRequired = requiredCount,
        practical = practical,
        complete = complete
    }
end

local function refreshCompletion(enrollmentId, institutionId, courseId)
    local course = getCourse(institutionId, courseId, enrollmentId)
    if not course then return nil end
    local progress = courseProgress(enrollmentId, course, institutionId, courseId)
    if not progress.complete then return progress end

    local record = MySQL.single.await(
        "SELECT citizenid, status FROM pm_education_enrollments WHERE id = ? AND institution_id = ? AND course_id = ?",
        {enrollmentId, institutionId, courseId})
    if not record or (record.status ~= 'enrolled' and record.status ~= 'in_progress' and
        record.status ~= 'completed') then return progress end

    -- Credential display is part of the enrolled curriculum revision.
    -- Do not relabel a historical qualification using today's credential catalog.
    local label = course.credentialId and (course.credentialLabel or course.credentialId) or nil

    local statements = {}
    if course.credentialId then
        statements[#statements + 1] = {
            query = "INSERT INTO pm_education_credentials (enrollment_id, citizenid, institution_id, credential_id, credential_label) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE id = id",
            values = {enrollmentId, record.citizenid, institutionId, course.credentialId, label}
        }
    end
    statements[#statements + 1] = {
        query = "UPDATE pm_education_enrollments SET status = 'completed' WHERE id = ? AND institution_id = ? AND course_id = ? AND status IN ('enrolled','in_progress','completed')",
        values = {enrollmentId, institutionId, courseId}
    }
    if not MySQL.transaction.await(statements) then
        error('Completion transaction failed; credential and enrollment unchanged')
    end
    return progress
end

RegisterNetEvent('pm-education:server:enroll', function(institutionId, courseId, paymentMethod)
    local src = source
    local player, citizenid = playerFor(src)
    local course = getCourse(institutionId, courseId)
    if not player or not course or not nearInteraction(src, institutionId, 'admissions') then return end
    if enrollmentLocks[citizenid] then return end
    enrollmentLocks[citizenid] = true
    enrollmentLockOwners[src] = citizenid
    local lookupOk, existing = pcall(enrollment, citizenid, institutionId, courseId)
    if not lookupOk then
        enrollmentLocks[citizenid] = nil
        enrollmentLockOwners[src] = nil
        return notify(src, 'Enrollment database unavailable. No fee charged.', 'error')
    end
    if existing then
        enrollmentLocks[citizenid] = nil
        enrollmentLockOwners[src] = nil
        return notify(src, 'Enrollment already exists. See My Enrollments.', 'error')
    end
    -- Refuse to enroll into an unfulfillable written course. An exam
    -- published later would not be pinned to this enrollment.
    if course.requireWritten ~= false then
        local questionsOk, questions, _, questionError = pcall(getQuestions, institutionId, courseId)
        if not questionsOk or questionError or type(questions) ~= 'table' or
            (course.requireWritten == true and #questions == 0) then
            enrollmentLocks[citizenid] = nil
        enrollmentLockOwners[src] = nil
            return notify(src, 'This course has no available approved written examination. No fee charged.', 'error')
        end
    end
    local fee = course.enrollmentFee or 0
    local paid, paymentId, paymentError = pcall(paymentStart, player, citizenid, institutionId, courseId, nil, 'enrollment', fee, paymentMethod)
    if not paid or not paymentId then
        enrollmentLocks[citizenid] = nil
        enrollmentLockOwners[src] = nil
        return notify(src, paid and paymentError or 'Payment processing failed; review ledger before retrying.', 'error')
    end
    -- Capture the published course revision at enrollment creation.
    -- A NULL revision is an explicit legacy-config snapshot, never auto-backfilled.
    local revisionOk, revisionId = pcall(MySQL.scalar.await,
        "SELECT id FROM pm_education_catalog WHERE institution_id = ? AND content_type = 'course' AND content_key = ? AND status = 'published' ORDER BY revision DESC LIMIT 1",
        {institutionId, courseId})
    if not revisionOk then
        enrollmentLocks[citizenid] = nil
        enrollmentLockOwners[src] = nil
        local refunded = paymentRefund(player, paymentId, fee, paymentMethod, 'Curriculum revision lookup failed')
        return notify(src, refunded and 'Enrollment cancelled; payment refunded.' or 'Enrollment cancelled; refund requires review.', 'error')
    end
    local examRevisionOk, examRevisionId = pcall(MySQL.scalar.await,
        "SELECT id FROM pm_education_catalog WHERE institution_id = ? AND content_type = 'exam' AND content_key = ? AND status = 'published' ORDER BY revision DESC LIMIT 1",
        {institutionId, courseId})
    if not examRevisionOk then
        enrollmentLocks[citizenid] = nil
        enrollmentLockOwners[src] = nil
        local refunded = paymentRefund(player, paymentId, fee, paymentMethod, 'Exam revision lookup failed')
        return notify(src, refunded and 'Enrollment cancelled; payment refunded.' or 'Enrollment cancelled; refund requires review.', 'error')
    end
    local columns = {'citizenid', 'institution_id', 'course_id'}
    local placeholders = {'?', '?', '?'}
    local insertParams = {citizenid, institutionId, courseId}
    if revisionId then
        columns[#columns + 1] = 'curriculum_revision_id'
        placeholders[#placeholders + 1] = '?'
        insertParams[#insertParams + 1] = revisionId
    end
    if examRevisionId then
        columns[#columns + 1] = 'exam_revision_id'
        placeholders[#placeholders + 1] = '?'
        insertParams[#insertParams + 1] = examRevisionId
    end
    local insertSql = 'INSERT INTO pm_education_enrollments (' .. table.concat(columns, ', ') ..
        ') VALUES (' .. table.concat(placeholders, ', ') .. ')'
    local ok, id = pcall(MySQL.insert.await, insertSql, insertParams)
    if not ok or not id then
        enrollmentLocks[citizenid] = nil
        enrollmentLockOwners[src] = nil
        local refunded = paymentRefund(player, paymentId, fee, paymentMethod, 'Enrollment insert failed')
        return notify(src, refunded and 'Enrollment failed. Payment refunded.' or 'Enrollment failed. Refund requires administrator review.', 'error')
    end
    local completedOk, credited = pcall(paymentComplete, paymentId, id, institutionId, fee)
    enrollmentLocks[citizenid] = nil
        enrollmentLockOwners[src] = nil
    if not completedOk or not credited then
        return notify(src, ('Enrollment #%s created; payment requires administrator reconciliation.'):format(id), 'error')
    end
    notify(src, ('Enrollment #%s created.'):format(id), 'success')
end)

-- Students can inspect their own payments; no other citizen IDs are accepted.
lib.callback.register('pm-education:server:myPayments', function(src, institutionId)
    local _, citizenid = playerFor(src)
    if not citizenid or type(institutionId) ~= 'string' or not Config.Institutions[institutionId] then return {} end
    return MySQL.query.await(
        'SELECT id, payment_type, amount, money_type, status, created_at FROM pm_education_payments WHERE citizenid = ? AND institution_id = ? ORDER BY id DESC LIMIT 50',
        { citizenid, institutionId })
end)


lib.callback.register('pm-education:server:myEnrollments', function(src, institutionId)
    local _, citizenid = playerFor(src)
    if not citizenid or type(institutionId) ~= 'string' or not Config.Institutions[institutionId] or Config.Institutions[institutionId].enabled == false then return {} end
    local rows = MySQL.query.await(
        'SELECT id, course_id, status FROM pm_education_enrollments WHERE citizenid = ? AND institution_id = ? ORDER BY id DESC LIMIT 50',
        { citizenid, institutionId })
    if not rows then error('Enrollment history database unavailable') end
    for _, row in ipairs(rows) do
        local course = getCourse(institutionId, row.course_id, row.id)
        row.courseLabel = course and course.label or row.course_id
    end
    return rows
end)

RegisterNetEvent('pm-education:server:requestExam', function(institutionId, courseId, paymentMethod)
    local src = source
    local player, citizenid = playerFor(src)
    local course = getCourse(institutionId, courseId)
    if not player or not course or not nearInteraction(src, institutionId, 'examiners', courseId) then return end
    if activeExams[src] and os.time() - activeExams[src].started <= 1800 then
        return notify(src, 'An exam is already active or starting.', 'error')
    end
    -- A stale pending session must not block the player permanently after a failed start.
    -- Uncertain payments remain protected separately by the durable payment ledger.
    if activeExams[src] then activeExams[src] = nil end
    -- Lock before any yielding database or payment call; rapid repeated events cannot double-charge.
    activeExams[src] = { pending = true, started = os.time() }
    local ok, record = pcall(enrollment, citizenid, institutionId, courseId)
    if not ok or not record or (record.status ~= 'enrolled' and record.status ~= 'in_progress') then
        activeExams[src] = nil
        return notify(src, ok and 'You must have an active enrollment.' or 'Enrollment database unavailable.', 'error')
    end
    local courseOk, assignedCourse = pcall(getCourse, institutionId, courseId, record.id)
    course = courseOk and assignedCourse or nil
    if not course then
        activeExams[src] = nil
        return notify(src, 'Assigned curriculum unavailable. No fee charged.', 'error')
    end
    if course.requireWritten == false then
        activeExams[src] = nil
        return notify(src, 'This course does not require a written examination.', 'error')
    end
    local questionsOk, selectedQuestions, revisionId, catalogError = pcall(getQuestions, institutionId, courseId, record.id)
    if not questionsOk or catalogError or type(selectedQuestions) ~= 'table' or #selectedQuestions == 0 then
        activeExams[src] = nil
        return notify(src, 'Assigned examination unavailable. No fee charged.', 'error')
    end
    local questions = {}
    local answerKey = {}
    for index, question in ipairs(selectedQuestions) do
        if type(question.question) ~= 'string' or type(question.answers) ~= 'table' or
            #question.answers < 2 or type(question.correct) ~= 'number' or
            question.correct % 1 ~= 0 or question.correct < 1 or question.correct > #question.answers then
            activeExams[src] = nil
            return notify(src, ('Question bank entry %d is invalid; no exam fee charged.'):format(index), 'error')
        end
        local answers = {}
        for answerIndex, label in ipairs(question.answers) do
            if type(label) ~= 'string' or label == '' then
                activeExams[src] = nil
                return notify(src, ('Question bank answer %d:%d is invalid; no exam fee charged.'):format(index, answerIndex), 'error')
            end
            answers[answerIndex] = label
        end
        questions[index] = { question = question.question, answers = answers }
        answerKey[index] = { correct = question.correct, count = #answers }
    end
    local threshold = tonumber(course.passPercent)
    if not threshold or threshold < 0 or threshold > 100 then
        activeExams[src] = nil
        return notify(src, 'Exam passing threshold is not configured correctly; no fee charged.', 'error')
    end
    local fee = course.examFee or 0
    local paid, paymentId, paymentError = pcall(paymentStart, player, citizenid, institutionId, courseId, record.id, 'exam', fee, paymentMethod)
    if not paid or not paymentId then
        activeExams[src] = nil
        return notify(src, paid and paymentError or 'Payment failed; review ledger before retrying.', 'error')
    end
    local updated, affected = pcall(MySQL.update.await,
        "UPDATE pm_education_enrollments SET status = 'in_progress' WHERE id = ? AND citizenid = ? AND status IN ('enrolled','in_progress')",
        { record.id, citizenid })
    if not updated or not affected or affected < 1 then
        -- MySQL may return zero affected rows for an already in-progress enrollment.
        local verifyOk, verified = pcall(enrollment, citizenid, institutionId, courseId)
        if not verifyOk or not verified or verified.id ~= record.id or verified.status ~= 'in_progress' then
            activeExams[src] = nil
            local refunded = paymentRefund(player, paymentId, fee, paymentMethod, 'Exam enrollment validation failed')
            return notify(src, refunded and 'Exam failed to start. Payment refunded.' or 'Exam failed. Refund needs administrator review.', 'error')
        end
    end
    activeExams[src] = { institutionId = institutionId, courseId = courseId, enrollmentId = record.id, citizenid = citizenid, started = os.time(), paymentId = paymentId, answerKey = answerKey, passPercent = threshold, catalogRevisionId = revisionId }
    local completedOk, credited = pcall(paymentComplete, paymentId, record.id, institutionId, fee)
    if not completedOk or not credited then
        notify(src, 'Exam started; society payment requires administrator reconciliation.', 'error')
    end
    TriggerClientEvent('pm-education:client:exam', src, institutionId, courseId, questions)
end)

RegisterNetEvent('pm-education:server:submitExam', function(institutionId, courseId, answers)
    local src = source
    local session = activeExams[src]
    if not session or session.pending or session.submitting or session.institutionId ~= institutionId or session.courseId ~= courseId then return end
    local _, citizenid = playerFor(src)
    if citizenid ~= session.citizenid or os.time() - session.started > 1800 then
        activeExams[src] = nil
        return
    end
    local courseOk, course = pcall(getCourse, institutionId, courseId, session.enrollmentId)
    if not courseOk then
        print(('[pm-education] Exam submission curriculum lookup failed: %s'):format(tostring(course)))
        return notify(src, 'Assigned curriculum temporarily unavailable. Your exam session remains active.', 'error')
    end
    local answerKey = session.answerKey or {}
    if not course or type(answers) ~= 'table' or #answerKey == 0 or #answers ~= #answerKey then
        return notify(src, 'Invalid examination submission. The active session was not consumed.', 'error')
    end
    for index, question in ipairs(answerKey) do
        if type(answers[index]) ~= 'number' or answers[index] % 1 ~= 0 or answers[index] < 1 or answers[index] > question.count then
            return notify(src, 'Invalid answer selection. The active session was not consumed.', 'error')
        end
    end
    session.submitting = true
    activeExams[src] = nil -- consumed before first yielding database validation
    local enrolledOk, current = pcall(enrollment, citizenid, institutionId, courseId)
    if not enrolledOk or not current or current.id ~= session.enrollmentId or
        (current.status ~= 'enrolled' and current.status ~= 'in_progress') then
        return notify(src, 'Exam enrollment is no longer active.', 'error')
    end
    local correct = 0
    for index, question in ipairs(answerKey) do
        if type(answers[index]) ~= 'number' or answers[index] % 1 ~= 0 or answers[index] < 1 or answers[index] > question.count then return end
        if answers[index] == question.correct then correct = correct + 1 end
    end
    local score = math.floor(correct * 100 / #answerKey)
    local passed = score >= session.passPercent
    local attemptSql = session.catalogRevisionId
        and 'INSERT INTO pm_education_attempts (enrollment_id, citizenid, score_percent, passed, answers_json, catalog_revision_id) VALUES (?, ?, ?, ?, ?, ?)'
        or 'INSERT INTO pm_education_attempts (enrollment_id, citizenid, score_percent, passed, answers_json) VALUES (?, ?, ?, ?, ?)'
    local attemptParams = {session.enrollmentId, citizenid, score, passed and 1 or 0, json.encode(answers)}
    if session.catalogRevisionId then attemptParams[#attemptParams + 1] = session.catalogRevisionId end
    local ok, saved = pcall(MySQL.insert.await, attemptSql, attemptParams)
    if not ok or not saved then
        return notify(src, 'Exam results could not be saved. Contact an administrator.', 'error')
    end
    if passed then
        local completionOk, completionError = pcall(refreshCompletion, session.enrollmentId, institutionId, courseId)
        if not completionOk then
            print(('[pm-education] Exam attempt #%s saved but completion refresh failed: %s'):format(saved, tostring(completionError)))
            return notify(src, 'Exam passed and saved, but credential completion needs administrator review.', 'error')
        end
    end
    notify(src, ('Exam %s: %d%%'):format(passed and 'passed' or 'failed', score), passed and 'success' or 'error')
end)

AddEventHandler('playerDropped', function()
    activeExams[source] = nil
    local citizenid = enrollmentLockOwners[source]
    if citizenid then
        enrollmentLocks[citizenid] = nil
        enrollmentLockOwners[source] = nil
    end
end)

-- Instructor management is always validated on the server.
local function instructorAuthorized(src, institutionId)
 if type(institutionId) ~= 'string' then return false end
 local institution = Config.Institutions[institutionId]
 if not institution or institution.enabled == false then return false end
 local player = QBCore.Functions.GetPlayer(src)
 if not player then return false end
 local job = player.PlayerData.job
 local rule = job and institution.staffJobs and institution.staffJobs[job.name]
 if not rule or (tonumber(job.grade and job.grade.level) or -1) < (rule.minGrade or 0) then return false end
 local ped = GetPlayerPed(src)
 if ped == 0 then return false end
 local pos = GetEntityCoords(ped)
 for _, desk in ipairs(institution.management or {}) do
  if desk.coords and #(pos - vector3(desk.coords.x, desk.coords.y, desk.coords.z)) <= 5.0 then return true end
 end
 return false
end

-- Return only curriculum-facing fields. Server retains authority over fees, permissions,
-- evaluation submissions, and enrollment state.
lib.callback.register('pm-education:server:courseOutline', function(src, institutionId, courseId, enrollmentId)
    local player = playerFor(src)
    if not player or type(enrollmentId) ~= 'number' or enrollmentId % 1 ~= 0 or
        not instructorAuthorized(src, institutionId) then return nil end
    local enrolled = MySQL.single.await(
        'SELECT course_id FROM pm_education_enrollments WHERE id = ? AND institution_id = ?',
        {enrollmentId, institutionId})
    if not enrolled or enrolled.course_id ~= courseId then return nil end
    local course = getCourse(institutionId, courseId, enrollmentId)
    if not course then return nil end
    local requirements = {}
    for _, requirement in ipairs(course.practicalRequirements or {}) do
        requirements[#requirements + 1] = {id = requirement.id, label = requirement.label}
    end
    return {
        label = course.label,
        requireWritten = course.requireWritten == true,
        practicalRequirements = requirements
    }
end)


lib.callback.register('pm-education:server:instructorStudents', function(src, institutionId)
 if not instructorAuthorized(src, institutionId) then return {} end
 local rows = MySQL.query.await(
  "SELECT id, citizenid, course_id, status FROM pm_education_enrollments WHERE institution_id = ? ORDER BY id DESC LIMIT 100",
  {institutionId})
 if not rows then error('Instructor student records unavailable') end
 local institution = Config.Institutions[institutionId]
 for _, row in ipairs(rows) do
  local assignedCourse = getCourse(institutionId, row.course_id, row.id)
  row.courseLabel = assignedCourse and assignedCourse.label or row.course_id
 end
 return rows
end)

lib.callback.register('pm-education:server:instructorResults', function(src, institutionId, enrollmentId)
 if not instructorAuthorized(src, institutionId) or type(enrollmentId) ~= 'number' then return {} end
 local record = MySQL.single.await('SELECT id FROM pm_education_enrollments WHERE id = ? AND institution_id = ?', {enrollmentId, institutionId})
 if not record then return {} end
 return MySQL.query.await(
  'SELECT requirement_id, result, notes, examiner_citizenid, recorded_at FROM pm_education_practical_results WHERE enrollment_id = ? AND institution_id = ? ORDER BY id DESC LIMIT 100',
  {enrollmentId, institutionId})
end)

RegisterNetEvent('pm-education:server:recordPractical', function(institutionId, enrollmentId, requirementId, result, notes)
 local src = source
 if not instructorAuthorized(src, institutionId) then return end
 if type(enrollmentId) ~= 'number' or enrollmentId % 1 ~= 0 or
    type(requirementId) ~= 'string' or
    (result ~= 'pass' and result ~= 'fail' and result ~= 'incomplete') or
    (notes ~= nil and type(notes) ~= 'string') then return end
 notes = notes or ''
 if #notes > 1000 then return end
 local record = MySQL.single.await(
  "SELECT citizenid, course_id FROM pm_education_enrollments WHERE id = ? AND institution_id = ? AND status IN ('enrolled','in_progress')",
  {enrollmentId, institutionId})
 if not record then return notify(src, 'Student is not actively enrolled.', 'error') end
 local course = getCourse(institutionId, record.course_id, enrollmentId)
 local valid = false
 for _, requirement in ipairs(course and course.practicalRequirements or {}) do
  if requirement.id == requirementId then valid = true break end
 end
 if not valid then return end
 local examiner = QBCore.Functions.GetPlayer(src)
 if not examiner then return end
 local ok, inserted = pcall(MySQL.insert.await,
  'INSERT INTO pm_education_practical_results (enrollment_id, citizenid, institution_id, course_id, requirement_id, result, notes, examiner_citizenid) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
  {enrollmentId, record.citizenid, institutionId, record.course_id, requirementId, result, notes, examiner.PlayerData.citizenid})
 if not ok or not inserted then return notify(src, 'Evaluation could not be saved.', 'error') end
 local refreshed, progress = pcall(refreshCompletion, enrollmentId, institutionId, record.course_id)
 if not refreshed or not progress then
  print(('[pm-education] Practical result #%s saved; completion refresh failed or returned no progress for enrollment #%s'):format(inserted, enrollmentId))
  return notify(src, 'Evaluation saved, but completion needs administrator review.', 'error')
 end
 notify(src, progress and progress.complete and 'Evaluation saved. All course requirements complete.' or 'Instructor evaluation recorded.', 'success')
end)

lib.callback.register('pm-education:server:courseProgress', function(src, institutionId, enrollmentId)
    if not instructorAuthorized(src, institutionId) or type(enrollmentId) ~= 'number' or enrollmentId % 1 ~= 0 then return nil end
    local record = MySQL.single.await(
        'SELECT course_id, status FROM pm_education_enrollments WHERE id = ? AND institution_id = ?',
        { enrollmentId, institutionId })
    if not record then return nil end
    local course = getCourse(institutionId, record.course_id, enrollmentId)
    if not course then return nil end
    local progress = courseProgress(enrollmentId, course, institutionId, record.course_id)
    progress.enrollmentStatus = record.status
    return progress
end)

-- Students may inspect only their own enrollment progress.
lib.callback.register('pm-education:server:myCourseProgress', function(src, institutionId, enrollmentId)
    local _, citizenid = playerFor(src)
    if not citizenid or type(institutionId) ~= 'string' or
        type(enrollmentId) ~= 'number' or enrollmentId % 1 ~= 0 then return nil end
    local record = MySQL.single.await(
        'SELECT course_id, status FROM pm_education_enrollments WHERE id = ? AND citizenid = ? AND institution_id = ?',
        { enrollmentId, citizenid, institutionId })
    if not record then return nil end
    local course = getCourse(institutionId, record.course_id, enrollmentId)
    if not course then return nil end
    local progress = courseProgress(enrollmentId, course, institutionId, record.course_id)
    progress.enrollmentStatus = record.status
    return progress
end)

-- Student-facing practical checklist: only the enrollment owner may read results.
-- Instructor notes and identities are intentionally not exposed here.
lib.callback.register('pm-education:server:myPracticalChecklist', function(src, institutionId, enrollmentId)
    local _, citizenid = playerFor(src)
    if not citizenid or type(institutionId) ~= 'string' or
        type(enrollmentId) ~= 'number' or enrollmentId % 1 ~= 0 then return nil end
    local record = MySQL.single.await(
        'SELECT course_id FROM pm_education_enrollments WHERE id = ? AND citizenid = ? AND institution_id = ?',
        {enrollmentId, citizenid, institutionId})
    if not record then return nil end
    local course = getCourse(institutionId, record.course_id, enrollmentId)
    if not course then return nil end
    local results = MySQL.query.await(
        'SELECT requirement_id, result FROM pm_education_practical_results WHERE enrollment_id = ? AND institution_id = ? AND course_id = ? ORDER BY id DESC',
        {enrollmentId, institutionId, record.course_id})
    if not results then return nil end
    local latest = {}
    for _, row in ipairs(results) do
        if latest[row.requirement_id] == nil then latest[row.requirement_id] = row.result end
    end
    local checklist = {}
    for _, requirement in ipairs(course.practicalRequirements or {}) do
        checklist[#checklist + 1] = {
            id = requirement.id,
            label = requirement.label,
            result = latest[requirement.id] or 'not_evaluated'
        }
    end
    return checklist
end)

-- Read-only verification: no license, rank, job or government authorization is granted.
exports('HasCredential', function(citizenid, credentialId)
    if type(citizenid) ~= 'string' or type(credentialId) ~= 'string' then return false end
    local row = MySQL.single.await(
        "SELECT id FROM pm_education_credentials WHERE citizenid = ? AND credential_id = ? AND status = 'active' AND (expires_at IS NULL OR expires_at > NOW()) LIMIT 1",
        { citizenid, credentialId })
    return row ~= nil
end)

lib.callback.register('pm-education:server:myCredentials', function(src)
    local _, citizenid = playerFor(src)
    if not citizenid then return nil end
    return MySQL.query.await(
        'SELECT id, institution_id, credential_id, credential_label, status, issued_at, expires_at FROM pm_education_credentials WHERE citizenid = ? ORDER BY id DESC LIMIT 100',
        { citizenid })
end)

-- Explicit cancellation clears an unfinished session. No results are fabricated.
RegisterNetEvent('pm-education:server:cancelExam', function(institutionId, courseId)
    local src = source
    local session = activeExams[src]
    if not session or session.institutionId ~= institutionId or session.courseId ~= courseId then return end
    local _, citizenid = playerFor(src)
    if citizenid ~= session.citizenid then return end
    activeExams[src] = nil
    notify(src, 'Exam cancelled. Any charged exam fee is not automatically refunded.', 'inform')
end)

-- Credential administrators require a separately configured job/grade AND an institution desk.
local function credentialAdminAuthorized(src, institutionId)
    if type(institutionId) ~= 'string' then return false end
    local institution = Config.Institutions[institutionId]
    if not institution or institution.enabled == false then return false end
    local player = QBCore.Functions.GetPlayer(src)
    local job = player and player.PlayerData.job
    local rule = job and institution.credentialAdminJobs and institution.credentialAdminJobs[job.name]
    if not rule or (tonumber(job.grade and job.grade.level) or -1) < (rule.minGrade or 0) then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, desk in ipairs(institution.management or {}) do
        if desk.coords and #(pos - vector3(desk.coords.x, desk.coords.y, desk.coords.z)) <= 5.0 then
            return true
        end
    end
    return false
end

-- Credential administrators can locate students without also holding an instructor job.
lib.callback.register('pm-education:server:adminStudents', function(src, institutionId)
    if not credentialAdminAuthorized(src, institutionId) then return nil end
    local rows = MySQL.query.await(
        'SELECT id, citizenid, course_id, status FROM pm_education_enrollments WHERE institution_id = ? ORDER BY id DESC LIMIT 100',
        {institutionId})
    if not rows then return nil end
    for _, row in ipairs(rows) do
        local course = getCourse(institutionId, row.course_id, row.id)
        row.courseLabel = course and course.label or row.course_id
    end
    return rows
end)

lib.callback.register('pm-education:server:adminCredentials', function(src, institutionId, enrollmentId)
    if not credentialAdminAuthorized(src, institutionId) or type(enrollmentId) ~= 'number' or enrollmentId % 1 ~= 0 then return {} end
    local record = MySQL.single.await(
        'SELECT id FROM pm_education_enrollments WHERE id = ? AND institution_id = ?',
        { enrollmentId, institutionId })
    if not record then return {} end
    return MySQL.query.await(
        'SELECT id, credential_label, status, issued_at FROM pm_education_credentials WHERE enrollment_id = ? AND institution_id = ? ORDER BY id DESC',
        { enrollmentId, institutionId })
end)

lib.callback.register('pm-education:server:credentialHistory', function(src, institutionId, credentialId)
    if not credentialAdminAuthorized(src, institutionId) or type(credentialId) ~= 'number' or credentialId % 1 ~= 0 then return {} end
    local record = MySQL.single.await('SELECT id FROM pm_education_credentials WHERE id = ? AND institution_id = ?', { credentialId, institutionId })
    if not record then return {} end
    return MySQL.query.await(
        'SELECT previous_status, new_status, reason, actor_citizenid, recorded_at FROM pm_education_credential_audit WHERE credential_id = ? ORDER BY id DESC LIMIT 50',
        { credentialId })
end)

lib.callback.register('pm-education:server:setCredentialStatus', function(src, institutionId, credentialId, nextStatus, reason)
    if not credentialAdminAuthorized(src, institutionId) then return false, 'Unauthorized' end
    if type(credentialId) ~= 'number' or credentialId % 1 ~= 0 or
        (nextStatus ~= 'active' and nextStatus ~= 'suspended' and nextStatus ~= 'revoked') or
        type(reason) ~= 'string' or #reason < 10 or #reason > 1000 or not reason:match('%S') then
        return false, 'Invalid status or reason (10-1000 characters required)'
    end
    local actor = QBCore.Functions.GetPlayer(src)
    if not actor then return false, 'Instructor not found' end
    if credentialLocks[credentialId] then return false, 'Credential update already in progress' end
    credentialLocks[credentialId] = true
    -- A transaction makes status and audit inseparable. No silent, unaudited changes.
    local ok, result, message = pcall(function()
        local record = MySQL.single.await(
            'SELECT id, citizenid, status FROM pm_education_credentials WHERE id = ? AND institution_id = ?',
            { credentialId, institutionId })
        if not record then return false, 'Credential not found' end
        if record.status == nextStatus then return false, 'Credential already has this status' end
        if record.status == 'revoked' then return false, 'Revoked credentials are terminal; new accreditation is required' end
        if record.status == 'active' and nextStatus ~= 'suspended' and nextStatus ~= 'revoked' then return false, 'Invalid active credential transition' end
        if record.status == 'suspended' and nextStatus ~= 'active' and nextStatus ~= 'revoked' then return false, 'Invalid suspended credential transition' end
        if record.status == 'expired' then return false, 'Expired credentials require renewal workflow' end
        local success = MySQL.transaction.await({
            {
                query = 'UPDATE pm_education_credentials SET status = ? WHERE id = ? AND institution_id = ? AND status = ?',
                values = { nextStatus, credentialId, institutionId, record.status }
            },
            {
                query = 'INSERT INTO pm_education_credential_audit (credential_id, institution_id, subject_citizenid, actor_citizenid, previous_status, new_status, reason) VALUES (?, ?, ?, ?, ?, ?, ?)',
                values = { credentialId, institutionId, record.citizenid, actor.PlayerData.citizenid, record.status, nextStatus, reason }
            }
        })
        if not success then return false, 'Database transaction failed' end
        return true, 'Credential status updated and audited'
    end)
    credentialLocks[credentialId] = nil
    if not ok then return false, 'Credential update failed' end
    return result, message
end)

-- Read-only console-side reconciliation. No network event and no automatic re-charge.
RegisterCommand('pm_education_payments', function(src)
    if src ~= 0 then return end
    local ok, rows = pcall(MySQL.query.await,
        "SELECT id, citizenid, payment_type, amount, status, details, created_at FROM pm_education_payments WHERE status IN ('pending','charged','refund_failed') ORDER BY id DESC LIMIT 50")
    if not ok then return print('[pm-education] Payment ledger unavailable') end
    print(('[pm-education] Payments needing review: %d (latest 50)'):format(#(rows or {})))
    for _, row in ipairs(rows or {}) do
        print(('[pm-education] #%s %s %s $%s %s %s'):format(row.id, row.citizenid, row.payment_type, row.amount, row.status, row.details or ''))
    end
end, false)