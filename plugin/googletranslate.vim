" vim:set ts=8 sts=2 sw=2 tw=0:
"
" googletranslate.vim - Translate between English and Locale Language
" using Google
" @see [http://code.google.com/apis/ajaxlanguage/ Google AJAX Language API]
"
" Author:	Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Contribute:	hotoo (闲耘™)
" Contribute:	MURAOKA Taro <koron.kaoriya@gmail.com>
" Based On:     excitetranslate.vim
" Last Change:	29-Nov-2011.

if !exists('g:googletranslate_options')
  let g:googletranslate_options = ["register","buffer"]
endif
" default language setting.
if !exists('g:googletranslate_locale')
  let g:googletranslate_locale = substitute(v:lang, '^\([a-z]*\).*$', '\1', '')
endif

let s:endpoint = 'http://ajax.googleapis.com/ajax/services/language/translate'

function! s:CheckLang(word)
  let all = strlen(a:word)
  let eng = strlen(substitute(a:word, '[^\t -~]', '', 'g'))
  return eng * 2 < all ? '' : 'en'
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

function! s:quote(s)
  let q = '"'
  if &shellxquote == '"'
    let q = "'"
  endif
  return q.a:s.q
endfunction

function! GoogleTranslate(word, from, to)
  let mode = a:from . "|" . a:to
  if exists("g:googletranslate_userip") == 0
    redraw
    echohl ErrorMsg
    echomsg "Google Translate changed term to use APIs."
    echomsg "If you want to use this plugin continued,"
    echomsg "Please set your internet IP address to `g:googletranslate_userip`."
    echomsg "see also http://code.google.com/intl/ja/apis/language/translate/v1/using_rest_translate.html#json_args"
    echohl None
    return ''
  endif
  let res = http#get(s:endpoint, {"v": "1.0", "langpair": mode, "q": a:word, "userip": g:googletranslate_userip})
  let obj = json#decode(res.content)
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
  let curline = a:firstline
  let strline = ''

  if a:0 >= 3
    let strline = a:3
  else
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

  let from = ''
  let to = g:googletranslate_locale
  if a:0 == 0
    let from = s:CheckLang(strline)
    let to = 'en'==from ? g:googletranslate_locale : 'en'
  elseif a:0 == 1
    let to = a:1
  elseif a:0 >= 2
    let from = a:1
    let to = a:2
  endif

  " Do translate.
  let jstr = GoogleTranslate(strline, from, to)
  if len(jstr) == 0
    return
  endif

  " Echo
  if index(g:googletranslate_options, 'echo') != -1
    echo jstr
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
      call setline(1, jstr)
    else
      call append(line('$'), '--------')
      call append(line('$'), jstr)
    endif
    normal! Gzt
  endif
  " Put to unnamed register.
  if index(g:googletranslate_options, 'register') != -1
    let @" = jstr
  endif
endfunction

command! -nargs=* -range GoogleTranslate <line1>,<line2>call GoogleTranslateRange(<f-args>)
command! -nargs=* -range Trans <line1>,<line2>call GoogleTranslateRange(<f-args>)
