if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:Flight = {}
function! s:newFlight(way, is_vmode) abort "{{{
  let u = copy(s:Flight)
  let u.save_opts = {'guicursor': &guicursor, 't_ve': &t_ve, 'scrolloff': &scrolloff}
  let u.save_mode = mode(1)
  let [u.top, u.bot] = [line('w0'), line('w$')]
  let u.pos = getpos('.')[1:2]
  let u.way = a:way
  let u.vmode= ''
  if a:is_vmode
    let u.vmode = visualmode()
    let [a, b] = [getpos("'<")[1:2], getpos("'>")[1:2]]
    let u.base_pos = a != u.pos ? a : b
  else
    let u.base_pos = copy(u.pos)
  end
  let [u.hists, u.hist_idx] = [[u.pos], 0]
  let u.InputLine = ''
  let u.mId = -1
  return u
endfunc
"}}}
function! s:Flight.start() abort "{{{
  setl guicursor=a:block-blinkon0-NONE t_ve= scrolloff=0
  highlight Flying_Cursor   gui=bold guifg=DarkSlateGray guibg=LightCyan cterm=bold ctermfg=black ctermbg=cyan term=reverse
  call self._pos_updated()
endfunc
"}}}
function! s:Flight.finish() abort "{{{
  if self.mId != -1
    call matchdelete(self.mId)
  end
  for [opt, val] in items(self.save_opts)
    exe 'let &l:'. opt. ' = val'
  endfor
endfunc
"}}}
function! s:Flight.update_inputline(appendee) abort "{{{
  if self.InputLine!=''
    let s:save_inputline = self.InputLine
  end
  let self.InputLine .= a:appendee
  let pos = self[self.way==#'f' ? '_searchforward' : '_searchbackward'](self.pos)
  if pos == []
    return -1
  end
  call self._append_pos(pos)._pos_updated()
endfunc
"}}}
function! s:Flight.reflect_pos() abort "{{{
  if self.base_pos == self.pos
    return
  end
  call cursor(self.base_pos)
  norm! m'
  call cursor(self.pos)
endfunc
"}}}
function! s:Flight._histgo(delta) abort "{{{
  let self.hist_idx += a:delta
  let self.pos = self.hists[self.hist_idx]
  call self._pos_updated()
endfunc
"}}}
function! s:Flight._append_pos(pos) abort "{{{
  let self.pos = a:pos
  if self.hist_idx != len(self.hists)-1
    let self.hists = self.hists[: self.hist_idx]
  end
  call add(self.hists, a:pos)
  let self.hist_idx += 1
  return self
endfunc
"}}}
function! s:Flight._pos_updated() abort "{{{
  if self.mId != -1
    call matchdelete(self.mId)
  end
  if self.vmode!=#'v' || self.base_pos == self.pos
    call cursor(self.pos)
  elseif self.base_pos[0] < self.pos[0] || self.base_pos[0] == self.pos[0] && self.base_pos[1] < self.pos[1]
    call cursor(self.pos[0], self.pos[1]-1)
  else
    call cursor(self.pos[0], self.pos[1]+1)
  end
  let self.mId = matchadd('Flying_Cursor', '\%'. self.pos[0]. 'l\&\%'. self.pos[1]. 'c', 1000)
  redraw
  echo printf('> %s %s', self.pos, self.InputLine)
  return self
endfunc
"}}}
function! s:Flight._searchforward(pos) abort "{{{
  call cursor(a:pos)
  let pos = searchpos('\V'. escape(self.InputLine, '\'), 'Wn', self.bot)
  if pos == [0,0]
    return []
  end
  let folded = foldclosedend(pos[0])
  if folded == -1
    return pos
  end
  while folded!=-1
    let unfold_border = folded+1
    let folded = foldclosedend(unfold_border)
  endwhile
  if unfold_border > line('$')
    return pos
  end
  call cursor([unfold_border, 1])
  return self._searchforward([unfold_border, 1])
endfunc
"}}}
function! s:Flight._searchbackward(pos) abort "{{{
  call cursor(a:pos)
  let pos = searchpos('\V'. escape(self.InputLine, '\'), 'nWb', self.top)
  if pos == [0,0]
    return []
  end
  let folded = foldclosed(pos[0])
  if folded==-1
    return pos
  end
  while !(folded==-1 || folded==1)
    let unfold_border = folded-1
    let folded = foldclosed(unfold_border)
  endwhile
  if folded == 1
    return pos
  end
  return self._searchbackward([unfold_border+1, 1])
endfunc
"}}}
function! s:Flight._restore_inputline() abort "{{{
  if self.InputLine==''
    if s:save_inputline==''
      return -1
    end
    let self.InputLine = s:save_inputline
  end
  return 0
endfunc
"}}}
let s:FlightAction = {}
function! s:FlightAction.exit() abort "{{{
  return -1
endfunc
"}}}
function! s:FlightAction.forward() abort "{{{
  if self._restore_inputline()
    return
  end
  let pos = self._searchforward(self.pos)
  if pos == []
    return
  end
  call self._append_pos(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.backward() abort "{{{
  if self._restore_inputline()
    return
  end
  let pos = self._searchbackward(self.pos)
  if pos == []
    return
  end
  call self._append_pos(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.nextline() abort "{{{
  if self._restore_inputline()
    return
  end
  let pos = self._searchforward([self.pos[0], col([self.pos[0], '$'])])
  if pos == []
    return
  end
  call self._append_pos(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.prevline() abort "{{{
  if self._restore_inputline()
    return
  end
  let pos = self._searchbackward([self.pos[0], 1])
  if pos == []
    return
  end
  call self._append_pos(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.histback() abort "{{{
  if self.hist_idx<=0
    return
  end
  call self._histgo(-1)
endfunc
"}}}
function! s:FlightAction.histadvance() abort "{{{
  if self.hist_idx>=len(self.hists)-1
    return
  end
  call self._histgo(1)
endfunc
"}}}
function! s:FlightAction.backspace() abort "{{{
  let self.InputLine = self.InputLine[: -2]
  call self._histgo(-1)
endfunc
"}}}
function! s:FlightAction.clearline() abort "{{{
  let self.InputLine = ''
  let self.pos = self.hists[0]
  let [self.hists, self.hist_idx] = [[self.pos], 0]
  call self._pos_updated()
endfunc
"}}}


let s:save_inputline = ''
function! flying#fly(way, is_vmode) abort "{{{
  if a:is_vmode
    norm! gv
  end
  let flight = s:newFlight(a:way, a:is_vmode)
  call flight.start()
  try
    call s:loop(flight)
    call flight.reflect_pos()
  finally
    call flight.finish()
  endtry
endfunc
"}}}
function! s:loop(flight) abort "{{{
  while 1
    let typee = __flying#lim#cap#keymappings(g:flying#keymappings, {'transit': 1, })
    if typee=={}
      break
    end
    if has_key(s:FlightAction, typee.action) && call(s:FlightAction[typee.action], [], a:flight)
      break
    end
    if typee.surplus!='' && a:flight.update_inputline(typee.surplus)
      break
    end
  endwhile
endfunc
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
