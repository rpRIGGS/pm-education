local QBCore = exports['qb-core']:GetCoreObject()
local activeExams = {}
local enrollmentLocks = {}
local credentialLocks = {}

local function getQuestions(institutionId, courseId)
    return EducationQuestions and EducationQuestions[institutionId] and EducationQuestions[institutionId][courseId] or {}
end

local function notify(src, message, kind)
    TriggerClientEvent('pm-education:client:notify', src, message, kind)
end

local function getCourse(institutionId, courseId)
    if type(institutionId) ~= 'string' or type(courseId) ~= 'string' then return end
    local institution = Config.Institutions[institutionId]
    return institution and institution.enabled ~= false and institution.courses and institution.courses[courseId], institution
end

local function nearInteraction(src, institutionId, kind, courseId)
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
        if allowed and #(position - vector3(point.coords.x, point.coords.y, point.coords.z)) <= 5.0 then return true end
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
    paymentStatus(paymentId, result and 'refunded' or 'refund_failed', details)
    return result
end

local function paymentStart(player, citizenid, institutionId, courseId, enrollmentId, paymentType, amount, method)
    if not validPaymentMethod(method) then return nil, 'Select cash or bank' end
    if type(amount) ~= 'number' or amount < 0 or amount % 1 ~= 0 then return nil, 'Invalid fee configuration' end
    local account = societyAccount(institutionId)
    if not account then return nil, 'Institution society account unavailable in qb-banking' end
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
        return false
    end
    if amount > 0 then
        local ok, credited = pcall(function()
            return exports['qb-banking']:AddMoney(account, amount, 'PM Education payment #' .. paymentId)
        end)
        if not ok or not credited then
            paymentStatus(paymentId, 'charged', 'Society credit failed or uncertain; reconcile qb-banking statements')
            return false
        end
    end
    local ok, changed = pcall(MySQL.update.await,
        "UPDATE pm_education_payments SET status = 'completed', enrollment_id = COALESCE(?, enrollment_id), details = ? WHERE id = ? AND status = 'charged'",
        { enrollmentId, 'Society credited: ' .. account, paymentId })
    if not ok or not changed or changed < 1 then
        print(('[pm-education] Society credit for payment #%s needs manual ledger reconciliation; DO NOT credit again'):format(paymentId))
    end
    return true
end


-- Completion is calculated from SQL results, never client-reported progress.
local function courseProgress(enrollmentId, course, institutionId, courseId)
    local writtenRequired = #getQuestions(institutionId, courseId) > 0
    local writtenPassed = false
    if writtenRequired then
        local attempt = MySQL.single.await(
            'SELECT id FROM pm_education_attempts WHERE enrollment_id = ? AND passed = 1 ORDER BY id DESC LIMIT 1',
            { enrollmentId })
        writtenPassed = attempt ~= nil
    end
    local practical = {}
    local rows = MySQL.query.await(
        'SELECT requirement_id, result FROM pm_education_practical_results WHERE enrollment_id = ? ORDER BY id DESC',
        { enrollmentId }) or {}
    for _, row in ipairs(rows) do
        if practical[row.requirement_id] == nil then practical[row.requirement_id] = row.result end
    end
    local requiredCount, passedCount = 0, 0
    for _, requirement in ipairs(course.practicalRequirements or {}) do
        requiredCount = requiredCount + 1
        if practical[requirement.id] == 'pass' then passedCount = passedCount + 1 end
    end
    local hasRequirements = course.requireWritten or writtenRequired or requiredCount > 0
    local complete = hasRequirements and (not course.requireWritten or writtenRequired) and (not writtenRequired or writtenPassed) and passedCount == requiredCount
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
    local course = getCourse(institutionId, courseId)
    if not course then return end
    local progress = courseProgress(enrollmentId, course, institutionId, courseId)
    if progress.complete then
        MySQL.update.await(
            "UPDATE pm_education_enrollments SET status = 'completed' WHERE id = ? AND institution_id = ? AND course_id = ? AND status IN ('enrolled','in_progress')",
            { enrollmentId, institutionId, courseId })
        if course.credentialId then
            local record = MySQL.single.await(
                "SELECT citizenid, status FROM pm_education_enrollments WHERE id = ? AND institution_id = ? AND course_id = ?",
                { enrollmentId, institutionId, courseId })
            if record and record.status == 'completed' then
                MySQL.insert.await(
                    "INSERT INTO pm_education_credentials (enrollment_id, citizenid, institution_id, credential_id, credential_label) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)",
                    { enrollmentId, record.citizenid, institutionId, course.credentialId, course.credentialLabel or course.credentialId })
            end
        end
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
    local lookupOk, existing = pcall(enrollment, citizenid, institutionId, courseId)
    if not lookupOk then
        enrollmentLocks[citizenid] = nil
        return notify(src, 'Enrollment database unavailable. No fee charged.', 'error')
    end
    if existing then
        enrollmentLocks[citizenid] = nil
        return notify(src, 'Enrollment already exists. See My Enrollments.', 'error')
    end
    local fee = course.enrollmentFee or 0
    local paid, paymentId, paymentError = pcall(paymentStart, player, citizenid, institutionId, courseId, nil, 'enrollment', fee, paymentMethod)
    if not paid or not paymentId then
        enrollmentLocks[citizenid] = nil
        return notify(src, paid and paymentError or 'Payment processing failed; review ledger before retrying.', 'error')
    end
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO pm_education_enrollments (citizenid, institution_id, course_id) VALUES (?, ?, ?)',
        { citizenid, institutionId, courseId })
    enrollmentLocks[citizenid] = nil
    if not ok or not id then
        local refunded = paymentRefund(player, paymentId, fee, paymentMethod, 'Enrollment insert failed')
        return notify(src, refunded and 'Enrollment failed. Payment refunded.' or 'Enrollment failed. Refund requires administrator review.', 'error')
    end
    paymentComplete(paymentId, id, institutionId, fee)
    notify(src, ('Enrollment #%s created.'):format(id), 'success')
end)

-- Students can inspect their own payments; no other citizen IDs are accepted.
lib.callback.register('pm-education:server:myPayments', function(src, institutionId)
    local _, citizenid = playerFor(src)
    if not citizenid or type(institutionId) ~= 'string' or not Config.Institutions[institutionId] then return {} end
    return MySQL.query.await(
        'SELECT id, payment_type, amount, money_type, status, created_at FROM pm_education_payments WHERE citizenid = ? AND institution_id = ? ORDER BY id DESC LIMIT 50',
        { citizenid, institutionId }) or {}
end)

lib.callback.register('pm-education:server:myEnrollments', function(src, institutionId)
    local _, citizenid = playerFor(src)
    if not citizenid or type(institutionId) ~= 'string' or not Config.Institutions[institutionId] or Config.Institutions[institutionId].enabled == false then return {} end
    local rows = MySQL.query.await(
        'SELECT id, course_id, status FROM pm_education_enrollments WHERE citizenid = ? AND institution_id = ? ORDER BY id DESC LIMIT 50',
        { citizenid, institutionId }) or {}
    for _, row in ipairs(rows) do
        local course = Config.Institutions[institutionId].courses[row.course_id]
        row.courseLabel = course and course.label or row.course_id
    end
    return rows
end)

RegisterNetEvent('pm-education:server:requestExam', function(institutionId, courseId, paymentMethod)
    local src = source
    local player, citizenid = playerFor(src)
    local course = getCourse(institutionId, courseId)
    if not player or not course or not nearInteraction(src, institutionId, 'examiners', courseId)
        or #getQuestions(institutionId, courseId) == 0 then return end
    if activeExams[src] and (activeExams[src].pending or os.time() - activeExams[src].started <= 1800) then
        return notify(src, 'An exam is already active or starting.', 'error')
    end
    -- Lock before any yielding database or payment call; rapid repeated events cannot double-charge.
    activeExams[src] = { pending = true, started = os.time() }
    local ok, record = pcall(enrollment, citizenid, institutionId, courseId)
    if not ok or not record or (record.status ~= 'enrolled' and record.status ~= 'in_progress') then
        activeExams[src] = nil
        return notify(src, ok and 'You must have an active enrollment.' or 'Enrollment database unavailable.', 'error')
    end
    local questions = {}
    local answerKey = {}
    for index, question in ipairs(getQuestions(institutionId, courseId)) do
        questions[index] = { question = question.question, answers = question.answers }
        answerKey[index] = { correct = question.correct, count = #question.answers }
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
    activeExams[src] = { institutionId = institutionId, courseId = courseId, enrollmentId = record.id, citizenid = citizenid, started = os.time(), paymentId = paymentId, answerKey = answerKey }
    paymentComplete(paymentId, record.id, institutionId, fee)
    TriggerClientEvent('pm-education:client:exam', src, institutionId, courseId, questions)
end)

RegisterNetEvent('pm-education:server:submitExam', function(institutionId, courseId, answers)
    local src = source
    local session = activeExams[src]
    if not session or session.pending or session.submitting or session.institutionId ~= institutionId or session.courseId ~= courseId then return end
    session.submitting = true
    activeExams[src] = nil -- consumed once, before any yielding validation or insert
    local _, citizenid = playerFor(src)
    if citizenid ~= session.citizenid or os.time() - session.started > 1800 then return end
    local course = getCourse(institutionId, courseId)
    local answerKey = session.answerKey or {}
    if not course or type(answers) ~= 'table' or #answerKey == 0 or #answers ~= #answerKey then return end
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
    local passed = score >= (course.passPercent or 70)
    local ok, saved = pcall(MySQL.insert.await,
        'INSERT INTO pm_education_attempts (enrollment_id, citizenid, score_percent, passed, answers_json) VALUES (?, ?, ?, ?, ?)',
        {session.enrollmentId, citizenid, score, passed and 1 or 0, json.encode(answers)})
    if not ok or not saved then
        return notify(src, 'Exam results could not be saved. Contact an administrator.', 'error')
    end
    if passed then refreshCompletion(session.enrollmentId, institutionId, courseId) end
    notify(src, ('Exam %s: %d%%'):format(passed and 'passed' or 'failed', score), passed and 'success' or 'error')
end)

AddEventHandler('playerDropped', function()
    activeExams[source] = nil
    local _, citizenid = playerFor(source)
    if citizenid then enrollmentLocks[citizenid] = nil end
end)

-- Instructor management is always validated on the server.
local function instructorAuthorized(src, institutionId)
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
  if #(pos - vector3(desk.coords.x, desk.coords.y, desk.coords.z)) <= 5.0 then return true end
 end
 return false
end

lib.callback.register('pm-education:server:instructorStudents', function(src, institutionId)
 if not instructorAuthorized(src, institutionId) then return {} end
 local rows = MySQL.query.await(
  "SELECT id, citizenid, course_id, status FROM pm_education_enrollments WHERE institution_id = ? ORDER BY id DESC LIMIT 100",
  {institutionId}) or {}
 local institution = Config.Institutions[institutionId]
 for _, row in ipairs(rows) do
  row.courseLabel = institution.courses[row.course_id] and institution.courses[row.course_id].label or row.course_id
 end
 return rows
end)

lib.callback.register('pm-education:server:instructorResults', function(src, institutionId, enrollmentId)
 if not instructorAuthorized(src, institutionId) or type(enrollmentId) ~= 'number' then return {} end
 local record = MySQL.single.await('SELECT id FROM pm_education_enrollments WHERE id = ? AND institution_id = ?', {enrollmentId, institutionId})
 if not record then return {} end
 return MySQL.query.await(
  'SELECT requirement_id, result, notes, examiner_citizenid, recorded_at FROM pm_education_practical_results WHERE enrollment_id = ? ORDER BY id DESC LIMIT 100',
  {enrollmentId}) or {}
end)

RegisterNetEvent('pm-education:server:recordPractical', function(institutionId, enrollmentId, requirementId, result, notes)
 local src = source
 if not instructorAuthorized(src, institutionId) then return end
 if type(enrollmentId) ~= 'number' or enrollmentId % 1 ~= 0 or
    type(requirementId) ~= 'string' or
    (result ~= 'pass' and result ~= 'fail' and result ~= 'incomplete') or
    type(notes) ~= 'string' or #notes > 1000 then return end
 local record = MySQL.single.await(
  "SELECT citizenid, course_id FROM pm_education_enrollments WHERE id = ? AND institution_id = ? AND status IN ('enrolled','in_progress')",
  {enrollmentId, institutionId})
 if not record then return notify(src, 'Student is not actively enrolled.', 'error') end
 local course = Config.Institutions[institutionId].courses[record.course_id]
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
 local progress = refreshCompletion(enrollmentId, institutionId, record.course_id)
 notify(src, progress and progress.complete and 'Evaluation saved. All course requirements complete.' or 'Instructor evaluation recorded.', 'success')
end)

lib.callback.register('pm-education:server:courseProgress', function(src, institutionId, enrollmentId)
    if not instructorAuthorized(src, institutionId) or type(enrollmentId) ~= 'number' or enrollmentId % 1 ~= 0 then return nil end
    local record = MySQL.single.await(
        'SELECT course_id, status FROM pm_education_enrollments WHERE id = ? AND institution_id = ?',
        { enrollmentId, institutionId })
    if not record then return nil end
    local course = getCourse(institutionId, record.course_id)
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
    local course = getCourse(institutionId, record.course_id)
    if not course then return nil end
    local progress = courseProgress(enrollmentId, course, institutionId, record.course_id)
    progress.enrollmentStatus = record.status
    return progress
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
    if not citizenid then return {} end
    return MySQL.query.await(
        'SELECT id, institution_id, credential_id, credential_label, status, issued_at, expires_at FROM pm_education_credentials WHERE citizenid = ? ORDER BY id DESC LIMIT 100',
        { citizenid }) or {}
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
    if not instructorAuthorized(src, institutionId) then return false end
    local institution = Config.Institutions[institutionId]
    local job = QBCore.Functions.GetPlayer(src).PlayerData.job
    local rule = institution.credentialAdminJobs and institution.credentialAdminJobs[job.name]
    return rule ~= nil and (tonumber(job.grade and job.grade.level) or -1) >= (rule.minGrade or 0)
end

lib.callback.register('pm-education:server:adminCredentials', function(src, institutionId, enrollmentId)
    if not credentialAdminAuthorized(src, institutionId) or type(enrollmentId) ~= 'number' or enrollmentId % 1 ~= 0 then return {} end
    local record = MySQL.single.await(
        'SELECT id FROM pm_education_enrollments WHERE id = ? AND institution_id = ?',
        { enrollmentId, institutionId })
    if not record then return {} end
    return MySQL.query.await(
        'SELECT id, credential_label, status, issued_at FROM pm_education_credentials WHERE enrollment_id = ? AND institution_id = ? ORDER BY id DESC',
        { enrollmentId, institutionId }) or {}
end)

lib.callback.register('pm-education:server:credentialHistory', function(src, institutionId, credentialId)
    if not credentialAdminAuthorized(src, institutionId) or type(credentialId) ~= 'number' or credentialId % 1 ~= 0 then return {} end
    local record = MySQL.single.await('SELECT id FROM pm_education_credentials WHERE id = ? AND institution_id = ?', { credentialId, institutionId })
    if not record then return {} end
    return MySQL.query.await(
        'SELECT previous_status, new_status, reason, actor_citizenid, recorded_at FROM pm_education_credential_audit WHERE credential_id = ? ORDER BY id DESC LIMIT 50',
        { credentialId }) or {}
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
