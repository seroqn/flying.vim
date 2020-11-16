if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_flying')| finish| endif| let g:loaded_flying = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
noremap <silent><Plug>(flying-f) :<C-u>call flying#fly('f', 0)<CR>
noremap <silent><Plug>(flying-F) :<C-u>call flying#fly('F', 0)<CR>
xnoremap <silent><Plug>(flying-f) :<C-u>call flying#fly('f', 1)<CR>
xnoremap <silent><Plug>(flying-F) :<C-u>call flying#fly('F', 1)<CR>

let g:flying#keymappings = exists('g:flying#keymappings') ? g:flying#keymappings :
  \ {"\<C-f>": "forward", "\<C-b>": "backward", "\<C-n>": "nextline", "\<C-p>": "prevline", "\<C-o>": "histback", "\<C-i>": "histadvance", "\<BS>": "backspace", "\<C-h>": "backspace", "\<C-u>": "clearline"}
let g:flying#keymappings = 
  \ {"\<C-f>": "forward", "\<C-b>": "backward", "\<C-n>": "nextline", "\<C-p>": "prevline", "\<C-o>": "histback", "\<C-i>": "histadvance", "\<BS>": "backspace", "\<C-h>": "backspace", "\<C-u>": "clearline"}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
