-- SERVER ONLY. Never load this file as shared_scripts or client_scripts.
EducationQuestions = {
 sandy_university = {
  transport_management = {
   { question = 'What is 2 + 2?', answers = {'3','4','5'}, correct = 2 }
  },
  flight_aerodynamics = {
   { question = 'What is the speed of light?', answers = {'300,000 km/s','150,000 km/s','450,000 km/s'}, correct = 1 }
  }
 },
 post = {
  post_basic = {
   -- REQUIRED: insert approved POST academy questions here before written exams can be taken.
   -- { question = 'Approved question', answers = {'A','B','C'}, correct = 2 },
  }
 }
}
