; docformat = 'rst'

;+
; Parse rst style comments into a parse tree.
; 
; The markup parser recognizes:
;   1. paragraphs separated by a blank line
;   
;   2. (not implemented) lists (numbered, bulleted, and definition)
;   
;   3. (not implemented) *emphasis* and **bold**
;   
;   4. (not implemented) code can be marked as `a = findgen(10)`
;   
;   5. (not implemented) links like: `my site <michaelgalloy.com>`_
;   
;   6. Inserting images via:
;
;      .. image:: people.jpg
;   
;   7. code callouts like::
;  
;        pro test, a
;          compile_opt strictarr
;         
;        end
; 
; :Todo: 
;    finish implementation specified above
;-


;+
; Process directives. Directives are of the form::
;
;    .. directive_name:: directive_argument
;
; :Params:
;    line : in, required, type=string
;       line the directive occurs on
;    pos : in, required, type=long
;       position of the start of the directive
;    len : in, required, type=long
;       length of the directive
; 
; :Keywords:
;    tree : in, required, type=object
;       parse tree to add markup for directive
;    file : in, optional, type=object
;       file object to add image to
;-
pro docparrstmarkupparser::_processDirective, line, pos, len, $
                                              tree=tree, file=file
  compile_opt strictarr, hidden
  
  catch, error
  if (error ne 0L) then begin
    catch, /cancel
    self.system->warning, 'unable to handle rst directive ' + directive
    return
  endif
  
  fullDirective = strmid(line, pos + 3L, len)
  tokens = strsplit(fullDirective, '::[[:space:]]+', /regex, /extract)
  directive = tokens[0]
  filename = tokens[1]
  
  case strlowcase(directive) of
    'image': begin
        tag = obj_new('MGtmTag', type='image')
        
        tag->addAttribute, 'source', filename
        file->getProperty, directory=directory
        directory->getProperty, location=location
        self.system->getProperty, output=output
        
        tag->addAttribute, 'location', location
      end
    'embed': begin
        tag = obj_new('MGtmTag', type='embed')
        
        tag->addAttribute, 'source', filename
        file->getProperty, directory=directory
        directory->getProperty, location=location
        self.system->getProperty, output=output
        
        tag->addAttribute, 'location', location
      end
    else: self.system->warning, 'unknown rst directive ' + directive
  endcase

  beforeDirective = strmid(line, 0, pos)
  afterDirective = strmid(line, pos + len)
  tree->addChild, obj_new('MGtmText', text=beforeDirective)
  tree->addChild, tag
  tree->addChild, obj_new('MGtmText', text=afterDirective)
  tree->addChild, obj_new('MGtmTag', type='newline')
  
  if (obj_valid(file)) then file->addImageRef, filename
end


;+
; Substitute correct codes for less than, greater than, and other signs. 
;
; :Returns:
;    string
;
; :Params:
;    line : in, required, type=string
;       line to process
;
; :Keywords:
;    code : in, optional, type=boolean
;       indicates the line is in code (so escapes might be different)
;-
function docparrstmarkupparser::_processText, line, code=code
  compile_opt strictarr, hidden
  
  output = ''
  self.system->getProperty, comment_style=commentStyle
  
  case commentstyle of
    'latex': begin
        for pos = 0L, strlen(line) - 1L do begin
          ch = strmid(line, pos, 1)
          case ch of
            '_': output += keyword_set(code) ? '_' : '\_'
            '$': output += keyword_set(code) ? '$' : '\$'
            '%': output += keyword_set(code) ? '%' : '\%'
            '#': output += keyword_set(code) ? '#' : '\#'
            '&': output += keyword_set(code) ? '&' : '\&'
            '^': output += keyword_set(code) ? '^' : '\verb+^+'
            '\': output += keyword_set(code) ? '\' : '\verb+\+'
            '~': output += keyword_set(code) ? '~' : '\verb+~+'
            '{': output += keyword_set(code) ? '{' : '\{'
            '}': output += keyword_set(code) ? '}' : '\}'
            else: output += ch
           endcase
        endfor
        break      
      end
    
    'docbook':
    'html': begin
        for pos = 0L, strlen(line) - 1L do begin
          ch = strmid(line, pos, 1)
          case ch of
            '<': output += '&lt;'
            '>': output += '&gt;'
            else: output += ch
           endcase
        endfor
        break
      end
    else:
  endcase
    
  return, output
end


;+
; Handle an indentation level.
;
; :Params:
;    lines : in, required, type=strarr
;       lines to be parsed
;    start : in, required, type=long
;       start index in lines
;    indent : in, required, type=long
;       number of spaces in indentation level
;       
; :Keywords:
;    tree : in, required, type=object
;       current parse tree
;    file : in, optional, type=object
;       file object to add image to
;-
pro docparrstmarkupparser::_handleLevel, lines, start, indent, tree=tree, file=file
  compile_opt strictarr, hidden

  code = 0B
  nextIsCode = 0B
  
  para = obj_new('MGtmTag', type='paragraph')
  tree->addChild, para
  
  for l = start, n_elements(lines) - 1L do begin    
    cleanline = strtrim(lines[l], 0)   ; remove trailing blanks
    dummy = stregex(lines[l], ' *[^[:space:]]', length=currentIndent)
    
    if (cleanLine eq '' && ~code) then begin
      para = obj_new('MGtmTag', type='paragraph')
      tree->addChild, para      
    endif
    
    nextIsCode = strmid(cleanline, 1, /reverse_offset) eq '::'
    
    if (nextIsCode) then cleanline = strmid(cleanline, 0, strlen(cleanline) - 1)
    
    directivePos = stregex(cleanline, '\.\. [[:alpha:]]+:: [[:alnum:]_/.\-]+', $
                           length=directiveLen)
    
    if ((~code || (currentIndent gt -1 && currentIndent le indent)) $
          && directivePos ne -1L) then begin
      self->_processDirective, cleanline, directivePos, directiveLen, $
                               tree=para, file=file
      code = 0B
    endif else begin
      if (code && (currentIndent eq -1 || currentIndent gt indent)) then begin
        listing->addChild, obj_new('MGtmText', $
                                   text=self->_processText(strmid(cleanline, $
                                                                  indent), $
                                                           code=code))
        listing->addChild, obj_new('MGtmTag', type='newline')
      endif else begin     
        code = 0B
        para->addChild, obj_new('MGtmText', $
                                text=self->_processText(cleanline, code=code))
        para->addChild, obj_new('MGtmTag', type='newline')
      endelse
    endelse
    
    if (nextIsCode) then begin
      code = 1B
      indent = currentIndent
      
      listing = obj_new('MGtmTag', type='listing')
      para->addChild, listing
    endif
  endfor  
end


;+
; Takes a string array of rst style comments and return a parse tree.
;
; :Returns: 
;    object
;
; :Params:
;    lines : in, required, type=strarr
;       lines to be parsed
;  
; :Keywords:
;    file : in, required, type=object
;       file object
;-
function docparrstmarkupparser::parse, lines, file=file
  compile_opt strictarr, hidden
  
  start = 0L  
  indent = 0L
  
  tree = obj_new('MGtmTag')
  
  self->_handleLevel, lines, start, indent, tree=tree, file=file
    
  return, tree  
end


;+
; Define instance variables.
;-
pro docparrstmarkupparser__define
  compile_opt strictarr, hidden
  
  define = { DOCparRstMarkupParser, inherits DOCparMarkupParser }
end