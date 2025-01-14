" Global variables
if !exists('g:obsidian_cache')
    let g:obsidian_cache = {}
endif
if !exists('g:obsidian_vault_path')
    let g:obsidian_vault_path = ''
endif
if !exists('g:obsidian_vault_name')
    let g:obsidian_vault_name = ''
endif
"if !exists('g:obsidian#load_vault_path')
"    let g:obsidian#load_vault_path = 1
"endif

" You can also add this to your vimrc or init.vim
" autocmd VimEnter * call obsidian#load_vault_path()


" Load the vault path from cache or prompt for one 
function! obsidian#load_vault_path()
    if !exists('g:obsidian_vault_path') || g:obsidian_vault_path == ''
        let json_data = s:read_json()
        if has_key(json_data, 'vault_path')
            let g:obsidian_vault_path = json_data['vault_path']
        else
            " If no path found, prompt for one or handle accordingly
            call obsidian#set_vault_path()
        endif
    endif
endfunction


" Commands
" Helper function to cache file information
function! s:cache_file_info(file)
    let full_path = g:obsidian_vault_path . a:file
    try
        let lines = readfile(full_path)
        let yaml_start = match(lines, '^---$')
        let yaml_end = match(lines, '^---$', yaml_start + 1)
        if yaml_start != -1 && yaml_end != -1
            let g:obsidian_cache[a:file] = {
            \   'yaml': lines[yaml_start+1 : yaml_end-1]
            \}
        else
            let g:obsidian_cache[a:file] = {'yaml': []}
        endif
    catch /^Vim\%((\a\+)\)\=:E484/
        echoerr "Error reading file: " . full_path
    endtry
endfunction

" Constants for JSON handling
let s:json_file = expand('~/.obsidian.json')

" Helper function to write to JSON file
function! s:write_json(data)
    let lines = ['{']
   " call add(lines, '{')
    for key in keys(a:data)
        " Ensure the JSON string is properly escaped
        let escaped_value = substitute(a:data[key], '\(["\\]\)', '\\\\\1', 'g')
        call add(lines, printf('  "%s": "%s",', key, escaped_value))
    endfor
    if !empty(lines)
        let lines[-1] = substitute(lines[-1], ',$', '', '')  " Remove trailing comma
    endif
    call add(lines, '}')
    try
        call writefile(lines, s:json_file, 'b')
    catch /^Vim\%((\a\+)\)\=:E484/
     echoerr "Error writing to " . s:json_file . ": " . v:exception
    endtry
endfunction

" Helper function to read from JSON file
function! s:read_json()
    if filereadable(s:json_file)
        let lines = readfile(s:json_file)
        let data = {}
        for line in lines
            let match = matchlist(line, '\v\s*"([^"]+)":\s*"([^"]+)"')
            if !empty(match)
                let data[match[1]] = match[2]
            endif
        endfo
        return data
    endif
    return {}
endfunction

" Set the vault path, either from cache, .obsidian.json, or new input
function! obsidian#set_vault_path()
    " Check if vault path is already cached
    if exists('g:obsidian_vault_path') && g:obsidian_vault_path != ''
        return
    endif

" Try to read from .obsidian.json
    let json_data = s:read_json()
    if has_key(json_data, 'vault_path')
        let g:obsidian_vault_path = json_data['vault_path']
        " Ensure there's exactly one trailing slash for consistency
        if g:obsidian_vault_path[-1:] != '/'
            let g:obsidian_vault_path .= '/'
        endif
        return
    endif

" If no cache or JSON file, prompt user for vault path
    let vault_name = input("Enter existing vault name or path: ")
    if vault_name != ''
        let g:obsidian_vault_path = expand(vault_name . '/')
        " Save to JSON for future use
        call s:write_json({'vault_path': g:obsidian_vault_path})
    else
        echo "No vault path provided."
    endif
endfunction

" Main dashboard
function! obsidian#dashboard()
  call obsidian#load_vault_path() " Ensure vault path is set
  if g:obsidian_vault_path == ''
        echoerr "No vault path set. Please create a vault first."
        return
    endif

    " Check if NERDTree is installed, use 'silent' to suppress NERDTree messages
    " if used
    if exists(":NERDTree")
         exe 'NERDTree ' . g:obsidian_vault_path
    else
        " Use Vim's built-in Explore as a fallback
         exe 'Explore ' . g:obsidian_vault_path
    endif

    " Only split if not already in a dashboard buffer    
    if &buftype != 'nofile' || expand('%:t') != 'ObsidianDashboard'
    vsplit 
    endif

    " Set up the dashboard buffer
    setlocal buftype=nofile bufhidden=hide noswapfile nowrap
    setlocal modifiable
    silent %delete _

    " Frame the buffer to indicate Obsidian dashboard
    call append(0, repeat('=', 50))
    call append(1, ' Obsidian Dashboard')
    call append(2, repeat('=', 50))
    call append(3, 'Vault: ' . g:obsidian_vault_path)

    " Add some useful information or commands here if needed
    if exists(":NERDTree")
        call append(4, ' - Navigate using NERDTree')
    else
        call append(4, ' - Navigate using Netrw')
    endif
    call append(5, ' - Use :ObsidianLinkNotes to see connections')
    call append(6, ' - Use :ObsidianNewFile for new notes')
    call append(7, ' - Use :ObsidianNewFolder for new folders')
    call append(8, ' - Use :ObsidianCreateVault for new vaults')
    call append(9, ' - Use :ObsidianSetVaultPath to change vaults')
    call append(10, ' - Use :ObsidianDashboard to refresh this buffer')
    call append(11, ' - Use q to close this buffer')
    call append(12, ' - Use :ObsidianHelp for more information')
    call append(13, ' - set mouse=a to enable mouse support')

    setlocal nomodifiable
    nnoremap <buffer> <silent> q :bd<CR>  " Close the dashboard buffer with 'q'

    " Populate cache
    let files = globpath(g:obsidian_vault_path, '**/*.md', 0, 1)
    for file in files
        call s:cache_file_info(file)
    endfor
endfunction

" Create a new vault
function! obsidian#create_vault()
    try
        let vault_name = input("Enter new vault name: ")
        if vault_name != ''
            let vault_path = expand('~/') . vault_name . '/'
            call mkdir(vault_path, 'p')
            let g:obsidian_vault_path = vault_path
            echo "New vault created at " . vault_path
            " Save to JSON for future use
            call s:write_json({'vault_path': g:obsidian_vault_path})
        else
            echo "No vault name provided."
        endif
    catch /^Vim\%((\a\+)\)\=:E739/
        echoerr "Cannot create directory: Permission denied."
    endtry
    
endfunction

" Create a new markdown file
function! obsidian#new_md_file()
    if g:obsidian_vault_path == ''
        echoerr "No vault path set. Please create a vault first."
        return
    endif
    try
        let name = input("Enter new markdown file name: ")
        if name != ''
            let full_path = g:obsidian_vault_path . name . '.md'
            exe 'edit ' . full_path
            write
        else
            echo "No file name provided."
        endif
    catch /^Vim\%((\a\+)\)\=:E484/
        echoerr "Cannot create file: Permission denied or file already exists."
    endtry
endfunction

" Create a new folder
function! obsidian#new_folder()
    let folder_name = input("Enter new folder name: ")
    if folder_name != ''
        let full_path = g:obsidian_vault_path . folder_name
        call mkdir(full_path, 'p')
        echo "Folder created at " . full_path
    else
        echo "No folder name provided."
    endif
endfunction

" Link notes
function! obsidian#link_notes()
    " Search for YAML front matter
    let yaml_start = search('^---$', 'nw')
    if yaml_start == 0
        return
    endif

    let yaml_end = search('^---$', 'nW')
    if yaml_end == 0
        return
    endif

    " Extract YAML content
    let yaml_content = getline(yaml_start + 1, yaml_end - 1)

    " Parse YAML for links (this would need a real YAML parser for robustness)
    for line in yaml_content
        if line =~? 'tags:' || line =~? 'links:'
            " Here you'd parse the actual tags or links.
            " For simplicity, let's just echo what we find:
            echo line
        endif
    endfor
endfunction

    " TODO: Implement actual linking by searching other files for matching tags or links



