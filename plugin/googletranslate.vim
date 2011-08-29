" vim:set ts=8 sts=2 sw=2 tw=0:
"
" googletranslate.vim - Translate between English and Locale Language
" using Google
" @see [http://code.google.com/apis/ajaxlanguage/ Google AJAX Language API]
"
" Author:	Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Contribute:	hotoo (闲耘™)
" Based On:     excitetranslate.vim
" Last Change:	12-Nov-2010.

if !exists('g:googletranslate_options')
  let g:googletranslate_options = ["register","buffer"]
endif
if !exists("g:googletranslate_balloon")
  let g:googletranslate_balloon = 0
endif

let s:endpoint = 'http://ajax.googleapis.com/ajax/services/language/translate'
let s:detectpoint = 'http://ajax.googleapis.com/ajax/services/language/detect'
let s:langMap = {
    \ 'zh_cn' : 'zh-CN',
    \ 'zh_tw' : 'zh-TW',
    \ 'zh_hk' : 'zh-TW',
    \ 'zh-hk' : 'zh-TW',
    \ 'ja_jp' : 'ja'
  \ }
let s:localMap = {
      \ 'zh-CN' : 'gb2312',
      \ 'zh-TW' : 'gbk',
      \ 'ja' : 'JIS'
      \}

function! s:getLocal()
  let k = g:googletranslate_locale
  return has_key(s:localMap, k) ? s:localMap[k] : "utf-8"
endfunction
function! s:fixLang(lang)
  let lang = tolower(a:lang)
  return has_key(s:langMap, lang) ? s:langMap[lang] : a:lang
endfunction
" default language setting.
if !exists('g:googletranslate_locale')
  let g:googletranslate_locale = s:fixLang(substitute(v:lang, '^\([a-zA-Z_]*\).*$', '\1', ''))
endif

function! s:checkLang(word)
  let all = strlen(a:word)
  let eng = strlen(substitute(a:word, '[^\t -~]', '', 'g'))
  return eng * 2 < all ? '' : 'en'
endfunction
function! s:detectLang(word)
  try
    let oldshellredir=&shellredir
    setlocal shellredir=>
    " NOT support post for now.
    "let text = system('curl -s -d "v=1.0&q='.s:encodeURIComponent(a:word).'" ' . s:detectpoint)
    let text = system('curl -s "' . s:detectpoint.'?v=1.0&q='.s:encodeURIComponent(a:word).'"')
    let &shellredir=oldshellredir
    let text = iconv(text, "utf-8", &encoding)
    let text = substitute(text, '\\u\(\x\x\x\x\)', '\=s:nr2enc_char("0x".submatch(1))', 'g')
    let [null,true,false] = [0,1,0]
    let obj = eval(text)
    return obj.responseData.language
  catch /.*/
    return s:checkLang(a:word)
  endtry
endfunction

function! s:nr2byte(nr)
  if a:nr < 0x80
    return nr2char(a:nr)
  elseif a:nr < 0x800
    return nr2char(a:nr/64+192).nr2char(a:nr%64+128)
  else
    return nr2char(a:nr/4096%16+224).nr2char(a:nr/64%64+128).nr2char(a:nr%64+128)
  endif
endfunction

function! s:nr2enc_char(charcode)
  if &encoding == 'utf-8'
    return nr2char(a:charcode)
  endif
  let char = s:nr2byte(a:charcode)
  if strlen(char) > 1
    let char = strtrans(iconv(char, 'utf-8', &encoding))
  endif
  return char
endfunction

" @see http://vim.g.hatena.ne.jp/eclipse-a/20080707/1215395816
function! s:char2hex(c)
  if a:c =~# '^[:cntrl:]$' | return '' | endif
  let r = ''
  for i in range(strlen(a:c))
    let r .= printf('%%%02X', char2nr(a:c[i]))
  endfor
  return r
endfunction
function! s:encodeURI(s)
  return substitute(a:s, '[^0-9A-Za-z-._~!''()*#$&+,/:;=?@]',
        \ '\=s:char2hex(submatch(0))', 'g')
endfunction
function! s:encodeURIComponent(s)
  return substitute(a:s, '[^0-9A-Za-z-._~!''()*]',
        \ '\=s:char2hex(submatch(0))', 'g')
endfunction

function! GoogleTranslate(word, ...)
  if a:word==""
    return ""
  endif
  if !executable("curl")
    echohl WarningMsg
    echo "GoogleTranslate require 'curl' command."
    echohl None
    return ""
  endif

  let from = ''
  let to = g:googletranslate_locale
  if a:0 == 0
    let from = s:detectLang(a:word)
    let to = g:googletranslate_locale==?from || ''==from ? 'en' : g:googletranslate_locale
  elseif a:0 == 1
    let to = a:1
  elseif a:0 >= 2
    let from = a:1
    let to = a:2
  endif
  let from = s:fixLang(from)
  let to = s:fixLang(to)
  let mode = from . "|" . to

  let oldshellredir=&shellredir
  setlocal shellredir=>
  let text = system('curl -s -d "v=1.0&langpair='.mode.'&q='.s:encodeURIComponent(a:word).'" ' . s:endpoint)
  let &shellredir=oldshellredir
  let text = iconv(text, "utf-8", &encoding)
  let text = substitute(text, '\\u\(\x\x\x\x\)', '\=s:nr2enc_char("0x".submatch(1))', 'g')
  let [null,true,false] = [0,1,0]
  let obj = eval(text)
  if type(obj.responseData) == 4
    let text = obj.responseData.translatedText
    let text = substitute(text, '&gt;', '>', 'g')
    let text = substitute(text, '&lt;', '<', 'g')
    let text = substitute(text, '&quot;', '"', 'g')
    let text = substitute(text, '&apos;', "'", 'g')
    let text = substitute(text, '&nbsp;', ' ', 'g')
    let text = substitute(text, '&yen;', '\&#65509;', 'g')
    let text = substitute(text, '&#\(\d\+\);', '\=s:nr2enc_char(submatch(1))', 'g')
    let text = substitute(text, '&amp;', '\&', 'g')
    echomsg ''==from ? obj.responseData.detectedSourceLanguage.'|'.to : mode
  else
    if !has_key(obj, 'responseDetails')
      let obj.responseDetails = 'unknown server error'
    endif
    echohl WarningMsg
    echo obj.responseDetails
    echohl None
    let text = ''
  endif
  return text
endfunction

function! GoogleTranslateRange(...) range
  " Concatenate input string.
  let strline = ''

  if a:0 >= 3
    let strline = a:3
  else
    " TODO: get the (inline) select words.
    let curline = a:firstline
    while curline <= a:lastline
      let tmpline = substitute(getline(curline), '^\s\+\|\s\+$', '', 'g')
      if tmpline=~ '\m^\a' && strline =~ '\m\a$'
        let strline = strline .' '. tmpline
      else
        let strline = strline . tmpline
      endif
      let curline = curline + 1
    endwhile
  endif

  " Do translate.
  if a:0 == 0
    let jstr = GoogleTranslate(strline)
  elseif a:0 == 1
    let jstr = GoogleTranslate(strline, a:1)
  elseif a:0 >= 2
    let jstr = GoogleTranslate(strline, a:1, a:2)
  endif

  call <SID>outputTranslate(jstr)
endfunction
function! s:outputTranslate(jstr)
  if len(a:jstr) == 0
    return
  endif

  " Echo
  if index(g:googletranslate_options, 'echo') != -1
    echo a:jstr
  endif
  " Put to buffer.
  if index(g:googletranslate_options, 'buffer') != -1
    " Open or go result buffer.
    let bufname = '==Google Translate=='
    let winnr = bufwinnr(bufname)
    if winnr < 1
      silent execute 'below 10new '.escape(bufname, ' ')
      nmap <buffer> q :<c-g><c-u>bw!<cr>
      vmap <buffer> q :<c-g><c-u>bw!<cr>
    else
      if winnr != winnr()
	execute winnr.'wincmd w'
      endif
    endif
    setlocal buftype=nofile bufhidden=hide noswapfile wrap ft=
    " Append translated string.
    if line('$') == 1 && getline('$').'X' ==# 'X'
      call setline(1, a:jstr)
    else
      call append(line('$'), '--------')
      call append(line('$'), a:jstr)
    endif
    normal! Gzt
  endif
  " Put to unnamed register.
  if index(g:googletranslate_options, 'register') != -1
    let @" = a:jstr
  endif
endfunction

function! s:TranslateVisualText()
    let startline = line('v')
    let startcol = col('v')
    let endline = line('.')
    let endcol = col('.')
    let mode = mode()
    if mode==#'n' || (mode==#'v' && endline==startline && endcol==startcol)
      let str = getline('.') " Not selection range.
    elseif mode==#'V'
      if startline==endline
        let str = substitute(getline(startline), '\s\{2,}', ' ', 'g')
      else
        let str = substitute(join(getline(startline, endline), ' '), '\s\{2,}', ' ', 'g')
      endif
    elseif mode==#'v'
      if endline>startline || (endline==startline && endcol>startcol)
        let [startline, startcol, endline, endcol] = [startline, startcol, endline, endcol]
      else " if endline<startline || (endline==startline && endcol<startcol)
        " reversed selection range.
        let [startline, startcol, endline, endcol] = [endline, endcol, startline, startcol]
      endif
      let lines = getline(startline, endline)
      let lines[0] = strpart(lines[0], startcol-1)
      let lines[-1] = strpart(lines[-1], 0, startline==endline ? endcol-startcol : endcol-1)
      let str = substitute(join(lines, ' '), '\s\{2,}', ' ', 'g')
    else
      let str = ''
      return ''
    endif
    let jstr = GoogleTranslate(str)
    call <SID>outputTranslate(jstr)
    return ''
endfunction

function! GoogleTranslateBallooneval(flag)
  if a:flag == "on"
    let g:googletranslate_balloon = 1
    echo "Google Translate Balloon is On."
  elseif a:flag == "off"
    let g:googletranslate_balloon = 0
    echo "Google Translate Balloon is Off."
  endif
endfunction
function! GoogleTranslateBalloon()
  if !g:googletranslate_balloon
    return ""
  endif
  let mode = mode()
  let str = v:beval_text
  if mode ==# "n"
    let orig_pos = getpos(".")
    call setpos(".", [v:beval_bufnr, v:beval_lnum, v:beval_col])
    normal! viw"py
    let str = @p
    normal! \<Esc>
    call setpos(".", orig_pos)
  endif
  if str==""
    return ""
  endif
  let text = GoogleTranslate(str)
  let text = iconv(text, &encoding, s:getLocal())
  let str = iconv(str, &encoding, s:getLocal())
  return text . "\n-------------------\n" . str
endfunction
if has('balloon_eval')
  set ballooneval
  set balloondelay=400
  set balloonexpr=GoogleTranslateBalloon()
  "set balloonevalcode 59
endif

command! -nargs=* -range GoogleTranslate <line1>,<line2>call GoogleTranslateRange(<f-args>)
command! -nargs=* -range Trans <line1>,<line2>call GoogleTranslateRange(<f-args>)
command! -nargs=1 GoogleTranslateBalloon call GoogleTranslateBallooneval(<f-args>)
command! -nargs=1 TransBalloon call GoogleTranslateBallooneval(<f-args>)
vnoremap  <expr>  <leader>gt    <SID>TranslateVisualText()
