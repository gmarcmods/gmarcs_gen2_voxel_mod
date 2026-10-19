-- Ask the desktop for a folder. No in-game directory browser or path entry.
local Picker = {}

function Picker.open(platform, shell)
  platform = platform or love.system.getOS()
  shell = shell or require('src.core.HostShell')
  local command
  if platform == 'Linux' then
    -- Select the available provider first: cancel must not launch a fallback.
    -- HostShell may prefix commands with `env -u ...`; keep the compound
    -- provider probe inside an explicit shell so that prefix remains valid.
    command = [[sh -c 'if command -v zenity >/dev/null 2>&1; then exec zenity --file-selection --directory --title="Select a folder for the voxel mod"; elif command -v kdialog >/dev/null 2>&1; then exec kdialog --getexistingdirectory . --title "Select a folder for the voxel mod"; else printf "__VOXEL_PICKER_UNAVAILABLE__\n"; fi']]
  elseif platform == 'OS X' then
    command = [[osascript -e 'POSIX path of (choose folder with prompt "Select a folder for the voxel mod")']]
  elseif platform == 'Windows' then
    command = [[powershell -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description='Select a folder for the voxel mod'; if($d.ShowDialog() -eq 'OK'){[Console]::OutputEncoding=[Text.Encoding]::UTF8; [Console]::Write($d.SelectedPath)}"]]
  else
    return nil, 'System folder selection is unavailable on this platform'
  end
  local pipe = shell.popen(command)
  if not pipe then return nil, 'Could not open the system folder chooser' end
  local ok, result = pcall(pipe.read, pipe, '*a')
  shell.pclose(pipe)
  if not ok then return nil, tostring(result) end
  result = (result or ''):gsub('\r?\n$', '')
  if result == '__VOXEL_PICKER_UNAVAILABLE__' then
    return nil, 'Install zenity or kdialog to use the system folder chooser'
  end
  if result == '' then return nil end -- User cancelled; keep the document.
  return result
end

return Picker
