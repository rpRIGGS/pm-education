Config = {}
Config.Debug = false
Config.Institutions = {
    sandy_university = {
        label = 'Sandy Shores University',
        society = 'university',
        admissions = {
            { model = 'a_m_m_business_01', coords = vector4(-1667.9, 190.13, 60.86, 19.6), label = 'University Admissions' }
        },
        examiners = {
            { model = 'a_f_m_bevhills_01', coords = vector4(-1573.95, 232.28, 57.85, 31.81), label = 'Professor', courses = {'transport_management', 'flight_aerodynamics'} }
        },
        courses = {
            transport_management = {
                label = 'Transport Management', enrollmentFee = 100, examFee = 50,
                passPercent = 100, requireWritten = true
            },
            flight_aerodynamics = {
                label = 'Flight Aerodynamics', enrollmentFee = 150, examFee = 75,
                passPercent = 100, requireWritten = true
            }
        }
    }
}
-- Course data above is inherited demonstration content, not the approved final catalog.

-- POST is the first instructor-management pilot. Coordinates remain unset until the academy location is confirmed.
Config.Institutions.post = {
 label = 'Peace Officer Standards and Training (POST)',
 society = 'post',
 staffJobs = {}, -- REQUIRED: set actual instructor job and minimum grade, e.g. { YOUR_JOB = { minGrade = 2 } }
 -- Keep empty until staff permissions are confirmed; no accidental instructor access.
 admissions = {},
 examiners = {},
 management = {}, -- REQUIRED: add real academy desk vector3; see development-reference/post-setup.md
 courses = {
  post_basic = {
   label = 'POST Basic Academy',
   enrollmentFee = 0,
   examFee = 0,
   passPercent = 80, -- PROVISIONAL passing threshold
   requireWritten = true, -- Fail closed until POST written questions are configured
   credentialId = 'post_basic_accreditation',
   credentialLabel = 'POST Basic Academy Accreditation',
   -- Written questions and answer keys: server/questions.lua (server only).
   practicalRequirements = {
    { id = 'code5', label = 'Code 5 Traffic Stop' },
    { id = 'pursuit', label = 'Vehicle Pursuit' },
    { id = 'evasive', label = 'Evasive Driving' }
   }
  }
 }
}
