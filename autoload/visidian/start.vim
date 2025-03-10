" Visidian First Start
" Maintainer: ubuntupunk
" License: GPL3

function! visidian#start#welcome() abort
    " Force immediate redraw
    redraw!
    
    " Create welcome message
    let welcome = [
        \ '   __   ___     _     _ _             ',
        \ '   \ \ / (_)___(_) __| (_) __ _ _ __  ',
        \ '    \ V /| / __| |/ _` | |/ _` | ''_ \ ',
        \ '     | | | \__ \ | (_| | | (_| | | | |',
        \ '     |_| |_|___/_|\__,_|_|\__,_|_| |_|',
        \ '',
        \ '    Welcome to Visidian - Your Vim-based Personal Knowledge Management System',
        \ '    Version: ' . get(g:, 'visidian_version', 'development'),
        \ '',
        \ '    This guide will help you set up Visidian for the first time.',
        \ '    Press any key to continue...'
        \ ]
    
    " Display welcome message in a popup
    let winid = popup_create(welcome, {
        \ 'title': ' Visidian Setup ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'close': 'click',
        \ 'focusable': 1,
        \ })
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Displayed welcome message')
    call getchar()
    call popup_close(winid)
endfunction

function! visidian#start#check_dependencies() abort
    let missing_deps = []
    
    " Check for required plugins
    if !exists('*fzf#run')
        call add(missing_deps, 'fzf.vim - for fuzzy finding')
    endif
    
    if !empty(missing_deps)
        let msg = [
            \ 'Some recommended dependencies are missing:',
            \ ''
            \ ] + missing_deps + [
            \ '',
            \ 'While Visidian will work without these,',
            \ 'installing them will enhance your experience.',
            \ '',
            \ 'Press any key to continue anyway...'
            \ ]
        
        let winid = popup_create(msg, {
            \ 'title': ' Dependencies ',
            \ 'padding': [1,2,1,2],
            \ 'border': [],
            \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
            \ 'pos': 'center',
            \ 'close': 'click',
            \ 'focusable': 1,
            \ })
        call win_execute(winid, 'redraw')
        call popup_setoptions(winid, {'focused': 1})
        
        call visidian#debug#info('START', 'Displayed missing dependencies: ' . string(missing_deps))
        call getchar()
        call popup_close(winid)
    endif
endfunction

" Track the current step in the setup process
let s:setup_step = 0

function! s:continue_setup() abort
    let s:setup_step += 1
    if s:setup_step == 1
        call visidian#start#setup_para()
    elseif s:setup_step == 2
        call visidian#start#create_note()
    elseif s:setup_step == 3
        call visidian#start#create_folder()
    elseif s:setup_step == 4
        call visidian#start#setup_sync()
    elseif s:setup_step == 5
        call visidian#start#customize()
    elseif s:setup_step == 6
        call visidian#start#finish()
    endif
endfunction

function! visidian#start#first_start() abort
    " Reset setup step
    let s:setup_step = 0
    
    " Force immediate screen refresh
    redraw!
    
    " Main onboarding function
    call visidian#debug#info('START', 'Beginning first-time setup')
    
    " Welcome screen
    call visidian#start#welcome()
    
    " Check dependencies
    call visidian#start#check_dependencies()
    
    " Setup vault
    call visidian#start#setup_vault()
endfunction

function! visidian#start#setup_vault() abort
    let msg = [
        \ 'First, lets set up your vault!',
        \ '',
        \ 'A vault is where all your notes will be stored.',
        \ 'You can either create a new vault or use an existing one.',
        \ '',
        \ 'Press:',
        \ '  [n] to create a New vault',
        \ '  [e] to select an Existing folder',
        \ '  [q] to Quit setup'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Vault Setup ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:vault_filter'),
        \ 'callback': function('s:vault_callback'),
        \ 'focusable': 1,
        \ })
    
    " Focus the popup immediately
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Displayed vault setup options')
endfunction

function! s:select_vault_path() abort
    " Try using browse() first
    if has('browse')
        let path = browse(0, 'Select Vault Directory', expand('~'), '')
    else
        " Fallback to input() in console mode
        echohl Question
        echo 'Enter vault path (or press Enter to cancel):'
        echohl None
        let path = input('Path: ', expand('~'), 'dir')
        redraw!
    endif
    return path
endfunction

function! s:vault_filter(winid, key) abort
    if a:key ==# 'n'
        call popup_close(a:winid)
        call visidian#create_vault()
        " After creating a new vault, show settings
        call visidian#start#show_settings()
        return 1
    elseif a:key ==# 'e'
        call popup_close(a:winid)
        let path = s:select_vault_path()
        if !empty(path)
            " Expand path immediately to handle ~ and environment variables
            let path = expand(path)
            " Ensure directory exists after expansion
            if !isdirectory(path)
                echohl Question
                echo 'Directory does not exist. Create it? (y/n)'
                echohl None
                let choice = nr2char(getchar())
                redraw!
                if choice ==? 'y'
                    call mkdir(path, 'p')
                else
                    call visidian#start#setup_vault()
                    return 1
                endif
            endif
            let g:visidian_vault_path = path
            call visidian#debug#info('START', 'Selected vault path: ' . path)
            " After selecting an existing vault, show settings
            call visidian#start#show_settings()
            return 1
        endif
        " If selection was cancelled, show vault setup again
        call visidian#start#setup_vault()
    elseif a:key ==# 'q'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! s:vault_callback(id, result) abort
    if !empty(g:visidian_vault_path)
        call visidian#debug#info('START', 'Vault setup completed successfully')
        " Continue with next step
        call timer_start(500, {-> s:continue_setup()})
    else
        call visidian#debug#error('START', 'Vault setup did not complete successfully')
    endif
endfunction

function! visidian#start#show_settings() abort
    let msg = [
        \ 'Settings have been loaded in the buffer.',
        \ 'Please review them before proceeding.',
        \ 'Press any key to continue...'
        \ ]
    let winid = popup_create(msg, {
        \ 'title': ' Settings Alert ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'close': 'click',
        \ 'focusable': 1,
        \ })
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    call getchar()
    call popup_close(winid)
    call s:continue_setup()
endfunction

function! visidian#start#setup_sync() abort
    let msg = [
        \ 'Sync Setup Options:',
        \ '',
        \ '  [1] Enable/Disable Sync',
        \ '  [2] Configure Sync Settings',
        \ '  [3] View Sync Status',
        \ '  [q] Quit and proceed with setup',
        \ '',
        \ 'Select an option:'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Sync Setup ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:sync_menu_filter'),
        \ 'focusable': 1,
        \ })
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Displayed sync setup options')
endfunction

function! s:sync_menu_filter(winid, key) abort
    if a:key ==# '1'
        call popup_close(a:winid)
        call visidian#toggle_auto_sync()
        call visidian#start#setup_sync()
        return 1
    elseif a:key ==# '2'
        call popup_close(a:winid)
        " Call sync configuration options from sync.vim
        call visidian#sync#sync()
        call s:continue_setup()
        return 1
    elseif a:key ==# '3'
        call popup_close(a:winid)
        " Placeholder for viewing sync status
        echo 'Viewing Sync Status...'
        call visidian#start#setup_sync()
        return 1
    elseif a:key ==# 'q'
        call popup_close(a:winid)
        call s:continue_setup()
        return 1
    endif
    return 0
endfunction

function! visidian#start#setup_para() abort
    let msg = [
        \ 'Would you like to set up PARA folders?',
        \ '',
        \ 'PARA is an organizational system that helps you',
        \ 'organize your notes into meaningful categories:',
        \ '',
        \ '  Projects - Active tasks and projects',
        \ '  Areas - Long-term responsibilities',
        \ '  Resources - Topics and interests',
        \ '  Archive - Completed and inactive items',
        \ '',
        \ 'Press:',
        \ '  [y] to create PARA folders',
        \ '  [n] to skip this step',
        \ '  [?] to learn more about PARA'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' PARA Setup ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:para_filter'),
        \ 'callback': {id, result -> timer_start(500, {-> s:continue_setup()})},
        \ 'focusable': 1,
        \ })
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Displayed PARA setup options')
endfunction

function! s:para_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        call visidian#create_para_folders()
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    elseif a:key ==# '?'
        call popup_close(a:winid)
        call visidian#help#show_para()
        return 1
    endif
    return 0
endfunction

function! visidian#start#create_note() abort
    let msg = [
        \ 'Would you like to create a new note?',
        \ '',
        \ 'Press:',
        \ '  [y] to create a new note',
        \ '  [n] to skip this step'
        \ ]
    let winid = popup_create(msg, {
        \ 'title': ' Create Note ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:note_filter'),
        \ 'callback': {id, result -> timer_start(500, {-> s:continue_setup()})},
        \ 'focusable': 1,
        \ })
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    call visidian#debug#info('START', 'Displayed create note options')
endfunction

function! s:note_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        " Prompt user to provide a path or browse to a directory
        let path = input('Enter the directory path for the new note: ', expand('~'), 'dir')
        if !empty(path)
            let path = expand(path)
            if !isdirectory(path)
                echohl Question
                echo 'Directory does not exist. Create it? (y/n)'
                echohl None
                let choice = nr2char(getchar())
                redraw!
                if choice ==? 'y'
                    call mkdir(path, 'p')
                else
                    echo 'Note creation cancelled.'
                    return 1
                endif
            endif
            " Set the path for the new note
            let g:visidian_note_path = path
            call visidian#new_md_file()
        else
            echo 'Note creation cancelled.'
        endif
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! visidian#start#create_folder() abort
    let msg = [
        \ 'Would you like to create a new folder?',
        \ '',
        \ 'Press:',
        \ '  [y] to create a new folder',
        \ '  [n] to skip this step'
        \ ]
    let winid = popup_create(msg, {
        \ 'title': ' Create Folder ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:folder_filter'),
        \ 'callback': {id, result -> timer_start(500, {-> s:continue_setup()})},
        \ 'focusable': 1,
        \ })
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    call visidian#debug#info('START', 'Displayed create folder options')
endfunction

function! s:folder_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        call visidian#new_folder()
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! visidian#start#import_notes() abort
    let msg = [
        \ 'Would you like to import existing notes?',
        \ '',
        \ 'Visidian can help organize your existing markdown',
        \ 'files into the PARA structure.',
        \ '',
        \ 'Press:',
        \ '  [y] to import and organize notes',
        \ '  [n] to skip this step'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Import Notes ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:import_filter'),
        \ 'callback': {id, result -> timer_start(500, {-> s:continue_setup()})},
        \ 'focusable': 1,
        \ })
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Displayed import options')
endfunction

function! s:import_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        call visidian#import_sort()
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! visidian#start#customize() abort
    let msg = [
        \ 'Would you like to view and customize settings?',
        \ '',
        \ 'A new buffer will open with all available settings.',
        \ 'You can copy the ones you want to your vimrc.',
        \ '',
        \ 'Press:',
        \ '  [y] to view settings (press any key to continue after viewing)',
        \ '  [n] to finish setup'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Settings ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:customize_filter'),
        \ 'callback': {id, result -> timer_start(500, {-> s:continue_setup()})},
        \ 'focusable': 1,
        \ })
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Displayed customization options')
endfunction

function! s:customize_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        " Open settings in a new buffer
        new
        file Visidian\ Settings
        setlocal buftype=nofile
        setlocal bufhidden=wipe
        setlocal noswapfile
        setlocal filetype=markdown
        
        " Add settings content
        call append(0, [
            \ '# Visidian Settings',
            \ '',
            \ '## Key Mappings',
            \ '```vim',
            \ '" Default prefix for all mappings',
            \ 'let g:visidian_map_prefix = "\v"',
            \ '```',
            \ '',
            \ '## Preview Options',
            \ '```vim',
            \ '" Enable/disable preview (1/0)',
            \ 'let g:visidian_preview_enabled = 1',
            \ '```',
            \ '',
            \ '## Auto-sync Settings',
            \ '```vim',
            \ '" Enable/disable auto-sync (1/0)',
            \ 'let g:visidian_autosync = 1',
            \ '```',
            \ '',
            \ '## Status Line',
            \ '```vim',
            \ '" Enable/disable status line integration (1/0)',
            \ 'let g:visidian_statusline = 1',
            \ '```',
            \ '',
            \ '# Instructions',
            \ '1. Review the settings above',
            \ '2. Copy desired settings to your vimrc',
            \ '3. Close this buffer when done (use :q)',
            \ '',
            \ 'Press any key to continue setup...'
            \ ])
        
        " Move cursor to top
        normal! gg
        
        " Wait for user to read and close the buffer
        while bufexists('%')
            redraw
            let char = getchar()
            if char != 0
                bwipeout
                break
            endif
            sleep 100m
        endwhile
        
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! visidian#start#finish() abort
    let msg = [
        \ 'Setup Complete!',
        \ '',
        \ 'You can now start using Visidian:',
        \ '',
        \ '  - Press \v to open the main menu',
        \ '  - Type :help visidian for documentation',
        \ '  - Visit our GitHub page for updates',
        \ '',
        \ 'Happy note-taking!',
        \ '',
        \ 'Press any key to close...'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' All Done! ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:finish_filter'),
        \ 'focusable': 1,
        \ })
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Setup completed')
endfunction

function! s:finish_filter(winid, key) abort
    call popup_close(a:winid)
    return 1
endfunction
