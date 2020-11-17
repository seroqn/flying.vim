if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_LIST = type([])
let s:TYPE_STR = type('')

"Misc:
function! s:_expand_keycodes(str) "{{{
  return substitute(a:str, '<\S\{-1,}>', '\=eval(''"\''. submatch(0). ''"'')', 'g')
endfunction
"}}}
function! s:_noexpand(str) "{{{
  return a:str
endfunction
"}}}
function! s:_cnvvimkeycodes(str) "{{{
  try
    let ret = has_key(s:, 'disable_keynotation') ? a:str : __flying#lim#keynotation#decode(a:str)
    return ret
  catch /E117:/
    let s:disable_keynotation = 1
    return a:str
  endtry
endfunction
"}}}

let s:Inputs = {}
function! s:newInputs(keys, ...) "{{{
  let obj = copy(s:Inputs)
  if a:0
    let obj.is_transit = get(a:1, 'transit', 0)
    let feed = get(a:1, 'feed', '')
    if feed!=''
      let obj.feed = feed
    end
    let async = get(a:1, 'async', {})
    let asyncfunc = get(async, 'func', [])
    let _ = len(asyncfunc)
    if type(asyncfunc)==s:TYPE_LIST && (_==2 || _==3)
      let obj.asyncfunc = asyncfunc
      let obj.asynctime = get(async, 'time', 0.5)
    end
  else
    let obj.is_transit = 0
  end
  let obj._feedidx = 0
  let obj.neutral_keys = a:keys
  let obj.keys = copy(a:keys)
  let obj.crrinput = ''
  let obj.justmatch = ''
  return obj
endfunction
"}}}
function! s:Inputs._reset() "{{{
  let self.keys = copy(self.neutral_keys)
  let self.crrinput = ''
  let self.justmatch = ''
endfunction
"}}}
function! s:Inputs._update() "{{{
  call filter(self.keys, 'stridx(v:val, self.crrinput)==0')
  if index(self.keys, self.crrinput)!=-1
    let self.justmatch = self.crrinput
  end
endfunction
"}}}
function! s:Inputs._given_feed() "{{{
  let i = 0
  let len = len(self.feed)
  while i < len
    let self.crrinput .= self.feed[i]
    let i += 1
    call self._update()
    if self.should_break()
      let self.crrinput .= self.feed[i :]
      break
    end
  endwhile
  return self.crrinput
endfunction
"}}}
function! s:Inputs.receive() "{{{
  if has_key(self, 'feed')
    return self._given_feed()
  elseif has_key(self, 'asyncfunc')
    let base_time = reltime()
    while 1
      let cn = getchar(0)
      if cn==s:TYPE_STR && cn !=# "\x80\xfd`" || cn
        break
      elseif str2float(reltimestr(reltime(base_time))) >= self.asynctime
        call call('call', self.asyncfunc)
        let base_time= reltime()
      end
    endwhile
  else
    while 1
      let cn = getchar()
      if cn !=# "\x80\xfd`"
        break
      end
    endwhile
  end
  let input = type(cn)==s:TYPE_STR ? cn : nr2char(cn)
  let self.crrinput .= input
  call self._update()
  while getchar(1)
    let cn = getchar()
    let char = type(cn)==s:TYPE_STR ? cn : nr2char(cn)
    let input .= char
    let self.crrinput .= char
    call self._update()
  endwhile
  return input
endfunction
"}}}
function! s:Inputs.should_break() "{{{
  if self.keys==[]
    if self.justmatch!='' || self.is_transit
      return 1
    end
    call self._reset()
    return 0
  elseif index(self.keys, self.crrinput)==-1
    return 0
  end
  let self.justmatch = self.crrinput
  if len(self.keys)==1
    return 1
  end
endfunction
"}}}
function! s:Inputs.get_results() "{{{
  return [self.justmatch, self.crrinput[len(self.justmatch):], self.crrinput]
endfunction
"}}}


"=============================================================================
"Main:
function! __flying#lim#cap#select(prompt, choices, ...) abort "{{{
  let behavior = a:0 ? a:1 : {}
  if a:choices==[]
    return []
  end
  echo a:prompt
  if !get(behavior, 'silent', 0)
    call s:_show_choices(a:choices, get(behavior, 'sort', 0))
  end
  let cancel_inputs = get(behavior, 'cancel_inputs', ["\<Esc>", "\<C-c>"])
  if cancel_inputs==[]
    call add(cancel_inputs, "\<C-c>")
  end
  let tmp = get(behavior, 'error_inputs', [])
  let error_inputs = type(tmp)==s:TYPE_LIST ? tmp : tmp ? cancel_inputs : []
  let dict = s:_get_choicesdict(a:choices, get(behavior, 'expand', 0))
  let inputs = s:newInputs(keys(dict))
  while 1
    let char = inputs.receive()
    if index(error_inputs, char)!=-1
      redraw!
      throw printf('select: inputed "%s"', s:_cnvvimkeycodes(char))
    elseif index(cancel_inputs, char)!=-1
      redraw!
      return []
    elseif inputs.should_break()
      break
    end
  endwhile
  redraw!
  let input = inputs.get_results()[0]
  return dict[input]
endfunctio
"}}}
function! s:_show_choices(choices, sort_choices) "{{{
  let mess = []
  for choice in a:choices
    if empty(get(choice, 0, '')) || get(choice, 1, '')==''
      continue
    end
    if type(choice[0])==s:TYPE_LIST
      let choices = copy(choice[0])
      if a:sort_choices
        call sort(choices)
      end
      let input = join(map(choices, 's:_cnvvimkeycodes(v:val)'), ', ')
    else
      let input = s:_cnvvimkeycodes(choice[0])
    end
    call add(mess, printf('%-6s: %s', input, choice[1]))
  endfor
  if a:sort_choices
    call sort(mess, 1)
  end
  for mes in mess
    echo mes
  endfor
  echon ' '
endfunction
"}}}
function! s:_get_choicesdict(choices, expand_keycodes) "{{{
  let dict = {}
  for cho in a:choices
    if type(cho[0])==s:TYPE_LIST
      for c in cho[0]
        let chr = a:expand_keycodes ? s:_expand_keycodes(c) : c
        if !(chr=='' || has_key(dict, chr))
          let dict[chr] = insert(cho[1:], c)
        end
      endfor
    else
      let chr = a:expand_keycodes ? s:_expand_keycodes(cho[0]) : cho[0]
      if !(chr=='' || has_key(dict, chr))
        let dict[chr] = insert(cho[1:], cho[0])
      end
    end
  endfor
  return dict
endfunction
"}}}

function! __flying#lim#cap#keybind(binddefs, ...) abort "{{{
  let behavior = a:0 ? a:1 : {}
  let bindacts = s:_get_bindacts(a:binddefs, function(get(behavior, 'expand') ? 's:_expand_keycodes' : 's:_noexpand'))
  return __flying#lim#cap#keymappings(bindacts, behavior)
endfunction
"}}}
function! s:_get_bindacts(binddefs, expandfunc) "{{{
  let bindacts= {}
  for [act, binds] in items(a:binddefs)
    if type(binds)==s:TYPE_STR
      let bindacts[a:expandfunc(binds)] = act
      continue
    end
    for bind in binds
      let bindacts[a:expandfunc(bind)] = act
    endfor
  endfor
  return bindacts
endfunction
"}}}

function! __flying#lim#cap#keymappings(keymappings, ...) abort "{{{
  let behavior = a:0 ? a:1 : {}
  let inputs = s:newInputs(keys(a:keymappings), behavior)
  while 1
    let char = inputs.receive()
    if !has_key(a:keymappings, "\<C-c>") && char=="\<C-c>"
      return {}
    elseif has_key(inputs, 'feed') || inputs.should_break()
      break
    end
  endwhile
  let [justmatch, surplus, raw] = inputs.get_results()
  return {'action': get(a:keymappings, justmatch, ''), 'surplus': surplus, 'raw': raw}
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
