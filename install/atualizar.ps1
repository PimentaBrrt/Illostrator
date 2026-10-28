# Illostrator: baixa a versao mais nova dos Releases do GitHub e instala quando o programa estiver fechado.
# Roda escondido ao entrar no Windows e todo dia ao meio-dia (instalar.ps1 configura isso).
# Cuida de dois arquivos, cada um trocado quando o seu processo estiver fechado:
#   Illostrator.exe      o app
#   illostrator-cli.exe  o servidor MCP que o Claude Desktop abre (fica aberto junto com o Claude)
# Com o programa aberto, a versao nova fica guardada e entra na proxima vez que este script rodar.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = 'PimentaBrrt/Illostrator'
$Dir = $PSScriptRoot
$Log = Join-Path $Dir 'atualizar.log'
$Files = @(
  @{ Asset = 'Illostrator-windows-x64.exe'; Name = 'Illostrator.exe'; Version = 'versao.txt' },
  @{ Asset = 'Illostrator-cli-windows-x64.exe'; Name = 'illostrator-cli.exe'; Version = 'versao-cli.txt' }
)

function Write-Log([string] $Message) {
  Add-Content -Path $Log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

function Read-Tag([string] $Path) {
  if (Test-Path $Path) { return (Get-Content $Path -Raw).Trim() }
  return ''
}

# O Windows guarda o icone de cada arquivo e nao percebe quando o Illostrator.exe muda: avisar o
# Explorer faz o .exe e os atalhos mostrarem o icone novo sem reiniciar (ie4uinit -show nao basta).
function Update-Icons {
  try {
    if (-not ('Illostrator.Shell' -as [type])) {
      Add-Type -Namespace Illostrator -Name Shell -MemberDefinition '[DllImport("shell32.dll", CharSet = CharSet.Unicode)] public static extern void SHChangeNotify(int eventId, uint flags, string item1, IntPtr item2);'
    }
    foreach ($path in @(
        (Join-Path $Dir 'Illostrator.exe'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Illostrator.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Programs')) 'Illostrator.lnk'))) {
      [Illostrator.Shell]::SHChangeNotify(0x2000, 0x1005, $path, [IntPtr]::Zero) # SHCNE_UPDATEITEM, SHCNF_PATHW | SHCNF_FLUSH
    }
    [Illostrator.Shell]::SHChangeNotify(0x8000000, 0x1000, $null, [IntPtr]::Zero) # SHCNE_ASSOCCHANGED, SHCNF_FLUSH
  } catch {
    Write-Log "nao deu para atualizar os icones: $_"
  }
}

try {
  $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'Illostrator-updater' }
  $tag = $release.tag_name
  foreach ($f in $Files) {
    $exe = Join-Path $Dir $f.Name
    $new = "$exe.new"
    $file = $release.assets | Where-Object { $_.name -eq $f.Asset } | Select-Object -First 1
    $wanted = ($tag -ne (Read-Tag (Join-Path $Dir $f.Version))) -or -not (Test-Path $exe)
    $ready = (Test-Path $new) -and ((Read-Tag "$new.txt") -eq $tag)
    if ($file -and $wanted -and -not $ready) {
      $part = "$new.part"
      Invoke-WebRequest $file.browser_download_url -OutFile $part -UseBasicParsing -Headers @{ 'User-Agent' = 'Illostrator-updater' }
      if ((Get-Item $part).Length -ne $file.size) { throw "download incompleto de $($f.Name) $tag" }
      Move-Item $part $new -Force
      Set-Content -Path "$new.txt" -Value $tag
      Write-Log "baixada $($f.Name) $tag"
    }
  }
} catch {
  Write-Log "nao deu para buscar atualizacao: $_"
}

foreach ($f in $Files) {
  $exe = Join-Path $Dir $f.Name
  $new = "$exe.new"
  if (-not (Test-Path $new)) { continue }
  $process = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  if (Get-Process -Name $process -ErrorAction SilentlyContinue) {
    Write-Log "$($f.Name) aberto; a versao nova entra na proxima vez"
    continue
  }
  try {
    Move-Item $new $exe -Force
    Move-Item "$new.txt" (Join-Path $Dir $f.Version) -Force
    Write-Log "instalada $($f.Name) $(Read-Tag (Join-Path $Dir $f.Version))"
    if ($f.Name -eq 'Illostrator.exe') { Update-Icons }
  } catch {
    Write-Log "nao deu para trocar $($f.Name): $_"
  }
}
