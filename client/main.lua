local QBCore = exports['qb-core']:GetCoreObject()
local activeExam = false

local function notify(message, kind)
    lib.notify({ description = message, type = kind or 'inform' })
end

local function openExam(institutionId, courseId, questions)
    if activeExam then return end
    activeExam = true
    local answers = {}
    for index, question in ipairs(questions) do
        local options = {}
        for answerIndex, answer in ipairs(question.answers) do
            options[#options + 1] = { value = tostring(answerIndex), label = answer }
        end
        local result = lib.inputDialog(('Question %d of %d'):format(index, #questions), {
            { type = 'select', label = question.question, options = options, required = true }
        }, { allowCancel = true })
        if not result then activeExam = false return end
        answers[index] = tonumber(result[1])
    end
    TriggerServerEvent('pm-education:server:submitExam', institutionId, courseId, answers)
    activeExam = false
end

RegisterNetEvent('pm-education:client:exam', openExam)
RegisterNetEvent('pm-education:client:notify', notify)

local function showEnrollments(institutionId)
    local records = lib.callback.await('pm-education:server:myEnrollments', false, institutionId)
    if not records then return notify('Unable to load enrollments.', 'error') end
    local options = {}
    for _, record in ipairs(records) do
        options[#options + 1] = {
            title = ('#%s %s'):format(record.id, record.courseLabel),
            description = ('Status: %s'):format(record.status),
            disabled = true
        }
    end
    if #options == 0 then options[1] = { title = 'No enrollments found', disabled = true } end
    lib.registerContext({ id = 'pm_education_my_enrollments', title = 'My Enrollments', options = options })
    lib.showContext('pm_education_my_enrollments')
end

local function showAdmissions(institutionId)
    local institution = Config.Institutions[institutionId]
    local options = {}
    for courseId, course in pairs(institution.courses) do
        local selectedId = courseId
        options[#options + 1] = {
            title = course.label,
            description = ('Enrollment fee: $%d'):format(course.enrollmentFee or 0),
            onSelect = function()
                TriggerServerEvent('pm-education:server:enroll', institutionId, selectedId)
            end
        }
    end
    options[#options + 1] = {
        title = 'My Enrollments',
        onSelect = function() showEnrollments(institutionId) end
    }
    lib.registerContext({ id = 'pm_education_admissions', title = institution.label .. ' Admissions', options = options })
    lib.showContext('pm_education_admissions')
end

local function showExaminer(institutionId, examiner)
    local institution = Config.Institutions[institutionId]
    local options = {}
    for _, courseId in ipairs(examiner.courses or {}) do
        local course = institution.courses[courseId]
        if course then
            local selectedId = courseId
            options[#options + 1] = {
                title = course.label,
                description = ('Exam fee: $%d'):format(course.examFee or 0),
                onSelect = function()
                    TriggerServerEvent('pm-education:server:requestExam', institutionId, selectedId)
                end
            }
        end
    end
    lib.registerContext({ id = 'pm_education_exams', title = examiner.label or 'Examinations', options = options })
    lib.showContext('pm_education_exams')
end

local function spawnInteraction(point, callback)
    local model = joaat(point.model)
    lib.requestModel(model)
    local ped = CreatePed(4, model, point.coords.x, point.coords.y, point.coords.z - 1.0, point.coords.w, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    exports['qb-target']:AddTargetEntity(ped, {
        options = {{ icon = 'fas fa-graduation-cap', label = point.label or 'Education', action = callback }},
        distance = 2.0
    })
end

CreateThread(function()
    for institutionId, institution in pairs(Config.Institutions) do
        local id = institutionId
        for _, point in ipairs(institution.admissions or {}) do
            spawnInteraction(point, function() showAdmissions(id) end)
        end
        for _, examiner in ipairs(institution.examiners or {}) do
            local location = examiner
            spawnInteraction(location, function() showExaminer(id, location) end)
        end
    end
end)
