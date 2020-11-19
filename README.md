# flying.vim
見えてる範囲にインクリメンタル検索でジャンプします。

標準の `f` `F` `t` `T` をリスペクトします。

## Setting
```vim
map f <Plug>(flying-f)
map F <Plug>(flying-F)
map t <Plug>(flying-t)
map T <Plug>(flying-T)
```

## Usage
`f` キーで検索モードに入ります。文字を打つごとにマッチする場所にジャンプします（現在位置はマッチ対象に含みません）。マッチする場所がないときや `<Esc>` 、`<CR>` などの関係ないキーが押されたときには検索モードを終了します。

検索モード中に、`<C-f>` ／ `<C-b>` で次のマッチ／前のマッチにジャンプします。入力がない状態で `<C-f>` ／ `<C-b>` を呼び出すと、以前の検索で使った文字列で検索します。

## Author
seroqn

## License
MIT