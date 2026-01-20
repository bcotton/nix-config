# Load required zsh modules
autoload -U add-zsh-hook     # Enable hook functionality for zsh
autoload -Uz vcs_info        # Load version control information system

# Enable prompt substitution - allows dynamic updating of prompt
setopt promptsubst

# Define color variables for use in prompt
# %{ and %} tell zsh these sequences are non-printing characters (helps with prompt alignment)
# See spectrum_ls for a list of colors!
local reset white grey green red yellow
reset="%{${reset_color}%}"   # Reset to default terminal color
white="%{$fg_bold[white]%}"  # Bold white (brighter)
grey="$FG[252]"
green="%{$fg_bold[green]%}"  # Bold green
red="%{$fg[red]%}"          # Regular red
yellow="%{$fg[yellow]%}"    # Regular yellow

# Configure the version control info system (vcs_info)
zstyle ':vcs_info:*' enable git svn                           # Enable git and svn support
zstyle ':vcs_info:git*:*' get-revision true                  # Get git commit hash
zstyle ':vcs_info:git*:*' check-for-changes true             # Check for uncommitted changes
zstyle ':vcs_info:git*:*' stagedstr "${green}S${grey}"       # Show 'S' in green for staged changes
zstyle ':vcs_info:git*:*' unstagedstr "${red}U${grey}"       # Show 'U' in red for unstaged changes
# Register custom hooks for additional git status information
zstyle ':vcs_info:git*+set-message:*' hooks git-st git-stash git-username

# Format string for vcs_info
# %s = version control system (git)
# %12.12i = first 12 chars of commit hash
# %c = staged changes indicator
# %u = unstaged changes indicator
# %b = branch name
# %m = misc (used by hooks)
zstyle ':vcs_info:git*' formats "(%s) %12.12i %c%u %b%m"
# Format during git operations (rebase, merge, etc)
# %a = current action (rebase, merge, etc)
zstyle ':vcs_info:git*' actionformats "(%s|${white}%a${grey}) %12.12i %c%u %b%m"

# Register the precmd hook to update prompt before each command
add-zsh-hook precmd theme_precmd

# Custom hook function to show remote tracking info
# Shows how many commits ahead/behind the remote branch we are
function +vi-git-st() {
    local ahead behind remote
    local -a gitstatus

    # Check if current branch is tracking a remote branch
    remote=${$(git rev-parse --verify ${hook_com[branch]}@{upstream} \
        --symbolic-full-name --abbrev-ref 2>/dev/null)}

    if [[ -n ${remote} ]] ; then
        # Count commits ahead of remote
        ahead=$(git rev-list ${hook_com[branch]}@{upstream}..HEAD 2>/dev/null | wc -l | sed -e 's/^[[:blank:]]*//')
        (( $ahead )) && gitstatus+=( "${green}+${ahead}${grey}" )

        # Count commits behind remote
        behind=$(git rev-list HEAD..${hook_com[branch]}@{upstream} 2>/dev/null | wc -l | sed -e 's/^[[:blank:]]*//')
        (( $behind )) && gitstatus+=( "${red}-${behind}${grey}" )

        # Add remote tracking info to branch name
        hook_com[branch]="${hook_com[branch]} [${remote} ${(j:/:)gitstatus}]"
    fi
}

# Custom hook function to show count of stashed changes
function +vi-git-stash() {
    local -a stashes

    # Check if stash exists and count entries
    if [[ -s ${hook_com[base]}/.git/refs/stash ]] ; then
        stashes=$(git stash list 2>/dev/null | wc -l | sed -e 's/^[[:blank:]]*//')
        hook_com[misc]+=" (${stashes} stashed)"
    fi
}

# Custom hook function to show local git user.name
function +vi-git-username() {
    local -a username

    # Get local git user.name, truncate if longer than 40 chars
    username=$(git config --local --get user.name | sed -e 's/\(.\{40\}\).*/\1.../')
    hook_com[misc]+=" ($username)"
}

# Function to set the prompt string
function setprompt() {
    local -a lines infoline
    local x i filler i_width i_pad
    
    # Build the information line
    # %n = username
    infoline+=( "-- %n" )
    # %m = hostname
    infoline+=( "@${red}%m${reset}" )

    # Add current directory to info line
    # %3~ = show last 3 components of current directory
    # Color yellow if not writable, green if writable
    [[ -w $PWD ]] && infoline+=( ${green} ) || infoline+=( ${yellow} )
    infoline+=( " (%3~)${reset} " )

    # Add kubernetes context if available (from kube_ps1 function)
    infoline+=("$(kube_ps1)")

    # Calculate width of info line (excluding color escape sequences)
    i_width=${(S)infoline//\%\{*\%\}} # Remove color escapes
    i_width=${#${(%)i_width}}         # Expand remaining % escapes and count chars

    # Create filler of dashes to pad to terminal width
    filler="${grey}${(l:$(( $COLUMNS - $i_width ))::-:)}${reset}"
    infoline[4]=( "${infoline[4]} ${filler} " )

    # Assemble final prompt
    lines+=( ${(j::)infoline} )                               # Info line
    [[ -n ${vcs_info_msg_0_} ]] && lines+=( "${grey}${vcs_info_msg_0_}${reset}" )  # VCS info if available
    # Final prompt line:
    # %(1j. .) = show number of background jobs if any
    # %(0?. .) = show red prompt character if last command failed, white if succeeded
    lines+=( "%(1j.${grey}%j${reset} .)%(0?.${white}.${red})%#${reset} " )

    # Set the prompt
    PROMPT=${(F)lines}    # (F) joins lines with newlines
}

# Precmd hook function - runs before each prompt
theme_precmd () {
    vcs_info              # Update version control info
    setprompt            # Set the prompt
}
