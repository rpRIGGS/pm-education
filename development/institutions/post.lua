-- Development-only templates. Not automatically published or imported.
-- IDs are stable across revisions. Only approved content should be populated.
return {
 institutionId = 'post',
 courses = {
  post_basic = {
   label = 'POST Basic Academy',
   credentialId = 'post_basic_accreditation',
   credentialLabel = 'POST Basic Academy Accreditation',
   requireWritten = true,
   passPercent = 80, -- provisional, pending POST approval
   practicalRequirements = {
    { id = 'code5', label = 'Code 5 Traffic Stop' },
    { id = 'pursuit', label = 'Vehicle Pursuit' },
    { id = 'evasive', label = 'Evasive Driving' }
   }
  }
 },
 exams = {
  post_basic = {
   label = 'POST Basic Written Examination',
   questions = {} -- Add approved questions; do not invent policy content.
  }
 }
}
