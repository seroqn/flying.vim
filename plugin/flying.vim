if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_flying')| finish| endif| let g:loaded_flying = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
noremap <silent><expr><Plug>(flying-f) flying#keymap('f')
noremap <silent><expr><Plug>(flying-F) flying#keymap('F')
noremap <silent><expr><Plug>(flying-t) flying#keymap('t')
noremap <silent><expr><Plug>(flying-T) flying#keymap('T')
sunmap <Plug>(flying-f)
sunmap <Plug>(flying-F)
sunmap <Plug>(flying-t)
sunmap <Plug>(flying-T)

let g:flying#keymappings = exists('g:flying#keymappings') ? g:flying#keymappings :
  \ {"\<C-f>": "forward", "\<C-b>": "backward", "\<C-n>": "nextline", "\<C-p>": "prevline",
  \ "\<C-o>": "histback", "\<C-i>": "histadvance", "\<BS>": "backspace", "\<C-h>": "backspace",
  \ "\<C-u>": "clearline", "\<C-^>": 'goto_[({[<]', "\<C-]>": 'goto_[)}\]>]'}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
