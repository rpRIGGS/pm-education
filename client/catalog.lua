-- Institution curriculum editor (ox_lib). All writes are authorized again server-side.
local function call(name, ...)
    return lib.callback.await('pm-education:server:' .. name, false, ...)
end

local openCatalog
local openRevision
local editExam

local function editQuestion(question)
    local input = lib.inputDialog('Edit written question', {
        {type='textarea', label='Question', required=true, default=question.question or '', max=2000},
        {type='textarea', label='Answer A', required=true, default=question.answers and question.answers[1] or '', max=500},
        {type='textarea', label='Answer B', required=true, default=question.answers and question.answers[2] or '', max=500},
        {type='textarea', label='Answer C (optional)', default=question.answers and question.answers[3] or '', max=500},
        {type='textarea', label='Answer D (optional)', default=question.answers and question.answers[4] or '', max=500},
        {type='number', label='Correct answer number (1-4)', required=true, default=question.correct or 1, min=1, max=4}
    })
    if not input then return nil end
    local answers = {input[2],input[3]}
    if input[4] and input[4] ~= '' then answers[#answers+1] = input[4] end
    if input[5] and input[5] ~= '' then
        if not input[4] or input[4] == '' then
            lib.notify({description='Fill answer C before answer D.',type='error'})
            return nil
        end
        answers[#answers+1] = input[5]
    end
    if input[6] > #answers then
        lib.notify({description='Correct answer must refer to a filled answer.',type='error'})
        return nil
    end
    return {question=input[1],answers=answers,correct=input[6]}
end

editExam=function(institutionId, record)
    local payload = record.payload
    local options = {
        {title='Edit exam title',onSelect=function()
            local input=lib.inputDialog('Exam title',{{type='input',label='Title',required=true,default=payload.label,max=160}})
            if input then payload.label=input[1] editExam(institutionId,record) end
        end},
        {title='Add question',onSelect=function()
            local question=editQuestion({answers={}})
            if question then payload.questions[#payload.questions+1]=question editExam(institutionId,record) end
        end}
    }
    for i,q in ipairs(payload.questions or {}) do
        local index=i
        options[#options+1]={title=('Question %d'):format(index),description=q.question,onSelect=function()
            local choice=lib.alertDialog({header='Edit question '..index,content=q.question,centered=true,cancel=true,labels={confirm='Edit',cancel='Back'}})
            if choice~='confirm' then return end
            local updated=editQuestion(q)
            if updated then payload.questions[index]=updated editExam(institutionId,record) end
        end}
    end
    options[#options+1]={title='Save draft',onSelect=function()
        local ok=call('catalogSaveDraft',institutionId,record.id,payload)
        lib.notify({description=ok and 'Draft saved' or 'Save failed',type=ok and 'success' or 'error'})
        if ok then openRevision(institutionId,record.id) end
    end}
    lib.registerContext({id='pm_education_catalog_exam',title=payload.label,options=options})
    lib.showContext('pm_education_catalog_exam')
end

openRevision=function(institutionId,catalogId)
    local record=call('catalogRead',institutionId,catalogId)
    if not record then return lib.notify({description='Unable to read catalog revision',type='error'}) end
    local options={{title=('Version %d / %s'):format(record.revision,record.status),disabled=true}}
    if record.status=='draft' then
        if record.content_type=='exam' then
            options[#options+1]={title='Edit questions and answers',onSelect=function() editExam(institutionId,record) end}
        else
            options[#options+1]={title='Edit title and passing score',onSelect=function()
                local fields={{type='input',label='Title',required=true,default=record.payload.label,max=160}}
                if record.content_type=='course' then fields[#fields+1]={type='number',label='Pass percentage',required=true,min=0,max=100,default=record.payload.passPercent} end
                local input=lib.inputDialog('Edit draft',fields)
                if not input then return end
                record.payload.label=input[1]
                if record.content_type=='course' then record.payload.passPercent=input[2] end
                local ok=call('catalogSaveDraft',institutionId,record.id,record.payload)
                lib.notify({description=ok and 'Draft saved' or 'Save failed',type=ok and 'success' or 'error'})
                if ok then openRevision(institutionId,catalogId) end
            end}
        end
        options[#options+1]={title='Publish revision',onSelect=function()
            if lib.alertDialog({header='Publish revision?',content='Published content cannot be edited in place. Existing published versions must first be retired.',cancel=true})~='confirm' then return end
            local ok=call('catalogPublish',institutionId,catalogId)
            lib.notify({description=ok and 'Revision published' or 'Publication failed',type=ok and 'success' or 'error'})
            openCatalog(institutionId)
        end}
    elseif record.status=='published' then
        options[#options+1]={title='Create replacement draft',onSelect=function()
            local id=call('catalogCreateDraft',institutionId,record.content_type,record.content_key,record.payload)
            if id then openRevision(institutionId,id) else lib.notify({description='Could not create draft',type='error'}) end
        end}
        options[#options+1]={title='Retire revision',onSelect=function()
            if lib.alertDialog({header='Retire published revision?',content='Existing qualifications are retained. New sessions will not use this revision.',cancel=true})~='confirm' then return end
            local ok=call('catalogRetire',institutionId,catalogId)
            lib.notify({description=ok and 'Revision retired' or 'Retirement failed',type=ok and 'success' or 'error'})
            openCatalog(institutionId)
        end}
    end
    options[#options+1]={title='Audit history',onSelect=function()
        local history=call('catalogHistory',institutionId,catalogId) or {}
        local entries={}
        for _,entry in ipairs(history) do entries[#entries+1]={title=entry.action,description=(entry.actor_citizenid or '')..' | '..(entry.notes or ''),disabled=true} end
        if #entries==0 then entries[1]={title='No history available',disabled=true} end
        lib.registerContext({id='pm_education_catalog_audit',title='Administrative history',options=entries})
        lib.showContext('pm_education_catalog_audit')
    end}
    lib.registerContext({id='pm_education_catalog_revision',title=record.content_key,options=options})
    lib.showContext('pm_education_catalog_revision')
end

openCatalog=function(institutionId)
    local records=call('catalogList',institutionId) or {}
    local options={{title='Create new examination',onSelect=function()
        local input=lib.inputDialog('New examination',{{type='input',label='Internal ID (letters/numbers/underscores)',required=true,max=80},{type='input',label='Examination title',required=true,max=160}})
        if not input then return end
        local id=call('catalogCreateDraft',institutionId,'exam',input[1],{label=input[2],questions={}})
        if id then openRevision(institutionId,id) else lib.notify({description='Could not create examination',type='error'}) end
    end}}
    for _,record in ipairs(records) do
        local id=record.id
        options[#options+1]={title=('%s / %s v%d'):format(record.content_type,record.content_key,record.revision),description=record.status,onSelect=function() openRevision(institutionId,id) end}
    end
    lib.registerContext({id='pm_education_catalog',title='Institution Curriculum Administration',options=options})
    lib.showContext('pm_education_catalog')
end

function OpenPMEducationCatalog(institutionId)
    openCatalog(institutionId)
end
