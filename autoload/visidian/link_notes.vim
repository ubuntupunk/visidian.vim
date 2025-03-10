"autoload/visidian/link_notes.vim

" FUNCTION: Check if yaml parser is available
function! s:yaml_parser_available()
    return exists('*yaml#decode')
endfunction

" FUNCTION: Simple YAML parser fallback
function! s:simple_yaml_parse(text)
    let yaml = {'tags': [], 'links': []}
    let lines = split(a:text, "\n")
    
    for line in lines
        " Skip empty lines and comments
        if line =~ '^\s*$' || line =~ '^\s*#'
            continue
        endif
        
        " Match key: value or key: [value1, value2]
        let matches = matchlist(line, '^\s*\(\w\+\):\s*\(\[.\{-}\]\|\S.\{-}\)\s*$')
        if !empty(matches)
            let key = matches[1]
            let value = matches[2]
            
            " Handle arrays
            if value =~ '^\['
                let value = split(substitute(value[1:-2], '\s', '', 'g'), ',')
            endif
            
            let yaml[key] = value
        endif
    endfor
    
    return yaml
endfunction

" FUNCTION: Get YAML front matter with fallback
function! s:get_yaml_front_matter(file)
    if g:visidian_debug
        call visidian#debug#trace('LINK', 'Reading YAML from: ' . a:file)
    endif

    try
        let lines = readfile(a:file)
        let yaml_text = []
        let in_yaml = 0
        let yaml_end = 0
        
        " Check if file starts with YAML frontmatter
        if len(lines) > 0 && lines[0] =~ '^---\s*$'
            let in_yaml = 1
            for line in lines[1:]
                if line =~ '^---\s*$'
                    let yaml_end = 1
                    break
                endif
                call add(yaml_text, line)
            endfor
        endif
        
        " Return empty YAML if no frontmatter found
        if !yaml_end
            return {'tags': [], 'links': []}
        endif
        
        let yaml_str = join(yaml_text, "\n")
        let yaml = {}
        
        " Try using yaml#decode if available
        if exists('*yaml#decode')
            try
                let yaml = yaml#decode(yaml_str)
            catch
                " Silently fall back to simple parser
                let yaml = {}
            endtry
        endif
        
        " If yaml#decode failed or wasn't available, use simple parser
        if empty(yaml)
            let yaml = s:simple_yaml_parse(yaml_str)
        endif
        
        " Ensure required fields exist
        let yaml.tags = get(yaml, 'tags', [])
        let yaml.links = get(yaml, 'links', [])
        
        return yaml
    catch
        return {'tags': [], 'links': []}
    endtry
endfunction

" FUNCTION: Create markdown link
function! s:create_markdown_link(file)
    let title = fnamemodify(a:file, ':t:r')
    let rel_path = fnamemodify(a:file, ':.')
    return '[' . title . '](' . rel_path . ')'
endfunction

" FUNCTION: Parse and normalize YAML link
function! s:parse_yaml_link(link)
    let link = a:link
    let type = 'internal-markdown'
    
    " Handle quoted links
    if link =~ '^".*"$' || link =~ "^'.*'$"
        let link = link[1:-2]
    endif
    
    " Handle external links
    if link =~ '^https\?://'
        let type = 'external-markdown'
        return {'type': type, 'path': link, 'display': link}
    endif
    
    " Handle expanded vault paths
    if link =~ '^\$VAULT_PATH:'
        let expanded = substitute(link, '^\$VAULT_PATH:', g:visidian_vault_path, '')
        return {'type': 'internal-markdown', 'path': expanded, 'display': link}
    endif
    
    " Handle internal markdown links
    if link =~ '^\.\./' || link =~ '^\./'
        return {'type': 'internal-markdown', 'path': link, 'display': fnamemodify(link, ':t:r')}
    endif
    
    " Default to internal markdown
    return {'type': 'internal-markdown', 'path': link, 'display': link}
endfunction

" FUNCTION: Handle YAML link click
function! s:handle_yaml_link(link_info)
    let link = a:link_info
    call visidian#debug#debug('LINK', 'Handling YAML link: ' . string(link))
    
    if link.type == 'external-markdown'
    call visidian#debug#info('LINK', 'Opening external link: ' . link.path)
        " Open external links in browser
        if has('unix')
            call system('xdg-open ' . shellescape(link.path) . ' &')
        elseif has('macunix')
            call system('open ' . shellescape(link.path) . ' &')
        elseif has('win32')
            call system('start ' . shellescape(link.path))
        endif
    else
        " Handle internal links
        if link.path =~ '^\$VAULT_PATH:'
            let target = substitute(link.path, '^\$VAULT_PATH:', g:visidian_vault_path, '')
        else
            let current_dir = expand('%:p:h')
            let target = resolve(current_dir . '/' . link.path)
        endif
        
        call visidian#debug#debug('LINK', 'Resolved internal link target: ' . target)
        
        if filereadable(target)
            execute 'edit ' . fnameescape(target)
        else
            call visidian#debug#error('LINK', 'Link target not found: ' . target)
            echohl WarningMsg
            echo "Link target not found: " . target
            echohl None
        endif
    endif
endfunction

" FUNCTION: Update buffer after YAML changes
function! s:update_buffer()
    " Save current view
    let view = winsaveview()
    
    " Reload buffer
    edit
    
    " Restore view
    call winrestview(view)
endfunction

" FUNCTION: Link Notes
function! visidian#link_notes#link_notes()
    " Check if vault exists
    if empty(g:visidian_vault_path)
        call visidian#debug#error('LINK', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please create or set a vault first."
        echohl None
        return 0
    endif

    " Normalize vault path
    let vault_path = substitute(g:visidian_vault_path, '[\/]\+$', '', '')
    if g:visidian_debug
        call visidian#debug#debug('LINK', 'Using vault path: ' . vault_path)
    endif

    " Get all markdown files in the vault
    let vault_files = []
    for para_folder in ['Projects', 'Areas', 'Resources', 'Archive']
        let folder_path = vault_path . '/' . para_folder
        if isdirectory(folder_path)
            let folder_files = glob(folder_path . '/**/*.md', 0, 1)
            let vault_files += folder_files
        endif
    endfor

    if empty(vault_files)
        if g:visidian_debug
            call visidian#debug#warn('LINK', 'No markdown files found in vault')
        endif
        echohl WarningMsg
        echo "No markdown files found in vault."
        echohl None
        return 0
    endif

    " Get current file path
    let current_file = expand('%:p')
    if current_file !~# '\.md$'
        call visidian#debug#error('LINK', 'Current file is not markdown: ' . current_file)
        echohl ErrorMsg
        echo "Current file is not a markdown file."
        echohl None
        return 0
    endif

    " Remove current file from the list
    let vault_files = filter(vault_files, 'v:val !=# current_file')

    if empty(vault_files)
        if g:visidian_debug
            call visidian#debug#warn('LINK', 'No other markdown files found in vault')
        endif
        echohl WarningMsg
        echo "No other markdown files found in vault."
        echohl None
        return 0
    endif

    " Ask user for link type
    echo "\nLink Type:"
    echo "1. YAML frontmatter link (metadata)"
    echo "2. Markdown link (in content)"
    echo "q. Cancel"
    
    let choice = input("\nEnter choice (1/2/q): ")
    echo "\n"
    
    if choice == 'q'
        echo "Operation cancelled."
        call visidian#debug#info('LINK', 'Link operation cancelled by user')
        return 0
    endif

    " Get current file's YAML if needed
    let current_yaml = {}
    if choice == '1'
        try
            let current_yaml = s:get_yaml_front_matter(current_file)
            call visidian#debug#debug('LINK', 'Loaded YAML front matter for current file')
        catch
        call visidian#debug#warn('LINK', 'Failed to load YAML front matter, using empty default')
            let current_yaml = {'tags': [], 'links': []}
        endtry
    endif

    " Weight and sort potential links
    call visidian#debug#debug('LINK', 'Weighting and sorting potential links')
    let weighted_files = s:weight_and_sort_links(current_yaml, vault_files)

    " Present top matches to user
    let max_suggestions = 10
    let top_matches = weighted_files[0:max_suggestions-1]
    
    echo "Select file to link (0 to cancel):"
    let i = 1
    for [file, weight] in top_matches
        let display_name = fnamemodify(file, ':t')
        echo printf("%d. %s", i, display_name)
        let i += 1
    endfor

    let selection = input("\nEnter number: ")
    if selection == '0' || selection == ''
        echo "\nOperation cancelled."
        call visidian#debug#info('LINK', 'Link operation cancelled by user')
        return 0
    endif

    let idx = str2nr(selection) - 1
    if idx >= 0 && idx < len(top_matches)
        let selected_file = top_matches[idx][0]
        
        if choice == '1'
            " Update YAML frontmatter
            call visidian#debug#debug('LINK', 'Updating YAML frontmatter')
            let links = get(current_yaml, 'links', [])
            let current_dir = fnamemodify(current_file, ':h')
            let target_path = fnamemodify(selected_file, ':p')
            let new_link = s:get_relative_path(current_dir, target_path)
            if index(links, new_link) == -1
                call add(links, new_link)
                let current_yaml['links'] = links
                call s:update_yaml_frontmatter(current_file, current_yaml)
                call s:update_buffer()
                call visidian#debug#info('LINK', 'Added YAML link to ' . new_link)
                echo "\nAdded YAML link to " . new_link
            else
                call visidian#debug#info('LINK', 'Link already exists in YAML frontmatter')
                echo "\nLink already exists in YAML frontmatter."
            endif
        else
            " Insert markdown link at cursor
            call visidian#debug#debug('LINK', 'Inserting markdown link at cursor')
            let md_link = s:create_markdown_link(selected_file)
            let pos = getpos('.')
            call append(pos[1], md_link)
            if g:visidian_debug
                call visidian#debug#info('CORE', 'Added markdown link: ' . md_link)
            endif
            echo "\nInserted markdown link: " . md_link
        endif
        
        return 1
    else
        echo "\nInvalid selection."
        call visidian#debug#info('LINK', 'Invalid selection')
        return 0
    endif
endfunction

" FUNCTION: Update YAML frontmatter in file
function! s:update_yaml_frontmatter(file, yaml)
    call visidian#debug#debug('LINK', 'Updating YAML frontmatter in: ' . a:file)
    let lines = readfile(a:file)
    let new_lines = []
    let in_yaml = 0
    let links_updated = 0
    
    " Process the file line by line
    let i = 0
    while i < len(lines)
        let line = lines[i]
        
        " Handle YAML frontmatter
        if line =~ '^---\s*$'
            if !in_yaml
                " Start of YAML block
                let in_yaml = 1
                call add(new_lines, line)
            else
                " End of YAML block - add links if not added yet
                if !links_updated && has_key(a:yaml, 'links')
                    call add(new_lines, 'links: [' . join(a:yaml.links, ', ') . ']')
                    let links_updated = 1
                endif
                call add(new_lines, line)
                let in_yaml = 0
            endif
        elseif in_yaml
            " Inside YAML block
            if line =~ '^\s*links:'
                " Skip existing links line
                let links_updated = 1
            else
                " Keep all other YAML lines
                call add(new_lines, line)
            endif
        else
            " Outside YAML block - copy line as is
            call add(new_lines, line)
        endif
        
        let i += 1
    endwhile
    
    " Write back to file
    call writefile(new_lines, a:file)
endfunction

" FUNCTION: Create link in current file
function! s:create_link(target_file, current_file)
    try
        let current_yaml = s:get_yaml_front_matter(a:current_file)
        let target_yaml = s:get_yaml_front_matter(a:target_file)
        
        " Get relative path from current file to target
        let current_dir = fnamemodify(a:current_file, ':h')
        let target_path = fnamemodify(a:target_file, ':p')
        let relative_path = s:get_relative_path(current_dir, target_path)
        
        " Get target title from YAML or filename
        let target_title = get(target_yaml, 'title', fnamemodify(a:target_file, ':t:r'))
        
        " Create link based on user's choice
        let choice = s:prompt_link_type()
        if choice == 1 " YAML frontmatter
            " Add to links array if not already present
            if index(current_yaml.links, relative_path) == -1
                call add(current_yaml.links, relative_path)
                call s:update_yaml_frontmatter(a:current_file, current_yaml)
                echo "Added YAML link to " . relative_path
            else
                echo "Link already exists in YAML frontmatter"
            endif
        elseif choice == 2 " Markdown link
            " Insert markdown link at cursor
            let link_text = '[' . target_title . '](' . relative_path . ')'
            call append(line('.'), link_text)
            echo "Added markdown link: " . link_text
        endif
        
        return 1
    catch
        echohl ErrorMsg
        echo "Failed to create link: " . v:exception
        echohl None
        return 0
    endtry
endfunction

" FUNCTION: Get YAML front matter
function! s:get_yaml_front_matter(file)
    try
        let lines = readfile(a:file)
        let yaml_text = []
        let in_yaml = 0
        let yaml_end = 0
        
        for line in lines
            if line =~ '^---\s*$'
                if !in_yaml
                    let in_yaml = 1
                    continue
                else
                    let yaml_end = 1
                    break
                endif
            endif
            if in_yaml
                call add(yaml_text, line)
            endif
        endfor
        
        if !yaml_end
            throw 'No valid YAML front matter found'
        endif
        
        let yaml = yaml#decode(join(yaml_text, "\n"))
        return yaml
    catch
        return {'tags': [], 'links': []}
    endtry
endfunction

" FUNCTION: Weight and sort potential links
function! s:weight_and_sort_links(current_yaml, all_files)
    let weights = {}
    let tags = get(a:current_yaml, 'tags', [])
    let links = get(a:current_yaml, 'links', [])
    
    for file in a:all_files
        try
            let yaml = s:get_yaml_front_matter(file)
            let file_tags = get(yaml, 'tags', [])
            let file_links = get(yaml, 'links', [])
            
            " Calculate weight based on shared tags and links
            let weight = 0
            
            " Tag matching
            for tag in tags
                if index(file_tags, tag) >= 0
                    let weight += 2
                endif
            endfor
            
            " Link matching
            for link in links
                if index(file_links, link) >= 0
                    let weight += 1
                endif
            endfor
            
            " Always give some weight to make sure file appears in list
            let weight += 1
            let weights[file] = weight
            
        catch
            " Don't stop on parsing errors, just give minimal weight
            let weights[file] = 1
            continue
        endtry
    endfor

    " Sort files by weight
    let sorted = []
    for [file, weight] in items(weights)
        call add(sorted, [file, weight])
    endfor
    
    " Sort in descending order of weight
    return reverse(sort(sorted, {a, b -> a[1] - b[1]}))
endfunction

" FUNCTION: Get relative path
function! s:get_relative_path(current_dir, target_path)
    let target_dir = fnamemodify(a:target_path, ':h')
    let rel_path = substitute(a:target_path, '^' . a:current_dir . '/', '', '')
    if target_dir == a:current_dir
        return rel_path
    else
        return '../' . rel_path
    endif
endfunction

" FUNCTION: Prompt link type
function! s:prompt_link_type()
    echo "\nLink Type:"
    echo "1. YAML frontmatter link (metadata)"
    echo "2. Markdown link (in content)"
    echo "q. Cancel"
    
    let choice = input("\nEnter choice (1/2/q): ")
    echo "\n"
    
    if choice == 'q'
        echo "Operation cancelled."
        return 0
    endif
    
    return str2nr(choice)
endfunction

" FUNCTION: Click YAML link under cursor
function! visidian#link_notes#click_yaml_link()
    " Get current line
    let line = getline('.')
    let col = col('.')
    
    " Check if we're in YAML frontmatter
    let in_yaml = 0
    let yaml_end = 0
    let lnum = 1
    
    while lnum <= line('$')
        let l = getline(lnum)
        if l =~ '^---\s*$'
            if !in_yaml
                let in_yaml = 1
            else
                let yaml_end = 1
                break
            endif
        endif
        let lnum += 1
    endwhile
    
    if !in_yaml || yaml_end
        echo "Not in YAML frontmatter"
        return
    endif
    
    " Extract link from current line
    let matches = matchlist(line, '^\s*\(\w\+\):\s*\(\[.\{-}\]\|\S.\{-}\)\s*$')
    if !empty(matches) && matches[1] == 'links'
        let value = matches[2]
        if value =~ '^\['
            " Handle array of links
            let links = split(substitute(value[1:-2], '\s', '', 'g'), ',')
            " Find which link the cursor is on
            let pos = 0
            for link in links
                let start = stridx(line, link, pos)
                let end = start + len(link)
                if col >= start && col <= end
                    call s:handle_yaml_link(s:parse_yaml_link(link))
                    return
                endif
                let pos = end
            endfor
        else
            " Single link
            call s:handle_yaml_link(s:parse_yaml_link(value))
        endif
    endif
endfunction
