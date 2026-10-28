# Instala o Illostrator para o usuario atual (sem precisar de administrador):
#   - o app em %LOCALAPPDATA%\Programs\Illostrator
#   - atalhos "Illostrator" no Menu Iniciar e na Area de Trabalho
#   - atualizacao automatica: ao entrar no Windows (pasta Inicializar) e todo dia ao meio-dia
#   - o servidor MCP "illostrator" no Claude Desktop: le a pasta Imagens e grava em
#     Imagens\Illostrator Claude
#
# Rodar de novo e seguro: atualiza tudo sem duplicar nada.
#
# No PowerShell:
#   irm https://raw.githubusercontent.com/PimentaBrrt/Illostrator/main/install/instalar.ps1 | iex
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Raw = 'https://raw.githubusercontent.com/PimentaBrrt/Illostrator/main/install'
$Dir = Join-Path $env:LOCALAPPDATA 'Programs\Illostrator'
$Exe = Join-Path $Dir 'Illostrator.exe'
$Cli = Join-Path $Dir 'illostrator-cli.exe'
$Updater = Join-Path $Dir 'atualizar.ps1'
$Run = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Updater`""

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
Invoke-WebRequest "$Raw/atualizar.ps1" -OutFile $Updater -UseBasicParsing
Invoke-WebRequest "$Raw/desinstalar.ps1" -OutFile (Join-Path $Dir 'desinstalar.ps1') -UseBasicParsing

Write-Host 'Baixando o Illostrator (uns 100 MB)...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Updater
if (-not (Test-Path $Exe)) { throw "Nao deu para baixar o Illostrator; veja $Dir\atualizar.log" }

$shell = New-Object -ComObject WScript.Shell
foreach ($folder in 'Programs', 'Desktop') {
  $link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath($folder)) 'Illostrator.lnk'))
  $link.TargetPath = $Exe
  $link.WorkingDirectory = $Dir
  $link.IconLocation = "$Exe,0"
  $link.Description = 'Illostrator'
  $link.Save()
}
# O Windows guarda o icone de cada arquivo: sem isso, um icone novo no mesmo Illostrator.exe so aparece
# depois de reiniciar. atualizar.ps1 tem a mesma funcao para as atualizacoes.
try {
  if (-not ('Illostrator.Shell' -as [type])) {
    Add-Type -Namespace Illostrator -Name Shell -MemberDefinition '[DllImport("shell32.dll", CharSet = CharSet.Unicode)] public static extern void SHChangeNotify(int eventId, uint flags, string item1, IntPtr item2);'
  }
  foreach ($path in @($Exe, (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Illostrator.lnk'), (Join-Path ([Environment]::GetFolderPath('Programs')) 'Illostrator.lnk'))) {
    [Illostrator.Shell]::SHChangeNotify(0x2000, 0x1005, $path, [IntPtr]::Zero) # SHCNE_UPDATEITEM, SHCNF_PATHW | SHCNF_FLUSH
  }
  [Illostrator.Shell]::SHChangeNotify(0x8000000, 0x1000, $null, [IntPtr]::Zero) # SHCNE_ASSOCCHANGED, SHCNF_FLUSH
} catch {
  Write-Host "Aviso: se o icone antigo continuar na Area de Trabalho, ele muda depois de reiniciar o PC."
}

# Ao entrar no Windows: um atalho escondido na pasta Inicializar.
$startup = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'Illostrator - atualizar.lnk'))
$startup.TargetPath = 'powershell.exe'
$startup.Arguments = $Run
$startup.WindowStyle = 7
$startup.Save()

# Todo dia ao meio-dia (ou assim que o PC ligar, se estava desligado).
try {
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $Run
  $trigger = New-ScheduledTaskTrigger -Daily -At '12:00'
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
  Register-ScheduledTask -TaskName 'Illostrator - atualizar' -Action $action -Trigger $trigger -Settings $settings -Description 'Baixa a versao nova do Illostrator' -Force | Out-Null
} catch {
  Write-Host "Aviso: a tarefa diaria nao foi criada ($_). A atualizacao ainda roda ao entrar no Windows."
}

# O Claude Desktop le os servidores MCP de claude_desktop_config.json: em %APPDATA%\Claude, ou, na
# versao da Microsoft Store, dentro da pasta do pacote. As outras configuracoes do arquivo ficam; a
# primeira vez guarda uma copia em claude_desktop_config.json.antes-do-illostrator.
function Set-ClaudeServer([string] $Folder, $Server) {
  $path = Join-Path $Folder 'claude_desktop_config.json'
  $config = $null
  if (Test-Path $path) {
    $text = [IO.File]::ReadAllText($path)
    # JSON invalido para aqui, antes de mexer no arquivo.
    if ($text.Trim()) { $config = $text | ConvertFrom-Json }
    if (-not (Test-Path "$path.antes-do-illostrator")) { Copy-Item $path "$path.antes-do-illostrator" }
  }
  if (-not $config) { $config = New-Object PSObject }
  if (-not $config.mcpServers) { $config | Add-Member -NotePropertyName mcpServers -NotePropertyValue (New-Object PSObject) -Force }
  $config.mcpServers | Add-Member -NotePropertyName illostrator -NotePropertyValue $Server -Force
  New-Item -ItemType Directory -Force -Path $Folder | Out-Null
  # Sem isso, o Windows PowerShell 5.1 escreve listas como {"value": [...], "Count": n}.
  Remove-TypeData System.Array -ErrorAction SilentlyContinue
  [IO.File]::WriteAllText($path, ($config | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
}

$claude = $false
if (Test-Path $Cli) {
  $pictures = [Environment]::GetFolderPath('MyPictures')
  $output = Join-Path $pictures 'Illostrator Claude'
  New-Item -ItemType Directory -Force -Path $output | Out-Null
  $server = [pscustomobject]@{
    command = $Cli
    args = @('mcp', '--automation-read-root', $pictures, '--automation-write-root', $output)
  }
  $folders = @(Join-Path $env:APPDATA 'Claude')
  $folders += @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'LocalCache\Roaming\Claude' } | Where-Object { Test-Path $_ })
  foreach ($folder in $folders) {
    try {
      Set-ClaudeServer $folder $server
      $claude = $true
    } catch {
      Write-Host "Aviso: nao deu para configurar o Claude Desktop em $folder ($_)."
    }
  }
} else {
  Write-Host 'Aviso: este Release ainda nao tem o servidor MCP; rode o instalador de novo depois da proxima versao.'
}

Write-Host 'Pronto! O Illostrator esta no Menu Iniciar e na Area de Trabalho.'
if ($claude) {
  Write-Host "No Claude Desktop: feche e abra o Claude (inclusive pelo icone perto do relogio) para ele ver o Illostrator."
  Write-Host "O Claude pode abrir as imagens da pasta Imagens e salva o que fizer em $output."
}
