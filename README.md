# Illostrator

Um editor de ilustração vetorial: caneta e curvas de Bézier, formas, texto, pincéis, efeitos e
arquivos SVG, PDF e AI.

Illostrator é o [VectorCraft](https://github.com/storytold/vectorcraft) (editor vetorial de código
aberto em Rust, MIT OR Apache-2.0) com outro nome, outro ícone e sem os links e o atualizador do
ArtCraft. Este repositório não guarda uma cópia do VectorCraft: guarda só as mudanças, e toda
semana o GitHub Actions aplica essas mudanças no VectorCraft mais novo, compila e publica um
Release. Assim as novidades do VectorCraft chegam sozinhas. É o irmão do
[Loloshop](https://github.com/PimentaBrrt/loloshop), feito do mesmo jeito.

## Instalar

No PowerShell:

```powershell
irm https://raw.githubusercontent.com/PimentaBrrt/Illostrator/main/install/instalar.ps1 | iex
```

Isso coloca o Illostrator no Menu Iniciar e na Área de Trabalho e liga a atualização automática
(ao entrar no Windows e todo dia ao meio-dia). Com o app aberto, a versão nova espera ele fechar.
O log fica em `%LOCALAPPDATA%\Programs\Illostrator\atualizar.log`. Rodar o comando de novo é
seguro: atualiza tudo sem duplicar nada. Para remover:
`%LOCALAPPDATA%\Programs\Illostrator\desinstalar.ps1`.

### No Claude Desktop

O instalador também registra o servidor MCP `illostrator` no Claude Desktop (o `vectorcraft-cli`
do VectorCraft, instalado como `illostrator-cli.exe`). Depois de fechar e abrir o Claude, dá para
pedir coisas como "desenha um logo de uma estrela com degradê no Illostrator e salva em SVG". O
Claude lê a pasta Imagens e só grava em `Imagens\Illostrator Claude`; ele não precisa do
Illostrator aberto.

## Como funciona

| Arquivo | O que faz |
|---|---|
| `layer/rename.sh` | Troca "VectorCraft" por "Illostrator" nos fontes Rust e nas traduções (com algumas exceções, explicadas no script) |
| `layer/illostrator.patch` | As mudanças de código feitas à mão: menu Ajuda, links do ArtCraft, Discord, atualizador desligado, metadados do `.exe`, traduções |
| `layer/BASE` | O commit do VectorCraft em que o patch foi feito |
| `layer/overlay/` | Arquivos que substituem os do VectorCraft (o ícone) |
| `layer/build-tree.sh` | Monta a árvore do Illostrator a partir de um commit do VectorCraft |
| `layer/make-patch.sh` | Salva mudanças de código como o novo `illostrator.patch` |
| `.github/workflows/release.yml` | Todo domingo: monta, testa, compila e publica o Release |
| `install/` | Instalação, atualização automática e registro no Claude Desktop, no Windows |

O workflow só publica quando o VectorCraft, a camada ou o próprio workflow mudaram, e só se a
compilação e os testes passarem. Se algo falhar, a última versão continua sendo a que ela recebe,
e o GitHub manda um e-mail avisando da falha.

## Compilar no Windows

Precisa do Rust e do Visual Studio Build Tools (C++). No Git Bash, monte a árvore; no PowerShell,
compile (no Git Bash, o `link` do coreutils atrapalha o linker do MSVC):

```bash
layer/build-tree.sh upstream main
```

```powershell
cd upstream; cargo run --release -p vectorcraft
```

## Quando o patch para de aplicar

Se o VectorCraft mudar um dos arquivos que o patch altera, o workflow falha com
`conflict: <arquivo>`. Para consertar:

```bash
layer/build-tree.sh upstream main          # falha e mostra os arquivos em conflito
cd upstream
git cherry-pick refs/illostrator/layer
# resolva os conflitos nos arquivos, depois:
git add -A && git -c user.name=x -c user.email=x@x cherry-pick --continue
cd .. && layer/make-patch.sh upstream      # grava o novo patch e o novo BASE
git add layer && git commit -m "Atualiza o patch" && git push
```

O push dispara uma build nova.

## Licença

O código do VectorCraft é MIT OR Apache-2.0 (veja o `NOTICE` e as licenças na árvore montada).
As mudanças e o ícone deste repositório seguem a mesma licença dupla.
