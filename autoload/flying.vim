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
  let u.posV = getpos('.')[1:2]
  let [u.way, u.is_omode] = [a:way, a:is_omode]
  let u.vmode= ''
  if a:is_vmode
    let u.vmode = visualmode()
    let [a, b] = [getpos("'<")[1:2], getpos("'>")[1:2]]
    let u.base_pos = a != u.posV ? a : b
  else
    let u.base_pos = copy(u.posV)
  end
  let [u.histsV, u.histIdxV] = [[u.posV], 0]
  let u.inputLineV = ''
  let u.preInvalidInputV = ''
  let u.mIdsV = []
  return u
endfunc
"}}}
function! s:Flight.landingpoint() abort "{{{
  return {'src_pos': self.base_pos, 'dst_pos': self.posV}
endfunc
"}}}
function! s:Flight.start() abort "{{{
  setl guicursor=a:block-blinkon0-NONE t_ve= scrolloff=0
  highlight Flying_Cursor   gui=bold guifg=DarkSlateGray guibg=LightCyan cterm=bold ctermfg=black ctermbg=cyan term=reverse
  highlight Flying_ORegion   guibg=SlateBlue cterm=reverse term=reverse
  call self._pos_updated()
endfunc
"}}}
function! s:Flight.cleanup() "{{{
  if self.inputLineV==''
    let s:save_inputline = ''
  end
  call self._clearmatches()
  let self.mIdsV = []
  for [opt, val] in items(self.save_opts)
    exe 'let &l:'. opt. ' = val'
  endfor
  call cursor(self.base_pos)
endfunc
"}}}
function! s:Flight.goto(pat) abort "{{{
  let pos = self[self.way=~'\l' ? '_searchforward' : '_searchbackward'](self.posV, '\m\C'. a:pat. '\V')
  if pos == []
    return
  end
  call self._move_pos_to(pos)._pos_updated()
endfunc
"}}}
function! s:Flight.append_input(appendee) abort "{{{
  if self.inputLineV!=''
    let s:save_inputline = self.inputLineV
  end
  let self.inputLineV .= a:appendee
  let pos = self[self.way=~'\l' ? '_searchforward' : '_searchbackward'](self.posV)
  if pos == []
    return -1
  end
  call self._move_pos_to(pos)._pos_updated()
endfunc
"}}}
function! s:Flight.times(inputline, cnt) abort "{{{
  let self.inputLineV = a:inputline
  let cnt = a:cnt
  while cnt
    let cnt -= 1
    let pos = self[self.way=~'\l' ? '_searchforward' : '_searchbackward'](self.posV)
    if pos == []
      break
    end
    let self.posV = pos
  endwhile
  return self
endfunc
"}}}
function! s:Flight._clearmatches() abort "{{{
  for mId in self.mIdsV
    call matchdelete(mId)
  endfor
  let self.mIdsV = []
endfunc
"}}}
function! s:Flight._histgo(delta) abort "{{{
  let self.histIdxV += a:delta
  let self.posV = self.histsV[self.histIdxV]
  call self._pos_updated()
endfunc
"}}}
function! s:Flight._move_pos_to(pos) abort "{{{
  let self.posV = a:pos
  if self.histIdxV != len(self.histsV)-1
    let self.histsV = self.histsV[: self.histIdxV]
  end
  call add(self.histsV, a:pos)
  let self.histIdxV += 1
  return self
endfunc
"}}}
function! s:Flight._pos_updated() abort "{{{
  call self._clearmatches()
  if self.is_omode
    let result = s:pos1_is_after(self.posV, self.base_pos)
    if result > 0
      call add(self.mIdsV, matchadd('Flying_ORegion', '\%(\%'. self.base_pos[0]. 'l\&\%'. self.base_pos[1]. 'c\)\_.\{-}\%(\%'. self.posV[0]. 'l\&\%'. self.posV[1]. 'c\)'))
    elseif result < 0
      call add(self.mIdsV, matchadd('Flying_ORegion', '\%(\%'. self.posV[0]. 'l\&\%'. self.posV[1]. 'c\)\_.\{-}\%(\%'. self.base_pos[0]. 'l\&\%'. self.base_pos[1]. 'c\)'))
    end
    call add(self.mIdsV, matchadd('Flying_Cursor', '\%'. self.base_pos[0]. 'l\&\%'. self.base_pos[1]. 'c'))
    redraw
    "echo printf('> %s %s', self.posV, self.inputLineV)
    return self
  end
  if self.vmode==#'v'
    let result = s:pos1_is_after(self.posV, self.base_pos)
    call cursor(result==0 ? self.posV : result > 0 ? [self.posV[0], self.posV[1]-1] : [self.posV[0], self.posV[1]+1])
  end
  call add(self.mIdsV, matchadd('Flying_Cursor', '\%'. self.posV[0]. 'l\&\%'. self.posV[1]. 'c'))
  redraw
  "echo printf('> %s %s', self.posV, self.inputLineV)
  return self
endfunc
"}}}
function! s:Flight._searchforward(pos, ...) abort "{{{
  let pat = a:0 ? a:1 : self._get_search_pat()
  call cursor(a:pos)
  let pos = searchpos(pat, 'Wn', self.bot)
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
  return self._searchforward([unfold_border, 1], pat)
endfunc
"}}}
function! s:Flight._searchbackward(pos, ...) abort "{{{
  let pat = a:0 ? a:1 : self._get_search_pat()
  call cursor(a:pos)
  let pos = searchpos(pat, 'nWb', self.top)
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
  return self._searchbackward([unfold_border+1, 1], pat)
endfunc
"}}}
function! s:Flight._get_search_pat() abort "{{{
  if self.way ==? 'f'
    return '\V'. escape(self.inputLineV, '\')
  elseif self.way ==# 't'
    return '.\ze\V'. escape(self.inputLineV, '\')
  end
  let [first; rest] = split(self.inputLineV, '\zs')
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
  if self.inputLineV==''
    if s:save_inputline==''
      return -1
    end
    let self.inputLineV = s:save_inputline
  end
  return 0
endfunc
"}}}
function! s:Flight._break_if_dual_invalid_input(raw) abort "{{{
  if a:raw ==# self.preInvalidInputV
    return -1
  end
  let self.preInvalidInputV = a:raw
endfunc
"}}}
let s:FlightAction = {}
function! s:FlightAction.exit(raw) abort "{{{
  return -1
endfunc
"}}}
function! s:FlightAction.forward(raw) abort "{{{
  if self._restore_inputline()
    return self._break_if_dual_invalid_input(a:raw)
  end
  let pos = self._searchforward(self.posV)
  if pos == []
    return self._break_if_dual_invalid_input(a:raw)
  end
  let self.preInvalidInputV = ''
  call self._move_pos_to(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.backward(raw) abort "{{{
  if self._restore_inputline()
    return self._break_if_dual_invalid_input(a:raw)
  end
  let pos = self._searchbackward(self.posV)
  if pos == []
    return self._break_if_dual_invalid_input(a:raw)
  end
  call self._move_pos_to(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.nextline(raw) abort "{{{
  if self._restore_inputline()
    return self._break_if_dual_invalid_input(a:raw)
  end
  let pos = self._searchforward([self.posV[0], col([self.posV[0], '$'])])
  if pos == []
    return self._break_if_dual_invalid_input(a:raw)
  end
  call self._move_pos_to(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.prevline(raw) abort "{{{
  if self._restore_inputline()
    return self._break_if_dual_invalid_input(a:raw)
  end
  let pos = self._searchbackward([self.posV[0], 1])
  if pos == []
    return self._break_if_dual_invalid_input(a:raw)
  end
  call self._move_pos_to(pos)._pos_updated()
endfunc
"}}}
function! s:FlightAction.histback(raw) abort "{{{
  if self.histIdxV<=0
    return
  end
  call self._histgo(-1)
endfunc
"}}}
function! s:FlightAction.histadvance(raw) abort "{{{
  if self.histIdxV>=len(self.histsV)-1
    return
  end
  call self._histgo(1)
endfunc
"}}}
function! s:FlightAction.backspace(raw) abort "{{{
  let self.inputLineV = join(split(self.inputLineV, '\zs')[: -2], '')
  call self._histgo(-1)
endfunc
"}}}
function! s:FlightAction.clearline(raw) abort "{{{
  let self.inputLineV = ''
  let self.posV = self.histsV[0]
  let [self.histsV, self.histIdxV] = [[self.posV], 0]
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
  let s:landingpoint = v:count==0 ? s:fly(a:way, 0, is_omode) : s:countjump_landingpoint(a:way, v:count, 0, is_omode)
  return printf(":\<C-u>call flying#_move_cursor('%s')\<CR>", a:way)
endfunc
"}}}
function! flying#_vmode(way) abort "{{{
  norm! gv
  let landingpoint = v:count==0 ? s:fly(a:way, 1, 0) : s:countjump_landingpoint(a:way, v:count, 1, 0)
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
    let pos = s:newFlight(a:way, 0, 1).times(s:save_inputline, v:count1).landingpoint().dst_pos
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
function! s:countjump_landingpoint(way, cnt, is_vmode, is_omode) abort "{{{
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
  return flight.times(s:save_inputline, a:cnt).landingpoint()
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
    else
      let pat = matchstr(typee.action, '^goto_\zs\[.\{-1,}\%(\%(\%(^\|[^\\]\)\%(\\\\\)*\)\@<=\\\)\@<!]$')
      if pat != '' && a:flight.goto(pat)
        break
      end
    end
    if typee.surplus!='' && a:flight.append_input(typee.surplus)
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
