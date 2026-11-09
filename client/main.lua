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

local function showStudentProgress(institutionId, record)
    local progress = lib.callback.await('pm-education:server:myCourseProgress', false, institutionId, record.id)
    if not progress then return notify('Unable to load course progress.', 'error') end
    local options = {
        {title = 'Enrollment status', description = progress.enrollmentStatus, disabled = true},
        {title = 'Written examination', description = progress.writtenRequired and
            (progress.writtenPassed and 'Passed' or 'Not passed') or 'Not required', disabled = true},
        {title = 'Practical evaluations', description = ('%d / %d passed'):format(
            progress.practicalPassed, progress.practicalRequired), disabled = true},
        {title = 'Course requirements', description = progress.complete and
            'Satisfied' or 'Outstanding', disabled = true}
    }
    local checklist = lib.callback.await('pm-education:server:myPracticalChecklist', false, institutionId, record.id)
    if not checklist then
        options[#options + 1] = {
            title = 'Practical checklist unavailable',
            description = 'Detailed results could not be loaded. Summary remains available.',
            disabled = true
        }
        checklist = {}
    end
    for index, practical in ipairs(checklist) do
        local status = ({
            pass = 'Passed', fail = 'Not passed', incomplete = 'Incomplete',
            not_evaluated = 'Awaiting instructor evaluation'
        })[practical.result] or 'Unknown'
        options[#options + 1] = {
            title = ('%d. %s'):format(index, practical.label),
            description = status,
            disabled = true
        }
    end
    options[#options + 1] = {
        title = 'Refresh progress',
        description = 'Retrieve the latest written exam and instructor practical results',
        onSelect = function() showStudentProgress(institutionId, record) end
    }
    lib.registerContext({
        id = 'pm_education_student_progress',
        title = record.courseLabel,
        menu = 'pm_education_my_enrollments',
        options = options
    })
    lib.showContext('pm_education_student_progress')
end

local function showEnrollments(institutionId)
    local records = lib.callback.await('pm-education:server:myEnrollments', false, institutionId)
    if not records then return notify('Unable to load enrollments.', 'error') end
    local options = {}
    for _, record in ipairs(records) do
        options[#options + 1] = {
            title = ('#%s %s'):format(record.id, record.courseLabel),
            description = ('Status: %s'):format(record.status),
            onSelect = function() showStudentProgress(institutionId, record) end
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

-- Course information is visible before the student commits to enrollment.
-- Practical requirements are instructor-evaluated, not automatic game objectives.
local function showCoursePreview(institutionId, course)
    local options = {
        {title = 'Enrollment fee', description = ('$%d'):format(course.enrollmentFee or 0), disabled = true},
        {title = 'Written examination', description = course.requireWritten == false and 'Not required' or 'Required', disabled = true},
        {title = 'Exam fee', description = ('$%d'):format(course.examFee or 0), disabled = true},
        {title = 'Passing threshold', description = ('%s%%'):format(tostring(course.passPercent or 'Pending')), disabled = true}
    }
    local practicals = course.practicalRequirements or {}
    if #practicals == 0 then
        options[#options + 1] = {title = 'Practical assessments', description = 'None configured', disabled = true}
    else
        for index, requirement in ipairs(practicals) do
            options[#options + 1] = {
                title = ('Practical %d: %s'):format(index, requirement.label),
                description = 'Evaluated and recorded by an authorized instructor',
                disabled = true
            }
        end
    end
    options[#options + 1] = {
        title = 'Request enrollment',
        description = 'Enrollment is subject to course and examination readiness checks.',
        onSelect = function()
            local method = choosePaymentMethod('Course enrollment', course.enrollmentFee or 0)
            if method then TriggerServerEvent('pm-education:server:enroll', institutionId, course.id, method) end
        end
    }
    lib.registerContext({
        id = 'pm_education_course_preview',
        title = course.label,
        menu = 'pm_education_admissions',
        options = options
    })
    lib.showContext('pm_education_course_preview')
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
            description = ('Enrollment fee: $%d'):format(selected.enrollmentFee or 0),
            onSelect = function() showCoursePreview(institutionId, selected) end
        }
    end
    if #courses == 0 then
        options[#options + 1] = {
            title = 'No courses currently available',
            description = 'The institution has not published or configured offerings yet.',
            disabled = true
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
        if offered[course.id] and course.requireWritten ~= false then
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
    local credentials = lib.callback.await('pm-education:server:adminCredentials', false, institutionId, student.id)
    if not credentials then return notify('Credential administration records unavailable.', 'error') end
    local options = {}
    for _, credential in ipairs(credentials) do
        local selected = credential
        options[#options + 1] = {
            title = selected.credential_label,
            description = ('Credential #%s | %s'):format(selected.id, selected.status),
            onSelect = function()
                local history = lib.callback.await('pm-education:server:credentialHistory', false, institutionId, selected.id)
                if not history then return notify('Credential audit history unavailable.', 'error') end
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
                            if ok then manageStudentCredentials(institutionId, student) end
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
 local history = lib.callback.await('pm-education:server:instructorResults', false, institutionId, student.id)
 if not history then return notify('Practical assessment history unavailable.', 'error') end
 local latest = {}
 for _, entry in ipairs(history) do
  if not latest[entry.requirement_id] then latest[entry.requirement_id] = entry.result end
 end
 local options = {
  { title = 'Written examination', description = progress.writtenRequired and (progress.writtenPassed and 'Passed' or 'Not passed') or 'Not required', disabled = true },
  { title = 'Practical progress', description = ('%d of %d passed'):format(progress.practicalPassed, progress.practicalRequired), disabled = true },
  { title = 'Completion', description = progress.complete and 'All requirements satisfied' or 'Requirements outstanding', disabled = true }
 }
 local institution = Config.Institutions[institutionId]
 local player = QBCore.Functions.GetPlayerData()
 local job = player and player.job
 local rule = job and institution and institution.credentialAdminJobs and institution.credentialAdminJobs[job.name]
 if rule and (tonumber(job.grade and job.grade.level) or -1) >= (rule.minGrade or 0) then
  table.insert(options, 1, {title = 'Manage credentials', onSelect = function()
   manageStudentCredentials(institutionId, student)
  end})
 end
 for _, requirement in ipairs(course.practicalRequirements or {}) do
  local selected = requirement
  options[#options + 1] = {
   title = selected.label,
   description = student.status == 'completed' and
    ('Final result: ' .. (latest[selected.id] or 'Not evaluated')) or
    ('Latest: ' .. (latest[selected.id] or 'Not evaluated')),
   disabled = student.status ~= 'enrolled' and student.status ~= 'in_progress',
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
 options[#options + 1] = {
  title = 'Assessment history',
  description = 'Review recorded results and instructor notes',
  onSelect = function()
   local entries = {}
   for _, result in ipairs(history) do
    entries[#entries + 1] = {
     title = ('%s: %s'):format(result.requirement_id, result.result),
     description = ('Examiner: %s | %s%s'):format(
      result.examiner_citizenid or 'Unknown', tostring(result.recorded_at or ''),
      result.notes and result.notes ~= '' and (' | ' .. result.notes) or ''),
     disabled = true
    }
   end
   if #entries == 0 then entries[1] = { title = 'No assessments recorded', disabled = true } end
   lib.registerContext({
    id = 'pm_education_instructor_history',
    title = 'Practical Assessment History',
    menu = 'pm_education_instructor_student',
    options = entries
   })
   lib.showContext('pm_education_instructor_history')
  end
 }
 options[#options + 1] = {
  title = 'Refresh student progress',
  onSelect = function() openInstructorStudent(institutionId, student) end
 }
 lib.registerContext({ id = 'pm_education_instructor_student', title = course.label .. ' / ' .. student.citizenid, options = options })
 lib.showContext('pm_education_instructor_student')
end

local function openCredentialAdministration(institutionId)
 local students = lib.callback.await('pm-education:server:adminStudents', false, institutionId)
 if not students then return notify('Credential administration unavailable or access denied.', 'error') end
 local options = {}
 for _, student in ipairs(students) do
  local selected = student
  options[#options + 1] = {
   title = selected.citizenid,
   description = ('Enrollment #%s | %s | %s'):format(selected.id, selected.courseLabel, selected.status),
   onSelect = function() manageStudentCredentials(institutionId, selected) end
  }
 end
 if #options == 0 then options[1] = {title = 'No student enrollments', disabled = true} end
 options[#options + 1] = {
  title = 'Refresh student roster',
  onSelect = function() openCredentialAdministration(institutionId) end
 }
 lib.registerContext({id = 'pm_education_credential_admin_students', title = 'Credential Administration', options = options})
 lib.showContext('pm_education_credential_admin_students')
end

local function openInstructorManagement(institutionId)
 local institution = Config.Institutions[institutionId]
 local player = QBCore.Functions.GetPlayerData()
 local job = player and player.job
 local adminRule = job and institution and institution.credentialAdminJobs and institution.credentialAdminJobs[job.name]
 local instructorRule = job and institution and institution.staffJobs and institution.staffJobs[job.name]
 local isAdmin = adminRule and (tonumber(job.grade and job.grade.level) or -1) >= (adminRule.minGrade or 0)
 local isInstructor = instructorRule and (tonumber(job.grade and job.grade.level) or -1) >= (instructorRule.minGrade or 0)
 if not isInstructor then
  if isAdmin then
   lib.registerContext({
    id='pm_education_admin_management',
    title='Institution Administration',
    options={
     {title='Curriculum Administration',onSelect=function() OpenPMEducationCatalog(institutionId) end},
     {title='Credential Administration',onSelect=function() openCredentialAdministration(institutionId) end}
    }
   })
   return lib.showContext('pm_education_admin_management')
  end
  return notify('Institution management access denied.', 'error')
 end
 local students = lib.callback.await('pm-education:server:instructorStudents', false, institutionId)
 if not students then return notify('Instructor records unavailable or access denied.', 'error') end
 local options = {}
 local rule = adminRule
 if rule and (tonumber(job.grade and job.grade.level) or -1) >= (rule.minGrade or 0) then
  options[#options + 1] = {
   title='Institution Curriculum Administration',
   description='Edit examinations, questions, answers and published revisions',
   onSelect=function() OpenPMEducationCatalog(institutionId) end
  }
  options[#options + 1] = {
   title='Credential Administration',
   description='Review and manage awarded student credentials',
   onSelect=function() openCredentialAdministration(institutionId) end
  }
 end
 for _, student in ipairs(students) do
  local selected = student
  options[#options + 1] = {
   title = selected.citizenid,
   description = ('Enrollment #%s | %s | %s'):format(selected.id, selected.courseLabel, selected.status),
   onSelect = function() openInstructorStudent(institutionId, selected) end
  }
 end
 if #students == 0 then options[#options + 1] = { title = 'No active students', disabled = true } end
 options[#options + 1] = {
  title = 'Refresh instructor roster',
  onSelect = function() openInstructorManagement(institutionId) end
 }
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
   managementZones[#managementZones + 1] = zoneName
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
