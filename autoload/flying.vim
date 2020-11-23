if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:save_inputline = ''
let s:landingpoint = {}

let s:Flight = {}
function! s:newFlight(way, is_vmode, is_omode) abort "{{{
  let u = copy(s:Flight)
  let u.save_opts = {'guicursor': &guicursor, 't_ve': &t_ve, 'scrolloff': &scrolloff}
  let [u.top, u.bot] = [line('w0'), line('w$')]
  let u.pos = getpos('.')[1:2]
  let [u.way, u.is_omode] = [a:way, a:is_omode]
  let u.vmode= ''
  if a:is_vmode
    let u.vmode = visualmode()
    let [a, b] = [getpos("'<")[1:2], getpos("'>")[1:2]]
    let u.base_pos = a != u.pos ? a : b
  else
    let u.base_pos = copy(u.pos)
  end
  let [u.hists, u.hist_idx] = [[u.pos], 0]
  let u.inputline = ''
  let u.pre_invalid_input = ''
  let u.mIds = []
  return u
endfunc
"}}}
function! s:Flight.landingpoint() abort "{{{
  return {'src_pos': self.base_pos, 'dst_pos': self.pos}
endfunc
"}}}
function! s:Flight.start() abort "{{{
  setl guicursor=a:block-blinkon0-NONE t_ve= scrolloff=0
  highlight Flying_Cursor   gui=bold guifg=DarkSlateGray guibg=LightCyan cterm=bold ctermfg=black ctermbg=cyan term=reverse
  highlight Flying_ORegion   guibg=SlateBlue cterm=reverse term=reverse
  call self._pos_updated()
endfunc
"}}}
function! s:Flight.cleanup() abort "{{{
  if self.inputline==''
    let s:save_inputline = ''
  end
  call self._clearmatches()
  let self.mIds = []
  for [opt, val] in items(self.save_opts)
    exe 'let &l:'. opt. ' = val'
  endfor
  call cursor(self.base_pos)
endfunc
"}}}
function! s:Flight.update_inputline(appendee) abort "{{{
  if self.inputline!=''
    let s:save_inputline = self.inputline
  end
  let self.inputline .= a:appendee
  let pos = self[self.way=~'\l' ? '_searchforward' : '_searchbackward'](self.pos)
  if pos == []
    return -1
  end
  call self._move_pos(pos)._pos_updated()
endfunc
"}}}
function! s:Flight.repeat(inputline, cnt) abort "{{{
  let self.inputline = a:inputline
  let cnt = a:cnt
  while cnt
    let cnt -= 1
    let pos = self[self.way=~'\l' ? '_searchforward' : '_searchbackward'](self.pos)
    if pos == []
      break
    end
    let self.pos = pos
  endwhile
  return self
endfunc
"}}}
function! s:Flight._clearmatches() abort "{{{
  for mId in self.mIds
    call matchdelete(mId)
  endfor
  let self.mIds = []
endfunc
"}}}
function! s:Flight._histgo(delta) abort "{{{
  let self.hist_idx += a:delta
  let self.pos = self.hists[self.hist_idx]
  call self._pos_updated()
endfunc
"}}}
function! s:Flight._move_pos(pos) abort "{{{
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
  call self._clearmatches()
  if self.is_omode
    let result = s:pos1_is_after(self.pos, self.base_pos)
    if result > 0
      call add(self.mIds, matchadd('Flying_ORegion', '\%(\%'. self.base_pos[0]. 'l\&\%'. self.base_pos[1]. 'c\)\_.\{-}\%(\%'. self.pos[0]. 'l\&\%'. self.pos[1]. 'c\)'))
    elseif result < 0
      call add(self.mIds, matchadd('Flying_ORegion', '\%(\%'. self.pos[0]. 'l\&\%'. self.pos[1]. 'c\)\_.\{-}\%(\%'. self.base_pos[0]. 'l\&\%'. self.base_pos[1]. 'c\)'))
    end
    call add(self.mIds, matchadd('Flying_Cursor', '\%'. self.base_pos[0]. 'l\&\%'. self.base_pos[1]. 'c'))
    redraw
    "echo printf('> %s %s', self.pos, self.inputline)
    return self
  end
  if self.vmode==#'v'
    let result = s:pos1_is_after(self.pos, self.base_pos)
    call cursor(result==0 ? self.pos : result > 0 ? [self.pos[0], self.pos[1]-1] : [self.pos[0], self.pos[1]+1])
  end
  call add(self.mIds, matchadd('Flying_Cursor', '\%'. self.pos[0]. 'l\&\%'. self.pos[1]. 'c'))
  redraw
  "echo printf('> %s %s', self.pos, self.inputline)
  return self
endfunc
"}}}
function! s:Flight._searchforward(pos) abort "{{{
  call cursor(a:pos)
  let pos = searchpos(self._get_search_pat(), 'Wn', self.bot)
  if pos == [0,0]
    return []
  end
  let folded = foldclosedend(pos[0])
  if folded == -1
    return self._modifypos_fw(pos)
  end
  while folded!=-1
    let unfold_border = folded+1
    let folded = foldclosedend(unfold_border)
  endwhile
  if unfold_border > line('$')
    return self._modifypos_fw(pos)
  end
  call cursor([unfold_border, 1])
  return self._searchforward([unfold_border, 1])
endfunc
"}}}
function! s:Flight._searchbackward(pos) abort "{{{
  call cursor(a:pos)
  let pos = searchpos(self._get_search_pat(), 'nWb', self.top)
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
function! s:Flight._get_search_pat() abort "{{{
  if self.way!=#'T'
    return (self.way==?'t' ? '.\ze\V': '\V'). escape(self.inputline, '\')
  end
  let [first; rest] = split(self.inputline, '\zs')
  return '\V'. escape(first, '\'). '\zs'. escape(join(rest, ''), '\')
endfunc
"}}}
function! s:Flight._modifypos_fw(pos) abort "{{{
  if self.is_omode
    return [a:pos[0], a:pos[1]+1]
  end
  return a:pos
endfunc
"}}}
function! s:Flight._restore_inputline() abort "{{{
  if self.inputline==''
    if s:save_inputline==''
      return -1
    end
    let self.inputline = s:save_inputline
  end
  return 0
endfunc
"}}}
function! s:Flight._break_for_invalid(raw) abort "{{{
  if a:raw ==# self.pre_invalid_input
    return -1
  end
  let self.pre_invalid_input = a:raw
endfunc
"}}}
let s:FlightAction = {}
function! s:FlightAction.exit(raw) abort "{{{
  return -1
endfunc
"}}}
function! s:FlightAction.forward(raw) abort "{{{
  if self._restore_inputline()
    return self._break_for_invalid(a:raw)
  end
  let pos = self._searchforward(self.pos)
  if pos == []
    return self._break_for_invalid(a:raw)
  end
  let self.pre_invalid_input = ''
  call self._move_pos(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.backward(raw) abort "{{{
  if self._restore_inputline()
    return self._break_for_invalid(a:raw)
  end
  let pos = self._searchbackward(self.pos)
  if pos == []
    return self._break_for_invalid(a:raw)
  end
  call self._move_pos(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.nextline(raw) abort "{{{
  if self._restore_inputline()
    return self._break_for_invalid(a:raw)
  end
  let pos = self._searchforward([self.pos[0], col([self.pos[0], '$'])])
  if pos == []
    return self._break_for_invalid(a:raw)
  end
  call self._move_pos(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.prevline(raw) abort "{{{
  if self._restore_inputline()
    return self._break_for_invalid(a:raw)
  end
  let pos = self._searchbackward([self.pos[0], 1])
  if pos == []
    return self._break_for_invalid(a:raw)
  end
  call self._move_pos(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.histback(raw) abort "{{{
  if self.hist_idx<=0
    return
  end
  call self._histgo(-1)
endfunc
"}}}
function! s:FlightAction.histadvance(raw) abort "{{{
  if self.hist_idx>=len(self.hists)-1
    return
  end
  call self._histgo(1)
endfunc
"}}}
function! s:FlightAction.backspace(raw) abort "{{{
  let self.inputline = self.inputline[: -2]
  call self._histgo(-1)
endfunc
"}}}
function! s:FlightAction.clearline(raw) abort "{{{
  let self.inputline = ''
  let self.pos = self.hists[0]
  let [self.hists, self.hist_idx] = [[self.pos], 0]
  call self._pos_updated()
endfunc
"}}}


function! flying#keymap(way) "{{{
  if a:way !~# '^[fFtT]$'
    throw "Error: Invalid mapping `". a:way. "`"
  endif
  let mode = mode(1)
  let [is_vmode, is_omode] = [mode==? 'v' || mode=="\<C-v>", mode[:1] == 'no']
  if is_vmode
    return printf(":\<C-u>call flying#_vmode('%s')\<CR>", a:way)
  end
  let s:landingpoint = v:count==0 ? s:fly(a:way, 0, is_omode) : s:countjump(a:way, v:count, 0, is_omode)
  return printf(":\<C-u>call flying#_move_cursor('%s')\<CR>", a:way)
endfunc
"}}}
function! flying#_vmode(way) abort "{{{
  norm! gv
  let landingpoint = v:count==0 ? s:fly(a:way, 1, 0) : s:countjump(a:way, v:count, 1, 0)
  if landingpoint.src_pos == landingpoint.dst_pos
    return
  end
  call cursor(landingpoint.src_pos)
  norm! m'
  call cursor(landingpoint.dst_pos)
endfunc
"}}}
function! flying#_move_cursor(way) abort "{{{
  if s:landingpoint=={}
    let pos = s:newFlight(a:way, 0, 1).repeat(s:save_inputline, v:count1).landingpoint().dst_pos
    call cursor(pos)
    return
  elseif s:landingpoint.src_pos != s:landingpoint.dst_pos
    call cursor(s:landingpoint.src_pos)
    norm! m'
    call cursor(s:landingpoint.dst_pos)
  end
  let s:landingpoint = {}
endfunc
"}}}
function! s:countjump(way, cnt, is_vmode, is_omode) abort "{{{
  while 1
    let cn = getchar()
    if cn !=# "\x80\xfd`"
      break
    endif
  endwhile
  let flight = s:newFlight(a:way, a:is_vmode, a:is_omode)
  if type(cn)!=type(1)
    return flight.landingpoint()
  end
  let s:save_inputline = nr2char(cn)
  return flight.repeat(s:save_inputline, a:cnt).landingpoint()
endfunc
"}}}
function! s:fly(way, is_vmode, is_omode) abort "{{{
  let flight = s:newFlight(a:way, a:is_vmode, a:is_omode)
  call flight.start()
  try
    call s:loop(flight)
  finally
    call flight.cleanup()
  endtry
  return flight.landingpoint()
endfunc
"}}}
function! s:loop(flight) abort "{{{
  while 1
    let typee = __flying#lim#cap#keymappings(g:flying#keymappings, {'transit': 1, })
    if typee=={}
      break
    end
    if has_key(s:FlightAction, typee.action) && call(s:FlightAction[typee.action], [typee.raw], a:flight)
      break
    end
    if typee.surplus!='' && a:flight.update_inputline(typee.surplus)
      break
    end
  endwhile
endfunc
"}}}

function! s:pos1_is_after(pos1, pos2) abort "{{{
  return a:pos1[0] == a:pos2[0] ? a:pos1[1] - a:pos2[1] : a:pos1[0] - a:pos2[0]
endfunc
"}}}
"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
