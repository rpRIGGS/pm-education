local QBCore = exports['qb-core']:GetCoreObject()
local activeExams = {}

local function notify(src, message, kind)
    TriggerClientEvent('pm-education:client:notify', src, message, kind)
end

local function getCourse(institutionId, courseId)
    if type(institutionId) ~= 'string' or type(courseId) ~= 'string' then return end
    local institution = Config.Institutions[institutionId]
    return institution and institution.courses[courseId], institution
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

local function charge(player, amount, reason)
    if type(amount) ~= 'number' or amount < 0 or amount % 1 ~= 0 then return false end
    if amount == 0 then return true end
    return player.Functions.RemoveMoney('cash', amount, reason)
end

RegisterNetEvent('pm-education:server:enroll', function(institutionId, courseId)
    local src = source
    local player, citizenid = playerFor(src)
    local course = getCourse(institutionId, courseId)
    if not player or not course then return end
    local existing = enrollment(citizenid, institutionId, courseId)
    if existing then return notify(src, 'Enrollment already exists. See My Enrollments.', 'error') end
    local fee = course.enrollmentFee or 0
    if not charge(player, fee, 'PM Education Enrollment') then
        return notify(src, 'Insufficient cash for enrollment.', 'error')
    end
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO pm_education_enrollments (citizenid, institution_id, course_id) VALUES (?, ?, ?)',
        { citizenid, institutionId, courseId })
    if not ok or not id then
        if fee > 0 then player.Functions.AddMoney('cash', fee, 'PM Education Enrollment Refund') end
        return notify(src, 'Enrollment could not be saved. Payment refunded.', 'error')
    end
    notify(src, ('Enrollment #%s created.'):format(id), 'success')
end)

lib.callback.register('pm-education:server:myEnrollments', function(src, institutionId)
    local _, citizenid = playerFor(src)
    if not citizenid or type(institutionId) ~= 'string' or not Config.Institutions[institutionId] then return {} end
    local rows = MySQL.query.await(
        'SELECT id, course_id, status FROM pm_education_enrollments WHERE citizenid = ? AND institution_id = ? ORDER BY id DESC LIMIT 50',
        { citizenid, institutionId })
    for _, row in ipairs(rows) do
        local course = Config.Institutions[institutionId].courses[row.course_id]
        row.courseLabel = course and course.label or row.course_id
    end
    return rows
end)

RegisterNetEvent('pm-education:server:requestExam', function(institutionId, courseId)
    local src = source
    local player, citizenid = playerFor(src)
    local course = getCourse(institutionId, courseId)
    if not player or not course or type(course.questions) ~= 'table' or #course.questions == 0 then return end
    if activeExams[src] then return notify(src, 'An exam is already active.', 'error') end
    local record = enrollment(citizenid, institutionId, courseId)
    if not record or (record.status ~= 'enrolled' and record.status ~= 'in_progress') then
        return notify(src, 'You must have an active enrollment.', 'error')
    end
    local fee = course.examFee or 0
    if not charge(player, fee, 'PM Education Exam') then return notify(src, 'Insufficient cash for exam.', 'error') end
    local questions = {}
    for index, question in ipairs(course.questions) do
        questions[index] = { question = question.question, answers = question.answers }
    end
    activeExams[src] = { institutionId = institutionId, courseId = courseId, enrollmentId = record.id, citizenid = citizenid, started = os.time() }
    MySQL.update.await("UPDATE pm_education_enrollments SET status = 'in_progress' WHERE id = ? AND status = 'enrolled'", {record.id})
    TriggerClientEvent('pm-education:client:exam', src, institutionId, courseId, questions)
end)

RegisterNetEvent('pm-education:server:submitExam', function(institutionId, courseId, answers)
    local src = source
    local session = activeExams[src]
    activeExams[src] = nil
    if not session or session.institutionId ~= institutionId or session.courseId ~= courseId then return end
    local _, citizenid = playerFor(src)
    if citizenid ~= session.citizenid or os.time() - session.started > 1800 then return end
    local course = getCourse(institutionId, courseId)
    if not course or type(answers) ~= 'table' or #answers ~= #course.questions then return end
    local correct = 0
    for index, question in ipairs(course.questions) do
        if type(answers[index]) ~= 'number' or answers[index] % 1 ~= 0 or answers[index] < 1 or answers[index] > #question.answers then return end
        if answers[index] == question.correct then correct = correct + 1 end
    end
    local score = math.floor(correct * 100 / #course.questions)
    local passed = score >= (course.passPercent or 70)
    MySQL.insert.await(
        'INSERT INTO pm_education_attempts (enrollment_id, citizenid, score_percent, passed, answers_json) VALUES (?, ?, ?, ?, ?)',
        {session.enrollmentId, citizenid, score, passed and 1 or 0, json.encode(answers)})
    if passed then
        MySQL.update.await("UPDATE pm_education_enrollments SET status = 'completed' WHERE id = ? AND citizenid = ? AND status = 'in_progress'",
            {session.enrollmentId, citizenid})
    end
    notify(src, ('Exam %s: %d%%'):format(passed and 'passed' or 'failed', score), passed and 'success' or 'error')
end)

AddEventHandler('playerDropped', function() activeExams[source] = nil end)
