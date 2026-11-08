local QBCore = exports['qb-core']:GetCoreObject()
local activeExam = false
local spawnedPeds = {}
local managementZones = {}

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
        if not result then
            TriggerServerEvent('pm-education:server:cancelExam', institutionId, courseId)
            activeExam = false
            return
        end
        answers[index] = tonumber(result[1])
    end
    TriggerServerEvent('pm-education:server:submitExam', institutionId, courseId, answers)
    activeExam = false
end

RegisterNetEvent('pm-education:client:exam', openExam)
RegisterNetEvent('pm-education:client:notify', notify)

local function showPaymentReceipts(institutionId)
    local receipts = lib.callback.await('pm-education:server:myPayments', false, institutionId)
    if not receipts then return notify('Payment records are temporarily unavailable.', 'error') end
    local options = {}
    for _, receipt in ipairs(receipts) do
        options[#options + 1] = {
            title = ('Receipt #%s - %s $%s'):format(receipt.id, receipt.payment_type, receipt.amount),
            description = ('%s | %s | %s'):format(receipt.status, receipt.money_type, receipt.created_at),
            disabled = true
        }
    end
    if #options == 0 then options[1] = { title = 'No payments recorded', disabled = true } end
    lib.registerContext({ id = 'pm_education_receipts', title = 'Payment Receipts', options = options })
    lib.showContext('pm_education_receipts')
end

local function showEnrollments(institutionId)
    local records = lib.callback.await('pm-education:server:myEnrollments', false, institutionId)
    if not records then return notify('Unable to load enrollments.', 'error') end
    local options = {}
    for _, record in ipairs(records) do
        options[#options + 1] = {
            title = ('#%s %s'):format(record.id, record.courseLabel),
            description = ('Status: %s'):format(record.status),
            onSelect = function()
                local progress = lib.callback.await('pm-education:server:myCourseProgress', false, institutionId, record.id)
                if not progress then return notify('Unable to load course progress.', 'error') end
                lib.registerContext({
                    id = 'pm_education_student_progress',
                    title = record.courseLabel,
                    menu = 'pm_education_my_enrollments',
                    options = {
                        { title = 'Enrollment status', description = progress.enrollmentStatus, disabled = true },
                        { title = 'Written exam', description = progress.writtenRequired and (progress.writtenPassed and 'Passed' or 'Not passed') or 'Not configured', disabled = true },
                        { title = 'Practical evaluations', description = ('%d / %d passed'):format(progress.practicalPassed, progress.practicalRequired), disabled = true },
                        { title = 'Course requirements', description = progress.complete and 'Satisfied' or 'Outstanding', disabled = true }
                    }
                })
                lib.showContext('pm_education_student_progress')
            end
        }
    end
    if #options == 0 then options[1] = { title = 'No enrollments found', disabled = true } end
    lib.registerContext({ id = 'pm_education_my_enrollments', title = 'My Enrollments', options = options })
    lib.showContext('pm_education_my_enrollments')
end


local function showMyCredentials()
    local records = lib.callback.await('pm-education:server:myCredentials', false)
    if not records then return notify('Credential records are temporarily unavailable.', 'error') end
    local options = {}
    for _, record in ipairs(records) do
        options[#options + 1] = {
            title = record.credential_label,
            description = ('Credential #%s | %s | %s'):format(record.id, record.institution_id, record.status),
            disabled = true
        }
    end
    if #options == 0 then options[1] = { title = 'No credentials awarded yet', disabled = true } end
    lib.registerContext({ id = 'pm_education_my_credentials', title = 'My Credentials', options = options })
    lib.showContext('pm_education_my_credentials')
end

local function choosePaymentMethod(label, amount)
    local methods = Config.Payment and Config.Payment.allowedMethods or {}
    if amount == 0 then
        if methods.cash then return 'cash' end
        if methods.bank then return 'bank' end
        return notify('No payment methods are configured.', 'error')
    end
    local options = {}
    if methods.cash then options[#options + 1] = {value = 'cash', label = 'Cash'} end
    if methods.bank then options[#options + 1] = {value = 'bank', label = 'Bank'} end
    if #options == 0 then return notify('No payment methods are configured.', 'error') end
    local result = lib.inputDialog(label, {{
        type = 'select', label = ('Payment method - $%d'):format(amount), required = true,
        options = options
    }})
    return result and result[1] or nil
end

local function loadCourses(institutionId)
    local courses = lib.callback.await('pm-education:server:availableCourses', false, institutionId)
    if not courses then
        notify('Course catalog unavailable. Try again later.', 'error')
        return nil
    end
    return courses
end

local function showAdmissions(institutionId)
    local institution = Config.Institutions[institutionId]
    local courses = loadCourses(institutionId)
    if not courses then return end
    local options = {}
    for _, course in ipairs(courses) do
        local selected = course
        options[#options + 1] = {
            title = selected.label,
            description = ('Enrollment fee: $%d'):format(selected.enrollmentFee),
            onSelect = function()
                local method = choosePaymentMethod('Course enrollment', selected.enrollmentFee)
                if method then TriggerServerEvent('pm-education:server:enroll', institutionId, selected.id, method) end
            end
        }
    end
    options[#options + 1] = {
        title = 'My Enrollments',
        onSelect = function() showEnrollments(institutionId) end
    }
    options[#options + 1] = {
        title = 'My Credentials',
        onSelect = showMyCredentials
    }
    options[#options + 1] = {
        title = 'Payment Receipts',
        onSelect = function() showPaymentReceipts(institutionId) end
    }
    lib.registerContext({ id = 'pm_education_admissions', title = institution.label .. ' Admissions', options = options })
    lib.showContext('pm_education_admissions')
end

local function showExaminer(institutionId, examiner)
    local courses = loadCourses(institutionId)
    if not courses then return end
    local offered = {}
    for _, courseId in ipairs(examiner.courses or {}) do offered[courseId] = true end
    local options = {}
    for _, course in ipairs(courses) do
        if offered[course.id] then
            local selected = course
            options[#options + 1] = {
                title = selected.label,
                description = ('Exam fee: $%d'):format(selected.examFee),
                onSelect = function()
                    local method = choosePaymentMethod('Written examination', selected.examFee)
                    if method then TriggerServerEvent('pm-education:server:requestExam', institutionId, selected.id, method) end
                end
            }
        end
    end
    if #options == 0 then options[1] = {title='No examinations offered at this location',disabled=true} end
    lib.registerContext({ id = 'pm_education_exams', title = examiner.label or 'Examinations', options = options })
    lib.showContext('pm_education_exams')
end

local function spawnInteraction(point, callback)
    if not point or type(point.model) ~= 'string' or not point.coords then
        print('[pm-education] Skipping unconfigured education NPC')
        return
    end
    local model = joaat(point.model)
    lib.requestModel(model)
    local ped = CreatePed(4, model, point.coords.x, point.coords.y, point.coords.z - 1.0, point.coords.w or 0.0, false, true)
    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(model)
        print('[pm-education] Failed to create education NPC for ' .. tostring(point.label))
        return
    end
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    spawnedPeds[#spawnedPeds + 1] = ped
    exports['qb-target']:AddTargetEntity(ped, {
        options = {{ icon = 'fas fa-graduation-cap', label = point.label or 'Education', action = callback }},
        distance = 2.0
    })
end

CreateThread(function()
    for institutionId, institution in pairs(Config.Institutions) do
        if institution.enabled ~= false then
        local id = institutionId
        for _, point in ipairs(institution.admissions or {}) do
            spawnInteraction(point, function() showAdmissions(id) end)
        end
        for _, examiner in ipairs(institution.examiners or {}) do
            local location = examiner
            spawnInteraction(location, function() showExaminer(id, location) end)
        end
        end
    end
end)

local function manageStudentCredentials(institutionId, student)
    local credentials = lib.callback.await('pm-education:server:adminCredentials', false, institutionId, student.id) or {}
    local options = {}
    for _, credential in ipairs(credentials) do
        local selected = credential
        options[#options + 1] = {
            title = selected.credential_label,
            description = ('Credential #%s | %s'):format(selected.id, selected.status),
            onSelect = function()
                local history = lib.callback.await('pm-education:server:credentialHistory', false, institutionId, selected.id) or {}
                local entries = {
                    { title = 'Current status: ' .. selected.status, disabled = true },
                    {
                        title = 'Change credential status',
                        disabled = selected.status == 'revoked' or selected.status == 'expired',
                        onSelect = function()
                            local input = lib.inputDialog('Credential administration', {
                                { type = 'select', label = 'New status', required = true, options =
                                    selected.status == 'active' and {
                                        { value = 'suspended', label = 'Suspend' },
                                        { value = 'revoked', label = 'Revoke' }
                                    } or selected.status == 'suspended' and {
                                        { value = 'active', label = 'Restore suspension' },
                                        { value = 'revoked', label = 'Revoke' }
                                    } or {}
                                },
                                { type = 'textarea', label = 'Reason (10-1000 characters)', required = true, min = 10, max = 1000 }
                            })
                            if not input then return end
                            local confirmation = lib.alertDialog({
                                header = 'Confirm credential status change',
                                content = ('Credential #%s: %s → %s\nReason: %s'):format(selected.id, selected.status, input[1], input[2]),
                                centered = true, cancel = true
                            })
                            if confirmation ~= 'confirm' then return end
                            local ok, message = lib.callback.await('pm-education:server:setCredentialStatus', false,
                                institutionId, selected.id, input[1], input[2])
                            notify(message or (ok and 'Updated' or 'Update failed'), ok and 'success' or 'error')
                        end
                    }
                }
                for _, entry in ipairs(history) do
                    entries[#entries + 1] = {
                        title = ('%s → %s'):format(entry.previous_status, entry.new_status),
                        description = ('%s | %s'):format(entry.actor_citizenid, entry.reason),
                        disabled = true
                    }
                end
                lib.registerContext({ id = 'pm_education_credential_admin_detail', title = selected.credential_label, options = entries })
                lib.showContext('pm_education_credential_admin_detail')
            end
        }
    end
    if #options == 0 then options[1] = { title = 'No credentials or administration access', disabled = true } end
    lib.registerContext({ id = 'pm_education_credential_admin', title = 'Credential Administration', options = options })
    lib.showContext('pm_education_credential_admin')
end

local function openInstructorStudent(institutionId, student)
 local course = lib.callback.await('pm-education:server:courseOutline', false, institutionId, student.course_id, student.id)
 if not course then return notify('Course requirements unavailable.', 'error') end
 local progress = lib.callback.await('pm-education:server:courseProgress', false, institutionId, student.id)
 if not progress then return notify('Unable to load course progress.', 'error') end
 local history = lib.callback.await('pm-education:server:instructorResults', false, institutionId, student.id) or {}
 local latest = {}
 for _, entry in ipairs(history) do
  if not latest[entry.requirement_id] then latest[entry.requirement_id] = entry.result end
 end
 local options = {
  { title = 'Manage credentials', onSelect = function() manageStudentCredentials(institutionId, student) end },
  { title = 'Written examination', description = progress.writtenRequired and (progress.writtenPassed and 'Passed' or 'Not passed') or 'Question bank not configured', disabled = true },
  { title = 'Practical progress', description = ('%d of %d passed'):format(progress.practicalPassed, progress.practicalRequired), disabled = true },
  { title = 'Completion', description = progress.complete and 'All requirements satisfied' or 'Requirements outstanding', disabled = true }
 }
 for _, requirement in ipairs(course.practicalRequirements or {}) do
  local selected = requirement
  options[#options + 1] = {
   title = selected.label,
   description = 'Latest: ' .. (latest[selected.id] or 'Not evaluated'),
   onSelect = function()
    local input = lib.inputDialog('Evaluate: ' .. selected.label, {
     { type = 'select', label = 'Result', required = true, options = {
      { value = 'pass', label = 'Pass' }, { value = 'fail', label = 'Fail' },
      { value = 'incomplete', label = 'Incomplete' }
     }},
     { type = 'textarea', label = 'Instructor notes (optional)', max = 1000 }
    })
    if not input then return end
    local confirm = lib.alertDialog({
     header = 'Record instructor evaluation?',
     content = ('Student: %s\nExercise: %s\nResult: %s'):format(student.citizenid, selected.label, input[1]),
     centered = true, cancel = true
    })
    if confirm == 'confirm' then
     TriggerServerEvent('pm-education:server:recordPractical', institutionId, student.id, selected.id, input[1], input[2] or '')
    end
   end
  }
 end
 if #options == 0 then options[1] = { title = 'No practical requirements configured', disabled = true } end
 lib.registerContext({ id = 'pm_education_instructor_student', title = course.label .. ' / ' .. student.citizenid, options = options })
 lib.showContext('pm_education_instructor_student')
end

local function openInstructorManagement(institutionId)
 local students = lib.callback.await('pm-education:server:instructorStudents', false, institutionId) or {}
 local options = {
  {title='Institution Curriculum Administration',description='Edit examinations, questions, answers and published revisions',onSelect=function()
   OpenPMEducationCatalog(institutionId)
  end}
 }
 for _, student in ipairs(students) do
  local selected = student
  options[#options + 1] = {
   title = selected.citizenid,
   description = ('Enrollment #%s | %s | %s'):format(selected.id, selected.courseLabel, selected.status),
   onSelect = function() openInstructorStudent(institutionId, selected) end
  }
 end
 if #options == 0 then options[1] = { title = 'No active students or access denied', disabled = true } end
 lib.registerContext({ id = 'pm_education_instructor_management', title = 'Instructor Management', options = options })
 lib.showContext('pm_education_instructor_management')
end

CreateThread(function()
 for institutionId, institution in pairs(Config.Institutions) do
  if institution.enabled ~= false then
  local id = institutionId
  for index, desk in ipairs(institution.management or {}) do
   local location = desk
   local zoneName = ('pm_education_management_%s_%d'):format(id, index)
   managementZones[#managementZones + 1] = zoneName
   if location.coords then
   exports['qb-target']:AddBoxZone(zoneName,
    location.coords, location.length or 1.5, location.width or 1.5, {
     name = ('pm_education_management_%s_%d'):format(id, index),
     heading = location.heading or 0.0, minZ = location.coords.z - 1.0, maxZ = location.coords.z + 1.0
    }, { options = {{
     icon = 'fas fa-clipboard-check',
     label = location.label or 'Instructor Management',
     action = function() openInstructorManagement(id) end
    }}, distance = 2.0 })
   else
    print(('[pm-education] Skipping management desk %s/%s without coordinates'):format(id, index))
   end
  end
  end
 end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, zoneName in ipairs(managementZones) do
        exports['qb-target']:RemoveZone(zoneName)
    end
    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            exports['qb-target']:RemoveTargetEntity(ped)
            DeleteEntity(ped)
        end
    end
end)
