-- Provisional developer seed for SAFR; NOT an approved certification standard.
-- All practical names, exam threshold and credential titles require institutional review.
-- Imported as drafts only; no exam answer keys or automatic job/rank/license awards.
return {
 institutionId = 'safr',
 courses = {
  safr_foundations = {
   label = 'SAFR Fire & Rescue Foundations',
   credentialId = 'safr_foundations_certificate',
   credentialLabel = 'SAFR Fire & Rescue Foundations Certificate',
   requireWritten = true,
   passPercent = 80, -- provisional, not an approved policy
   practicalRequirements = {
    { id = 'incident_scene', label = 'Incident Scene Safety Assessment' },
    { id = 'fire_response', label = 'Fire Response Practical' },
    { id = 'rescue_response', label = 'Rescue Response Practical' }
   }
  }
 },
 exams = {
  safr_foundations = {
   label = 'SAFR Fire & Rescue Foundations Written Examination',
   questions = {} -- Populate only with approved institution questions.
  }
 },
 credentials = {}
}
