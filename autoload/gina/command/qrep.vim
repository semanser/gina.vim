let s:Console = vital#gina#import('Vim.Console')
let s:Guard = vital#gina#import('Vim.Guard')


function! gina#command#qrep#call(range, args, mods) abort
  let git = gina#core#get_or_fail()
  let args = s:build_args(git, a:args)

  call gina#util#doautocmd('QuickfixCmdPre')
  let result = gina#core#process#call(git, args)
  let guard = s:Guard.store(['&more'])
  try
    set nomore
    call gina#core#process#inform(result)

    let items = map(
          \ result.content,
          \ 's:parse_record(git, v:val)',
          \)
    call setqflist(
          \ filter(items, '!empty(v:val)'),
          \ args.params.action,
          \)
  finally
    call guard.restore()
  endtry
  call gina#util#doautocmd('QuickfixCmdPost')
  if !args.params.bang
    cc
  endif
endfunction


" Private --------------------------------------------------------------------
function! s:build_args(git, args) abort
  let args = gina#command#parse_args(a:args)
  let args.params = {}
  let args.params.bang = args.get(0) =~# '!$'
  let args.params.action = args.pop('--action', ' ')
  let args.params.pattern = args.pop(1, '')
  let args.params.commit = args.pop(1, '')

  " Check if available grep patterns has specified and ask if not
  if empty(args.params.pattern) && !(args.has('-e') || args.has('-f'))
    let pattern = s:Console.ask('Pattern: ')
    if empty(pattern)
      throw gina#core#exception#info('Cancel')
    endif
    let args.params.pattern = pattern
  endif

  call args.set('--line-number', 1)
  call args.set('--color', 'always')
  call args.set(0, 'grep')
  call args.set(1, args.params.pattern)
  call args.set(2, args.params.commit)
  return args.lock()
endfunction

function! s:parse_record(git, record) abort
  " Parse record to make a gina candidate and translate it to a quickfix item
  let candidate = gina#command#grep#parse_record(a:git, a:record)
  if empty(candidate)
    return {}
  endif
  return {
        \ 'filename': candidate.path,
        \ 'text': candidate.word,
        \ 'lnum': candidate.line,
        \ 'col': candidate.col,
        \}
endfunction