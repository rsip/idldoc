; docformat = 'rst'

;+
; This class represents a information about .pro file.
; 
; :Properties:
;    basename : get, set, type=string
;       basename of filename
;    has_main_level : get, set, type=boolean
;       true if the file has a main-level program at the end
;    is_batch : get, set, type=boolean
;       true if the file is a batch file
;    comments : get, set, type=object
;       text tree hierarchy for file level comments
;    n_routines : get, type=integer
;       number of routines in the file
;    routines : get, type=object
;       list object containing routine objects in file
;-


;+
; Get properties.
;-
pro doctreeprofile::getProperty, basename=basename, $
                                 has_main_level=hasMainLevel, $
                                 is_batch=isBatch, $
                                 has_class=hasClass, classes=classes, $
                                 comments=comments, $
                                 n_routines=nRoutines, routines=routines, $
                                 n_lines=nLines, directory=directory                                 
  compile_opt strictarr
  
  if (arg_present(basename)) then basename = self.basename
  if (arg_present(directory)) then directory = self.directory
  if (arg_present(hasMainLevel)) then hasMainLevel = self.hasMainLevel
  if (arg_present(isBatch)) then isBatch = self.isBatch 
  if (arg_present(hasClass)) then hasClass = self.classes->count() gt 0   
  if (arg_present(classes)) then classes = self.classes  
  if (arg_present(comments)) then comments = self.comments
  if (arg_present(nRoutines)) then nRoutines = self.routines->count()
  if (arg_present(routines)) then routines = self.routines
  if (arg_present(nLines)) then nLines = self.nLines  
end


;+
; Set properties.
;-
pro doctreeprofile::setProperty, code=code, has_main_level=hasMainLevel, $
                                 is_hidden=isHidden, is_private=isPrivate, $
                                 is_batch=isBatch, $
                                 is_abstract=isAbstract, $
                                 is_obsolete=isObsolete, $
                                 comments=comments, $
                                 modification_time=mTime, n_lines=nLines, $ 
                                 format=format, markup=markup, $
                                 examples=examples, $
                                 author=author, copyright=copyright, $
                                 history=history, version=version                                 
  compile_opt strictarr
  
  if (n_elements(code) gt 0) then begin
    ; translate strarr to parse tree, also mark comments
    
    proFileParser = self.system->getParser('profile')
    self.code = obj_new('MGtmTag')
      
    for l = 0L, n_elements(code) - 1L do begin
      line = code[l]
      lessPos = strpos(line, '<')
      while (lessPos ne -1) do begin
        case lessPos of
          0: line = '&lt;' + strmid(line, 1)
          strlen(line) - 1L: line = strmid(line, 0, strlen(line) - 1L) + '&lt;'
          else: line = strmid(line, 0L, lessPos) + '&lt;' + strmid(line, lessPos + 1L)
        endcase
        lessPos = strpos(line, '<')
      endwhile
      
      regularLines = proFileParser->_stripComments(line, comments=commentsLines)
            
      self.code->addChild, obj_new('MGtmText', text=regularLines)
      
      if (strlen(commentsLines) gt 0) then begin
        commentsNode = obj_new('MGtmTag', type='comments')
        self.code->addChild, commentsNode
        commentsNode->addChild, obj_new('MGtmText', text=commentsLines)
      endif
      
      self.code->addChild, obj_new('MGtmTag', type='newline')
    endfor  
  endif
  
  if (n_elements(isHidden) gt 0) then self.isHidden = isHidden
  if (n_elements(isPrivate) gt 0) then self.isPrivate = isPrivate
  
  if (n_elements(hasMainLevel) gt 0) then self.hasMainLevel = hasMainLevel
  if (n_elements(isAbstract) gt 0) then self.isAbstract = isAbstract
  if (n_elements(isBatch) gt 0) then self.isBatch = isBatch
  if (n_elements(isObsolete) gt 0) then self.isObsolete = isObsolete
  if (n_elements(comments) gt 0) then begin
    if (obj_valid(self.comments)) then begin
      parent = obj_new('MGtmTag')
      parent->addChild, self.comments
      parent->addChild, comments
      self.comments = parent
    endif else self.comments = comments
  endif
  if (n_elements(format) gt 0) then self.format = format
  if (n_elements(markup) gt 0) then self.markup = markup
  if (n_elements(nLines) gt 0) then self.nLines = nLines
  if (n_elements(mTime) gt 0) then self.modificationTime = mTime
  
  if (n_elements(examples) gt 0) then self.examples = examples
  
  ; "author info" attributes
  if (n_elements(author) gt 0) then begin
    self.hasAuthorInfo = 1B
    self.author = author
  endif

  if (n_elements(copyright) gt 0) then begin
    self.hasAuthorInfo = 1B
    self.copyright = copyright
  endif
  
  if (n_elements(history) gt 0) then begin
    self.hasAuthorInfo = 1B
    self.history = history
  endif  

  if (n_elements(version) gt 0) then begin
    self.hasAuthorInfo = 1B
    self.version = version
  endif    
end


;+
; Get a class of the given name if defined in the file or system already, create 
; it if not.
;
; :Returns: class tree object
;
; :Params:
;    classname : in, required, type=string
;       classname of the class
;-
function doctreeprofile::getClass, classname
  compile_opt strictarr
  
  ; first, check the file: if it's there, everything is set up already
  for c = 0L, self.classes->count() - 1L do begin
    class = self.classes->get(position=c)
    class->getProperty, classname=checkClassname
    if (strlowcase(classname) eq strlowcase(checkClassname)) then return, class
  endfor

  ; next, check the system for the class, it may have been referenced by 
  ; another class in another file
  self.system->getProperty, classes=classes
  class = classes->get(strlowcase(classname), found=found)
  if (found) then begin
    class->setProperty, pro_file=self, classname=classname
    self.classes->add, class
    return, class
  endif
    
  ; create the class if there is no record of it
  class = obj_new('DOCtreeClass', classname, pro_file=self, system=self.system)
  self.classes->add, class
  return, class
end


;+
; Get variables for use with templates.
;
; :Returns: variable
; :Params:
;    name : in, required, type=string
;       name of variable
;
; :Keywords:
;    found : out, optional, type=boolean
;       set to a named variable, returns if variable name was found
;-
function doctreeprofile::getVariable, name, found=found
  compile_opt strictarr
  
  found = 1B
  case strlowcase(name) of
    'basename': return, self.basename
    'local_url': return, file_basename(self.basename, '.pro') + '.html'
    'source_url': return, file_basename(self.basename, '.pro') + '-code.html'
    'direct_source_url': return, file_basename(self.basename)
    'code': return, self.system->processComments(self.code)
    
    'is_batch': return, self.isBatch
    'has_main_level': return, self.hasMainLevel
    'has_class': return, self.classes->count() gt 0
    'classes': return, self.classes->get(/all)
    'is_private': return, self.isPrivate
    'is_abstract': return, self.isAbstract
    'is_obsolete': return, self.isObsolete
    
    'modification_time': return, self.modificationTime
    'n_lines': return, mg_int_format(self.nLines)
    'format': return, self.format
    'markup': return, self.markup

    'has_examples': return, obj_valid(self.examples)
    'examples': return, self.system->processComments(self.examples) 
        
    'has_comments': return, obj_valid(self.comments)
    'comments': return, self.system->processComments(self.comments)       
    'comments_first_line': begin
        ; if no file comments, but there is only one routine then return the
        ; first line of the routine's comments
        if (~obj_valid(self.comments)) then begin
          if (self.routines->count() eq 1) then begin
            routine = self.routines->get(position=0L)
            return, routine->getVariable('comments_first_line', found=found)
          endif else return, ''
        endif
        
        self.firstline = mg_tm_firstline(self.comments)
        return, self.system->processComments(self.firstline)        
      end
          
    'n_routines' : return, self.routines->count()
    'routines' : return, self.routines->get(/all)
    'n_visible_routines': begin
        nVisible = 0L
        for r = 0L, self.routines->count() - 1L do begin
          routine = self.routines->get(position=r)          
          nVisible += routine->isVisible()          
        endfor
        return, nVisible
      end
    'visible_routines': begin        
        routines = self.routines->get(/all, count=nRoutines)
        if (nRoutines eq 0L) then return, -1L
        
        isVisibleRoutines = bytarr(nRoutines)
        for r = 0L, nRoutines - 1L do begin
          isVisibleRoutines[r] = routines[r]->isVisible()
        endfor
        
        ind = where(isVisibleRoutines eq 1B, nVisibleRoutines)
        if (nVisibleRoutines eq 0L) then return, -1L
        
        return, routines[ind]
      end
    
    'has_author_info': return, self.hasAuthorInfo
    
    'has_author': return, obj_valid(self.author)
    'author': return, self.system->processComments(self.author)

    'has_copyright': return, obj_valid(self.copyright)
    'copyright': return, self.system->processComments(self.copyright)
    
    'has_history': return, obj_valid(self.history)
    'history': return, self.system->processComments(self.history)

    'has_version': return, obj_valid(self.version)
    'version': return, self.system->processComments(self.version)

    'index_name': return, self.basename
    'index_type': begin
        return, '.pro file in ' + self.directory->getVariable('location') + ' directory'
      end      
    'index_url': begin
        self.directory->getProperty, url=dirUrl
        return, dirUrl + file_basename(self.basename, '.pro') + '.html'
      end
            
    else: begin
        ; search in the system object if the variable is not found here
        var = self.directory->getVariable(name, found=found)
        if (found) then return, var
        
        found = 0B
        return, -1L
      end
  endcase
end


;+
; Uses file hidden/private attributes and system wide user/developer level to
; determine if this file should be visible.
;
; :Returns: boolean
;-
function doctreeprofile::isVisible
  compile_opt strictarr
  
  if (self.isHidden) then return, 0B
  
  ; if creating user-level docs and private then not visible
  self.system->getProperty, user=user
  if (self.isPrivate && user) then return, 0B
  
  return, 1B
end


;+
; Add a routine to the list of routines in the file.
; 
; :Params:
;    routine : in, required, type=object
;       routine object
;-
pro doctreeprofile::addRoutine, routine
  compile_opt strictarr
  
  self.routines->add, routine
end


pro doctreeprofile::_propertyCheck, methodname, propertyname, comments, class
  compile_opt strictarr
  
  class->getProperty, classname=classname
  
  for r = 0L, self.routines->count() - 1L do begin
    routine = self.routines->get(position=r)    
    routine->getProperty, name=name
    
    if (strlowcase(name) eq strlowcase(classname + '::' + methodname)) then begin
      routine->getProperty, keywords=keywords
      for k = 0L, keywords->count() - 1L do begin
        keyword = keywords->get(position=k)
        keyword->getProperty, name=keywordname, comments=keywordComments
        
        if (strlowcase(propertyname) eq strlowcase(keywordname)) then begin
          if (~obj_valid(keywordComments)) then begin
            keyword->setProperty, comments=comments
          endif
        endif
      endfor
      break
    endif
  endfor
end


;+
; Do any analysis necessary on information gathered during the "parseTree"
; phase.
;-
pro doctreeprofile::process
  compile_opt strictarr
  
  if (self.classes->count() gt 0) then begin
    ; if has properties, then place properties' comment into keyword comments
    ; for getProperty, setProperty, and init if there are no comments there
    ; already
    
    for c = 0L, self.classes->count() - 1L do begin      
      class = self.classes->get(position=c)
      class->getProperty, properties=properties
      propertyNames = properties->keys(count=nProperties)
      
      for p = 0L, nProperties - 1L do begin
        property = properties->get(propertyNames[p])
        property->getProperty, is_get=isGet, is_set=isSet, is_init=isInit, $
                               comments=comments
        
        if (isGet) then begin
          self->_propertyCheck, 'getProperty', propertyNames[p], comments, class
        endif
        
        if (isSet) then begin
          self->_propertyCheck, 'setProperty', propertyNames[p], comments, class
        endif
        
        if (isInit) then begin
          self->_propertyCheck, 'init', propertyNames[p], comments, class
        endif
      endfor
    endfor
  endif
  
  for r = 0L, self.routines->count() - 1L do begin
    routine = self.routines->get(position=r)
    routine->markArguments
    routine->checkDocumentation
  endfor
end


pro doctreeprofile::generateOutput, outputRoot, directory
  compile_opt strictarr
  
  ; don't produce output if not visible
  if (~self->isVisible()) then return
  
  self.system->print, '  Generating output for ' + self.basename + '...'

  proFileTemplate = self.system->getTemplate('profile')
  
  outputDir = outputRoot + directory
  outputFilename = outputDir + file_basename(self.basename, '.pro') + '.html'
  
  proFileTemplate->reset
  proFileTemplate->process, self, outputFilename  
  
  self.system->getProperty, nosource=nosource
  if (nosource) then return
  
  ; chromocoded version of the source code
  sourceTemplate = self.system->getTemplate('source')
  
  outputFilename = outputDir + file_basename(self.basename, '.pro') + '-code.html'
  
  sourceTemplate->reset
  sourceTemplate->process, self, outputFilename    
  
  ; direct version of the source code
  file_copy, self.fullpath, outputDir + file_basename(self.basename), $
             /allow_same, /overwrite
end


;+
; Free resources.
;-
pro doctreeprofile::cleanup
  compile_opt strictarr
  
  obj_destroy, self.firstline
  obj_destroy, self.routines
  obj_destroy, self.classes
  obj_destroy, [self.author, self.copyright, self.history]
  obj_destroy, self.code
end


;+
; Create file tree object.
;
; :Returns: 1 for success, 0 for failure
;
; :Keywords:
;    basename : in, required, type=string
;       basename of the .pro file
;    directory : in, required, type=object
;       directory tree object
;    system : in, required, type=object
;       system object
;    fullpath : in, required, type=string
;       full filename of the .pro file
;-
function doctreeprofile::init, basename=basename, directory=directory, $
                               system=system, fullpath=fullpath
  compile_opt strictarr
  
  self.basename = basename
  self.directory = directory
  self.system = system
  self.fullpath = fullpath
  
  self.classes = obj_new('MGcoArrayList', type=11, block_size=3)
  
  self.routines = obj_new('MGcoArrayList', type=11)
  
  self.system->createIndexEntry, self.basename, self
  self.system->print, '  Parsing ' + self.basename + '...'
  
  return, 1
end


;+
; Define instance variables.
;
; :Fields:
;    directory
;       directory tree object
;    basename
;       basename of file
;    hasMainLevel
;       true if the file has a main level program at the end
;    isBatch
;       true if the file is a batch file
;    routines 
;       list of routine objects
;-
pro doctreeprofile__define
  compile_opt strictarr
  
  define = { DOCtreeProFile, $
             system: obj_new(), $
             directory: obj_new(), $
             
             fullpath: '', $
             basename: '', $
             code: obj_new(), $
             
             hasMainLevel: 0B, $
             isBatch: 0B, $
             
             classes: obj_new(), $
             
             modificationTime: '', $
             nLines: 0L, $
             format: '', $
             markup: '', $
             
             comments: obj_new(), $
             firstline: obj_new(), $
             
             routines: obj_new(), $
             
             isAbstract: 0B, $
             isHidden: 0B, $
             isObsolete: 0B, $
             isPrivate: 0B, $
             
             examples: obj_new(), $
             
             hasAuthorInfo: 0B, $
             author: obj_new(), $
             copyright: obj_new(), $
             history: obj_new(), $
             version: obj_new() $
           }
end