-- Provisional developer seed for SAMS; NOT an approved certification standard.
-- All practical names, exam threshold and credential titles require institutional review.
-- Imported as drafts only; no exam answer keys or automatic job/rank/license awards.
return {
 institutionId = 'sams',
 courses = {
  sams_foundations = {
   label = 'SAMS Medical & EMS Foundations',
   credentialId = 'sams_foundations_certificate',
   credentialLabel = 'SAMS Medical & EMS Foundations Certificate',
   requireWritten = true,
   passPercent = 80, -- provisional, not an approved policy
   practicalRequirements = {
    { id = 'patient_assessment', label = 'Patient Assessment Practical' },
    { id = 'patient_care', label = 'Patient Care Practical' },
    { id = 'handoff', label = 'Patient Handoff Practical' }
   }
  }
 },
 exams = {
  sams_foundations = {
   label = 'SAMS Medical & EMS Foundations Written Examination',
   questions = {} -- Populate only with approved institution questions.
  }
 },
 credentials = {}
}
