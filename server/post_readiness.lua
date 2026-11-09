-- POST pilot deployment readiness, console-only and read-only.
-- No exam keys, job names, or academy coordinates are fabricated by this check.
local function configuredPoint(point)
    if type(point) ~= 'table' or not point.coords then return false end
    local coords = point.coords
    return type(coords.x) == 'number' and type(coords.y) == 'number' and type(coords.z) == 'number'
end

local function examinerOffers(points, courseId)
    for _, point in ipairs(points or {}) do
        if configuredPoint(point) then
            for _, offered in ipairs(point.courses or {}) do
                if offered == courseId then return true end
            end
        end
    end
    return false
end

local function countPoints(points)
    local count = 0
    for _, point in ipairs(points or {}) do
        if configuredPoint(point) then count = count + 1 end
    end
    return count
end

local function countRules(rules)
    local count = 0
    for _, rule in pairs(rules or {}) do
        if type(rule) == 'table' and type(rule.minGrade) == 'number' then
            count = count + 1
        end
    end
    return count
end

local function approvedWrittenBank()
    local bank = EducationQuestions and EducationQuestions.post and EducationQuestions.post.post_basic
    if type(bank) ~= 'table' or #bank == 0 then return false end
    for _, question in ipairs(bank) do
        if type(question) ~= 'table' or type(question.question) ~= 'string' or question.question == '' or
            type(question.answers) ~= 'table' or #question.answers < 2 or
            type(question.correct) ~= 'number' or question.correct % 1 ~= 0 or
            question.correct < 1 or question.correct > #question.answers then return false end
        for _, answer in ipairs(question.answers) do
            if type(answer) ~= 'string' or answer == '' then return false end
        end
    end
    return true
end

RegisterCommand('pm_education_post_check', function(source)
    if source ~= 0 then return end
    local institution = Config.Institutions and Config.Institutions.post
    if not institution then
        print('[pm-education][POST] BLOCKED: POST institution is not configured')
        return
    end
    local checks = {
        { 'institution enabled', institution.enabled ~= false },
        { 'admissions desk', countPoints(institution.admissions) > 0 },
        { 'written examination desk offering post_basic', examinerOffers(institution.examiners, 'post_basic') },
        { 'instructor management desk', countPoints(institution.management) > 0 },
        { 'instructor job rules', countRules(institution.staffJobs) > 0 },
        { 'credential administrator job rules', countRules(institution.credentialAdminJobs) > 0 },
        { 'POST basic offering', institution.courses and institution.courses.post_basic ~= nil },
        { 'POST basic credential configured', institution.courses and institution.courses.post_basic and
            type(institution.courses.post_basic.credentialId) == 'string' and
            institution.courses.post_basic.credentialId ~= '' },
        { 'POST written assessment required', institution.courses and institution.courses.post_basic and
            institution.courses.post_basic.requireWritten == true },
        { 'POST legacy written question bank populated (published exam can substitute)', approvedWrittenBank() },
        { 'POST practical requirements configured', institution.courses and institution.courses.post_basic and
            type(institution.courses.post_basic.practicalRequirements) == 'table' and
            #institution.courses.post_basic.practicalRequirements > 0 },
    }
    local passed = 0
    for _, check in ipairs(checks) do
        if check[2] then passed = passed + 1 end
        print(('[pm-education][POST] %s: %s'):format(check[1], check[2] and 'CONFIGURED' or 'PENDING'))
    end
    print(('[pm-education][POST] Configuration: %d/%d checks; published catalog questions may replace the legacy bank. SQL, publication, approved policy and FiveM gameplay still require separate validation.'):format(passed, #checks))
end, true)
