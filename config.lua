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
                passPercent = 100,
                questions = {{ question = 'What is 2 + 2?', answers = {'3','4','5'}, correct = 2 }}
            },
            flight_aerodynamics = {
                label = 'Flight Aerodynamics', enrollmentFee = 150, examFee = 75,
                passPercent = 100,
                questions = {{ question = 'What is the speed of light?', answers = {'300,000 km/s','150,000 km/s','450,000 km/s'}, correct = 1 }}
            }
        }
    }
}
-- Course data above is inherited demonstration content, not the approved final catalog.
