" visidian/autoload/image.vim

" Function: visidian#image#display_graph
" Description: Display a gnuplot graph in a vsplit buffer
" Parameters:
"   - data: List of [x, y] pairs to plot
"   - title: Title for the graph buffer (optional)
function! visidian#image#display_graph(data, ...)
    call visidian#debug#debug('IMAGE', 'Starting display_graph with data: ' . string(a:data))
    
    " Create temporary files with .dat and .png extensions
    let tempfile = tempname()
    let datafile = tempfile . '.dat'
    let pngfile = tempfile . '.png'
    let scriptfile = tempfile . '.gnuplot'

    " Write data to temporary file
    call writefile(map(copy(a:data), 'string(v:val[0]) . " " . string(v:val[1])'), datafile)

    " Generate gnuplot command with enhanced styling
    let plotcmd = 'set terminal png size 800,600 enhanced font "arial,10";'
    let plotcmd .= 'set output "' . pngfile . '";'
    let plotcmd .= 'set title "' . (a:0 > 0 ? a:1 : 'Statistics Graph') . '";'
    let plotcmd .= 'set xlabel "Categories";'
    let plotcmd .= 'set ylabel "Count";'
    let plotcmd .= 'set style data histogram;'
    let plotcmd .= 'set style fill solid;'
    let plotcmd .= 'plot "' . datafile . '" using 2:xticlabels(1) title "Count" with boxes'

    " Create gnuplot script
    call writefile([plotcmd], scriptfile)

    " Execute gnuplot and check for success
    let gnuplot_output = system('gnuplot ' . scriptfile)
    if v:shell_error != 0
        call visidian#debug#debug('IMAGE', 'Error running gnuplot: ' . gnuplot_output)
        return
    endif

    " Check if the PNG file was created
    if !filereadable(pngfile)
        call visidian#debug#debug('IMAGE', 'PNG file was not created: ' . pngfile)
        return
    endif

    " Create new vsplit buffer for the graph
    vsplit
    enew

    " Set buffer name
    let buffer_name = a:0 > 0 ? a:1 : 'GraphOutput'
    if buflisted(buffer_name)
        let buffer_name .= '_' . localtime()
    endif

    " Set buffer options before naming it
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal modifiable
    setlocal noreadonly
    setlocal bufhidden=wipe

    " Name the buffer
    execute 'silent file ' . buffer_name

    " Get terminal dimensions
    let width = winwidth(0)
    let height = winheight(0)

    " Check if we're in Kitty terminal
    if exists('$KITTY_WINDOW_ID') && executable('timg')
        " Use timg with Kitty protocol
        let timg_cmd = 'timg -pk --compress -g' . width . 'x' . height . ' --clear ' . pngfile
        let output = system(timg_cmd)
        
        if v:shell_error != 0
            call visidian#debug#debug('IMAGE', 'Error running timg with Kitty protocol: ' . output)
            " Try fallback to regular timg
            let timg_cmd = 'timg -g' . width . 'x' . height . ' --clear ' . pngfile
            let output = system(timg_cmd)
            
            if v:shell_error != 0
                call visidian#debug#debug('IMAGE', 'Error running timg fallback: ' . output)
                " Fallback to ASCII art
                call visidian#graph#PlotData(a:data, a:0 > 0 ? a:1 : '')
                return
            endif
        endif
    elseif executable('timg')
        " Use regular timg
        let timg_cmd = 'timg -g' . width . 'x' . height . ' --clear ' . pngfile
        let output = system(timg_cmd)
        
        if v:shell_error != 0
            call visidian#debug#debug('IMAGE', 'Error running timg: ' . output)
            " Fallback to ASCII art
            call visidian#graph#PlotData(a:data, a:0 > 0 ? a:1 : '')
            return
        endif
    else
        " Fallback to ASCII art if no image display is available
        call visidian#graph#PlotData(a:data, a:0 > 0 ? a:1 : '')
        return
    endif

    " Clear buffer and insert output
    silent! %delete _
    silent! 0put =output
    normal! gg
    setlocal nomodifiable

    " Clean up temporary files
    call delete(datafile)
    call delete(scriptfile)
    call delete(pngfile)

    call visidian#debug#debug('IMAGE', 'Completed display_graph')
endfunction

" Function: visidian#image#check_dependencies
" Description: Check if required Python dependencies are available
" Returns: 1 if all dependencies are met, 0 otherwise
function! visidian#image#check_dependencies()
    call visidian#debug#debug('IMAGE', 'Checking Python and Pillow dependencies')
    if !has('python3')
        call visidian#debug#error('IMAGE', 'Python3 support required for image preview')
        echohl ErrorMsg
        echom '🔧 Visidian Image Preview needs Python3! Please compile Vim with Python3 support.'
        echohl None
        return 0
    endif

python3 << EOF
import vim
try:
    from PIL import Image
    vim.command('let l:has_pillow = 1')
    vim.command("call visidian#debug#debug('IMAGE', 'Successfully imported PIL')")
except ImportError as e:
    vim.command('let l:has_pillow = 0')
    vim.command("call visidian#debug#error('IMAGE', 'PIL import error')")
    vim.command("echohl WarningMsg")
    vim.command("echom '📦 Visidian Image Preview needs the Pillow library! Install it with:'")
    vim.command("echohl None")
    vim.command("echom '   pip install Pillow'")
EOF

    let has_deps = exists('l:has_pillow') && l:has_pillow
    call visidian#debug#debug('IMAGE', 'Dependency check result: ' . (has_deps ? 'OK' : 'Failed'))
    return has_deps
endfunction

" Function: visidian#image#display_image
" Description: Display an image file in a buffer using ASCII art
" Parameters:
"   - image_path: Path to the image file
function! visidian#image#display_image()
    " Direct echo test
    echom "DIRECT TEST: Image display function called"
    echohl ErrorMsg
    echom "TEST MESSAGE: Image function called"
    echohl None
    
    " Test debug message
    call visidian#debug#error('IMAGE', 'TEST: Image display function called')
    call visidian#debug#debug('IMAGE', 'Starting image display process')
    
    if !visidian#image#check_dependencies()
        call visidian#debug#error('IMAGE', 'Dependencies check failed')
        return
    endif

    let image_path = expand('%:p')
    call visidian#debug#debug('IMAGE', 'Attempting to display image: ' . image_path)

    if !filereadable(image_path)
        call visidian#debug#error('IMAGE', 'Cannot read image file: ' . image_path)
        echohl ErrorMsg
        echom '❌ Oops! Cannot read image: ' . fnamemodify(image_path, ':t')
        echohl None
        return
    endif

python3 << EOF
import vim
from PIL import Image
import os

def create_ascii_image(image_path, max_width=None, max_height=None):
    try:
        vim.command("call visidian#debug#debug('IMAGE', 'Python: Starting ASCII conversion')")
        
        # Open the image with detailed error handling
        try:
            img = Image.open(image_path)
            vim.command("call visidian#debug#debug('IMAGE', 'Opened image successfully')")
        except FileNotFoundError:
            vim.command("call visidian#debug#error('IMAGE', 'File not found')")
            vim.command("echohl ErrorMsg")
            vim.command("echom '😕 Sorry! Could not find the image file.'")
            vim.command("echohl None")
            return
        except Exception as e:
            vim.command("call visidian#debug#error('IMAGE', 'Error opening image')")
            vim.command("echohl ErrorMsg")
            vim.command("echom '😕 Sorry! Could not open the image.'")
            vim.command("echohl None")
            return

        # Convert to grayscale first for better quality
        img = img.convert('L')
        
        # Get terminal dimensions
        term_width = int(vim.eval('&columns'))
        term_height = int(vim.eval('&lines'))
        
        # Calculate dimensions while maintaining aspect ratio
        img_width, img_height = img.size
        aspect_ratio = img_height / float(img_width)
        
        # Calculate new dimensions
        new_width = min(term_width - 4, img_width)
        new_height = int(new_width * aspect_ratio * 0.45)
        
        # Ensure height fits in terminal
        if new_height > term_height - 4:
            new_height = term_height - 4
            new_width = int(new_height / (aspect_ratio * 0.45))
        
        # Resize image
        img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Get pixel data
        pixels = list(img.getdata())
        pixels = [pixels[i:i + new_width] for i in range(0, len(pixels), new_width)]
        
        # ASCII chars (darkest to lightest)
        ascii_chars = '@%#*+=-:. '  # Reversed for dark terminal
        char_width = len(ascii_chars) - 1
        
        # Convert to ASCII art with proper encoding
        ascii_img = []
        for row in pixels:
            ascii_row = []
            for pixel in row:
                # Map pixel value to ASCII char
                char_idx = min(int(pixel / 255.0 * char_width), char_width)
                ascii_row.append(ascii_chars[char_idx])
            ascii_img.append(''.join(ascii_row))
        
        # Prepare buffer content with proper encoding
        header = [
            f'Image: {os.path.basename(image_path)}',
            f'Size: {img_width}x{img_height}',
            f'ASCII Size: {new_width}x{new_height}',
            ''
        ]
        
        # Clear and set buffer content safely
        vim.command('setlocal modifiable')
        vim.current.buffer[:] = header + ascii_img
        vim.command('setlocal nomodifiable')
        
        # Set buffer options
        vim.command('setlocal nowrap')
        vim.command('setlocal buftype=nofile')
        vim.command('setlocal nonumber')
        vim.command('setlocal norelativenumber')
        vim.command('setlocal signcolumn=no')
        
        # Success message
        vim.command("echohl MoreMsg")
        vim.command("echom '✨ ASCII art conversion complete!'")
        vim.command("echohl None")

    except Exception as e:
        vim.command("call visidian#debug#error('IMAGE', 'Error in ASCII conversion')")
        vim.command("echohl ErrorMsg")
        vim.command("echom '😢 Something went wrong while creating ASCII art'")
        vim.command("echohl None")
EOF
endfunction

" Function: visidian#image#setup_autocmds
" Description: Set up autocommands for image handling
function! visidian#image#setup_autocmds()
    call visidian#debug#debug('IMAGE', 'Setting up image autocommands')
    
    " Only set up autocommands if dependencies are met
    if !visidian#image#check_dependencies()
        call visidian#debug#info('IMAGE', 'Image preview disabled: missing dependencies')
        return
    endif

    augroup VisidianImage
        autocmd!
        autocmd BufReadPre *.png,*.jpg,*.jpeg,*.gif,*.bmp if !exists('g:visidian_disable_image_preview') | 
            \ let b:visidian_is_image = 1 |
            \ endif
        autocmd BufRead *.png,*.jpg,*.jpeg,*.gif,*.bmp if exists('b:visidian_is_image') |
            \ call visidian#image#display_image() |
            \ endif
    augroup END

    call visidian#debug#info('IMAGE', 'Image preview enabled')
    echohl MoreMsg
    echom '🖼️  Visidian Image Preview is ready! Open any image to see the magic ✨'
    echohl None
endfunction

" Initialize autocommands
call visidian#image#setup_autocmds()