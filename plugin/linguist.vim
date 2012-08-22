" plugin/linguist.vim
" Author:       Lowe Thiderman <lowe.thiderman@gmail.com>

" Install this file as plugin/linguist.vim.

if exists('g:loaded_linguist') || &cp
  finish
endif
let g:loaded_linguist = 1

let s:cpo_save = &cpo
set cpo&vim

if !exists('g:linguist')
  let g:linguist = {}
endif

" Public API {{{1

function! LinguistParse(fn, ...)
  let fn = fnamemodify(a:fn, ':p')
  if !filereadable(fn)
    return {}
  endif

  if has_key(g:linguist, fn) && !a:0
    return g:linguist[fn]
  endif

  let d = {}
  let d.fn = fn
  let d.get_data = function('s:get_data')
  let d.data = d.get_data()
  let d.complete = function('LinguistComplete')
  let d.render = function('LinguistRenderMessage')
  let d._render_cache = {}

  let g:linguist[fn] = d
  return d
endfunction

" }}}
" Core helpers {{{1

function! s:get_data() dict abort
  let data = {}
  let lnr = 0
  let start = 0
  let in = 0
  let key = ""
  let plural = ""

  let lines = readfile(self.fn)
  let len = len(lines)
  for line in lines
    let lnr = lnr + 1
    if line =~ '^\(\s*$\|#[ .:,|]\@!.*$\)' || lnr == len
      if in && key != ""
        if has_key(data, key)
          echo 'duplicate key' key start lnr
        endif
        let data[key] = [start, lnr - 1]
        let key = ""
        if plural != ""
          let data[plural] = [start, lnr - 1]
          let plural = ""
        endif
        let start = 0
        let in = 0
      endif
      continue
    else
      if !in
        let in = 1
        let start = lnr
      endif

      let m = matchlist(line, '^msgid "\(.*\)"')
      if len(m) != 0
        let key = m[1]
        if key == ''  " E713: Cannot use empty key for Dictionary
          let key = '<root>'
        endif
      endif

      let m = matchlist(line, '^msgid_plural "\(.*\)"')
      if len(m) != 0
        let plural = m[1]
      endif
    endif
  endfor

  return data
endfunction

" }}}
" Rendering {{{1

function! LinguistRenderMessage(key) dict abort
  let key = a:key  " fak u vim
  if !has_key(self.data, key)
    return {}
  endif

  if has_key(self._render_cache, key)
    return self._render_cache[key]
  endif

  let data = {}
  let data.str = ''
  " let data.id = key

  let idx = ""
  let next = ""
  for line in readfile(self.fn)[self.data[key][0] - 1 : self.data[key][1]]
    if line =~ '^#'
      if line =~ '^#  ' || line =~ '^#\.'
        if line =~ '^#  '
          let k = 'translator_comments'
          let c = matchlist(line, '^#  \(.*\)')[1]
        else
          let k = 'extracted_comments'
          let c = matchlist(line, '^#\. \(.*\)')[1]
        endif

        if has_key(data, k)
          let data[k] = data[k] . ' ' . c
        else
          let data[k] = c
        endif
      elseif line =~ '^#:'
        if !has_key(data, 'reference')
          let data.reference = []
        endif
        let data.reference = extend(data.reference, split(line, ' ')[1:])
      elseif line =~ '^#,'
        let data.flags = split(line, ', ')[1:]
      elseif line =~ '^#|'
        if !has_key(data, 'prev')
          let data.prev = {}
        endif
        if line =~ '^#| msgid "'
          let data.prev.id = matchlist(line, '^#| msgid "\(.*\)"')[1]
        elseif line =~ '^#| msgctxt "'
          let data.prev.ctx = matchlist(line, '^#| msgctxt "\(.*\)"')[1]
        endif
      endif
    elseif line =~ '^msgctxt "'
      let data.ctx = matchlist(line, '^msgctxt "\(.*\)"')[1]
    elseif line =~ '^msgid "'
      continue
    elseif line =~ '^msgid_plural'
      if !has_key(data, 'plural')
        let data.plural = {}
      endif
      let data.plural.id = matchlist(line, '^msgid_plural "\(.*\)"')[1]
    elseif line =~ '^msgstr "'
      let msg = matchlist(line, '^msgstr "\(.*\)"', 0, 1)[1]
      if msg == ""
        let next = 'str'
      endif
      let data.str = msg
    elseif line =~ '^msgstr\['
      if !has_key(data.plural, 'str')
        let data.plural.str = {}
      endif
      let m = matchlist(line, '^msgstr\[\(.*\)\] "\(.*\)"')
      let idx = m[1]
      let msg = m[2]
      if msg == ""
        let next = idx
      endif
      let data.plural.str[idx] = msg
    elseif line =~ '^"' && next != ""
      let msg = matchlist(line, '^"\(.*\)"$')[1]
      if next == 'str'
        let data[next] = data[next] . msg
      else
        let data.plural.str[next] = data.plural.str[next] . msg
      endif
    endif
  endfor

  " let self._render_cache[a:key] = data
  return data
endfunction

" }}}
" Completion {{{1

function! LinguistComplete() dict abort
  return
endfunction

" }}}

let &cpo = s:cpo_save
" vim:set sw=2 sts=2:
