" vim:set ts=8 sts=2 sw=2 tw=0:
"
" googletranslate.vim - Translate between English and Japanese using Google
"
" Author:	Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Based On:     excitetranslate.vim
" Last Change:	28-Oct-2010.

if !exists('g:googletranslate_options')
  let g:googletranslate_options = ["register","buffer"]
endif

let s:endpoint = 'http://ajax.googleapis.com/ajax/services/language/translate'

function! s:CheckEorJ(word)
  let all = strlen(a:word)
  let eng = strlen(substitute(a:word, '[^\t -~]', '', 'g'))
  return eng * 2 < all ? 'ja|en' : 'en|ja'
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

function! GoogleTranslate(word, ...)
  let mode = a:0 >= 2 ? a:2 : s:CheckEorJ(a:word)
  let @a= mode
  " Makeup query data chunk
  let res = http#post(s:endpoint, {"v": "1.0", "langpair": mode, "q": a:word})
  let str = iconv(res.content, "utf-8", &encoding)
  let str = substitute(str, '\\u\(\x\x\x\x\)', '\=s:nr2enc_char("0x".submatch(1))', 'g')
  let str = substitute(str, '^window\.google\.ac\.h', '', '')
  let l:null = 0
  let l:true = 1
  let l:false = 0
  let obj = eval(str)
  return obj.responseData.translatedText
endfunction

function! GoogleTranslateRange() range
  " Concatenate input string.
  let curline = a:firstline
  let strline = ''
  while curline <= a:lastline
    let tmpline = substitute(getline(curline), '^\s\+\|\s\+$', '', 'g')
    if tmpline=~ '\m^\a' && strline =~ '\m\a$'
      let strline = strline .' '. tmpline
    else
      let strline = strline . tmpline
    endif
    let curline = curline + 1
  endwhile
  " Do translate.
  let jstr = GoogleTranslate(strline)
  " Put to buffer.
  if index(g:googletranslate_options, 'buffer') != -1
    " Open or go result buffer.
    let bufname = '==Translate== Google'
    let winnr = bufwinnr(bufname)
    if winnr < 1
      execute 'below new '.escape(bufname, ' ')
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

command! -nargs=0 -range GoogleTranslate <line1>,<line2>call GoogleTranslateRange()
