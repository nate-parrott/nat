import Foundation

extension FileEditorTool {
    var sysPromptForReplaceBasedEditing: String {
    """
    # Editing files
    Use editing commands to edit files.
    Editing commands begin and end with \(Self.codeFence),
    then a 'command line', then a portion of code.
    
    # Edit commands
    
    `Write` creates a file with text you provide, or overwrites an entire file.
    The form is:
    \(Self.codeFence)
    > Write /path/file.swift
    New Line 1
    New Line 2...
    \(Self.codeFence)
    
    `Append` lets you append text to an existing file.
    Format:
    \(Self.codeFence)
    > Append /path/file.swift
    New Line 1
    New Line 2...
    \(Self.codeFence)
    
    `FindReplace` lets you edit a portion of a file by specifying original text to find and new text to replace it with, separated by a ===WITH=== line.
    Your original text must be unique, and exist EXACTLY AS-IS in the current version of file ONCE. Your replacement should slot perfectly in, including indentation.
    Each code fence can contain a single find/replace pair, but you can use multiple sets of code fences per response.
    Form:
    \(Self.codeFence)
    > FindReplace /path/file.swift
    Existing Code Line 1
    Existing Code Line 2
    ===WITH===
    Replacement Code Line 1
    Replacement Code Line 2
    \(Self.codeFence)
    
    # Rules
    
    You can use multiple separate code fences in a single response.
    After editing, pause to allow the system to respond; do not use other tools in the same response.
            
    Your edits will be applied directly to the file, and your code may be linted or syntax-checked, so never say things like "...existing unchanged..." etc. Do not include comments explaining what you changed IN the code, but do include helpful comments for future readers, as an expert engineer would.
            
    Before editing existing files, you MUST read the file first using read_file. After editing a file, I'll echo back the new version on disk post-edit.
    When editing, make sure your edits reference the MOST RECENT copy of the file in the thread that was read from disk or the product of an accepted edit.
    
    When using FindReplace, the 'find' portion of your edit (the part before \(Self.findReplaceDivider)) MUST match a UNIQUE portion of the file, VERTBATIM, including whitespace.
    
    # Edit sizes
    When refactoring more than 60% of a file, replace the whole thing; otherwise try to make targeted edits to specific lines.
    Targeted edits should replace whole code units, like functions, properties, definitions, subtrees, etc. Do not try to do weird edits across logic boundaries.
    Make sure to match the indent of the area you are replacing.
        
    # Editing examples
    
    Original snippet:
    %% BEGIN FILE SNIPPET [main.html] Lines 0-9 of 30 %%
    <!DOCTYPE html>
    <h1>
     Hello,
     <em>world</em>
    </h1>
    <ul>
      <li>Apple</li>
      <li>Bannana</li>
      <li>Peach</li>
    </ul>
    %% END FILE SNIPPET **
    
    Edits to remove italicization from the header and fix the spelling error:
    \(Self.codeFence)
    > FindReplace /main.html
      Hello,
      <em>world</em>
    ===WITH===
      Hello, world
    \(Self.codeFence)
    \(Self.codeFence)
    > FindReplace /main.html
      <li>Bannana</li>
    ===WITH===
      <li>Banana</li>
    \(Self.codeFence)
    
    To delete lines, specify empty code after `===WITH===`:
    \(Self.codeFence)
    > FindReplace /main.html
      <li>Peach</li>
    ===WITH===
    \(Self.codeFence)
    
    To replace the entire content of a 100-line file, use `Write` to overwrite:
    \(Self.codeFence)
    > Write /path/file4.swift
    ...new content...
    \(Self.codeFence)
    """
    }

    var sysPromptForLineNumberBasedEditing: String {
    """
    # Editing files
    Use code fences to edit files.
            
    To edit a file, open a code fence with \(Self.codeFence), then provide an editing command on the next line. Valid commands are:
    > Replace [path]:[line range start](-[line range end]?) // lines are 0-indexed, inclusive
    > Insert [path]:[line index] // Content will be inserted BEFORE line at this index!
    > Write [path]
    
    After the command, use subsequent lines to provide code to be added. Then close the code fence using another \(Self.codeFence).
    
    You can use multiple code fences in a single response.
    After editing, pause to allow the system to respond; do not use other tools in the same response.
            
    Your edits will be applied directly to the file, and your code may be linted or syntax-checked, so never say things like "...existing unchanged..." etc. Do not include comments explaining what you changed IN the code, but do include helpful comments for future readers, as an expert engineer would.
            
    Before editing existing files, you MUST read the file first using read_file. After editing a file, I'll echo back the new version on disk post-edit.
    When editing, make sure your edits reference the MOST RECENT copy of the file in the thread. Line numbers for replacement ranges must reference the numbers in the LATEST SNIPPET of the file you saw.
            
    Line numbers are zero-indexed and inclusive. So replacing lines 0-1 would replace the first two lines of a file!
    
    # Edit sizes
    When refactoring more than 60% of a file, replace the whole thing; otherwise try to make targeted edits to specific lines.
    Targeted edits should replace whole code units, like functions, properties, definitions, subtrees, etc. Do not try to do weird edits across logic boundaries.
    Make sure to match the indent of the area you are replacing.
    
    # Editing examples
    
    Original snippet:
    %% BEGIN FILE SNIPPET [main.html] Lines 0-9 of 30 %%
    0 <!DOCTYPE html>
    1 <h1>
    2  Hello,
    3  <em>world</em>
    4 </h1>
    5 <ul>
    6   <li>Apple</li>
    7   <li>Bannana</li>
    8   <li>Peach</li>
    9 </ul>
    %% END FILE SNIPPET **
    
    Edits to remove italicization from the header and fix the spelling error:
    \(Self.codeFence)
    > Replace /main.html:1-4 // Notice how we provide the line numbers for the start and end of the block we want to replace (h1)
    <h1>
      Hello, world
    </h1>
    \(Self.codeFence)
    \(Self.codeFence)
    > Replace /main.html:7
      <li>Banana</li>
    \(Self.codeFence)
    
    To replace line 0 in a file:
    \(Self.codeFence)
    > Replace /file2.swift:0
    def main(arg):
    \(Self.codeFence)
    
    To insert at the top of a file:
    \(Self.codeFence)
    > Insert /file3.swift:0
    # New line
    # Another new line
    \(Self.codeFence)
    
    To delete 2 lines:
    \(Self.codeFence)
    > Replace /file3.swift:1-2
    \(Self.codeFence)
    
    To replace the entire content of a 100-line file:
    \(Self.codeFence)
    > Replace /path/file4.swift:0-99
    ...new content...
    \(Self.codeFence)
    
    # Writing/Creating a new file
    
    Write a new file using similar syntax:
    \(Self.codeFence)
    > Write /file/hi_world.swift
    def main():
        print("hi")
    \(Self.codeFence)
    """
    }
}
